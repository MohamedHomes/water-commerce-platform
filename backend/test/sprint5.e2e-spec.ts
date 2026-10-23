import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { createTestApplication } from './database-test-utils';

describe('Sprint 5 address and checkout', () => {
    let app: INestApplication;
    let authToken: string;
    let customerId: string;
    let addressId: string;
    let close: () => Promise<void>;

    beforeAll(async () => {
        const setup = await createTestApplication();
        app = setup.app;
        close = setup.close;

        const registerResponse = await request(app.getHttpServer())
            .post('/api/v1/auth/register')
            .send({
                email: 'sprint5@example.com',
                password: 'StrongPass123!',
                firstName: 'Sprint',
                lastName: 'Five',
                phone: '+966500000999',
            })
            .expect(201);

        authToken = registerResponse.body.accessToken;
        customerId = registerResponse.body.customer.id;
    }, 15000);

    afterAll(async () => {
        await close();
    }, 15000);

    it('creates addresses, sets a default, and prepares checkout', async () => {
        const citiesResponse = await request(app.getHttpServer())
            .get('/api/v1/addresses/cities')
            .set('Authorization', `Bearer ${authToken}`)
            .expect(200);

        expect(citiesResponse.body.items.length).toBeGreaterThan(0);

        const createAddressResponse = await request(app.getHttpServer())
            .post('/api/v1/addresses')
            .set('Authorization', `Bearer ${authToken}`)
            .send({
                label: 'Home',
                recipientName: 'Sprint Customer',
                phone: '+966500000111',
                city: 'Riyadh',
                district: 'Al Olaya',
                street: 'King Fahad Road',
                building: '12',
                apartment: 'A5',
                floor: '2',
                latitude: 24.7136,
                longitude: 46.6753,
                notes: 'Near the mall',
                isDefault: true,
            })
            .expect(201);

        addressId = createAddressResponse.body.id;
        expect(createAddressResponse.body.isDefault).toBe(true);

        const updateResponse = await request(app.getHttpServer())
            .patch(`/api/v1/addresses/${addressId}`)
            .set('Authorization', `Bearer ${authToken}`)
            .send({
                notes: 'Near the metro station',
            })
            .expect(200);

        expect(updateResponse.body.notes).toBe('Near the metro station');

        await request(app.getHttpServer())
            .patch(`/api/v1/addresses/${addressId}`)
            .set('Authorization', `Bearer ${authToken}`)
            .send({ city: 'Unconfigured City' })
            .expect(400);

        const otherCustomer = await request(app.getHttpServer())
            .post('/api/v1/auth/register')
            .send({
                email: 'sprint5-other@example.com',
                password: 'StrongPass123!',
                firstName: 'Other',
                lastName: 'Customer',
                phone: '+966500000998',
            })
            .expect(201);

        const otherAddresses = await request(app.getHttpServer())
            .get('/api/v1/addresses')
            .set('Authorization', `Bearer ${otherCustomer.body.accessToken}`)
            .expect(200);
        expect(otherAddresses.body.items).toHaveLength(0);

        await request(app.getHttpServer())
            .delete(`/api/v1/addresses/${addressId}`)
            .set('Authorization', `Bearer ${otherCustomer.body.accessToken}`)
            .expect(404);

        await request(app.getHttpServer())
            .post('/api/v1/checkout/prepare')
            .set('Authorization', `Bearer ${authToken}`)
            .send({
                addressId,
                deliveryZoneId: 'zone-riyadh-central',
                deliveryOption: 'standard',
                paymentMethod: 'card',
            })
            .expect(400);

        const cartAddResponse = await request(app.getHttpServer())
            .post('/api/v1/cart/items')
            .set('Authorization', `Bearer ${authToken}`)
            .send({ productId: 'prod-1', quantity: 2 })
            .expect(201);

        expect(cartAddResponse.body.summary.total).toBeGreaterThan(0);

        const zonesResponse = await request(app.getHttpServer())
            .get('/api/v1/addresses/delivery-zones')
            .set('Authorization', `Bearer ${authToken}`)
            .expect(200);

        expect(zonesResponse.body.items).toEqual(
            expect.arrayContaining([
                expect.objectContaining({ city: 'Riyadh' }),
            ]),
        );

        await request(app.getHttpServer())
            .post('/api/v1/checkout/prepare')
            .set('Authorization', `Bearer ${authToken}`)
            .send({
                addressId,
                deliveryZoneId: 'zone-jeddah-central',
                deliveryOption: 'standard',
                paymentMethod: 'card',
            })
            .expect(400);

        const prepareResponse = await request(app.getHttpServer())
            .post('/api/v1/checkout/prepare')
            .set('Authorization', `Bearer ${authToken}`)
            .send({
                addressId,
                deliveryZoneId: 'zone-riyadh-central',
                deliveryOption: 'standard',
                paymentMethod: 'card',
            })
            .expect(201);

        expect(prepareResponse.body.valid).toBe(true);
        expect(prepareResponse.body.summary.total).toBeGreaterThan(0);
        expect(prepareResponse.body.address.id).toBe(addressId);
        expect(prepareResponse.body.status).toBe('draft');

        const sessionResponse = await request(app.getHttpServer())
            .get(`/api/v1/checkout/${prepareResponse.body.checkoutId}`)
            .set('Authorization', `Bearer ${authToken}`)
            .expect(200);
        expect(sessionResponse.body.customerId).toBe(customerId);

        await request(app.getHttpServer())
            .get(`/api/v1/checkout/${prepareResponse.body.checkoutId}`)
            .set('Authorization', `Bearer ${otherCustomer.body.accessToken}`)
            .expect(404);
    });
});
