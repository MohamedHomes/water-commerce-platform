import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { createTestApplication } from './database-test-utils';

describe('Cart and pricing', () => {
    let app: INestApplication;
    let token: string;
    let close: () => Promise<void>;

    beforeAll(async () => {
        const setup = await createTestApplication();
        app = setup.app;
        close = setup.close;

        const registerResponse = await request(app.getHttpServer())
            .post('/api/v1/auth/register')
            .send({
                email: 'cart@example.com',
                password: 'StrongPass123!',
                firstName: 'Cart',
                lastName: 'Customer',
                phone: '+966500000001',
            })
            .expect(201);

        token = registerResponse.body.accessToken;
    });

    afterAll(async () => {
        await close();
    });

    it('adds, updates, validates, and totals cart items', async () => {
        await request(app.getHttpServer())
            .post('/api/v1/cart/items')
            .set('Authorization', `Bearer ${token}`)
            .send({ productId: 'prod-1', quantity: 0 })
            .expect(400);

        const addResponse = await request(app.getHttpServer())
            .post('/api/v1/cart/items')
            .set('Authorization', `Bearer ${token}`)
            .send({ productId: 'prod-1', quantity: 2 })
            .expect(201);

        expect(addResponse.body.items).toHaveLength(1);
        expect(addResponse.body.items[0].productId).toBe('prod-1');
        expect(addResponse.body.items[0].quantity).toBe(2);
        expect(addResponse.body.summary.subtotal).toBe(11);
        expect(addResponse.body.summary.discount).toBe(2);
        expect(addResponse.body.summary.total).toBe(9);

        const updateResponse = await request(app.getHttpServer())
            .patch('/api/v1/cart/items/prod-1')
            .set('Authorization', `Bearer ${token}`)
            .send({ quantity: 3 })
            .expect(200);

        expect(updateResponse.body.items[0].quantity).toBe(3);

        const validateResponse = await request(app.getHttpServer())
            .post('/api/v1/cart/validate')
            .set('Authorization', `Bearer ${token}`)
            .expect(200);

        expect(validateResponse.body.valid).toBe(true);
        expect(validateResponse.body.summary.total).toBeGreaterThan(0);

        const clearResponse = await request(app.getHttpServer())
            .delete('/api/v1/cart')
            .set('Authorization', `Bearer ${token}`)
            .expect(200);

        expect(clearResponse.body.items).toHaveLength(0);
    });

    it('does not expose a customer cart to another customer', async () => {
        const other = await request(app.getHttpServer())
            .post('/api/v1/auth/register')
            .send({
                email: 'other-cart@example.com',
                password: 'StrongPass123!',
                firstName: 'Other',
                lastName: 'Customer',
            })
            .expect(201);

        await request(app.getHttpServer())
            .post('/api/v1/cart/items')
            .set('Authorization', `Bearer ${token}`)
            .send({ productId: 'prod-1', quantity: 1 })
            .expect(201);

        const otherCart = await request(app.getHttpServer())
            .get('/api/v1/cart')
            .set('Authorization', `Bearer ${other.body.accessToken}`)
            .expect(200);
        expect(otherCart.body.items).toHaveLength(0);
    });
});
