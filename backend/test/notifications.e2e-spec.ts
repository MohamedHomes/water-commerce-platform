import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { createTestApplication } from './database-test-utils';

describe('Customer notifications', () => {
    let app: INestApplication;
    let close: () => Promise<void>;

    beforeAll(async () => {
        const setup = await createTestApplication();
        app = setup.app;
        close = setup.close;
    }, 15000);

    afterAll(async () => {
        await close();
    }, 15000);

    async function register(email: string) {
        const response = await request(app.getHttpServer())
            .post('/api/v1/auth/register')
            .send({
                email,
                password: 'StrongPass123!',
                firstName: 'Notify',
                lastName: 'Customer',
            })
            .expect(201);
        return response.body.accessToken as string;
    }

    it('creates an in-app notification on order placement and limits access to its customer', async () => {
        const token = await register('notification-owner@example.com');
        await request(app.getHttpServer())
            .post('/api/v1/cart/items')
            .set('Authorization', `Bearer ${token}`)
            .send({ productId: 'prod-1', quantity: 1 })
            .expect(201);
        const address = await request(app.getHttpServer())
            .post('/api/v1/addresses')
            .set('Authorization', `Bearer ${token}`)
            .send({
                label: 'Home',
                recipientName: 'Notify Customer',
                phone: '+966500000333',
                city: 'Riyadh',
                district: 'Central',
                street: 'Main Street',
                building: '30',
            })
            .expect(201);
        const checkout = await request(app.getHttpServer())
            .post('/api/v1/checkout/prepare')
            .set('Authorization', `Bearer ${token}`)
            .send({
                addressId: address.body.id,
                deliveryZoneId: 'zone-riyadh-central',
                deliveryOption: 'standard',
                paymentMethod: 'cash',
            })
            .expect(201);
        const order = await request(app.getHttpServer())
            .post('/api/v1/orders')
            .set('Authorization', `Bearer ${token}`)
            .send({ checkoutId: checkout.body.checkoutId })
            .expect(201);

        const list = await request(app.getHttpServer())
            .get('/api/v1/notifications')
            .set('Authorization', `Bearer ${token}`)
            .expect(200);
        const placed = list.body.items.find((item: { type: string }) => item.type === 'order_placed');
        expect(placed).toMatchObject({
            title: 'Order placed',
            readAt: null,
            data: { orderId: order.body.id },
        });

        const otherToken = await register('notification-other@example.com');
        await request(app.getHttpServer())
            .patch(`/api/v1/notifications/${placed.id}/read`)
            .set('Authorization', `Bearer ${otherToken}`)
            .expect(404);

        const marked = await request(app.getHttpServer())
            .patch(`/api/v1/notifications/${placed.id}/read`)
            .set('Authorization', `Bearer ${token}`)
            .expect(200);
        expect(marked.body.readAt).toEqual(expect.any(String));

        await request(app.getHttpServer())
            .patch(`/api/v1/notifications/${placed.id}/read`)
            .set('Authorization', `Bearer ${token}`)
            .expect(200)
            .expect((response) => expect(response.body.readAt).toBe(marked.body.readAt));

        const afterCancel = await request(app.getHttpServer())
            .post(`/api/v1/orders/${order.body.id}/cancel`)
            .set('Authorization', `Bearer ${token}`)
            .expect(200);
        expect(afterCancel.body.status).toBe('cancelled');
        const updatedList = await request(app.getHttpServer())
            .get('/api/v1/notifications?limit=10')
            .set('Authorization', `Bearer ${token}`)
            .expect(200);
        expect(updatedList.body.items.map((item: { type: string }) => item.type))
            .toContain('order_cancelled');
    });
});
