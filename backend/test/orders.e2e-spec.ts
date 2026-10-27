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

    async function prepareCheckout(
        token: string,
        paymentMethod: 'card' | 'cash',
        quantity = 2,
        promotionCode?: string,
    ) {
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
                promotionCode,
            })
            .expect(201);
        return {
            checkoutId: checkout.body.checkoutId as string,
            addressId: address.body.id as string,
        };
    }

    it('places from a validated checkout once and keeps the order private to its customer', async () => {
        const customer = await registerCustomer('orders-card@example.com');
        const beforeReservation = await app
            .get(DatabaseService)
            .query<{ quantity: number }>('SELECT quantity FROM products WHERE id = $1', ['prod-1']);
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
            summary: expect.objectContaining({
                total: expect.any(Number),
                currency: 'SAR',
            }),
        });
        const inventory = await app
            .get(DatabaseService)
            .query<{ quantity: number }>('SELECT quantity FROM products WHERE id = $1', ['prod-1']);
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

        await request(app.getHttpServer())
            .post(`/api/v1/orders/${created.body.id}/cancel`)
            .set('Authorization', `Bearer ${customer.token}`)
            .expect(200);
    });

    it('cancels an unpaid cash order and reorders its item snapshot at current prices', async () => {
        const customer = await registerCustomer('orders-cash@example.com');
        const before = await app
            .get(DatabaseService)
            .query<{ quantity: number }>('SELECT quantity FROM products WHERE id = $1', ['prod-1']);
        const prepared = await prepareCheckout(customer.token, 'cash');
        const created = await request(app.getHttpServer())
            .post('/api/v1/orders')
            .set('Authorization', `Bearer ${customer.token}`)
            .send({ checkoutId: prepared.checkoutId })
            .expect(201);
        expect(created.body.status).toBe('placed');
        expect(created.body.items[0].unitPrice).toBe(4.5);
        const afterReservation = await app
            .get(DatabaseService)
            .query<{ quantity: number }>('SELECT quantity FROM products WHERE id = $1', ['prod-1']);
        expect(afterReservation.rows[0].quantity).toBe(before.rows[0].quantity - 2);

        const cancelled = await request(app.getHttpServer())
            .post(`/api/v1/orders/${created.body.id}/cancel`)
            .set('Authorization', `Bearer ${customer.token}`)
            .expect(200);
        expect(cancelled.body.status).toBe('cancelled');
        expect(cancelled.body.cancelledAt).toEqual(expect.any(String));
        const cancelledDelivery = await request(app.getHttpServer())
            .get(`/api/v1/deliveries/orders/${created.body.id}`)
            .set('Authorization', `Bearer ${customer.token}`)
            .expect(200);
        expect(cancelledDelivery.body.status).toBe('cancelled');
        const afterRelease = await app
            .get(DatabaseService)
            .query<{ quantity: number }>('SELECT quantity FROM products WHERE id = $1', ['prod-1']);
        expect(afterRelease.rows[0].quantity).toBe(before.rows[0].quantity);

        await app.get(DatabaseService).query('UPDATE products SET price = $1 WHERE id = $2', [6, 'prod-1']);
        const reordered = await request(app.getHttpServer())
            .post(`/api/v1/orders/${created.body.id}/reorder`)
            .set('Authorization', `Bearer ${customer.token}`)
            .expect(200);
        expect(reordered.body.cart.items).toEqual([
            expect.objectContaining({
                productId: 'prod-1',
                quantity: 2,
                unitPrice: 6,
            }),
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
        const originalInventory = await app
            .get(DatabaseService)
            .query<{ quantity: number }>('SELECT quantity FROM products WHERE id = $1', ['prod-1']);
        await app
            .get(DatabaseService)
            .query("UPDATE products SET quantity = 1, availability = 'in_stock' WHERE id = $1", ['prod-1']);
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
        const successfulIndex = results.findIndex((result) => result.status === 201);
        const successfulOrder = results[successfulIndex]?.body;
        const successfulToken = successfulIndex === 0 ? firstCustomer.token : secondCustomer.token;
        expect(successfulOrder).toBeDefined();

        const inventory = await app
            .get(DatabaseService)
            .query<{ quantity: number }>('SELECT quantity FROM products WHERE id = $1', ['prod-1']);
        expect(inventory.rows[0].quantity).toBe(0);
        const reservations = await app
            .get(DatabaseService)
            .query<{ count: string }>(
                "SELECT COUNT(*)::text AS count FROM inventory_reservations WHERE order_id = $1 AND status = 'reserved'",
                [successfulOrder.id],
            );
        expect(Number(reservations.rows[0].count)).toBe(1);
        const delivery = await request(app.getHttpServer())
            .get(`/api/v1/deliveries/orders/${successfulOrder.id}`)
            .set('Authorization', `Bearer ${successfulToken}`)
            .expect(200);
        expect(delivery.body).toMatchObject({
            orderId: successfulOrder.id,
            status: 'pending_dispatch',
            trackingAvailable: false,
            events: [expect.objectContaining({ status: 'pending_dispatch' })],
        });
        await request(app.getHttpServer())
            .get(`/api/v1/deliveries/orders/${successfulOrder.id}`)
            .set('Authorization', `Bearer ${successfulIndex === 0 ? secondCustomer.token : firstCustomer.token}`)
            .expect(404);

        await request(app.getHttpServer())
            .post(`/api/v1/orders/${successfulOrder.id}/cancel`)
            .set('Authorization', `Bearer ${successfulToken}`)
            .expect(200);

        await app
            .get(DatabaseService)
            .query('UPDATE products SET quantity = $1, availability = $2 WHERE id = $3', [
                originalInventory.rows[0].quantity,
                'in_stock',
                'prod-1',
            ]);
    });

    it('applies a server-calculated promotion once and enforces redemption limits', async () => {
        const database = app.get(DatabaseService);
        await database.query(
            `
                INSERT INTO promotions (
                    code, discount_type, discount_value, max_redemptions, max_per_customer
                ) VALUES ('SAVE10', 'percentage', 10, 1, 1)
            `,
        );

        const customer = await registerCustomer('promotion-customer@example.com');
        const prepared = await prepareCheckout(customer.token, 'cash', 2, ' save10 ');
        expect(prepared.checkoutId).toBeTruthy();

        const session = await request(app.getHttpServer())
            .get(`/api/v1/checkout/${prepared.checkoutId}`)
            .set('Authorization', `Bearer ${customer.token}`)
            .expect(200);
        expect(session.body.summary).toMatchObject({
            promotionCode: 'SAVE10',
            discount: expect.any(Number),
        });
        expect(session.body.summary.discount).toBeGreaterThan(0);

        const created = await request(app.getHttpServer())
            .post('/api/v1/orders')
            .set('Authorization', `Bearer ${customer.token}`)
            .send({ checkoutId: prepared.checkoutId })
            .expect(201);
        expect(created.body.summary.discount).toBe(session.body.summary.discount);
        expect(created.body.summary.promotionCode).toBe('SAVE10');
        const redemptions = await database.query<{ count: string }>(
            'SELECT COUNT(*)::text AS count FROM promotion_redemptions',
        );
        expect(Number(redemptions.rows[0].count)).toBe(1);

        const anotherCustomer = await registerCustomer('promotion-other@example.com');
        await request(app.getHttpServer())
            .post('/api/v1/cart/items')
            .set('Authorization', `Bearer ${anotherCustomer.token}`)
            .send({ productId: 'prod-1', quantity: 1 })
            .expect(201);
        const address = await request(app.getHttpServer())
            .post('/api/v1/addresses')
            .set('Authorization', `Bearer ${anotherCustomer.token}`)
            .send({
                label: 'Home',
                recipientName: 'Promotion Customer',
                phone: '+966500000111',
                city: 'Riyadh',
                district: 'Central',
                street: 'Main Street',
                building: '12',
            })
            .expect(201);
        await request(app.getHttpServer())
            .post('/api/v1/checkout/prepare')
            .set('Authorization', `Bearer ${anotherCustomer.token}`)
            .send({
                addressId: address.body.id,
                deliveryZoneId: 'zone-riyadh-central',
                deliveryOption: 'standard',
                paymentMethod: 'cash',
                promotionCode: 'SAVE10',
            })
            .expect(400);
    });

    it('allows admins to advance delivery state only through the supported sequence', async () => {
        const customer = await registerCustomer('delivery-admin-customer@example.com');
        const prepared = await prepareCheckout(customer.token, 'cash', 1);
        const order = await request(app.getHttpServer())
            .post('/api/v1/orders')
            .set('Authorization', `Bearer ${customer.token}`)
            .send({ checkoutId: prepared.checkoutId })
            .expect(201);
        const delivery = await request(app.getHttpServer())
            .get(`/api/v1/deliveries/orders/${order.body.id}`)
            .set('Authorization', `Bearer ${customer.token}`)
            .expect(200);
        await request(app.getHttpServer())
            .post('/api/v1/catalog/products/prod-1/reviews')
            .set('Authorization', `Bearer ${customer.token}`)
            .send({ orderId: order.body.id, rating: 5, comment: 'Before delivery' })
            .expect(400);

        const admin = await registerCustomer('delivery-admin@example.com');
        const database = app.get(DatabaseService);
        await database.query("UPDATE customers SET role = 'admin' WHERE id = $1", [admin.customerId]);
        const adminLogin = await request(app.getHttpServer())
            .post('/api/v1/auth/login')
            .send({ email: 'delivery-admin@example.com', password: 'StrongPass123!' })
            .expect(201);
        const adminToken = adminLogin.body.accessToken as string;

        await request(app.getHttpServer())
            .patch(`/api/v1/admin/deliveries/${delivery.body.id}/status`)
            .set('Authorization', `Bearer ${customer.token}`)
            .send({ status: 'assigned', note: 'Customer cannot assign delivery' })
            .expect(403);
        await request(app.getHttpServer())
            .patch(`/api/v1/admin/deliveries/${delivery.body.id}/status`)
            .set('Authorization', `Bearer ${adminToken}`)
            .send({ status: 'delivered', note: 'Attempt to skip steps' })
            .expect(409);
        for (const status of ['assigned', 'picked_up', 'delivered']) {
            await request(app.getHttpServer())
                .patch(`/api/v1/admin/deliveries/${delivery.body.id}/status`)
                .set('Authorization', `Bearer ${adminToken}`)
                .send({ status, note: `Operations marked ${status}` })
                .expect(200);
        }

        const updated = await request(app.getHttpServer())
            .get(`/api/v1/deliveries/orders/${order.body.id}`)
            .set('Authorization', `Bearer ${customer.token}`)
            .expect(200);
        expect(updated.body.status).toBe('delivered');
        expect(updated.body.deliveredAt).toEqual(expect.any(String));
        expect(updated.body.events.map((event: { status: string }) => event.status)).toEqual([
            'pending_dispatch',
            'assigned',
            'picked_up',
            'delivered',
        ]);
        const orderDetails = await request(app.getHttpServer())
            .get(`/api/v1/orders/${order.body.id}`)
            .set('Authorization', `Bearer ${customer.token}`)
            .expect(200);
        expect(orderDetails.body).toMatchObject({
            status: 'placed',
            deliveryStatus: 'delivered',
        });
        const customerOrders = await request(app.getHttpServer())
            .get('/api/v1/orders')
            .set('Authorization', `Bearer ${customer.token}`)
            .expect(200);
        expect(customerOrders.body.items).toContainEqual(
            expect.objectContaining({
                id: order.body.id,
                status: 'placed',
                deliveryStatus: 'delivered',
            }),
        );

        const anotherCustomer = await registerCustomer('review-other-customer@example.com');
        await request(app.getHttpServer())
            .post('/api/v1/catalog/products/prod-1/reviews')
            .set('Authorization', `Bearer ${anotherCustomer.token}`)
            .send({ orderId: order.body.id, rating: 5, comment: 'Not my order' })
            .expect(400);
        await request(app.getHttpServer())
            .post('/api/v1/catalog/products/prod-1/reviews')
            .set('Authorization', `Bearer ${customer.token}`)
            .send({ orderId: order.body.id, rating: 6, comment: 'Invalid rating' })
            .expect(400);

        const submitted = await request(app.getHttpServer())
            .post('/api/v1/catalog/products/prod-1/reviews')
            .set('Authorization', `Bearer ${customer.token}`)
            .send({
                orderId: order.body.id,
                rating: 5,
                comment: 'Arrived in good condition',
            })
            .expect(201);
        expect(submitted.body.status).toBe('pending');
        const orderAfterReview = await request(app.getHttpServer())
            .get(`/api/v1/orders/${order.body.id}`)
            .set('Authorization', `Bearer ${customer.token}`)
            .expect(200);
        expect(orderAfterReview.body).toMatchObject({
            status: 'placed',
            deliveryStatus: 'delivered',
        });
        const hidden = await request(app.getHttpServer()).get('/api/v1/catalog/products/prod-1/reviews').expect(200);
        expect(hidden.body).toMatchObject({
            items: [],
            summary: { count: 0, averageRating: null },
        });

        const pendingReviews = await request(app.getHttpServer())
            .get('/api/v1/admin/reviews')
            .set('Authorization', `Bearer ${adminToken}`)
            .expect(200);
        expect(pendingReviews.body.items).toContainEqual(
            expect.objectContaining({ id: submitted.body.id, product_id: 'prod-1' }),
        );
        await request(app.getHttpServer())
            .patch(`/api/v1/admin/reviews/${submitted.body.id}/status`)
            .set('Authorization', `Bearer ${adminToken}`)
            .send({ status: 'approved' })
            .expect(200);

        const secondPrepared = await prepareCheckout(customer.token, 'cash', 1);
        const secondOrder = await request(app.getHttpServer())
            .post('/api/v1/orders')
            .set('Authorization', `Bearer ${customer.token}`)
            .send({ checkoutId: secondPrepared.checkoutId })
            .expect(201);
        const secondDelivery = await request(app.getHttpServer())
            .get(`/api/v1/deliveries/orders/${secondOrder.body.id}`)
            .set('Authorization', `Bearer ${customer.token}`)
            .expect(200);
        for (const status of ['assigned', 'picked_up', 'delivered']) {
            await request(app.getHttpServer())
                .patch(`/api/v1/admin/deliveries/${secondDelivery.body.id}/status`)
                .set('Authorization', `Bearer ${adminToken}`)
                .send({ status, note: `Operations marked ${status}` })
                .expect(200);
        }
        const rejectedReview = await request(app.getHttpServer())
            .post('/api/v1/catalog/products/prod-1/reviews')
            .set('Authorization', `Bearer ${customer.token}`)
            .send({
                orderId: secondOrder.body.id,
                rating: 2,
                comment: 'Rejected review',
            })
            .expect(201);
        await request(app.getHttpServer())
            .patch(`/api/v1/admin/reviews/${rejectedReview.body.id}/status`)
            .set('Authorization', `Bearer ${adminToken}`)
            .send({ status: 'rejected' })
            .expect(200);
        const hiddenRejected = await request(app.getHttpServer())
            .get('/api/v1/catalog/products/prod-1/reviews')
            .expect(200);
        expect(hiddenRejected.body.summary).toEqual({ count: 1, averageRating: 5 });
        expect(hiddenRejected.body.items).toHaveLength(1);

        const published = await request(app.getHttpServer()).get('/api/v1/catalog/products/prod-1/reviews').expect(200);
        expect(published.body.summary).toEqual({ count: 1, averageRating: 5 });
        expect(published.body.items).toEqual([
            expect.objectContaining({
                rating: 5,
                comment: 'Arrived in good condition',
            }),
        ]);
        await request(app.getHttpServer())
            .post('/api/v1/catalog/products/prod-1/reviews')
            .set('Authorization', `Bearer ${customer.token}`)
            .send({ orderId: order.body.id, rating: 4, comment: '' })
            .expect(409);
    });
});
