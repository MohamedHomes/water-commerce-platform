import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { createTestApplication } from './database-test-utils';

describe('Customer favorites', () => {
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

    async function register(email: string) {
        const response = await request(app.getHttpServer())
            .post('/api/v1/auth/register')
            .send({
                email,
                password: 'StrongPass123!',
                firstName: 'Favorite',
                lastName: 'Customer',
            })
            .expect(201);
        return response.body.accessToken as string;
    }

    it('persists favorites privately and supports idempotent add and removal', async () => {
        const token = await register('favorites-owner@example.test');
        const otherToken = await register('favorites-other@example.test');

        await request(app.getHttpServer())
            .get('/api/v1/catalog/favorites')
            .set('Authorization', `Bearer ${token}`)
            .expect(200)
            .expect(({ body }) => expect(body.items).toEqual([]));

        const added = await request(app.getHttpServer())
            .put('/api/v1/catalog/favorites/prod-1')
            .set('Authorization', `Bearer ${token}`)
            .expect(200);
        expect(added.body).toMatchObject({
            id: 'prod-1',
            name: 'AquaFlow 1.5L Mineral Water',
        });
        await request(app.getHttpServer())
            .put('/api/v1/catalog/favorites/prod-1')
            .set('Authorization', `Bearer ${token}`)
            .expect(200);

        const list = await request(app.getHttpServer())
            .get('/api/v1/catalog/favorites')
            .set('Authorization', `Bearer ${token}`)
            .expect(200);
        expect(list.body.total).toBe(1);
        expect(list.body.items[0].id).toBe('prod-1');

        const privateList = await request(app.getHttpServer())
            .get('/api/v1/catalog/favorites')
            .set('Authorization', `Bearer ${otherToken}`)
            .expect(200);
        expect(privateList.body.items).toEqual([]);
        await request(app.getHttpServer())
            .delete('/api/v1/catalog/favorites/prod-1')
            .set('Authorization', `Bearer ${otherToken}`)
            .expect(404);

        await request(app.getHttpServer())
            .delete('/api/v1/catalog/favorites/prod-1')
            .set('Authorization', `Bearer ${token}`)
            .expect(200);
        const removed = await request(app.getHttpServer())
            .get('/api/v1/catalog/favorites')
            .set('Authorization', `Bearer ${token}`)
            .expect(200);
        expect(removed.body.items).toEqual([]);
    });
});
