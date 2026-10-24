import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { DatabaseService } from '../src/database/database.service';
import { createTestApplication } from './database-test-utils';

describe('Catalog and search API', () => {
    let app: INestApplication;
    let close: () => Promise<void>;

    beforeAll(async () => {
        const setup = await createTestApplication();
        app = setup.app;
        close = setup.close;
    });

    afterAll(async () => {
        await close();
    });

    it('returns catalog categories, brands, products and search results', async () => {
        const categoriesResponse = await request(app.getHttpServer())
            .get('/api/v1/catalog/categories')
            .expect(200);

        expect(categoriesResponse.body.items.length).toBeGreaterThan(0);
        expect(categoriesResponse.body.items).toContainEqual(
            expect.objectContaining({ id: 'cat-water', nameAr: 'مياه معبأة' }),
        );

        const brandsResponse = await request(app.getHttpServer())
            .get('/api/v1/catalog/brands')
            .expect(200);

        expect(brandsResponse.body.items.length).toBeGreaterThan(0);

        const productsResponse = await request(app.getHttpServer())
            .get('/api/v1/catalog/products')
            .query({ q: 'water', page: 1, limit: 10 })
            .expect(200);

        expect(productsResponse.body.items.length).toBeGreaterThan(0);
        expect(productsResponse.body.items[0].name).toContain('Water');
        expect(productsResponse.body.items[0].nameAr).toEqual(expect.any(String));

        const productDetailResponse = await request(app.getHttpServer())
            .get(`/api/v1/catalog/products/${productsResponse.body.items[0].id}`)
            .expect(200);

        expect(productDetailResponse.body.id).toBe(productsResponse.body.items[0].id);
        const database = app.get(DatabaseService);
        const selectedProductId = productsResponse.body.items[0].id as string;
        await database.query('UPDATE products SET is_active = FALSE WHERE id = $1', [selectedProductId]);
        try {
            await request(app.getHttpServer())
                .get(`/api/v1/catalog/products/${selectedProductId}`)
                .expect(404);
        } finally {
            await database.query('UPDATE products SET is_active = TRUE WHERE id = $1', [selectedProductId]);
        }

        const searchResponse = await request(app.getHttpServer())
            .get('/api/v1/search/products')
            .query({ q: 'family', page: 1, limit: 10 })
            .expect(200);

        expect(searchResponse.body.items.length).toBeGreaterThan(0);
        expect(searchResponse.body.items[0].name).toContain('Family');

        const arabicSearch = await request(app.getHttpServer())
            .get('/api/v1/catalog/products')
            .query({ q: 'مياه', page: 1, limit: 10 })
            .expect(200);
        expect(arabicSearch.body.items.length).toBeGreaterThan(0);
        expect(arabicSearch.body.items.some((item: { nameAr?: string }) => item.nameAr)).toBe(true);
    });
});
