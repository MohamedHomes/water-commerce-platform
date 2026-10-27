import { Injectable, NotFoundException } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { CatalogService } from './catalog.service';

@Injectable()
export class FavoritesService {
    constructor(
        private readonly database: DatabaseService,
        private readonly catalog: CatalogService,
    ) {}

    async list(customerId: string) {
        const result = await this.database.query<{ product_id: string }>(
            `
                SELECT f.product_id
                FROM customer_favorites f
                JOIN products p ON p.id = f.product_id AND p.is_active = TRUE
                WHERE f.customer_id = $1
                ORDER BY f.created_at DESC, f.product_id
                LIMIT 100
            `,
            [customerId],
        );
        const products = await this.catalog.getProductsByIds(result.rows.map(({ product_id }) => product_id));
        return { items: products, total: products.length };
    }

    async add(customerId: string, productId: string) {
        const product = await this.catalog.getProductById(productId);
        await this.database.query(
            `
                INSERT INTO customer_favorites (customer_id, product_id)
                VALUES ($1, $2)
                ON CONFLICT (customer_id, product_id) DO NOTHING
            `,
            [customerId, productId],
        );
        return product;
    }

    async remove(customerId: string, productId: string) {
        const result = await this.database.query<{ product_id: string }>(
            `
                DELETE FROM customer_favorites
                WHERE customer_id = $1 AND product_id = $2
                RETURNING product_id
            `,
            [customerId, productId],
        );
        if (!result.rows[0]) {
            throw new NotFoundException('Favorite product not found');
        }
        return { success: true };
    }
}
