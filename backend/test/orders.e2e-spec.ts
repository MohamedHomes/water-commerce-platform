import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { DatabaseService } from '../src/database/database.service';
import { createTestApplication } from './database-test-utils';

describe('Orders', () => {
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

    async function registerCustomer(email: string) {
        const response = await request(app.getHttpServer())
            .post('/api/v1/auth/register')
            .send({
                email,
                password: 'StrongPass123!',
                firstName: 'Order',
                lastName: 'Customer',
            })
            .expect(201);
        return {
            token: response.body.accessToken as string,
            customerId: response.body.customer.id as string,
        };
    }

    async function prepareCheckout(token: string, paymentMethod: 'card' | 'cash', quantity = 2) {
        await request(app.getHttpServer())
            .post('/api/v1/cart/items')
            .set('Authorization', `Bearer ${token}`)
            .send({ productId: 'prod-1', quantity })
            .expect(201);

        const address = await request(app.getHttpServer())
            .post('/api/v1/addresses')
            .set('Authorization', `Bearer ${token}`)
            .send({
                label: 'Home',
                recipientName: 'Order Customer',
                phone: '+966500000111',
                city: 'Riyadh',
                district: 'Central',
                street: 'Main Street',
                building: '12',
            })
            .expect(201);

        const checkout = await request(app.getHttpServer())
            .post('/api/v1/checkout/prepare')
            .set('Authorization', `Bearer ${token}`)
            .send({
                addressId: address.body.id,
                deliveryZoneId: 'zone-riyadh-central',
                deliveryOption: 'standard',
                paymentMethod,
            })
            .expect(201);
        return {
            checkoutId: checkout.body.checkoutId as string,
            addressId: address.body.id as string,
        };
    }

    it('places from a validated checkout once and keeps the order private to its customer', async () => {
        const customer = await registerCustomer('orders-card@example.com');
        const beforeReservation = await app.get(DatabaseService).query<{ quantity: number }>(
            'SELECT quantity FROM products WHERE id = $1',
            ['prod-1'],
        );
        const prepared = await prepareCheckout(customer.token, 'card');

        const created = await request(app.getHttpServer())
            .post('/api/v1/orders')
            .set('Authorization', `Bearer ${customer.token}`)
            .send({ checkoutId: prepared.checkoutId })
            .expect(201);

        expect(created.body).toMatchObject({
            customerId: customer.customerId,
            checkoutId: prepared.checkoutId,
            status: 'payment_pending',
            paymentMethod: 'card',
            items: [expect.objectContaining({ productId: 'prod-1', quantity: 2 })],
            summary: expect.objectContaining({ total: expect.any(Number), currency: 'SAR' }),
        });
        const inventory = await app.get(DatabaseService).query<{ quantity: number }>(
            'SELECT quantity FROM products WHERE id = $1',
            ['prod-1'],
        );
        expect(inventory.rows[0].quantity).toBe(beforeReservation.rows[0].quantity - 2);

        const repeated = await request(app.getHttpServer())
            .post('/api/v1/orders')
            .set('Authorization', `Bearer ${customer.token}`)
            .send({ checkoutId: prepared.checkoutId })
            .expect(201);
        expect(repeated.body.id).toBe(created.body.id);

        await request(app.getHttpServer())
            .patch(`/api/v1/addresses/${prepared.addressId}`)
            .set('Authorization', `Bearer ${customer.token}`)
            .send({ street: 'Updated Road' })
            .expect(200);
        const details = await request(app.getHttpServer())
            .get(`/api/v1/orders/${created.body.id}`)
            .set('Authorization', `Bearer ${customer.token}`)
            .expect(200);
        expect(details.body.address.street).toBe('Main Street');

        const cart = await request(app.getHttpServer())
            .get('/api/v1/cart')
            .set('Authorization', `Bearer ${customer.token}`)
            .expect(200);
        expect(cart.body.items).toHaveLength(0);

        const otherCustomer = await registerCustomer('orders-other@example.com');
        await request(app.getHttpServer())
            .get(`/api/v1/orders/${created.body.id}`)
            .set('Authorization', `Bearer ${otherCustomer.token}`)
            .expect(404);

        const list = await request(app.getHttpServer())
            .get('/api/v1/orders?page=1&limit=10')
            .set('Authorization', `Bearer ${customer.token}`)
            .expect(200);
        expect(list.body.items.map((order: { id: string }) => order.id)).toContain(created.body.id);
        expect(list.body.total).toBe(1);

        const otherList = await request(app.getHttpServer())
            .get('/api/v1/orders')
            .set('Authorization', `Bearer ${otherCustomer.token}`)
            .expect(200);
        expect(otherList.body.items).toHaveLength(0);
        expect(otherCustomer.customerId).not.toBe(customer.customerId);
    });

    it('cancels an unpaid cash order and reorders its item snapshot at current prices', async () => {
        const customer = await registerCustomer('orders-cash@example.com');
        const before = await app.get(DatabaseService).query<{ quantity: number }>(
            'SELECT quantity FROM products WHERE id = $1',
            ['prod-1'],
        );
        const prepared = await prepareCheckout(customer.token, 'cash');
        const created = await request(app.getHttpServer())
            .post('/api/v1/orders')
            .set('Authorization', `Bearer ${customer.token}`)
            .send({ checkoutId: prepared.checkoutId })
            .expect(201);
        expect(created.body.status).toBe('placed');
        expect(created.body.items[0].unitPrice).toBe(4.5);
        const afterReservation = await app.get(DatabaseService).query<{ quantity: number }>(
            'SELECT quantity FROM products WHERE id = $1',
            ['prod-1'],
        );
        expect(afterReservation.rows[0].quantity).toBe(before.rows[0].quantity - 2);

        const cancelled = await request(app.getHttpServer())
            .post(`/api/v1/orders/${created.body.id}/cancel`)
            .set('Authorization', `Bearer ${customer.token}`)
            .expect(200);
        expect(cancelled.body.status).toBe('cancelled');
        expect(cancelled.body.cancelledAt).toEqual(expect.any(String));
        const afterRelease = await app.get(DatabaseService).query<{ quantity: number }>(
            'SELECT quantity FROM products WHERE id = $1',
            ['prod-1'],
        );
        expect(afterRelease.rows[0].quantity).toBe(before.rows[0].quantity);

        await app.get(DatabaseService).query(
            'UPDATE products SET price = $1 WHERE id = $2',
            [6, 'prod-1'],
        );
        const reordered = await request(app.getHttpServer())
            .post(`/api/v1/orders/${created.body.id}/reorder`)
            .set('Authorization', `Bearer ${customer.token}`)
            .expect(200);
        expect(reordered.body.cart.items).toEqual([
            expect.objectContaining({ productId: 'prod-1', quantity: 2, unitPrice: 6 }),
        ]);
        expect(reordered.body.cart.summary.total).toBe(12);
        const persistedOrder = await request(app.getHttpServer())
            .get(`/api/v1/orders/${created.body.id}`)
            .set('Authorization', `Bearer ${customer.token}`)
            .expect(200);
        expect(persistedOrder.body.items[0].unitPrice).toBe(4.5);
    });

    it('rejects order placement when the cart has changed since checkout review', async () => {
        const customer = await registerCustomer('orders-stale@example.com');
        const prepared = await prepareCheckout(customer.token, 'cash');

        await request(app.getHttpServer())
            .patch('/api/v1/cart/items/prod-1')
            .set('Authorization', `Bearer ${customer.token}`)
            .send({ quantity: 3 })
            .expect(200);

        await request(app.getHttpServer())
            .post('/api/v1/orders')
            .set('Authorization', `Bearer ${customer.token}`)
            .send({ checkoutId: prepared.checkoutId })
            .expect(409);

        const orders = await request(app.getHttpServer())
            .get('/api/v1/orders')
            .set('Authorization', `Bearer ${customer.token}`)
            .expect(200);
        expect(orders.body.items).toHaveLength(0);
    });

    it('serializes competing orders so inventory cannot be oversold', async () => {
        await app.get(DatabaseService).query(
            "UPDATE products SET quantity = 1, availability = 'in_stock' WHERE id = $1",
            ['prod-1'],
        );
        const firstCustomer = await registerCustomer('inventory-first@example.com');
        const secondCustomer = await registerCustomer('inventory-second@example.com');
        const firstCheckout = await prepareCheckout(firstCustomer.token, 'cash', 1);
        const secondCheckout = await prepareCheckout(secondCustomer.token, 'cash', 1);

        const results = await Promise.all([
            request(app.getHttpServer())
                .post('/api/v1/orders')
                .set('Authorization', `Bearer ${firstCustomer.token}`)
                .send({ checkoutId: firstCheckout.checkoutId }),
            request(app.getHttpServer())
                .post('/api/v1/orders')
                .set('Authorization', `Bearer ${secondCustomer.token}`)
                .send({ checkoutId: secondCheckout.checkoutId }),
        ]);
        expect(results.map((result) => result.status).sort()).toEqual([201, 400]);
        const successfulOrder = results.find((result) => result.status === 201)?.body;
        expect(successfulOrder).toBeDefined();

        const inventory = await app.get(DatabaseService).query<{ quantity: number }>(
            'SELECT quantity FROM products WHERE id = $1',
            ['prod-1'],
        );
        expect(inventory.rows[0].quantity).toBe(0);
        const reservations = await app.get(DatabaseService).query<{ count: string }>(
            "SELECT COUNT(*)::text AS count FROM inventory_reservations WHERE order_id = $1 AND status = 'reserved'",
            [successfulOrder.id],
        );
        expect(Number(reservations.rows[0].count)).toBe(1);
    });
});
