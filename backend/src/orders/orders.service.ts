import {
    BadRequestException,
    ConflictException,
    Injectable,
    NotFoundException,
} from '@nestjs/common';
import { Type } from 'class-transformer';
import {
    IsInt,
    IsOptional,
    IsUUID,
    Max,
    Min,
} from 'class-validator';
import { QueryResultRow } from 'pg';
import { AddressRecord, AddressService, DeliveryZoneRecord } from '../address/address.service';
import { CartItemSnapshot, CartResponse, CartService } from '../cart/cart.service';
import { DatabaseService, QueryExecutor } from '../database/database.service';
import { DeliveryService } from '../delivery/delivery.service';
import { NotificationsService } from '../notifications/notifications.service';

export class PlaceOrderDto {
    @IsUUID()
    checkoutId!: string;
}

export class ListOrdersQuery {
    @IsOptional()
    @Type(() => Number)
    @IsInt()
    @Min(1)
    page = 1;

    @IsOptional()
    @Type(() => Number)
    @IsInt()
    @Min(1)
    @Max(100)
    limit = 20;
}

export type OrderStatus = 'payment_pending' | 'placed' | 'paid' | 'cancelled';

export interface OrderSummary {
    subtotal: number;
    discount: number;
    promotionCode?: string;
    deliveryFee: number;
    serviceFee: number;
    total: number;
    currency: string;
}

export interface OrderRecord {
    id: string;
    customerId: string;
    checkoutId: string;
    status: OrderStatus;
    paymentStatus?: string;
    deliveryStatus?: string;
    paymentMethod: 'card' | 'cash';
    deliveryOption: 'standard' | 'express';
    address: AddressRecord;
    deliveryZone: DeliveryZoneRecord;
    items: CartItemSnapshot[];
    summary: OrderSummary;
    createdAt: string;
    updatedAt: string;
    cancelledAt?: string;
}

interface CheckoutRow extends QueryResultRow {
    id: string;
    customer_id: string;
    address_id: string;
    delivery_zone_id: string | null;
    cart_snapshot: CartResponse;
    subtotal: string | number;
    promotion_id: string | null;
    promotion_code: string | null;
    discount_amount: string | number;
    delivery_fee: string | number;
    service_fee: string | number;
    total: string | number;
    currency: string;
    payment_method: 'card' | 'cash';
    delivery_option: 'standard' | 'express';
    status: string;
    expires_at: Date | string;
}

interface OrderRow extends QueryResultRow {
    id: string;
    customer_id: string;
    checkout_session_id: string;
    status: OrderStatus;
    payment_method: 'card' | 'cash';
    delivery_option: 'standard' | 'express';
    address_snapshot: AddressRecord;
    delivery_zone_snapshot: DeliveryZoneRecord;
    cart_snapshot: CartResponse;
    payment_status?: string | null;
    delivery_status?: string | null;
    subtotal: string | number;
    promotion_id: string | null;
    promotion_code: string | null;
    discount_amount: string | number;
    delivery_fee: string | number;
    service_fee: string | number;
    total: string | number;
    currency: string;
    created_at: Date | string;
    updated_at: Date | string;
    cancelled_at: Date | string | null;
}

interface ProductRow extends QueryResultRow {
    id: string;
    price: string | number;
    compare_at_price: string | number | null;
    discount_percent: string | number | null;
    availability: string;
    is_active: boolean;
    quantity: number;
}

@Injectable()
export class OrdersService {
    constructor(
        private readonly database: DatabaseService,
        private readonly cartService: CartService,
        private readonly addressService: AddressService,
        private readonly deliveryService: DeliveryService,
        private readonly notificationsService: NotificationsService,
    ) { }

    async placeOrder(customerId: string, dto: PlaceOrderDto): Promise<OrderRecord> {
        const result = await this.database.withTransaction(async (client) => {
            const checkoutResult = await client.query<CheckoutRow>(
                `
                    SELECT id, customer_id, address_id, delivery_zone_id, cart_snapshot,
                        subtotal, promotion_id, promotion_code, discount_amount,
                        delivery_fee, service_fee, total, currency, payment_method,
                        delivery_option, status, expires_at
                    FROM checkout_sessions
                    WHERE id = $1 AND customer_id = $2
                    FOR UPDATE
                `,
                [dto.checkoutId, customerId],
            );
            const checkout = checkoutResult.rows[0];
            if (!checkout) {
                throw new NotFoundException('Checkout session not found');
            }

            const existingOrder = await client.query<{ id: string }>(
                'SELECT id FROM orders WHERE checkout_session_id = $1',
                [checkout.id],
            );
            if (existingOrder.rows[0]) {
                return { orderId: existingOrder.rows[0].id };
            }

            if (checkout.status !== 'draft') {
                throw new ConflictException('Checkout session is no longer available for ordering');
            }
            if (new Date(checkout.expires_at).getTime() <= Date.now()) {
                await client.query(
                    "UPDATE checkout_sessions SET status = 'expired', updated_at = NOW() WHERE id = $1",
                    [checkout.id],
                );
                return { expired: true as const };
            }
            if (checkout.promotion_id) {
                const promotionResult = await client.query<{
                    id: string;
                    is_active: boolean;
                    starts_at: Date | string;
                    ends_at: Date | string | null;
                    max_redemptions: number | null;
                    max_per_customer: number;
                }>(
                    `
                        SELECT id, is_active, starts_at, ends_at, max_redemptions, max_per_customer
                        FROM promotions
                        WHERE id = $1
                        FOR UPDATE
                    `,
                    [checkout.promotion_id],
                );
                const promotion = promotionResult.rows[0];
                const [redemptions, customerRedemptions] = await Promise.all([
                    client.query<{ count: string }>(
                        'SELECT COUNT(*)::text AS count FROM promotion_redemptions WHERE promotion_id = $1',
                        [checkout.promotion_id],
                    ),
                    client.query<{ count: string }>(
                        'SELECT COUNT(*)::text AS count FROM promotion_redemptions WHERE promotion_id = $1 AND customer_id = $2',
                        [checkout.promotion_id, customerId],
                    ),
                ]);
                const now = Date.now();
                if (!promotion || !promotion.is_active
                    || new Date(promotion.starts_at).getTime() > now
                    || (promotion.ends_at !== null && new Date(promotion.ends_at).getTime() <= now)
                    || (promotion.max_redemptions !== null
                        && Number(redemptions.rows[0].count) >= promotion.max_redemptions)
                    || Number(customerRedemptions.rows[0].count) >= promotion.max_per_customer) {
                    throw new ConflictException('Promotion is no longer available; prepare checkout again');
                }
            }

            await client.query(
                "SELECT id FROM carts WHERE customer_id = $1 AND status = 'active' FOR UPDATE",
                [customerId],
            );
            await client.query(
                `
                    SELECT p.id
                    FROM products p
                    JOIN cart_items ci ON ci.product_id = p.id
                    JOIN carts c ON c.id = ci.cart_id
                    WHERE c.customer_id = $1 AND c.status = 'active'
                    ORDER BY p.id
                    FOR UPDATE OF p
                `,
                [customerId],
            );
            const cart = await this.cartService.getCart(customerId, client);
            if (!cart.items.length) {
                throw new BadRequestException('Cart is empty');
            }
            const validation = await this.cartService.validateCart(customerId, client);
            if (!validation.valid) {
                throw new BadRequestException(validation.errors.join('; '));
            }
            if (!this.matchesCheckoutCart(checkout.cart_snapshot, cart)) {
                throw new ConflictException('Cart or pricing changed after checkout was prepared');
            }

            const address = await this.addressService.getAddressById(customerId, checkout.address_id, client);
            const deliveryZone = await this.addressService.resolveDeliveryZone(
                address.city,
                checkout.delivery_zone_id ?? undefined,
                client,
            );
            const status: OrderStatus = checkout.payment_method === 'cash' ? 'placed' : 'payment_pending';
            const inserted = await client.query<{ id: string }>(
                `
                    INSERT INTO orders (
                        customer_id, checkout_session_id, status, payment_method, delivery_option,
                        address_snapshot, delivery_zone_snapshot, cart_snapshot,
                        subtotal, promotion_id, promotion_code, discount_amount,
                        delivery_fee, service_fee, total, currency
                    ) VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7::jsonb, $8::jsonb, $9, $10, $11, $12, $13, $14, $15, $16)
                    RETURNING id
                `,
                [
                    customerId, checkout.id, status, checkout.payment_method, checkout.delivery_option,
                    JSON.stringify(address), JSON.stringify(deliveryZone), JSON.stringify(checkout.cart_snapshot),
                    checkout.subtotal, checkout.promotion_id, checkout.promotion_code,
                    checkout.discount_amount, checkout.delivery_fee, checkout.service_fee,
                    checkout.total, checkout.currency,
                ],
            );

            if (checkout.promotion_id && Number(checkout.discount_amount) > 0) {
                await client.query(
                    `
                        INSERT INTO promotion_redemptions (
                            promotion_id, customer_id, order_id, discount_amount
                        ) VALUES ($1, $2, $3, $4)
                    `,
                    [checkout.promotion_id, customerId, inserted.rows[0].id, checkout.discount_amount],
                );
            }

            await client.query(
                'UPDATE checkout_sessions SET status = $2, updated_at = NOW() WHERE id = $1',
                [checkout.id, status === 'placed' ? 'confirmed' : 'payment_pending'],
            );
            await this.notificationsService.create(client, {
                customerId,
                type: 'order_placed',
                title: 'Order placed',
                body: status === 'payment_pending'
                    ? 'Your order is awaiting payment.'
                    : 'Your cash-on-delivery order has been placed.',
                data: { orderId: inserted.rows[0].id },
                deduplicationKey: `order:${inserted.rows[0].id}:placed`,
            });
            if (checkout.payment_method === 'cash') {
                await this.deliveryService.createForOrder(client, {
                    id: inserted.rows[0].id,
                    customerId,
                    estimatedMinutes: deliveryZone.estimatedMinutes,
                });
            }
            for (const item of checkout.cart_snapshot.items) {
                const stockUpdate = await client.query<{ id: string }>(
                    `
                        UPDATE products
                        SET quantity = quantity - $2,
                            availability = CASE
                                WHEN quantity - $2 <= 0 THEN 'out_of_stock'
                                WHEN availability = 'out_of_stock' THEN 'in_stock'
                                ELSE availability
                            END,
                            updated_at = NOW()
                        WHERE id = $1 AND is_active = TRUE AND quantity >= $2
                        RETURNING id
                    `,
                    [item.productId, item.quantity],
                );
                if (!stockUpdate.rows[0]) {
                    throw new BadRequestException(`Insufficient inventory for ${item.name}`);
                }
                await client.query(
                    `
                        INSERT INTO inventory_reservations (order_id, product_id, quantity)
                        VALUES ($1, $2, $3)
                    `,
                    [inserted.rows[0].id, item.productId, item.quantity],
                );
                await client.query(
                    `
                        INSERT INTO inventory_movements (
                            order_id, product_id, quantity_delta, reason
                        ) VALUES ($1, $2, $3, 'order_reserved')
                    `,
                    [inserted.rows[0].id, item.productId, -item.quantity],
                );
            }
            await client.query(
                `
                    DELETE FROM cart_items
                    WHERE cart_id = (
                        SELECT id FROM carts WHERE customer_id = $1 AND status = 'active'
                    )
                `,
                [customerId],
            );
            return { orderId: inserted.rows[0].id };
        });

        if ('expired' in result && result.expired) {
            throw new BadRequestException('Checkout session has expired');
        }
        return this.getOrder(customerId, result.orderId);
    }

    async getOrders(customerId: string, query: ListOrdersQuery) {
        const page = query.page ?? 1;
        const limit = query.limit ?? 20;
        const offset = (page - 1) * limit;
        const [orders, count] = await Promise.all([
            this.database.query<OrderRow>(
                `
                    SELECT o.*,
                        (SELECT p.status FROM payments p WHERE p.order_id = o.id
                         ORDER BY p.created_at DESC, p.id DESC LIMIT 1) AS payment_status,
                        (SELECT d.status FROM deliveries d WHERE d.order_id = o.id) AS delivery_status
                    FROM orders o
                    WHERE o.customer_id = $1
                    ORDER BY o.created_at DESC, o.id DESC
                    LIMIT $2 OFFSET $3
                `,
                [customerId, limit, offset],
            ),
            this.database.query<{ count: string }>(
                'SELECT COUNT(*)::text AS count FROM orders WHERE customer_id = $1',
                [customerId],
            ),
        ]);
        return {
            items: orders.rows.map((row) => this.toOrder(row)),
            total: Number(count.rows[0].count),
            page,
            limit,
        };
    }

    async getOrder(customerId: string, orderId: string): Promise<OrderRecord> {
        const result = await this.database.query<OrderRow>(
            `
                SELECT o.*,
                    (SELECT p.status FROM payments p WHERE p.order_id = o.id
                     ORDER BY p.created_at DESC, p.id DESC LIMIT 1) AS payment_status,
                    (SELECT d.status FROM deliveries d WHERE d.order_id = o.id) AS delivery_status
                FROM orders o
                WHERE o.id = $1 AND o.customer_id = $2
            `,
            [orderId, customerId],
        );
        if (!result.rows[0]) {
            throw new NotFoundException('Order not found');
        }
        return this.toOrder(result.rows[0]);
    }

    async cancelOrder(customerId: string, orderId: string): Promise<OrderRecord> {
        await this.database.withTransaction(async (client) => {
            const result = await client.query<OrderRow>(
                'SELECT * FROM orders WHERE id = $1 AND customer_id = $2 FOR UPDATE',
                [orderId, customerId],
            );
            const order = result.rows[0];
            if (!order) {
                throw new NotFoundException('Order not found');
            }
            if (order.status === 'cancelled') {
                return;
            }
            if (order.status !== 'placed' && order.status !== 'payment_pending') {
                throw new ConflictException('Order can no longer be cancelled');
            }
            const activePayment = await client.query<{ id: string }>(
                "SELECT id FROM payments WHERE order_id = $1 AND status = 'pending' LIMIT 1",
                [orderId],
            );
            if (activePayment.rows[0]) {
                throw new ConflictException('Cancel the payment with the provider before cancelling this order');
            }
            await client.query(
                `
                    UPDATE orders
                    SET status = 'cancelled', cancelled_at = NOW(), updated_at = NOW()
                    WHERE id = $1
                `,
                [orderId],
            );
            await client.query(
                "UPDATE checkout_sessions SET status = 'cancelled', updated_at = NOW() WHERE id = $1",
                [order.checkout_session_id],
            );
            await this.deliveryService.cancelForOrder(client, orderId);
            await this.notificationsService.create(client, {
                customerId,
                type: 'order_cancelled',
                title: 'Order cancelled',
                body: 'Your order has been cancelled.',
                data: { orderId },
                deduplicationKey: `order:${orderId}:cancelled`,
            });
            const reservations = await client.query<{ product_id: string; quantity: number }>(
                `
                    SELECT product_id, quantity
                    FROM inventory_reservations
                    WHERE order_id = $1 AND status = 'reserved'
                    FOR UPDATE
                `,
                [orderId],
            );
            for (const reservation of reservations.rows) {
                await client.query(
                    `
                        UPDATE products
                        SET quantity = quantity + $2,
                            availability = CASE
                                WHEN availability = 'out_of_stock' THEN 'in_stock'
                                ELSE availability
                            END,
                            updated_at = NOW()
                        WHERE id = $1
                    `,
                    [reservation.product_id, reservation.quantity],
                );
                await client.query(
                    `
                        UPDATE inventory_reservations
                        SET status = 'released', released_at = NOW()
                        WHERE order_id = $1 AND product_id = $2
                    `,
                    [orderId, reservation.product_id],
                );
                await client.query(
                    `
                        INSERT INTO inventory_movements (
                            order_id, product_id, quantity_delta, reason
                        ) VALUES ($1, $2, $3, 'order_cancelled')
                    `,
                    [orderId, reservation.product_id, reservation.quantity],
                );
            }
        });
        return this.getOrder(customerId, orderId);
    }

    async reorder(customerId: string, orderId: string) {
        const order = await this.getOrder(customerId, orderId);
        return this.database.withTransaction(async (client) => {
            const cartResult = await client.query<{ id: string }>(
                `
                    INSERT INTO carts (customer_id, status)
                    VALUES ($1, 'active')
                    ON CONFLICT (customer_id, status)
                    DO UPDATE SET updated_at = NOW()
                    RETURNING id
                `,
                [customerId],
            );
            const cartId = cartResult.rows[0].id;

            for (const item of order.items) {
                const productResult = await client.query<ProductRow>(
                    `
                        SELECT id, price, compare_at_price, discount_percent,
                            availability, is_active, quantity
                        FROM products
                        WHERE id = $1
                        FOR UPDATE
                    `,
                    [item.productId],
                );
                const product = productResult.rows[0];
                if (!product || !product.is_active || product.availability === 'out_of_stock') {
                    throw new BadRequestException(`Product ${item.productId} is no longer available`);
                }
                const existing = await client.query<{ quantity: number }>(
                    'SELECT quantity FROM cart_items WHERE cart_id = $1 AND product_id = $2',
                    [cartId, item.productId],
                );
                const quantity = item.quantity + (existing.rows[0]?.quantity ?? 0);
                if (quantity > product.quantity) {
                    throw new BadRequestException(`Product ${item.productId} does not have enough stock`);
                }
                await client.query(
                    `
                        INSERT INTO cart_items (
                            cart_id, product_id, quantity, unit_price, compare_at_price, discount_percent
                        ) VALUES ($1, $2, $3, $4, $5, $6)
                        ON CONFLICT (cart_id, product_id)
                        DO UPDATE SET quantity = EXCLUDED.quantity, unit_price = EXCLUDED.unit_price,
                            compare_at_price = EXCLUDED.compare_at_price,
                            discount_percent = EXCLUDED.discount_percent, updated_at = NOW()
                    `,
                    [
                        cartId, product.id, quantity, product.price,
                        product.compare_at_price, product.discount_percent,
                    ],
                );
            }
            return {
                orderId,
                cart: await this.cartService.getCart(customerId, client),
            };
        });
    }

    private matchesCheckoutCart(snapshot: CartResponse, current: CartResponse) {
        if (!snapshot || !Array.isArray(snapshot.items) || snapshot.items.length !== current.items.length) {
            return false;
        }
        const currentItems = new Map(current.items.map((item) => [item.productId, item]));
        return snapshot.items.every((item) => {
            const currentItem = currentItems.get(item.productId);
            return currentItem !== undefined
                && currentItem.quantity === item.quantity
                && Number(currentItem.unitPrice) === Number(item.unitPrice)
                && Number(currentItem.lineTotal) === Number(item.lineTotal);
        }) && Number(snapshot.summary.total) === Number(current.summary.total);
    }

    private toOrder(row: OrderRow): OrderRecord {
        return {
            id: row.id,
            customerId: row.customer_id,
            checkoutId: row.checkout_session_id,
            status: row.status,
            paymentStatus: row.payment_status ?? undefined,
            deliveryStatus: row.delivery_status ?? undefined,
            paymentMethod: row.payment_method,
            deliveryOption: row.delivery_option,
            address: row.address_snapshot,
            deliveryZone: row.delivery_zone_snapshot,
            items: row.cart_snapshot.items,
            summary: {
                subtotal: Number(row.subtotal),
                discount: Number(row.discount_amount),
                promotionCode: row.promotion_code ?? undefined,
                deliveryFee: Number(row.delivery_fee),
                serviceFee: Number(row.service_fee),
                total: Number(row.total),
                currency: row.currency,
            },
            createdAt: new Date(row.created_at).toISOString(),
            updatedAt: new Date(row.updated_at).toISOString(),
            cancelledAt: row.cancelled_at ? new Date(row.cancelled_at).toISOString() : undefined,
        };
    }
}
