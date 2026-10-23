import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { PAYMENT_PROVIDER, PaymentProvider, signPaymentWebhook } from '../src/payments/payment-provider';
import { createTestApplication } from './database-test-utils';

const TEST_WEBHOOK_SECRET = 'test-only-payment-webhook-secret';

describe('Payments', () => {
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

    async function createCardOrder(email: string) {
        const registration = await request(app.getHttpServer())
            .post('/api/v1/auth/register')
            .send({
                email,
                password: 'StrongPass123!',
                firstName: 'Payment',
                lastName: 'Customer',
            })
            .expect(201);
        const token = registration.body.accessToken as string;

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
                recipientName: 'Payment Customer',
                phone: '+966500000222',
                city: 'Riyadh',
                district: 'Central',
                street: 'Main Street',
                building: '20',
            })
            .expect(201);

        const checkout = await request(app.getHttpServer())
            .post('/api/v1/checkout/prepare')
            .set('Authorization', `Bearer ${token}`)
            .send({
                addressId: address.body.id,
                deliveryZoneId: 'zone-riyadh-central',
                deliveryOption: 'standard',
                paymentMethod: 'card',
            })
            .expect(201);

        const order = await request(app.getHttpServer())
            .post('/api/v1/orders')
            .set('Authorization', `Bearer ${token}`)
            .send({ checkoutId: checkout.body.checkoutId })
            .expect(201);
        return { token, order: order.body };
    }

    function webhookBody(eventId: string, paymentId: string, type: string, amount = 7) {
        return Buffer.from(JSON.stringify({ eventId, paymentId, type, amount, currency: 'SAR' }));
    }

    function webhookSignature(body: Buffer) {
        return signPaymentWebhook(body, TEST_WEBHOOK_SECRET);
    }

    function createIntent(token: string, orderId: string, idempotencyKey: string) {
        return request(app.getHttpServer())
            .post('/api/v1/payments/intents')
            .set('Authorization', `Bearer ${token}`)
            .send({ orderId, idempotencyKey });
    }

    function postWebhook(body: Buffer, signature: string) {
        return request(app.getHttpServer())
            .post('/api/v1/payments/webhook')
            .set('Content-Type', 'application/json')
            .set('x-payment-signature', signature)
            .send(body.toString('utf8'));
    }

    it('creates payment intents idempotently and prevents cross-customer access', async () => {
        const customer = await createCardOrder('payment-intent@example.com');
        const key = 'payment-intent-2026-0001';
        const first = await createIntent(customer.token, customer.order.id, key).expect(201);
        expect(first.body).toMatchObject({
            orderId: customer.order.id,
            status: 'pending',
            provider: 'test',
            providerPaymentId: `test-${first.body.id}`,
            amount: customer.order.summary.total,
            currency: 'SAR',
            checkoutUrl: null,
        });

        const repeated = await createIntent(customer.token, customer.order.id, key).expect(201);
        expect(repeated.body.id).toBe(first.body.id);
        await request(app.getHttpServer())
            .post('/api/v1/payments/intents')
            .set('Authorization', `Bearer ${customer.token}`)
            .send({
                orderId: customer.order.id,
                idempotencyKey: 'payment-card-data-0001',
                cardNumber: 'not-a-real-card-number',
                cvv: 'not-a-real-cvv',
            })
            .expect(400);

        const other = await request(app.getHttpServer())
            .post('/api/v1/auth/register')
            .send({
                email: 'payment-other@example.com',
                password: 'StrongPass123!',
                firstName: 'Other',
                lastName: 'Customer',
            })
            .expect(201);
        await createIntent(other.body.accessToken, customer.order.id, key).expect(404);
        await request(app.getHttpServer())
            .get(`/api/v1/payments/orders/${customer.order.id}`)
            .set('Authorization', `Bearer ${other.body.accessToken}`)
            .expect(404);

        await request(app.getHttpServer())
            .post(`/api/v1/orders/${customer.order.id}/cancel`)
            .set('Authorization', `Bearer ${customer.token}`)
            .expect(409);
    });

    it('verifies signed webhooks, deduplicates events, and advances order state', async () => {
        const customer = await createCardOrder('payment-webhook@example.com');
        const intent = await createIntent(customer.token, customer.order.id, 'payment-webhook-0001')
            .expect(201);
        const body = webhookBody(
            'event-success-1',
            intent.body.providerPaymentId,
            'payment.succeeded',
            intent.body.amount,
        );
        const provider = app.get<PaymentProvider>(PAYMENT_PROVIDER);
        expect(provider.verifyWebhook(body, webhookSignature(body)).paymentId)
            .toBe(intent.body.providerPaymentId);

        await postWebhook(body, '00'.repeat(32)).expect(401);
        const incorrectAmount = webhookBody(
            'event-wrong-amount',
            intent.body.providerPaymentId,
            'payment.succeeded',
            intent.body.amount + 1,
        );
        await postWebhook(incorrectAmount, webhookSignature(incorrectAmount)).expect(409);

        const accepted = await postWebhook(body, webhookSignature(body)).expect(200);
        expect(accepted.body).toMatchObject({
            accepted: true,
            duplicate: false,
            payment: { id: intent.body.id, status: 'succeeded' },
        });

        const duplicate = await postWebhook(body, webhookSignature(body)).expect(200);
        expect(duplicate.body.duplicate).toBe(true);

        const order = await request(app.getHttpServer())
            .get(`/api/v1/orders/${customer.order.id}`)
            .set('Authorization', `Bearer ${customer.token}`)
            .expect(200);
        expect(order.body.status).toBe('paid');
        const delivery = await request(app.getHttpServer())
            .get(`/api/v1/deliveries/orders/${customer.order.id}`)
            .set('Authorization', `Bearer ${customer.token}`)
            .expect(200);
        expect(delivery.body.status).toBe('pending_dispatch');
        await request(app.getHttpServer())
            .post(`/api/v1/orders/${customer.order.id}/cancel`)
            .set('Authorization', `Bearer ${customer.token}`)
            .expect(409);

        const payments = await request(app.getHttpServer())
            .get(`/api/v1/payments/orders/${customer.order.id}`)
            .set('Authorization', `Bearer ${customer.token}`)
            .expect(200);
        expect(payments.body.items).toEqual([
            expect.objectContaining({ id: intent.body.id, status: 'succeeded' }),
        ]);

        const changedPayload = webhookBody(
            'event-success-1',
            intent.body.providerPaymentId,
            'payment.failed',
            intent.body.amount,
        );
        await postWebhook(changedPayload, webhookSignature(changedPayload)).expect(409);
    });

    it('allows a new intent after a verified provider failure without marking the order paid', async () => {
        const customer = await createCardOrder('payment-retry@example.com');
        const intent = await createIntent(customer.token, customer.order.id, 'payment-retry-0001')
            .expect(201);
        const body = webhookBody(
            'event-failed-1',
            intent.body.providerPaymentId,
            'payment.failed',
            intent.body.amount,
        );
        const result = await postWebhook(body, webhookSignature(body)).expect(200);
        expect(result.body.payment.status).toBe('failed');

        const retry = await createIntent(customer.token, customer.order.id, 'payment-retry-0002')
            .expect(201);
        expect(retry.body.id).not.toBe(intent.body.id);
        expect(retry.body.status).toBe('pending');

        const order = await request(app.getHttpServer())
            .get(`/api/v1/orders/${customer.order.id}`)
            .set('Authorization', `Bearer ${customer.token}`)
            .expect(200);
        expect(order.body.status).toBe('payment_pending');
    });
});
