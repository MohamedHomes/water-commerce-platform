import {
    BadRequestException,
    Injectable,
    NotFoundException,
} from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsIn, IsOptional, IsString, IsUUID } from 'class-validator';
import { randomUUID } from 'crypto';
import { QueryResultRow } from 'pg';
import { AddressService } from '../address/address.service';
import { CartResponse, CartService } from '../cart/cart.service';
import { DatabaseService } from '../database/database.service';

export class PrepareCheckoutDto {
    @IsString()
    @IsUUID()
    addressId!: string;

    @IsOptional()
    @IsString()
    deliveryZoneId?: string;

    @Type(() => String)
    @IsString()
    @IsIn(['standard', 'express'])
    deliveryOption!: 'standard' | 'express';

    @Type(() => String)
    @IsString()
    @IsIn(['card', 'cash'])
    paymentMethod!: 'card' | 'cash';
}

export interface CheckoutSummary {
    subtotal: number;
    deliveryFee: number;
    serviceFee: number;
    total: number;
    currency: string;
}

export interface CheckoutSessionRecord {
    checkoutId: string;
    customerId: string;
    addressId: string;
    deliveryZoneId: string | null;
    cart: CartResponse;
    summary: CheckoutSummary;
    deliveryOption: 'standard' | 'express';
    paymentMethod: 'card' | 'cash';
    status: 'draft' | 'payment_pending' | 'confirmed' | 'expired' | 'cancelled';
    expiresAt: string;
}

interface CheckoutRow extends QueryResultRow {
    id: string;
    customer_id: string;
    address_id: string;
    delivery_zone_id: string | null;
    cart_snapshot: CartResponse;
    subtotal: string | number;
    delivery_fee: string | number;
    service_fee: string | number;
    total: string | number;
    currency: string;
    payment_method: 'card' | 'cash';
    delivery_option: 'standard' | 'express';
    status: 'draft' | 'expired' | 'payment_pending' | 'confirmed' | 'cancelled';
    expires_at: Date | string;
}

@Injectable()
export class CheckoutService {
    private readonly serviceFeeRate = Number(process.env.AQUAFLOW_SERVICE_FEE_RATE ?? 0);

    constructor(
        private readonly database: DatabaseService,
        private readonly cartService: CartService,
        private readonly addressService: AddressService,
    ) { }

    async getCheckoutSession(userId: string, checkoutId: string) {
        const result = await this.database.query<CheckoutRow>(
            `
                SELECT id, customer_id, address_id, delivery_zone_id, cart_snapshot,
                    subtotal, delivery_fee, service_fee, total, currency, payment_method,
                    delivery_option, status, expires_at
                FROM checkout_sessions
                WHERE id = $1 AND customer_id = $2
            `,
            [checkoutId, userId],
        );
        const row = result.rows[0];
        if (!row) {
            throw new NotFoundException('Checkout session not found');
        }
        if (row.status === 'draft' && new Date(row.expires_at).getTime() <= Date.now()) {
            await this.database.query(
                "UPDATE checkout_sessions SET status = 'expired', updated_at = NOW() WHERE id = $1 AND customer_id = $2",
                [checkoutId, userId],
            );
            throw new BadRequestException('Checkout session has expired');
        }
        return this.toSession(row);
    }

    async prepareCheckout(userId: string, dto: PrepareCheckoutDto) {
        return this.database.withTransaction(async (client) => {
            await client.query(
                "SELECT id FROM carts WHERE customer_id = $1 AND status = 'active' FOR UPDATE",
                [userId],
            );
            const cart = await this.cartService.getCart(userId, client);
            if (!cart.items.length) {
                throw new BadRequestException('Cart is empty');
            }
            const validation = await this.cartService.validateCart(userId, client);
            if (!validation.valid) {
                throw new BadRequestException(validation.errors.join('; '));
            }
            const address = await this.addressService.getAddressById(userId, dto.addressId, client);
            const deliveryZone = await this.addressService.resolveDeliveryZone(address.city, dto.deliveryZoneId, client);

            const subtotal = cart.summary.total;
            const deliveryFee = deliveryZone.baseFee
                + (dto.deliveryOption === 'express' ? deliveryZone.expressFee ?? 0 : 0);
            const serviceFee = Number((subtotal * this.serviceFeeRate).toFixed(2));
            const total = Number((subtotal + deliveryFee + serviceFee).toFixed(2));
            const expiresAt = new Date(Date.now() + 30 * 60 * 1000);
            const summary: CheckoutSummary = {
                subtotal: Number(subtotal.toFixed(2)),
                deliveryFee: Number(deliveryFee.toFixed(2)),
                serviceFee,
                total,
                currency: 'SAR',
            };
            const checkoutId = randomUUID();
            const result = await client.query<CheckoutRow>(
                `
                    INSERT INTO checkout_sessions (
                        id, customer_id, address_id, delivery_zone_id, cart_snapshot,
                        subtotal, delivery_fee, service_fee, total, currency, payment_method,
                        delivery_option, status, expires_at
                    ) VALUES ($1, $2, $3, $4, $5::jsonb, $6, $7, $8, $9, $10, $11, $12, 'draft', $13)
                    RETURNING id, customer_id, address_id, delivery_zone_id, cart_snapshot,
                        subtotal, delivery_fee, service_fee, total, currency, payment_method,
                        delivery_option, status, expires_at
                `,
                [
                    checkoutId, userId, address.id, deliveryZone.id, JSON.stringify(cart),
                    summary.subtotal, summary.deliveryFee, summary.serviceFee, summary.total,
                    summary.currency, dto.paymentMethod, dto.deliveryOption, expiresAt,
                ],
            );

            return {
                checkoutId,
                customerId: userId,
                address,
                cart,
                deliveryZone,
                deliveryOption: dto.deliveryOption,
                paymentMethod: dto.paymentMethod,
                summary,
                valid: true,
                status: result.rows[0].status,
                expiresAt: new Date(result.rows[0].expires_at).toISOString(),
            };
        });
    }

    private toSession(row: CheckoutRow): CheckoutSessionRecord {
        return {
            checkoutId: row.id,
            customerId: row.customer_id,
            addressId: row.address_id,
            deliveryZoneId: row.delivery_zone_id,
            cart: row.cart_snapshot,
            summary: {
                subtotal: Number(row.subtotal),
                deliveryFee: Number(row.delivery_fee),
                serviceFee: Number(row.service_fee),
                total: Number(row.total),
                currency: row.currency,
            },
            deliveryOption: row.delivery_option,
            paymentMethod: row.payment_method,
            status: row.status,
            expiresAt: new Date(row.expires_at).toISOString(),
        };
    }
}
