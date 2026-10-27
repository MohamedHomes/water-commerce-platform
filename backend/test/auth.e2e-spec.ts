import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { createTestApplication } from './database-test-utils';

describe('Authentication and customer identity', () => {
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

    it('registers, logs in, refreshes token, and returns profile', async () => {
        const registerPayload = {
            email: 'customer@example.com',
            password: 'StrongPass123!',
            firstName: 'Amina',
            lastName: 'Rahman',
            phone: '+966500000000',
        };

        const registerResponse = await request(app.getHttpServer())
            .post('/api/v1/auth/register')
            .send(registerPayload)
            .expect(201);

        expect(registerResponse.body.customer.email).toBe(registerPayload.email.toLowerCase());
        expect(registerResponse.body.customer.role).toBe('customer');
        expect(registerResponse.body.customer.password_hash).toBeUndefined();
        expect(registerResponse.body.accessToken).toBeTruthy();
        expect(registerResponse.body.refreshToken).toBeTruthy();

        const duplicateResponse = await request(app.getHttpServer())
            .post('/api/v1/auth/register')
            .send(registerPayload)
            .expect(400);
        expect(duplicateResponse.body.message).toBe('Customer with this email already exists');

        const loginResponse = await request(app.getHttpServer())
            .post('/api/v1/auth/login')
            .send({
                email: registerPayload.email,
                password: registerPayload.password,
            })
            .expect(201);

        expect(loginResponse.body.customer.id).toBe(registerResponse.body.customer.id);
        expect(loginResponse.body.accessToken).toBeTruthy();

        const refreshResponse = await request(app.getHttpServer())
            .post('/api/v1/auth/refresh')
            .send({ refreshToken: loginResponse.body.refreshToken })
            .expect(201);

        expect(refreshResponse.body.accessToken).toBeTruthy();
        expect(refreshResponse.body.refreshToken).toBeTruthy();

        const profileResponse = await request(app.getHttpServer())
            .get('/api/v1/auth/profile')
            .set('Authorization', `Bearer ${loginResponse.body.accessToken}`)
            .expect(200);

        expect(profileResponse.body.email).toBe(registerPayload.email.toLowerCase());

        const logoutResponse = await request(app.getHttpServer())
            .post('/api/v1/auth/logout')
            .set('Authorization', `Bearer ${loginResponse.body.accessToken}`)
            .expect(201);

        expect(logoutResponse.body.success).toBe(true);
    });

    it('rejects invalid registration email and password with validation details', async () => {
        const invalidEmail = await request(app.getHttpServer())
            .post('/api/v1/auth/register')
            .send({
                email: 'not-an-email',
                password: 'StrongPass123!',
                firstName: 'Test',
                lastName: 'Customer',
            })
            .expect(400);
        expect(invalidEmail.body.message).toContain('email must be an email');

        const invalidPassword = await request(app.getHttpServer())
            .post('/api/v1/auth/register')
            .send({
                email: 'validation@example.test',
                password: 'weak',
                firstName: 'Test',
                lastName: 'Customer',
            })
            .expect(400);
        expect(invalidPassword.body.message).toEqual(
            expect.arrayContaining([
                'Password must include a letter, number, and symbol',
                'password must be longer than or equal to 8 characters',
            ]),
        );
    });
});
