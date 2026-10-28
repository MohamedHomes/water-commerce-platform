import {
    BadRequestException,
    ConflictException,
    Injectable,
    NotFoundException,
} from '@nestjs/common';
import { Transform, Type } from 'class-transformer';
import {
    IsBoolean,
    IsDateString,
    IsIn,
    IsInt,
    IsNumber,
    IsNotEmpty,
    IsOptional,
    IsString,
    Length,
    Matches,
    Max,
    MaxLength,
    Min,
} from 'class-validator';
import { QueryResultRow } from 'pg';
import { randomUUID } from 'crypto';
import { DatabaseService } from '../database/database.service';

export class CreatePromotionDto {
    @Transform(({ value }) => (typeof value === 'string' ? value.trim().toUpperCase() : value))
    @IsString()
    @MaxLength(64)
    @Matches(/^[A-Z0-9_-]+$/)
    code!: string;

    @IsIn(['percentage', 'fixed'])
    discountType!: 'percentage' | 'fixed';

    @Type(() => Number)
    @IsNumber()
    @Min(0.01)
    @Max(100000)
    discountValue!: number;

    @IsOptional()
    @Type(() => Number)
    @IsNumber()
    @Min(0.01)
    maxDiscount?: number;

    @IsOptional()
    @Type(() => Number)
    @IsNumber()
    @Min(0)
    minimumSubtotal = 0;

    @IsOptional()
    @Type(() => Number)
    @IsInt()
    @Min(1)
    maxRedemptions?: number;

    @IsOptional()
    @Type(() => Number)
    @IsInt()
    @Min(1)
    maxPerCustomer = 1;

    @IsOptional()
    @IsDateString()
    startsAt?: string;

    @IsOptional()
    @IsDateString()
    endsAt?: string;
}

export class SetPromotionActiveDto {
    @IsBoolean()
    isActive!: boolean;
}

export class AdjustInventoryDto {
    @Type(() => Number)
    @IsInt()
    @Min(-1000000)
    @Max(1000000)
    quantityDelta!: number;
}

export class DeliveryStatusUpdateDto {
    @IsIn(['assigned', 'picked_up', 'delivered', 'failed'])
    status!: 'assigned' | 'picked_up' | 'delivered' | 'failed';

    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @IsNotEmpty()
    @MaxLength(255)
    note!: string;
}

export class ModerateReviewDto {
    @IsIn(['approved', 'rejected'])
    status!: 'approved' | 'rejected';
}

export class UpdateProductOperationsDto {
    @IsOptional()
    @Type(() => Number)
    @IsNumber()
    @Min(0.01)
    @Max(1000000)
    price?: number;

    @IsOptional()
    @IsBoolean()
    isActive?: boolean;

    @IsOptional()
    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @IsNotEmpty()
    @MaxLength(200)
    name?: string;

    @IsOptional()
    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @MaxLength(200)
    nameAr?: string;

    @IsOptional()
    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @Length(1, 200)
    @Matches(/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
    slug?: string;

    @IsOptional()
    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @MaxLength(10000)
    description?: string;

    @IsOptional()
    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @MaxLength(10000)
    descriptionAr?: string;

    @IsOptional()
    @IsString()
    @Length(1, 80)
    categoryId?: string;

    @IsOptional()
    @IsString()
    @Length(1, 80)
    brandId?: string;
}

export class CreateProductOperationsDto {
    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @IsNotEmpty()
    @MaxLength(200)
    name!: string;

    @IsOptional()
    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @MaxLength(200)
    nameAr?: string;

    @Transform(({ value }) => (typeof value === 'string' ? value.trim().toLowerCase() : value))
    @IsString()
    @Length(1, 200)
    @Matches(/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
    slug!: string;

    @IsString()
    @Length(1, 80)
    categoryId!: string;

    @IsString()
    @Length(1, 80)
    brandId!: string;

    @IsOptional()
    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @MaxLength(10000)
    description?: string;

    @IsOptional()
    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @MaxLength(10000)
    descriptionAr?: string;

    @Type(() => Number)
    @IsNumber()
    @Min(0.01)
    @Max(1000000)
    price!: number;

    @IsOptional()
    @Type(() => Number)
    @IsInt()
    @Min(0)
    @Max(1000000)
    quantity = 0;

    @IsOptional()
    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @MaxLength(80)
    packageSize?: string;
}

export class CatalogTermDto {
    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @IsNotEmpty()
    @MaxLength(150)
    name!: string;

    @IsOptional()
    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @MaxLength(150)
    nameAr?: string;

    @Transform(({ value }) => (typeof value === 'string' ? value.trim().toLowerCase() : value))
    @IsString()
    @Length(1, 150)
    @Matches(/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
    slug!: string;

    @IsOptional()
    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @MaxLength(10000)
    description?: string;

    @IsOptional()
    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @MaxLength(10000)
    descriptionAr?: string;
}

export class UpdateCatalogTermDto {
    @IsOptional()
    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @IsNotEmpty()
    @MaxLength(150)
    name?: string;

    @IsOptional()
    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @MaxLength(150)
    nameAr?: string;

    @IsOptional()
    @Transform(({ value }) => (typeof value === 'string' ? value.trim().toLowerCase() : value))
    @IsString()
    @Length(1, 150)
    @Matches(/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
    slug?: string;

    @IsOptional()
    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @MaxLength(10000)
    description?: string;

    @IsOptional()
    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @MaxLength(10000)
    descriptionAr?: string;
}

export class AdminOrdersQuery {
    @IsOptional()
    @IsIn(['payment_pending', 'placed', 'paid', 'cancelled'])
    status?: string;

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

interface AdminOrderRow extends QueryResultRow {
    id: string;
    customer_id: string;
    customer_first_name: string;
    customer_last_name: string;
    status: string;
    delivery_status: string | null;
    payment_method: string;
    total: string | number;
    currency: string;
    created_at: Date | string;
}

interface AdminOrderDetailsRow extends QueryResultRow {
    id: string;
    customer_id: string;
    customer_email: string;
    customer_first_name: string;
    customer_last_name: string;
    customer_phone: string | null;
    status: string;
    payment_method: string;
    delivery_option: string;
    address_snapshot: Record<string, unknown>;
    delivery_zone_snapshot: Record<string, unknown>;
    cart_snapshot: { items?: unknown[] };
    subtotal: string | number;
    discount_amount: string | number;
    promotion_code: string | null;
    delivery_fee: string | number;
    service_fee: string | number;
    total: string | number;
    currency: string;
    created_at: Date | string;
    updated_at: Date | string;
    cancelled_at: Date | string | null;
}

@Injectable()
export class AdminService {
    constructor(private readonly database: DatabaseService) { }

    async getDashboard() {
        const result = await this.database.query<{
            total_orders: string;
            open_orders: string;
            awaiting_payment: string;
            paid_revenue: string;
            pending_dispatch: string;
            active_products: string;
        }>(
            `
                SELECT
                    (SELECT COUNT(*) FROM orders) AS total_orders,
                    (SELECT COUNT(*) FROM orders WHERE status IN ('placed', 'paid')) AS open_orders,
                    (SELECT COUNT(*) FROM orders WHERE status = 'payment_pending') AS awaiting_payment,
                    (SELECT COALESCE(SUM(total), 0) FROM orders WHERE status = 'paid') AS paid_revenue,
                    (SELECT COUNT(*) FROM deliveries WHERE status = 'pending_dispatch') AS pending_dispatch,
                    (SELECT COUNT(*) FROM products WHERE is_active = TRUE) AS active_products
            `,
        );
        const row = result.rows[0];
        return {
            totalOrders: Number(row.total_orders),
            openOrders: Number(row.open_orders),
            awaitingPayment: Number(row.awaiting_payment),
            paidRevenue: Number(row.paid_revenue),
            pendingDispatch: Number(row.pending_dispatch),
            activeProducts: Number(row.active_products),
            currency: 'SAR',
        };
    }

    async getOrders(query: AdminOrdersQuery) {
        const page = query.page ?? 1;
        const limit = query.limit ?? 20;
        const offset = (page - 1) * limit;
        const values: unknown[] = [];
        const statusCondition = query.status
            ? (values.push(query.status), `WHERE status = $${values.length}`)
            : '';
        const count = await this.database.query<{ count: string }>(
            `SELECT COUNT(*)::text AS count FROM orders ${statusCondition}`,
            values,
        );
        values.push(limit, offset);
        const result = await this.database.query<AdminOrderRow>(
            `
                SELECT o.id, o.customer_id, c.first_name AS customer_first_name,
                    c.last_name AS customer_last_name, o.status, d.status AS delivery_status,
                    o.payment_method, o.total, o.currency, o.created_at
                FROM orders o
                JOIN customers c ON c.id = o.customer_id
                LEFT JOIN deliveries d ON d.order_id = o.id
                ${query.status ? `WHERE o.status = $1` : ''}
                ORDER BY o.created_at DESC, o.id DESC
                LIMIT $${values.length - 1} OFFSET $${values.length}
            `,
            values,
        );
        return {
            items: result.rows.map((row) => ({
                id: row.id,
                customerId: row.customer_id,
                customerName: `${row.customer_first_name} ${row.customer_last_name}`.trim() || null,
                status: row.status,
                deliveryStatus: row.delivery_status,
                paymentMethod: row.payment_method,
                total: Number(row.total),
                currency: row.currency,
                createdAt: new Date(row.created_at).toISOString(),
            })),
            total: Number(count.rows[0].count),
            page,
            limit,
        };
    }

    async getOrderDetails(orderId: string) {
        const result = await this.database.query<AdminOrderDetailsRow>(
            `
                SELECT o.id, o.customer_id, c.email AS customer_email,
                    c.first_name AS customer_first_name, c.last_name AS customer_last_name,
                    c.phone AS customer_phone, o.status, o.payment_method,
                    o.delivery_option, o.address_snapshot, o.delivery_zone_snapshot,
                    o.cart_snapshot, o.subtotal, o.discount_amount, o.promotion_code,
                    o.delivery_fee, o.service_fee, o.total, o.currency,
                    o.created_at, o.updated_at, o.cancelled_at
                FROM orders o
                JOIN customers c ON c.id = o.customer_id
                WHERE o.id = $1
            `,
            [orderId],
        );
        const order = result.rows[0];
        if (!order) {
            throw new NotFoundException('Order not found');
        }

        const [paymentResult, deliveryResult] = await Promise.all([
            this.database.query<{
                id: string;
                provider: string;
                status: string;
                amount: string | number;
                currency: string;
                failure_code: string | null;
                created_at: Date | string;
                updated_at: Date | string;
            }>(
                `
                    SELECT id, provider, status, amount, currency, failure_code,
                        created_at, updated_at
                    FROM payments
                    WHERE order_id = $1
                    ORDER BY created_at, id
                `,
                [orderId],
            ),
            this.database.query<{
                id: string;
                status: string;
                estimated_minutes: number;
                tracking_code: string;
                created_at: Date | string;
                updated_at: Date | string;
                delivered_at: Date | string | null;
            }>(
                `
                    SELECT id, status, estimated_minutes, tracking_code,
                        created_at, updated_at, delivered_at
                    FROM deliveries
                    WHERE order_id = $1
                `,
                [orderId],
            ),
        ]);
        const payments = paymentResult.rows.map((payment) => ({
            id: payment.id,
            provider: payment.provider,
            status: payment.status,
            amount: Number(payment.amount),
            currency: payment.currency,
            failureCode: payment.failure_code,
            createdAt: new Date(payment.created_at).toISOString(),
            updatedAt: new Date(payment.updated_at).toISOString(),
        }));
        const delivery = deliveryResult.rows[0];
        let deliveryDetails: {
            id: string;
            status: string;
            estimatedMinutes: number;
            trackingCode: string;
            createdAt: string;
            updatedAt: string;
            deliveredAt: string | null;
            events: {
                status: string;
                note: string;
                createdAt: string;
            }[];
        } | null = null;
        if (delivery) {
            const eventResult = await this.database.query<{
                status: string;
                note: string;
                created_at: Date | string;
            }>(
                `
                    SELECT status, note, created_at
                    FROM delivery_events
                    WHERE delivery_id = $1
                    ORDER BY created_at, id
                `,
                [delivery.id],
            );
            deliveryDetails = {
                id: delivery.id,
                status: delivery.status,
                estimatedMinutes: delivery.estimated_minutes,
                trackingCode: delivery.tracking_code,
                createdAt: new Date(delivery.created_at).toISOString(),
                updatedAt: new Date(delivery.updated_at).toISOString(),
                deliveredAt: delivery.delivered_at
                    ? new Date(delivery.delivered_at).toISOString()
                    : null,
                events: eventResult.rows.map((event) => ({
                    status: event.status,
                    note: event.note,
                    createdAt: new Date(event.created_at).toISOString(),
                })),
            };
        }

        return {
            id: order.id,
            status: order.status,
            paymentStatus: payments.length
                ? payments[payments.length - 1].status
                : null,
            paymentMethod: order.payment_method,
            deliveryOption: order.delivery_option,
            customer: {
                id: order.customer_id,
                email: order.customer_email,
                firstName: order.customer_first_name,
                lastName: order.customer_last_name,
                phone: order.customer_phone,
            },
            items: order.cart_snapshot.items ?? [],
            address: order.address_snapshot,
            deliveryZone: order.delivery_zone_snapshot,
            summary: {
                subtotal: Number(order.subtotal),
                discount: Number(order.discount_amount),
                promotionCode: order.promotion_code,
                deliveryFee: Number(order.delivery_fee),
                serviceFee: Number(order.service_fee),
                total: Number(order.total),
                currency: order.currency,
            },
            payments,
            delivery: deliveryDetails,
            createdAt: new Date(order.created_at).toISOString(),
            updatedAt: new Date(order.updated_at).toISOString(),
            cancelledAt: order.cancelled_at
                ? new Date(order.cancelled_at).toISOString()
                : null,
        };
    }

    async getPromotions() {
        const result = await this.database.query(
            `
                SELECT p.id, p.code, p.discount_type, p.discount_value, p.max_discount,
                    p.minimum_subtotal, p.max_redemptions, p.max_per_customer,
                    p.starts_at, p.ends_at, p.is_active,
                    COUNT(r.id)::integer AS redemption_count
                FROM promotions p
                LEFT JOIN promotion_redemptions r ON r.promotion_id = p.id
                GROUP BY p.id
                ORDER BY p.created_at DESC, p.id DESC
            `,
        );
        return { items: result.rows };
    }

    async getInventory() {
        const result = await this.database.query(
            `
                SELECT id, name, quantity, availability, is_active
                FROM products
                ORDER BY name, id
                LIMIT 500
            `,
        );
        return { items: result.rows };
    }

    async getInventoryMovements(productId: string) {
        const product = await this.database.query<{ id: string }>(
            'SELECT id FROM products WHERE id = $1',
            [productId],
        );
        if (!product.rows[0]) {
            throw new NotFoundException('Product not found');
        }

        const result = await this.database.query<{
            id: string;
            order_id: string | null;
            admin_customer_id: string | null;
            quantity_delta: number;
            reason: string;
            created_at: Date | string;
        }>(
            `
                SELECT id, order_id, admin_customer_id, quantity_delta, reason, created_at
                FROM inventory_movements
                WHERE product_id = $1
                ORDER BY created_at DESC, id DESC
                LIMIT 100
            `,
            [productId],
        );
        return {
            items: result.rows.map((movement) => ({
                id: movement.id,
                orderId: movement.order_id,
                adminId: movement.admin_customer_id,
                quantityDelta: movement.quantity_delta,
                reason: movement.reason,
                createdAt: new Date(movement.created_at).toISOString(),
            })),
        };
    }

    async getCatalogTerms() {
        const [categories, brands] = await Promise.all([
            this.database.query(
                `SELECT id, name, name_ar, slug, description, description_ar
                FROM categories ORDER BY name, id`,
            ),
            this.database.query(
                `SELECT id, name, name_ar, slug, description, description_ar
                FROM brands ORDER BY name, id`,
            ),
        ]);
        return { categories: categories.rows, brands: brands.rows };
    }

    async createCatalogTerm(
        adminId: string,
        type: 'category' | 'brand',
        dto: CatalogTermDto,
    ) {
        const table = type === 'category' ? 'categories' : 'brands';
        const id = randomUUID();
        try {
            return await this.database.withTransaction(async (client) => {
                const result = await client.query(
                    `INSERT INTO ${table} (id, name, name_ar, slug, description, description_ar)
                    VALUES ($1, $2, $3, $4, $5, $6)
                    RETURNING id, name, name_ar, slug, description, description_ar`,
                    [id, dto.name, dto.nameAr ?? null, dto.slug, dto.description ?? null, dto.descriptionAr ?? null],
                );
                await this.writeCatalogAudit(client, adminId, `${type}_created`, type, id, dto);
                return result.rows[0];
            });
        } catch (error) {
            if (this.isUniqueViolation(error)) {
                throw new ConflictException(`${type} slug already exists`);
            }
            throw error;
        }
    }

    async updateCatalogTerm(
        adminId: string,
        type: 'category' | 'brand',
        id: string,
        dto: UpdateCatalogTermDto,
    ) {
        const table = type === 'category' ? 'categories' : 'brands';
        const fields = [
            ['name', dto.name],
            ['name_ar', dto.nameAr],
            ['slug', dto.slug],
            ['description', dto.description],
            ['description_ar', dto.descriptionAr],
        ] as const;
        const updates = fields.filter(([, value]) => value !== undefined);
        if (updates.length === 0) {
            throw new BadRequestException('At least one catalog field must be updated');
        }
        try {
            return await this.database.withTransaction(async (client) => {
                const values: unknown[] = [id];
                const assignments = updates.map(([column, value]) => {
                    values.push(value);
                    return `${column} = $${values.length}`;
                });
                assignments.push('updated_at = NOW()');
                const result = await client.query<{ id: string } & QueryResultRow>(
                    `UPDATE ${table} SET ${assignments.join(', ')}
                    WHERE id = $1
                    RETURNING id, name, name_ar, slug, description, description_ar`,
                    values,
                );
                if (!result.rows[0]) {
                    throw new NotFoundException(`${type} not found`);
                }
                await this.writeCatalogAudit(client, adminId, `${type}_updated`, type, id, dto);
                return result.rows[0];
            });
        } catch (error) {
            if (this.isUniqueViolation(error)) {
                throw new ConflictException(`${type} slug already exists`);
            }
            throw error;
        }
    }

    async adjustInventory(adminId: string, productId: string, dto: AdjustInventoryDto) {
        if (dto.quantityDelta === 0) {
            throw new BadRequestException('Inventory adjustment must be non-zero');
        }
        return this.database.withTransaction(async (client) => {
            const selected = await client.query<{
                id: string;
                quantity: number;
                availability: string;
            }>(
                'SELECT id, quantity, availability FROM products WHERE id = $1 FOR UPDATE',
                [productId],
            );
            const product = selected.rows[0];
            if (!product) {
                throw new NotFoundException('Product not found');
            }
            const quantity = product.quantity + dto.quantityDelta;
            if (quantity < 0) {
                throw new BadRequestException('Inventory cannot be reduced below zero');
            }
            const updated = await client.query<{
                quantity: number;
                availability: string;
            }>(
                `
                    UPDATE products
                    SET quantity = $2,
                        availability = CASE
                            WHEN $2 = 0 THEN 'out_of_stock'
                            WHEN availability = 'out_of_stock' THEN 'in_stock'
                            ELSE availability
                        END,
                        updated_at = NOW()
                    WHERE id = $1
                    RETURNING quantity, availability
                `,
                [productId, quantity],
            );
            const persisted = updated.rows[0];
            await client.query(
                `
                    INSERT INTO inventory_movements (
                        order_id, admin_customer_id, product_id, quantity_delta, reason
                    ) VALUES (NULL, $1, $2, $3, 'inventory_adjustment')
                `,
                [adminId, productId, dto.quantityDelta],
            );
            await client.query(
                `
                    INSERT INTO admin_audit_logs (
                        admin_customer_id, action, resource_type, resource_id, metadata
                    ) VALUES ($1, 'inventory_adjusted', 'product', NULL, $2::jsonb)
                `,
                [adminId, JSON.stringify({
                    productId,
                    quantityDelta: dto.quantityDelta,
                    quantity: persisted.quantity,
                    availability: persisted.availability,
                })],
            );
            return {
                productId,
                quantity: persisted.quantity,
                availability: persisted.availability,
            };
        });
    }

    async getDeliveries() {
        const result = await this.database.query(
            `
                SELECT id, order_id, status, estimated_minutes, created_at, updated_at
                FROM deliveries
                ORDER BY created_at DESC, id DESC
                LIMIT 100
            `,
        );
        return { items: result.rows };
    }

    async setDeliveryStatus(adminId: string, deliveryId: string, dto: DeliveryStatusUpdateDto) {
        return this.database.withTransaction(async (client) => {
            const selected = await client.query<{
                id: string;
                status: 'pending_dispatch' | 'assigned' | 'picked_up' | 'delivered' | 'failed' | 'cancelled';
            }>(
                'SELECT id, status FROM deliveries WHERE id = $1 FOR UPDATE',
                [deliveryId],
            );
            const delivery = selected.rows[0];
            if (!delivery) {
                throw new NotFoundException('Delivery not found');
            }
            const allowedNext: Record<string, string[]> = {
                pending_dispatch: ['assigned'],
                assigned: ['picked_up', 'failed'],
                picked_up: ['delivered', 'failed'],
            };
            if (!allowedNext[delivery.status]?.includes(dto.status)) {
                throw new ConflictException(`Delivery cannot transition from ${delivery.status} to ${dto.status}`);
            }
            await client.query(
                `
                    UPDATE deliveries
                    SET status = $2,
                        delivered_at = CASE WHEN $3 THEN NOW() ELSE delivered_at END,
                        updated_at = NOW()
                    WHERE id = $1
                `,
                [deliveryId, dto.status, dto.status === 'delivered'],
            );
            await client.query(
                'INSERT INTO delivery_events (delivery_id, status, note) VALUES ($1, $2, $3)',
                [deliveryId, dto.status, dto.note],
            );
            await client.query(
                `
                    INSERT INTO admin_audit_logs (
                        admin_customer_id, action, resource_type, resource_id, metadata
                    ) VALUES ($1, 'delivery_status_changed', 'delivery', $2, $3::jsonb)
                `,
                [adminId, deliveryId, JSON.stringify({
                    previousStatus: delivery.status,
                    status: dto.status,
                    note: dto.note,
                })],
            );
            return { id: deliveryId, status: dto.status };
        });
    }

    async getPendingReviews() {
        const result = await this.database.query(
            `
                SELECT r.id, r.product_id, p.name AS product_name,
                    p.name_ar AS product_name_ar, r.customer_id,
                    r.order_id, r.rating, r.comment, r.created_at
                FROM product_reviews r
                JOIN products p ON p.id = r.product_id
                WHERE r.status = 'pending'
                ORDER BY r.created_at, r.id
                LIMIT 100
            `,
        );
        return { items: result.rows };
    }

    async moderateReview(adminId: string, reviewId: string, dto: ModerateReviewDto) {
        return this.database.withTransaction(async (client) => {
            const result = await client.query(
                `
                    UPDATE product_reviews
                    SET status = $2, moderated_by = $3, moderated_at = NOW(), updated_at = NOW()
                    WHERE id = $1 AND status = 'pending'
                    RETURNING id, status, moderated_at
                `,
                [reviewId, dto.status, adminId],
            );
            if (!result.rows[0]) {
                throw new NotFoundException('Pending review not found');
            }
            await client.query(
                `
                    INSERT INTO admin_audit_logs (
                        admin_customer_id, action, resource_type, resource_id, metadata
                    ) VALUES ($1, 'product_review_moderated', 'product_review', $2, $3::jsonb)
                `,
                [adminId, reviewId, JSON.stringify({ status: dto.status })],
            );
            return result.rows[0];
        });
    }

    async getProducts() {
        const result = await this.database.query(
            `
                SELECT p.id, p.name, p.name_ar, p.slug, p.description,
                    p.description_ar, p.price, p.quantity, p.availability, p.is_active,
                    p.category_id, p.brand_id,
                    c.name AS category_name, c.name_ar AS category_name_ar,
                    b.name AS brand_name, b.name_ar AS brand_name_ar
                FROM products p
                JOIN categories c ON c.id = p.category_id
                JOIN brands b ON b.id = p.brand_id
                ORDER BY p.name, p.id
                LIMIT 500
            `,
        );
        return {
            items: result.rows.map((row) => ({
                ...row,
                price: Number(row.price),
                quantity: Number(row.quantity),
            })),
        };
    }

    async updateProduct(adminId: string, productId: string, dto: UpdateProductOperationsDto) {
        const fields = [
            ['price', dto.price],
            ['is_active', dto.isActive],
            ['name', dto.name],
            ['name_ar', dto.nameAr],
            ['slug', dto.slug],
            ['description', dto.description],
            ['description_ar', dto.descriptionAr],
            ['category_id', dto.categoryId],
            ['brand_id', dto.brandId],
        ] as const;
        const updates = fields.filter(([, value]) => value !== undefined);
        if (updates.length === 0) {
            throw new BadRequestException('At least one product field must be updated');
        }
        try {
            return await this.database.withTransaction(async (client) => {
                if (dto.categoryId) await this.ensureCatalogTerm(client, 'categories', dto.categoryId);
                if (dto.brandId) await this.ensureCatalogTerm(client, 'brands', dto.brandId);
                const values: unknown[] = [productId];
                const assignments = updates.map(([column, value]) => {
                    values.push(value);
                    return `${column} = $${values.length}`;
                });
                assignments.push('updated_at = NOW()');
                const result = await client.query(
                    `
                        UPDATE products
                        SET ${assignments.join(', ')}
                        WHERE id = $1
                        RETURNING id, name, name_ar, slug, description, description_ar,
                            price, quantity, availability, is_active, category_id, brand_id
                    `,
                    values,
                );
                if (!result.rows[0]) {
                    throw new NotFoundException('Product not found');
                }
                await client.query(
                    `
                        INSERT INTO admin_audit_logs (
                            admin_customer_id, action, resource_type, resource_id, metadata
                        ) VALUES ($1, 'product_updated', 'product', NULL, $2::jsonb)
                    `,
                    [adminId, JSON.stringify({ productId, ...dto })],
                );
                return {
                    ...result.rows[0],
                    price: Number(result.rows[0].price),
                    quantity: Number(result.rows[0].quantity),
                };
            });
        } catch (error) {
            if (this.isUniqueViolation(error)) {
                throw new ConflictException('Product slug already exists');
            }
            throw error;
        }
    }

    async createProduct(adminId: string, dto: CreateProductOperationsDto) {
        try {
            return await this.database.withTransaction(async (client) => {
                await this.ensureCatalogTerm(client, 'categories', dto.categoryId);
                await this.ensureCatalogTerm(client, 'brands', dto.brandId);
                const result = await client.query<{
                    id: string;
                    price: string | number;
                    quantity: string | number;
                } & QueryResultRow>(
                    `INSERT INTO products (
                        id, name, name_ar, slug, category_id, brand_id, description,
                        description_ar, price, availability, package_size, quantity, updated_at
                    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9,
                        CASE WHEN $11 = 0 THEN 'out_of_stock' ELSE 'in_stock' END,
                        $10, $11, NOW())
                    RETURNING id, name, name_ar, slug, category_id, brand_id, description,
                        description_ar, price, quantity, availability, is_active`,
                    [
                        randomUUID(), dto.name, dto.nameAr ?? null, dto.slug,
                        dto.categoryId, dto.brandId, dto.description ?? null,
                        dto.descriptionAr ?? null, dto.price, dto.packageSize ?? null, dto.quantity,
                    ],
                );
                await this.writeCatalogAudit(
                    client,
                    adminId,
                    'product_created',
                    'product',
                    result.rows[0].id,
                    dto,
                );
                return {
                    ...result.rows[0],
                    price: Number(result.rows[0].price),
                    quantity: Number(result.rows[0].quantity),
                };
            });
        } catch (error) {
            if (this.isUniqueViolation(error)) {
                throw new ConflictException('Product slug already exists');
            }
            throw error;
        }
    }

    async createPromotion(adminId: string, dto: CreatePromotionDto) {
        if (dto.discountType === 'percentage' && dto.discountValue > 100) {
            throw new BadRequestException('Percentage discounts cannot exceed 100');
        }
        if (dto.startsAt && dto.endsAt
            && new Date(dto.endsAt).getTime() <= new Date(dto.startsAt).getTime()) {
            throw new BadRequestException('Promotion end date must be after its start date');
        }
        try {
            return await this.database.withTransaction(async (client) => {
                const result = await client.query(
                    `
                        INSERT INTO promotions (
                            code, discount_type, discount_value, max_discount, minimum_subtotal,
                            max_redemptions, max_per_customer, starts_at, ends_at
                        ) VALUES ($1, $2, $3, $4, $5, $6, $7, COALESCE($8::timestamptz, NOW()), $9)
                        RETURNING id, code, discount_type, discount_value, max_discount,
                            minimum_subtotal, max_redemptions, max_per_customer,
                            starts_at, ends_at, is_active
                    `,
                    [
                        dto.code, dto.discountType, dto.discountValue, dto.maxDiscount ?? null,
                        dto.minimumSubtotal ?? 0, dto.maxRedemptions ?? null,
                        dto.maxPerCustomer ?? 1, dto.startsAt ?? null, dto.endsAt ?? null,
                    ],
                );
                await client.query(
                    `
                        INSERT INTO admin_audit_logs (
                            admin_customer_id, action, resource_type, resource_id, metadata
                        ) VALUES ($1, 'promotion_created', 'promotion', $2, $3::jsonb)
                    `,
                    [adminId, result.rows[0].id, JSON.stringify({ code: dto.code })],
                );
                return result.rows[0];
            });
        } catch (error) {
            if (this.isUniqueViolation(error)) {
                throw new ConflictException('Promotion code already exists');
            }
            throw error;
        }
    }

    async setPromotionActive(adminId: string, promotionId: string, dto: SetPromotionActiveDto) {
        return this.database.withTransaction(async (client) => {
            const result = await client.query(
                `
                    UPDATE promotions SET is_active = $2
                    WHERE id = $1
                    RETURNING id, code, is_active
                `,
                [promotionId, dto.isActive],
            );
            if (!result.rows[0]) {
                throw new NotFoundException('Promotion not found');
            }
            await client.query(
                `
                    INSERT INTO admin_audit_logs (
                        admin_customer_id, action, resource_type, resource_id, metadata
                    ) VALUES ($1, 'promotion_status_changed', 'promotion', $2, $3::jsonb)
                `,
                [adminId, promotionId, JSON.stringify({ isActive: dto.isActive })],
            );
            return result.rows[0];
        });
    }

    private isUniqueViolation(error: unknown) {
        return typeof error === 'object' && error !== null
            && 'code' in error && error.code === '23505';
    }

    private async ensureCatalogTerm(
        executor: { query: (sql: string, values?: unknown[]) => Promise<{ rows: unknown[] }> },
        table: 'categories' | 'brands',
        id: string,
    ) {
        const result = await executor.query(`SELECT id FROM ${table} WHERE id = $1`, [id]);
        if (!result.rows.length) {
            throw new BadRequestException(`${table === 'categories' ? 'Category' : 'Brand'} not found`);
        }
    }

    private async writeCatalogAudit(
        executor: { query: (sql: string, values?: unknown[]) => Promise<unknown> },
        adminId: string,
        action: string,
        resourceType: string,
        resourceId: string,
        metadata: unknown,
    ) {
        const auditMetadata = metadata && typeof metadata === 'object' && !Array.isArray(metadata)
            ? { resourceId, ...metadata }
            : { resourceId, value: metadata };
        await executor.query(
            `INSERT INTO admin_audit_logs (
                admin_customer_id, action, resource_type, resource_id, metadata
            ) VALUES ($1, $2, $3, NULL, $4::jsonb)`,
            [adminId, action, resourceType, JSON.stringify(auditMetadata)],
        );
    }
}
