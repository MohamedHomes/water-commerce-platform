import {
    BadRequestException,
    Injectable,
    NotFoundException,
} from '@nestjs/common';
import { Transform, Type } from 'class-transformer';
import { IsIn, IsOptional, IsString, IsUUID, Matches, MaxLength } from 'class-validator';
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

    @IsOptional()
    @Transform(({ value }) => (typeof value === 'string' ? value.trim().toUpperCase() : value))
    @IsString()
    @MaxLength(64)
    @Matches(/^[A-Z0-9_-]+$/)
    promotionCode?: string;

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
    discount: number;
    promotionCode?: string;
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
    discount_amount: string | number;
    promotion_id: string | null;
    promotion_code: string | null;
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
                    subtotal, discount_amount, promotion_id, promotion_code,
                    delivery_fee, service_fee, total, currency, payment_method,
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
            let promotionId: string | null = null;
            let promotionCode: string | undefined;
            let discount = 0;
            if (dto.promotionCode) {
                const promotionResult = await client.query<{
                    id: string;
                    code: string;
                    discount_type: 'percentage' | 'fixed';
                    discount_value: string | number;
                    max_discount: string | number | null;
                    minimum_subtotal: string | number;
                    max_redemptions: number | null;
                    max_per_customer: number;
                }>(
                    `
                        SELECT id, code, discount_type, discount_value, max_discount,
                            minimum_subtotal, max_redemptions, max_per_customer
                        FROM promotions
                        WHERE UPPER(code) = $1 AND is_active = TRUE
                            AND starts_at <= NOW() AND (ends_at IS NULL OR ends_at > NOW())
                        FOR SHARE
                    `,
                    [dto.promotionCode],
                );
                const promotion = promotionResult.rows[0];
                if (!promotion || subtotal < Number(promotion.minimum_subtotal)) {
                    throw new BadRequestException('Promotion code is invalid or unavailable');
                }
                const [redemptionCount, customerRedemptionCount] = await Promise.all([
                    client.query<{ count: string }>(
                        'SELECT COUNT(*)::text AS count FROM promotion_redemptions WHERE promotion_id = $1',
                        [promotion.id],
                    ),
                    client.query<{ count: string }>(
                        'SELECT COUNT(*)::text AS count FROM promotion_redemptions WHERE promotion_id = $1 AND customer_id = $2',
                        [promotion.id, userId],
                    ),
                ]);
                if ((promotion.max_redemptions !== null
                        && Number(redemptionCount.rows[0].count) >= promotion.max_redemptions)
                    || Number(customerRedemptionCount.rows[0].count) >= promotion.max_per_customer) {
                    throw new BadRequestException('Promotion code is invalid or unavailable');
                }
                const rawDiscount = promotion.discount_type === 'percentage'
                    ? subtotal * Number(promotion.discount_value) / 100
                    : Number(promotion.discount_value);
                discount = Number(Math.min(
                    subtotal,
                    promotion.max_discount === null ? rawDiscount : Math.min(rawDiscount, Number(promotion.max_discount)),
                ).toFixed(2));
                promotionId = promotion.id;
                promotionCode = promotion.code;
            }
            const deliveryFee = deliveryZone.baseFee
                + (dto.deliveryOption === 'express' ? deliveryZone.expressFee ?? 0 : 0);
            const serviceFee = Number(((subtotal - discount) * this.serviceFeeRate).toFixed(2));
            const total = Number((subtotal - discount + deliveryFee + serviceFee).toFixed(2));
            const expiresAt = new Date(Date.now() + 30 * 60 * 1000);
            const summary: CheckoutSummary = {
                subtotal: Number(subtotal.toFixed(2)),
                discount,
                promotionCode,
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
                            subtotal, promotion_id, promotion_code, discount_amount,
                            delivery_fee, service_fee, total, currency, payment_method,
                            delivery_option, status, expires_at
                        ) VALUES ($1, $2, $3, $4, $5::jsonb, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, 'draft', $16)
                        RETURNING id, customer_id, address_id, delivery_zone_id, cart_snapshot,
                            subtotal, promotion_id, promotion_code, discount_amount,
                            delivery_fee, service_fee, total, currency, payment_method,
                            delivery_option, status, expires_at
                `,
                [
                    checkoutId, userId, address.id, deliveryZone.id, JSON.stringify(cart),
                    summary.subtotal, promotionId, promotionCode ?? null, summary.discount,
                    summary.deliveryFee, summary.serviceFee, summary.total,
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
                discount: Number(row.discount_amount),
                promotionCode: row.promotion_code ?? undefined,
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
