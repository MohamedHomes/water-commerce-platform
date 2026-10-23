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
    Matches,
    Max,
    MaxLength,
    Min,
} from 'class-validator';
import { QueryResultRow } from 'pg';
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
    status: string;
    payment_method: string;
    total: string | number;
    currency: string;
    created_at: Date | string;
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
                SELECT id, customer_id, status, payment_method, total, currency, created_at
                FROM orders ${statusCondition}
                ORDER BY created_at DESC, id DESC
                LIMIT $${values.length - 1} OFFSET $${values.length}
            `,
            values,
        );
        return {
            items: result.rows.map((row) => ({
                id: row.id,
                customerId: row.customer_id,
                status: row.status,
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
            await client.query(
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
                `,
                [productId, quantity],
            );
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
                [adminId, JSON.stringify({ productId, quantityDelta: dto.quantityDelta, quantity })],
            );
            return { productId, quantity, availability: quantity === 0 ? 'out_of_stock' : 'in_stock' };
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
                SELECT r.id, r.product_id, p.name AS product_name, r.customer_id,
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
                SELECT p.id, p.name, p.price, p.quantity, p.availability, p.is_active,
                    c.name AS category_name, b.name AS brand_name
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
        if (dto.price === undefined && dto.isActive === undefined) {
            throw new BadRequestException('At least one product field must be updated');
        }
        return this.database.withTransaction(async (client) => {
            const result = await client.query(
                `
                    UPDATE products
                    SET price = COALESCE($2, price),
                        is_active = COALESCE($3, is_active),
                        updated_at = NOW()
                    WHERE id = $1
                    RETURNING id, name, price, quantity, availability, is_active
                `,
                [productId, dto.price ?? null, dto.isActive ?? null],
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
                [adminId, JSON.stringify({ productId, price: dto.price, isActive: dto.isActive })],
            );
            return {
                ...result.rows[0],
                price: Number(result.rows[0].price),
                quantity: Number(result.rows[0].quantity),
            };
        });
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
}
