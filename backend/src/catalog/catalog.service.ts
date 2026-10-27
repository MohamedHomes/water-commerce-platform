import { Injectable, NotFoundException } from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString, Min } from 'class-validator';
import { randomUUID } from 'crypto';
import { QueryResultRow } from 'pg';
import { DatabaseService } from '../database/database.service';
import { SEED_BRAND_IDS, SEED_CATEGORY_IDS } from '../database/seed.constants';

export interface CategoryRecord {
    id: string;
    name: string;
    nameAr?: string;
    slug: string;
    description?: string;
    descriptionAr?: string;
}

export interface BrandRecord {
    id: string;
    name: string;
    nameAr?: string;
    slug: string;
    description?: string;
    descriptionAr?: string;
}

export interface ProductVariantRecord {
    id: string;
    productId: string;
    sku: string;
    barcode: string;
    packageSize: string;
    quantity: number;
    volume: string;
    weight: string;
    dimensions: string;
    price: number;
    compareAtPrice?: number;
    discountPercent?: number;
    isAvailable: boolean;
}

export interface ProductRecord {
    id: string;
    name: string;
    slug: string;
    description: string;
    nameAr?: string;
    descriptionAr?: string;
    categoryId: string;
    brandId: string;
    price: number;
    compareAtPrice?: number;
    discountPercent?: number;
    availability: 'in_stock' | 'low_stock' | 'out_of_stock';
    imageUrl?: string;
    packageSize: string;
    quantity: number;
    volume: string;
    weight: string;
    dimensions: string;
    isActive: boolean;
    createdAt: string;
    updatedAt: string;
    variants: ProductVariantRecord[];
}

export class GetProductsQueryDto {
    @IsOptional()
    @IsString()
    q?: string;

    @IsOptional()
    @IsString()
    categoryId?: string;

    @IsOptional()
    @IsString()
    brandId?: string;

    @IsOptional()
    @Type(() => Number)
    @IsInt()
    @Min(1)
    page?: number;

    @IsOptional()
    @Type(() => Number)
    @IsInt()
    @Min(1)
    limit?: number;

    @IsOptional()
    @IsIn(['relevance', 'price_asc', 'price_desc', 'newest'])
    sort?: 'relevance' | 'price_asc' | 'price_desc' | 'newest';
}

interface CatalogProductRow extends QueryResultRow {
    id: string;
    name: string;
    slug: string;
    description: string | null;
    name_ar: string | null;
    description_ar: string | null;
    category_id: string;
    brand_id: string;
    price: string | number;
    compare_at_price: string | number | null;
    discount_percent: string | number | null;
    availability: ProductRecord['availability'];
    image_url: string | null;
    package_size: string | null;
    quantity: number;
    volume: string | null;
    weight: string | null;
    dimensions: string | null;
    is_active: boolean;
    created_at: Date | string;
    updated_at: Date | string;
    variant_id: string | null;
    variant_sku: string | null;
    variant_barcode: string | null;
    variant_package_size: string | null;
    variant_quantity: number | null;
    variant_volume: string | null;
    variant_weight: string | null;
    variant_dimensions: string | null;
    variant_price: string | number | null;
    variant_compare_at_price: string | number | null;
    variant_discount_percent: string | number | null;
    variant_is_available: boolean | null;
    total_count?: string | number;
}

@Injectable()
export class CatalogService {
    constructor(private readonly database: DatabaseService) {}

    async getCategories() {
        const result = await this.database.query<CategoryRecord>(
            `
                SELECT id, name, name_ar AS "nameAr", slug, description,
                    description_ar AS "descriptionAr"
                FROM categories
                ORDER BY CASE id
                    WHEN 'cat-water' THEN 1
                    WHEN 'cat-boxes' THEN 2
                    WHEN 'cat-bulk' THEN 3
                    ELSE 4
                END, name
            `,
        );
        return { items: result.rows, total: result.rowCount ?? result.rows.length };
    }

    async getBrands() {
        const result = await this.database.query<BrandRecord>(
            `SELECT id, name, name_ar AS "nameAr", slug, description,
                description_ar AS "descriptionAr" FROM brands ORDER BY name, id`,
        );
        return { items: result.rows, total: result.rowCount ?? result.rows.length };
    }

    async getProducts(query: GetProductsQueryDto = {}) {
        const page = Number(query.page ?? 1);
        const limit = Number(query.limit ?? 10);
        const search = (query.q ?? '').trim() || null;
        const orderBy = {
            relevance: 'p.created_at ASC, p.id ASC',
            price_asc: 'p.price ASC, p.id ASC',
            price_desc: 'p.price DESC, p.id DESC',
            newest: 'p.created_at DESC, p.id DESC',
        }[query.sort ?? 'relevance'];
        const result = await this.database.query<CatalogProductRow>(
            `
                WITH paged_products AS (
                    SELECT p.*, COUNT(*) OVER() AS total_count
                    FROM products p
                    WHERE ($1::text IS NULL OR
                        p.name ILIKE '%' || $1 || '%' OR
                        COALESCE(p.name_ar, '') ILIKE '%' || $1 || '%' OR
                        COALESCE(p.description, '') ILIKE '%' || $1 || '%' OR
                        COALESCE(p.description_ar, '') ILIKE '%' || $1 || '%' OR
                        p.id ILIKE '%' || $1 || '%' OR
                        p.category_id ILIKE '%' || $1 || '%' OR
                        p.brand_id ILIKE '%' || $1 || '%' OR
                        EXISTS (
                            SELECT 1 FROM product_variants search_variant
                            WHERE search_variant.product_id = p.id
                              AND search_variant.sku ILIKE '%' || $1 || '%'
                        ) OR EXISTS (
                            SELECT 1 FROM categories search_category
                            WHERE search_category.id = p.category_id
                              AND (search_category.name ILIKE '%' || $1 || '%'
                                OR COALESCE(search_category.name_ar, '') ILIKE '%' || $1 || '%')
                        ) OR EXISTS (
                            SELECT 1 FROM brands search_brand
                            WHERE search_brand.id = p.brand_id
                              AND (search_brand.name ILIKE '%' || $1 || '%'
                                OR COALESCE(search_brand.name_ar, '') ILIKE '%' || $1 || '%')
                        )
                    )
                    AND ($2::text IS NULL OR p.category_id = $2)
                    AND ($3::text IS NULL OR p.brand_id = $3)
                    AND p.is_active = TRUE
                    ORDER BY ${orderBy}
                    LIMIT $4 OFFSET $5
                )
                SELECT p.*, v.id AS variant_id, v.sku AS variant_sku,
                    v.barcode AS variant_barcode, v.package_size AS variant_package_size,
                    v.quantity AS variant_quantity, v.volume AS variant_volume,
                    v.weight AS variant_weight, v.dimensions AS variant_dimensions,
                    v.price AS variant_price, v.compare_at_price AS variant_compare_at_price,
                    v.discount_percent AS variant_discount_percent,
                    v.is_available AS variant_is_available
                FROM paged_products p
                LEFT JOIN product_variants v ON v.product_id = p.id
                ORDER BY ${orderBy}, v.id
            `,
            [search, query.categoryId || null, query.brandId || null, limit, (page - 1) * limit],
        );
        const items = this.mapProducts(result.rows);
        const total = result.rows.length ? Number(result.rows[0].total_count) : 0;

        return {
            items,
            page,
            limit,
            total,
            totalPages: Math.max(1, Math.ceil(total / limit)),
        };
    }

    async getProductById(id: string) {
        const result = await this.database.query<CatalogProductRow>(
            `
                SELECT p.*, v.id AS variant_id, v.sku AS variant_sku,
                    v.barcode AS variant_barcode, v.package_size AS variant_package_size,
                    v.quantity AS variant_quantity, v.volume AS variant_volume,
                    v.weight AS variant_weight, v.dimensions AS variant_dimensions,
                    v.price AS variant_price, v.compare_at_price AS variant_compare_at_price,
                    v.discount_percent AS variant_discount_percent,
                    v.is_available AS variant_is_available
                FROM products p
                LEFT JOIN product_variants v ON v.product_id = p.id
                WHERE p.id = $1 AND p.is_active = TRUE
                ORDER BY v.id
            `,
            [id],
        );
        if (!result.rows.length) {
            throw new NotFoundException('Product not found');
        }
        return this.mapProducts(result.rows)[0];
    }

    async getProductsByIds(ids: string[]) {
        if (ids.length === 0) {
            return [];
        }
        const result = await this.database.query<CatalogProductRow>(
            `
                SELECT p.*, v.id AS variant_id, v.sku AS variant_sku,
                    v.barcode AS variant_barcode, v.package_size AS variant_package_size,
                    v.quantity AS variant_quantity, v.volume AS variant_volume,
                    v.weight AS variant_weight, v.dimensions AS variant_dimensions,
                    v.price AS variant_price, v.compare_at_price AS variant_compare_at_price,
                    v.discount_percent AS variant_discount_percent,
                    v.is_available AS variant_is_available
                FROM products p
                LEFT JOIN product_variants v ON v.product_id = p.id
                WHERE p.id = ANY($1::varchar[]) AND p.is_active = TRUE
                ORDER BY array_position($1::varchar[], p.id), v.id
            `,
            [ids],
        );
        return this.mapProducts(result.rows);
    }

    async createProduct(input: Partial<ProductRecord>) {
        const now = new Date().toISOString();
        const id = input.id ?? randomUUID();
        await this.database.withTransaction(async (client) => {
            await client.query(
                `
                    INSERT INTO products (
                        id, name, name_ar, slug, category_id, brand_id, description,
                        description_ar, price,
                        compare_at_price, discount_percent, availability, image_url,
                        package_size, quantity, volume, weight, dimensions, is_active,
                        created_at, updated_at
                    ) VALUES (
                        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12,
                        $13, $14, $15, $16, $17, $18, $19, $20, $20
                    )
                `,
                [
                    id,
                    input.name ?? 'New Product',
                    input.nameAr ?? null,
                    input.slug ?? `new-product-${id}`,
                    input.categoryId ?? SEED_CATEGORY_IDS.water,
                    input.brandId ?? SEED_BRAND_IDS.aquaflow,
                    input.description ?? 'New product',
                    input.descriptionAr ?? null,
                    input.price ?? 0,
                    input.compareAtPrice ?? null,
                    input.discountPercent ?? null,
                    input.availability ?? 'in_stock',
                    input.imageUrl ?? null,
                    input.packageSize ?? '1L',
                    input.quantity ?? 0,
                    input.volume ?? '1L',
                    input.weight ?? '1kg',
                    input.dimensions ?? '10 x 10 x 10 cm',
                    input.isActive ?? true,
                    now,
                ],
            );

            for (const variant of input.variants ?? []) {
                await client.query(
                    `
                        INSERT INTO product_variants (
                            id, product_id, sku, barcode, package_size, quantity, volume,
                            weight, dimensions, price, compare_at_price, discount_percent,
                            is_available
                        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
                    `,
                    [
                        variant.id ?? randomUUID(),
                        id,
                        variant.sku,
                        variant.barcode || null,
                        variant.packageSize,
                        variant.quantity,
                        variant.volume,
                        variant.weight,
                        variant.dimensions,
                        variant.price,
                        variant.compareAtPrice ?? null,
                        variant.discountPercent ?? null,
                        variant.isAvailable,
                    ],
                );
            }
        });
        return this.getProductById(id);
    }

    searchProducts(query: GetProductsQueryDto = {}) {
        return this.getProducts(query);
    }

    private mapProducts(rows: CatalogProductRow[]): ProductRecord[] {
        const products = new Map<string, ProductRecord>();
        for (const row of rows) {
            let product = products.get(row.id);
            if (!product) {
                product = {
                    id: row.id,
                    name: row.name,
                    slug: row.slug,
                    description: row.description ?? '',
                    nameAr: row.name_ar ?? undefined,
                    descriptionAr: row.description_ar ?? undefined,
                    categoryId: row.category_id,
                    brandId: row.brand_id,
                    price: Number(row.price),
                    compareAtPrice: row.compare_at_price === null ? undefined : Number(row.compare_at_price),
                    discountPercent: row.discount_percent === null ? undefined : Number(row.discount_percent),
                    availability: row.availability,
                    imageUrl: row.image_url ?? undefined,
                    packageSize: row.package_size ?? '',
                    quantity: row.quantity,
                    volume: row.volume ?? '',
                    weight: row.weight ?? '',
                    dimensions: row.dimensions ?? '',
                    isActive: row.is_active,
                    createdAt: new Date(row.created_at).toISOString(),
                    updatedAt: new Date(row.updated_at).toISOString(),
                    variants: [],
                };
                products.set(row.id, product);
            }

            if (row.variant_id !== null) {
                product.variants.push({
                    id: row.variant_id,
                    productId: row.id,
                    sku: row.variant_sku ?? '',
                    barcode: row.variant_barcode ?? '',
                    packageSize: row.variant_package_size ?? '',
                    quantity: row.variant_quantity ?? 0,
                    volume: row.variant_volume ?? '',
                    weight: row.variant_weight ?? '',
                    dimensions: row.variant_dimensions ?? '',
                    price: Number(row.variant_price),
                    compareAtPrice:
                        row.variant_compare_at_price === null ? undefined : Number(row.variant_compare_at_price),
                    discountPercent:
                        row.variant_discount_percent === null ? undefined : Number(row.variant_discount_percent),
                    isAvailable: row.variant_is_available ?? false,
                });
            }
        }
        return [...products.values()];
    }
}
