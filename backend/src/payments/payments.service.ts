import {
    BadRequestException,
    ConflictException,
    Inject,
    Injectable,
    Logger,
    NotFoundException,
    ServiceUnavailableException,
    UnauthorizedException,
} from '@nestjs/common';
import { IsString, IsUUID, Length, Matches } from 'class-validator';
import { createHash } from 'crypto';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../database/database.service';
import { DeliveryService } from '../delivery/delivery.service';
import { NotificationsService } from '../notifications/notifications.service';
import {
    PAYMENT_PROVIDER,
    PaymentProvider,
    ProviderIntent,
    VerifiedPaymentEvent,
} from './payment-provider';

export class CreatePaymentIntentDto {
    @IsUUID()
    orderId!: string;

    @IsString()
    @Length(8, 128)
    @Matches(/^[A-Za-z0-9._:-]+$/)
    idempotencyKey!: string;
}

export interface PaymentRecord {
    id: string;
    orderId: string;
    status: 'creating' | 'pending' | 'succeeded' | 'failed' | 'cancelled';
    provider: string;
    providerPaymentId: string | null;
    amount: number;
    currency: string;
    checkoutUrl: string | null;
    failureCode: string | null;
    createdAt: string;
}

interface PaymentRow extends QueryResultRow {
    id: string;
    order_id: string;
    customer_id: string;
    provider: string;
    idempotency_key: string;
    provider_payment_id: string | null;
    status: PaymentRecord['status'];
    amount: string | number;
    currency: string;
    checkout_url: string | null;
    failure_code: string | null;
    created_at: Date | string;
}

interface OrderPaymentRow extends QueryResultRow {
    id: string;
    status: string;
    payment_method: string;
    total: string | number;
    currency: string;
    checkout_session_id: string;
}

@Injectable()
export class PaymentsService {
    private readonly logger = new Logger(PaymentsService.name);

    constructor(
        private readonly database: DatabaseService,
        private readonly deliveryService: DeliveryService,
        private readonly notificationsService: NotificationsService,
        @Inject(PAYMENT_PROVIDER) private readonly provider: PaymentProvider,
    ) { }

    async createIntent(customerId: string, dto: CreatePaymentIntentDto): Promise<PaymentRecord> {
        if (!this.provider.configured) {
            throw new ServiceUnavailableException('Payment processing is not configured');
        }

        const reservation = await this.database.withTransaction(async (client) => {
            await client.query(
                'SELECT pg_advisory_xact_lock(hashtext($1))',
                [`payment:${customerId}:${dto.idempotencyKey}`],
            );
            const existing = await client.query<PaymentRow>(
                'SELECT * FROM payments WHERE customer_id = $1 AND idempotency_key = $2',
                [customerId, dto.idempotencyKey],
            );
            if (existing.rows[0]) {
                if (existing.rows[0].order_id !== dto.orderId) {
                    throw new ConflictException('Idempotency key was already used for a different order');
                }
                return {
                    row: existing.rows[0],
                    created: existing.rows[0].status === 'creating',
                };
            }

            const orderResult = await client.query<OrderPaymentRow>(
                `
                    SELECT id, status, payment_method, total, currency, checkout_session_id
                    FROM orders
                    WHERE id = $1 AND customer_id = $2
                    FOR UPDATE
                `,
                [dto.orderId, customerId],
            );
            const order = orderResult.rows[0];
            if (!order) {
                throw new NotFoundException('Order not found');
            }
            if (order.payment_method !== 'card') {
                throw new BadRequestException('Only card orders can create a payment intent');
            }
            if (order.status !== 'payment_pending') {
                throw new ConflictException('Order is not awaiting payment');
            }

            const inserted = await client.query<PaymentRow>(
                `
                    INSERT INTO payments (
                        order_id, customer_id, provider, idempotency_key,
                        status, amount, currency
                    ) VALUES ($1, $2, $3, $4, 'creating', $5, $6)
                    RETURNING *
                `,
                [order.id, customerId, this.provider.name, dto.idempotencyKey, order.total, order.currency],
            );
            return {
                row: inserted.rows[0],
                created: true,
                order,
            };
        });

        if (!reservation.created) {
            return this.toRecord(reservation.row);
        }

        try {
            const intent = await this.provider.createIntent({
                paymentId: reservation.row.id,
                orderId: reservation.row.order_id,
                customerId,
                amount: Number(reservation.row.amount),
                currency: reservation.row.currency,
                idempotencyKey: dto.idempotencyKey,
            });
            const updated = await this.database.query<PaymentRow>(
                `
                    UPDATE payments
                    SET provider_payment_id = $2, checkout_url = $3,
                        status = 'pending', updated_at = NOW()
                    WHERE id = $1 AND status = 'creating'
                    RETURNING *
                `,
                [reservation.row.id, intent.providerPaymentId, intent.checkoutUrl],
            );
            if (!updated.rows[0]) {
                const current = await this.database.query<PaymentRow>(
                    'SELECT * FROM payments WHERE id = $1',
                    [reservation.row.id],
                );
                if (
                    current.rows[0]?.status === 'pending'
                    && current.rows[0].provider_payment_id === intent.providerPaymentId
                ) {
                    return this.toRecord(current.rows[0]);
                }
                throw new ConflictException('Payment intent changed while it was being created');
            }
            return this.toRecord(updated.rows[0]);
        } catch (error) {
            await this.database.query(
                `
                    UPDATE payments
                    SET status = 'failed', failure_code = 'provider_error', updated_at = NOW()
                    WHERE id = $1 AND status = 'creating'
                `,
                [reservation.row.id],
            );
            this.logger.error('Payment intent creation failed for a persisted intent');
            if (error instanceof ServiceUnavailableException || error instanceof ConflictException) {
                throw error;
            }
            throw new ServiceUnavailableException('Payment intent could not be created');
        }
    }

    async processWebhook(rawBody: Buffer | undefined, signature: string | undefined) {
        if (!this.provider.configured) {
            throw new ServiceUnavailableException('Payment webhook processing is not configured');
        }
        if (!rawBody || !Buffer.isBuffer(rawBody) || !signature) {
            throw new BadRequestException('A raw webhook body and signature are required');
        }

        let event: VerifiedPaymentEvent;
        try {
            event = this.provider.verifyWebhook(rawBody, signature);
        } catch {
            throw new UnauthorizedException('Invalid payment webhook signature or payload');
        }

        const payloadSha256 = createHash('sha256').update(rawBody).digest('hex');
        return this.database.withTransaction(async (client) => {
            const paymentResult = await client.query<PaymentRow>(
                `
                    SELECT *
                    FROM payments
                    WHERE provider = $1 AND provider_payment_id = $2
                    FOR UPDATE
                `,
                [this.provider.name, event.paymentId],
            );
            const payment = paymentResult.rows[0];
            if (!payment) {
                throw new NotFoundException('Payment intent not found');
            }
            if (
                Number(payment.amount) !== event.amount
                || payment.currency.toUpperCase() !== event.currency.toUpperCase()
            ) {
                throw new ConflictException('Payment webhook amount or currency does not match the intent');
            }

            const recordedEvent = await client.query<{ id: string }>(
                `
                    INSERT INTO payment_webhook_events (
                        provider, provider_event_id, payment_id, event_type, payload_sha256
                    ) VALUES ($1, $2, $3, $4, $5)
                    ON CONFLICT (provider, provider_event_id) DO NOTHING
                    RETURNING id
                `,
                [this.provider.name, event.eventId, payment.id, event.type, payloadSha256],
            );
            if (!recordedEvent.rows[0]) {
                const previousEvent = await client.query<{ payload_sha256: string }>(
                    'SELECT payload_sha256 FROM payment_webhook_events WHERE provider = $1 AND provider_event_id = $2',
                    [this.provider.name, event.eventId],
                );
                if (previousEvent.rows[0]?.payload_sha256 !== payloadSha256) {
                    throw new ConflictException('Payment webhook event ID was reused with a different payload');
                }
                return { accepted: true, duplicate: true, payment: this.toRecord(payment) };
            }

            if (payment.status !== 'pending') {
                if (payment.status === (event.type === 'payment.succeeded' ? 'succeeded' : 'failed')) {
                    return { accepted: true, duplicate: false, payment: this.toRecord(payment) };
                }
                throw new ConflictException('Payment is no longer pending');
            }

            const succeeded = event.type === 'payment.succeeded';
            const order = await client.query<OrderPaymentRow>(
                'SELECT id, status, payment_method, total, currency, checkout_session_id FROM orders WHERE id = $1 FOR UPDATE',
                [payment.order_id],
            );
            if (!order.rows[0] || order.rows[0].status !== 'payment_pending') {
                throw new ConflictException('Order is no longer awaiting payment');
            }
            await client.query(
                `
                    UPDATE payments
                    SET status = $2, failure_code = $3, updated_at = NOW()
                    WHERE id = $1
                `,
                [payment.id, succeeded ? 'succeeded' : 'failed', succeeded ? null : 'provider_declined'],
            );
            if (succeeded) {
                await client.query(
                    "UPDATE orders SET status = 'paid', updated_at = NOW() WHERE id = $1",
                    [payment.order_id],
                );
                await client.query(
                    "UPDATE checkout_sessions SET status = 'confirmed', updated_at = NOW() WHERE id = $1",
                    [order.rows[0].checkout_session_id],
                );
                const zone = await client.query<{ estimated_minutes: number }>(
                    `
                        SELECT z.estimated_minutes
                        FROM orders o
                        JOIN delivery_zones z
                          ON o.delivery_zone_snapshot->>'id' = z.id
                        WHERE o.id = $1
                    `,
                    [payment.order_id],
                );
                if (zone.rows[0]) {
                    await this.deliveryService.createForOrder(client, {
                        id: payment.order_id,
                        customerId: payment.customer_id,
                        estimatedMinutes: zone.rows[0].estimated_minutes,
                    });
                }
            }
            await this.notificationsService.create(client, {
                customerId: payment.customer_id,
                type: succeeded ? 'payment_succeeded' : 'payment_failed',
                title: succeeded ? 'Payment received' : 'Payment failed',
                body: succeeded
                    ? 'Payment for your order was confirmed.'
                    : 'Payment was not completed. You can try another payment attempt.',
                data: { orderId: payment.order_id, paymentId: payment.id },
                deduplicationKey: `payment:${payment.id}:${succeeded ? 'succeeded' : 'failed'}`,
            });

            return {
                accepted: true,
                duplicate: false,
                payment: {
                    ...this.toRecord(payment),
                    status: succeeded ? 'succeeded' : 'failed',
                    failureCode: succeeded ? null : 'provider_declined',
                },
            };
        });
    }

    async getPayments(customerId: string, orderId: string) {
        const order = await this.database.query<{ id: string }>(
            'SELECT id FROM orders WHERE id = $1 AND customer_id = $2',
            [orderId, customerId],
        );
        if (!order.rows[0]) {
            throw new NotFoundException('Order not found');
        }
        const result = await this.database.query<PaymentRow>(
            'SELECT * FROM payments WHERE customer_id = $1 AND order_id = $2 ORDER BY created_at DESC, id DESC',
            [customerId, orderId],
        );
        return { items: result.rows.map((row) => this.toRecord(row)) };
    }

    private toRecord(row: PaymentRow): PaymentRecord {
        return {
            id: row.id,
            orderId: row.order_id,
            status: row.status,
            provider: row.provider,
            providerPaymentId: row.provider_payment_id,
            amount: Number(row.amount),
            currency: row.currency,
            checkoutUrl: row.checkout_url,
            failureCode: row.failure_code,
            createdAt: new Date(row.created_at).toISOString(),
        };
    }
}
