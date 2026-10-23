import {
    BadRequestException,
    ConflictException,
    Injectable,
    NotFoundException,
} from '@nestjs/common';
import { Transform, Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min } from 'class-validator';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../database/database.service';

export class CreateProductReviewDto {
    @IsUUID()
    orderId!: string;

    @Type(() => Number)
    @IsInt()
    @Min(1)
    @Max(5)
    rating!: number;

    @IsOptional()
    @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
    @IsString()
    @MaxLength(1000)
    comment = '';
}

interface ProductReviewRow extends QueryResultRow {
    id: string;
    product_id: string;
    customer_id: string;
    order_id: string;
    rating: number;
    comment: string;
    status: string;
    created_at: Date | string;
}

@Injectable()
export class ProductReviewsService {
    constructor(private readonly database: DatabaseService) { }

    async getProductReviews(productId: string) {
        const product = await this.database.query<{ id: string }>(
            'SELECT id FROM products WHERE id = $1 AND is_active = TRUE',
            [productId],
        );
        if (!product.rows[0]) {
            throw new NotFoundException('Product not found');
        }
        const [reviews, summary] = await Promise.all([
            this.database.query<ProductReviewRow>(
                `
                    SELECT id, product_id, customer_id, order_id, rating, comment,
                        status, created_at
                    FROM product_reviews
                    WHERE product_id = $1 AND status = 'approved'
                    ORDER BY created_at DESC, id DESC
                    LIMIT 50
                `,
                [productId],
            ),
            this.database.query<{ count: string; average_rating: string | null }>(
                `
                    SELECT COUNT(*)::text AS count, AVG(rating)::text AS average_rating
                    FROM product_reviews
                    WHERE product_id = $1 AND status = 'approved'
                `,
                [productId],
            ),
        ]);
        return {
            items: reviews.rows.map((row) => ({
                id: row.id,
                productId: row.product_id,
                rating: row.rating,
                comment: row.comment,
                createdAt: new Date(row.created_at).toISOString(),
            })),
            summary: {
                count: Number(summary.rows[0].count),
                averageRating: summary.rows[0].average_rating === null
                    ? null
                    : Number(Number(summary.rows[0].average_rating).toFixed(2)),
            },
        };
    }

    async createReview(customerId: string, productId: string, dto: CreateProductReviewDto) {
        return this.database.withTransaction(async (client) => {
            const purchase = await client.query<{ id: string }>(
                `
                    SELECT o.id
                    FROM orders o
                    JOIN deliveries d ON d.order_id = o.id
                    WHERE o.id = $1 AND o.customer_id = $2 AND d.status = 'delivered'
                        AND EXISTS (
                            SELECT 1
                            FROM jsonb_array_elements(o.cart_snapshot->'items') item
                            WHERE item->>'productId' = $3
                        )
                    FOR SHARE OF o, d
                `,
                [dto.orderId, customerId, productId],
            );
            if (!purchase.rows[0]) {
                throw new BadRequestException('A delivered order containing this product is required');
            }
            try {
                const result = await client.query<ProductReviewRow>(
                    `
                        INSERT INTO product_reviews (
                            product_id, customer_id, order_id, rating, comment
                        ) VALUES ($1, $2, $3, $4, $5)
                        RETURNING id, product_id, customer_id, order_id, rating,
                            comment, status, created_at
                    `,
                    [productId, customerId, dto.orderId, dto.rating, dto.comment ?? ''],
                );
                const row = result.rows[0];
                return {
                    id: row.id,
                    productId: row.product_id,
                    orderId: row.order_id,
                    rating: row.rating,
                    comment: row.comment,
                    status: row.status,
                    createdAt: new Date(row.created_at).toISOString(),
                };
            } catch (error) {
                if (typeof error === 'object' && error !== null
                    && 'code' in error && error.code === '23505') {
                    throw new ConflictException('A review already exists for this product and order');
                }
                throw error;
            }
        });
    }
}
