import {
    BadRequestException,
    Injectable,
    NotFoundException,
} from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsInt, IsString, Min } from 'class-validator';
import { QueryResultRow } from 'pg';
import { DatabaseService, QueryExecutor } from '../database/database.service';
import { CatalogService } from '../catalog/catalog.service';

export class AddCartItemDto {
    @IsString()
    productId!: string;

    @Type(() => Number)
    @IsInt()
    @Min(1)
    quantity!: number;
}

export class UpdateCartItemDto {
    @Type(() => Number)
    @IsInt()
    @Min(1)
    quantity!: number;
}

export interface CartItemSnapshot {
    productId: string;
    name: string;
    nameAr?: string;
    imageUrl?: string;
    quantity: number;
    unitPrice: number;
    compareAtPrice?: number;
    discountPercent?: number;
    lineTotal: number;
    availability: 'in_stock' | 'low_stock' | 'out_of_stock';
}

export interface CartSummary {
    subtotal: number;
    discount: number;
    total: number;
    itemCount: number;
    currency: string;
}

export interface CartResponse {
    items: CartItemSnapshot[];
    summary: CartSummary;
    valid: boolean;
    errors: string[];
}

interface CartRow extends QueryResultRow {
    product_id: string;
    name: string;
    name_ar: string | null;
    image_url: string | null;
    quantity: number;
    price: string | number;
    compare_at_price: string | number | null;
    discount_percent: string | number | null;
    availability: CartItemSnapshot['availability'];
    is_active: boolean;
    stock_quantity: number;
}

@Injectable()
export class CartService {
    constructor(
        private readonly database: DatabaseService,
        private readonly catalogService: CatalogService,
    ) { }

    getCart(userId: string, executor: QueryExecutor = this.database) {
        return this.readCart(userId, executor);
    }

    async addItem(userId: string, dto: AddCartItemDto): Promise<CartResponse> {
        const product = await this.catalogService.getProductById(dto.productId);
        if (!product.isActive) {
            throw new BadRequestException('This product is currently unavailable');
        }

        return this.database.withTransaction(async (client) => {
            const cart = await client.query<{ id: string }>(
                `
                    INSERT INTO carts (customer_id, status)
                    VALUES ($1, 'active')
                    ON CONFLICT (customer_id, status)
                    DO UPDATE SET updated_at = NOW()
                    RETURNING id
                `,
                [userId],
            );
            await client.query(
                `
                    INSERT INTO cart_items (
                        cart_id, product_id, quantity, unit_price, compare_at_price, discount_percent
                    ) VALUES ($1, $2, $3, $4, $5, $6)
                    ON CONFLICT (cart_id, product_id)
                    DO UPDATE SET
                        quantity = cart_items.quantity + EXCLUDED.quantity,
                        unit_price = EXCLUDED.unit_price,
                        compare_at_price = EXCLUDED.compare_at_price,
                        discount_percent = EXCLUDED.discount_percent,
                        updated_at = NOW()
                `,
                [cart.rows[0].id, product.id, dto.quantity, product.price, product.compareAtPrice ?? null, product.discountPercent ?? null],
            );
            return this.readCart(userId, client);
        });
    }

    async updateItem(userId: string, productId: string, dto: UpdateCartItemDto) {
        const product = await this.catalogService.getProductById(productId);
        if (dto.quantity <= 0) {
            throw new BadRequestException('Quantity must be greater than zero');
        }
        if (dto.quantity > product.quantity) {
            throw new BadRequestException('Requested quantity exceeds available stock');
        }

        return this.database.withTransaction(async (client) => {
            await client.query(
                "SELECT id FROM carts WHERE customer_id = $1 AND status = 'active' FOR UPDATE",
                [userId],
            );
            const result = await client.query<{ id: string }>(
                `
                    UPDATE cart_items ci
                    SET quantity = $3,
                        unit_price = $4,
                        compare_at_price = $5,
                        discount_percent = $6,
                        updated_at = NOW()
                    FROM carts c
                    WHERE ci.cart_id = c.id
                      AND c.customer_id = $1
                      AND c.status = 'active'
                      AND ci.product_id = $2
                    RETURNING ci.id
                `,
                [userId, productId, dto.quantity, product.price, product.compareAtPrice ?? null, product.discountPercent ?? null],
            );
            if (!result.rows.length) {
                throw new NotFoundException('Cart item not found');
            }
            return this.readCart(userId, client);
        });
    }

    async removeItem(userId: string, productId: string) {
        return this.database.withTransaction(async (client) => {
            await client.query(
                "SELECT id FROM carts WHERE customer_id = $1 AND status = 'active' FOR UPDATE",
                [userId],
            );
            await client.query(
                `
                    DELETE FROM cart_items ci
                    USING carts c
                    WHERE ci.cart_id = c.id
                      AND c.customer_id = $1
                      AND c.status = 'active'
                      AND ci.product_id = $2
                `,
                [userId, productId],
            );
            return this.readCart(userId, client);
        });
    }

    async clearCart(userId: string) {
        return this.database.withTransaction(async (client) => {
            await client.query(
                "SELECT id FROM carts WHERE customer_id = $1 AND status = 'active' FOR UPDATE",
                [userId],
            );
            await client.query(
                `
                    DELETE FROM cart_items
                    WHERE cart_id IN (
                        SELECT id FROM carts WHERE customer_id = $1 AND status = 'active'
                    )
                `,
                [userId],
            );
            return this.readCart(userId, client);
        });
    }

    async validateCart(userId: string, executor: QueryExecutor = this.database): Promise<CartResponse> {
        const result = await this.queryCart(userId, executor);
        const items = result.map((row) => this.toCartItem(row));
        const errors: string[] = [];

        for (const row of result) {
            if (!row.is_active) {
                errors.push(`${row.name} is no longer available`);
            } else if (row.availability === 'out_of_stock') {
                errors.push(`${row.name} is out of stock`);
            } else if (row.quantity > row.stock_quantity) {
                errors.push(`${row.name} quantity exceeds stock availability`);
            }
        }

        return this.buildResponse(items, errors);
    }

    private async readCart(userId: string, executor: QueryExecutor = this.database): Promise<CartResponse> {
        const rows = await this.queryCart(userId, executor);
        return this.buildResponse(rows.map((row) => this.toCartItem(row)));
    }

    private queryCart(userId: string, executor: QueryExecutor) {
        return executor.query<CartRow>(
            `
                SELECT ci.product_id, p.name, p.name_ar, p.image_url, ci.quantity, p.price,
                    p.compare_at_price, p.discount_percent, p.availability,
                    p.is_active, p.quantity AS stock_quantity
                FROM carts c
                JOIN cart_items ci ON ci.cart_id = c.id
                JOIN products p ON p.id = ci.product_id
                WHERE c.customer_id = $1 AND c.status = 'active'
                ORDER BY ci.created_at, ci.id
            `,
            [userId],
        ).then((result) => result.rows);
    }

    private toCartItem(row: CartRow): CartItemSnapshot {
        const unitPrice = Number(row.price);
        const compareAtPrice = row.compare_at_price === null ? undefined : Number(row.compare_at_price);
        return {
            productId: row.product_id,
            name: row.name,
            nameAr: row.name_ar ?? undefined,
            imageUrl: row.image_url ?? undefined,
            quantity: row.quantity,
            unitPrice,
            compareAtPrice,
            discountPercent: row.discount_percent === null ? undefined : Number(row.discount_percent),
            lineTotal: this.calculateLineTotal(unitPrice, row.quantity),
            availability: row.availability,
        };
    }

    private buildResponse(items: CartItemSnapshot[], errors: string[] = []): CartResponse {
        const total = items.reduce((amount, item) => amount + item.lineTotal, 0);
        const discount = items.reduce((amount, item) =>
            amount + (item.compareAtPrice && item.compareAtPrice > item.unitPrice
                ? (item.compareAtPrice - item.unitPrice) * item.quantity
                : 0), 0);

        return {
            items,
            summary: {
                subtotal: Number((total + discount).toFixed(2)),
                discount: Number(discount.toFixed(2)),
                total: Number(total.toFixed(2)),
                itemCount: items.reduce((count, item) => count + item.quantity, 0),
                currency: 'SAR',
            },
            valid: errors.length === 0,
            errors,
        };
    }

    private calculateLineTotal(price: number, quantity: number) {
        return Number((price * quantity).toFixed(2));
    }
}
