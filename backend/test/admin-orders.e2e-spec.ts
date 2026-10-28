import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import {
    PGliteDatabaseAdapter,
    createTestApplication,
} from './database-test-utils';

describe('Admin order and delivery operations', () => {
    let app: INestApplication;
    let database: PGliteDatabaseAdapter;
    let close: () => Promise<void>;
    let customerToken: string;
    let adminToken: string;

    const customerPassword = 'StrongPass123!';
    const orderId = '30000000-0000-4000-8000-000000000001';
    const cityId = '30000000-0000-4000-8000-000000000002';
    const zoneId = '30000000-0000-4000-8000-000000000003';
    const addressId = '30000000-0000-4000-8000-000000000004';
    const checkoutId = '30000000-0000-4000-8000-000000000005';
    const deliveryId = '30000000-0000-4000-8000-000000000006';

    beforeAll(async () => {
        const setup = await createTestApplication();
        app = setup.app;
        database = setup.database;
        close = setup.close;

        const registration = await request(app.getHttpServer())
            .post('/api/v1/auth/register')
            .send({
                email: 'admin-orders@example.test',
                password: customerPassword,
                firstName: 'Aqua',
                lastName: 'Admin',
                phone: '+966500000123',
            })
            .expect(201);
        await database.query(
            "UPDATE customers SET role = 'admin' WHERE id = $1",
            [registration.body.customer.id],
        );
        const login = await request(app.getHttpServer())
            .post('/api/v1/auth/login')
            .send({
                email: 'admin-orders@example.test',
                password: customerPassword,
            })
            .expect(201);
        adminToken = login.body.accessToken;

        const customer = await request(app.getHttpServer())
            .post('/api/v1/auth/register')
            .send({
                email: 'ordinary-customer@example.test',
                password: customerPassword,
                firstName: 'Regular',
                lastName: 'Customer',
            })
            .expect(201);
        customerToken = customer.body.accessToken;

        await seedOrder(registration.body.customer.id);
    }, 30_000);

    afterAll(async () => {
        await close();
    });

    it('requires authentication and the administrator role for order details', async () => {
        await request(app.getHttpServer())
            .get(`/api/v1/admin/orders/${orderId}`)
            .expect(401);

        await request(app.getHttpServer())
            .get(`/api/v1/admin/orders/${orderId}`)
            .set('Authorization', `Bearer ${customerToken}`)
            .expect(403);
    });

    it('returns order, customer, payment, address, and delivery details to admins', async () => {
        const response = await request(app.getHttpServer())
            .get(`/api/v1/admin/orders/${orderId}`)
            .set('Authorization', `Bearer ${adminToken}`)
            .expect(200);

        expect(response.body).toMatchObject({
            id: orderId,
            status: 'paid',
            paymentStatus: 'succeeded',
            paymentMethod: 'card',
            customer: {
                email: 'admin-orders@example.test',
                firstName: 'Aqua',
                lastName: 'Admin',
                phone: '+966500000123',
            },
            items: [
                {
                    productId: 'product-test',
                    name: 'Test water',
                    quantity: 2,
                    unitPrice: 5,
                    lineTotal: 10,
                },
            ],
            summary: {
                subtotal: 10,
                total: 17,
                currency: 'SAR',
            },
            payments: [
                {
                    provider: 'test-provider',
                    status: 'succeeded',
                    amount: 17,
                    currency: 'SAR',
                },
            ],
            delivery: {
                id: deliveryId,
                status: 'pending_dispatch',
                trackingCode: 'TESTTRACK001',
                estimatedMinutes: 45,
                events: [
                    {
                        status: 'pending_dispatch',
                        note: 'Order is ready for dispatch',
                    },
                ],
            },
        });
        expect(response.body.address.recipientName).toBe('Aqua Admin');
        expect(response.body.deliveryZone.city).toBe('Test city');
    });

    it('enforces delivery transitions and refreshes the delivery event history', async () => {
        await request(app.getHttpServer())
            .patch(`/api/v1/admin/deliveries/${deliveryId}/status`)
            .set('Authorization', `Bearer ${adminToken}`)
            .send({ status: 'assigned', note: 'Assigned for dispatch' })
            .expect(200);

        await request(app.getHttpServer())
            .patch(`/api/v1/admin/deliveries/${deliveryId}/status`)
            .set('Authorization', `Bearer ${adminToken}`)
            .send({ status: 'delivered', note: 'Invalid skipped state' })
            .expect(409);

        const response = await request(app.getHttpServer())
            .get(`/api/v1/admin/orders/${orderId}`)
            .set('Authorization', `Bearer ${adminToken}`)
            .expect(200);

        expect(response.body.delivery.status).toBe('assigned');
        expect(
            response.body.delivery.events.map(
                (event: { status: string }) => event.status,
            ),
        ).toEqual(['pending_dispatch', 'assigned']);
    });

    it('validates order identifiers and returns not-found for absent orders', async () => {
        await request(app.getHttpServer())
            .get('/api/v1/admin/orders/not-a-uuid')
            .set('Authorization', `Bearer ${adminToken}`)
            .expect(400);

        await request(app.getHttpServer())
            .get('/api/v1/admin/orders/30000000-0000-4000-8000-000000000099')
            .set('Authorization', `Bearer ${adminToken}`)
            .expect(404);
    });

    async function seedOrder(customerId: string) {
        await database.query(
            'INSERT INTO cities (id, name, region) VALUES ($1, $2, $3)',
            [cityId, 'Test city', 'Test region'],
        );
        await database.query(
            'INSERT INTO delivery_zones (id, city_id, name) VALUES ($1, $2, $3)',
            [zoneId, cityId, 'Test zone'],
        );
        await database.query(
            `
                INSERT INTO customer_addresses (
                    id, customer_id, city_id, label, recipient_name, phone,
                    city, district, street, building
                ) VALUES ($1, $2, $3, 'Home', 'Aqua Admin', '+966500000123',
                    'Test city', 'Central', 'Water street', '10')
            `,
            [addressId, customerId, cityId],
        );

        const items = [
            {
                productId: 'product-test',
                name: 'Test water',
                quantity: 2,
                unitPrice: 5,
                lineTotal: 10,
            },
        ];
        await database.query(
            `
                INSERT INTO checkout_sessions (
                    id, customer_id, address_id, delivery_zone_id, cart_snapshot,
                    subtotal, delivery_fee, service_fee, total, payment_method,
                    delivery_option, status, expires_at
                ) VALUES ($1, $2, $3, $4, $5::jsonb, 10, 5, 2, 17, 'card',
                    'standard', 'confirmed', NOW() + INTERVAL '1 hour')
            `,
            [
                checkoutId,
                customerId,
                addressId,
                zoneId,
                JSON.stringify({ items }),
            ],
        );
        await database.query(
            `
                INSERT INTO orders (
                    id, customer_id, checkout_session_id, status, payment_method,
                    delivery_option, address_snapshot, delivery_zone_snapshot,
                    cart_snapshot, subtotal, delivery_fee, service_fee, total, currency
                ) VALUES ($1, $2, $3, 'paid', 'card', 'standard', $4::jsonb,
                    $5::jsonb, $6::jsonb, 10, 5, 2, 17, 'SAR')
            `,
            [
                orderId,
                customerId,
                checkoutId,
                JSON.stringify({
                    recipientName: 'Aqua Admin',
                    phone: '+966500000123',
                    city: 'Test city',
                    district: 'Central',
                    street: 'Water street',
                    building: '10',
                }),
                JSON.stringify({
                    city: 'Test city',
                    name: 'Test zone',
                    baseFee: 5,
                    estimatedMinutes: 45,
                }),
                JSON.stringify({ items }),
            ],
        );
        await database.query(
            `
                INSERT INTO payments (
                    order_id, customer_id, provider, idempotency_key,
                    status, amount, currency
                ) VALUES ($1, $2, 'test-provider', 'admin-order-test',
                    'succeeded', 17, 'SAR')
            `,
            [orderId, customerId],
        );
        await database.query(
            `
                INSERT INTO deliveries (
                    id, order_id, customer_id, estimated_minutes, tracking_code
                ) VALUES ($1, $2, $3, 45, 'TESTTRACK001')
            `,
            [deliveryId, orderId, customerId],
        );
        await database.query(
            `
                INSERT INTO delivery_events (delivery_id, status, note)
                VALUES ($1, 'pending_dispatch', 'Order is ready for dispatch')
            `,
            [deliveryId],
        );
    }
});
