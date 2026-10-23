import { INestApplication } from '@nestjs/common';
import request from 'supertest';
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

        const productDetailResponse = await request(app.getHttpServer())
            .get(`/api/v1/catalog/products/${productsResponse.body.items[0].id}`)
            .expect(200);

        expect(productDetailResponse.body.id).toBe(productsResponse.body.items[0].id);

        const searchResponse = await request(app.getHttpServer())
            .get('/api/v1/search/products')
            .query({ q: 'family', page: 1, limit: 10 })
            .expect(200);

        expect(searchResponse.body.items.length).toBeGreaterThan(0);
        expect(searchResponse.body.items[0].name).toContain('Family');
    });
});
