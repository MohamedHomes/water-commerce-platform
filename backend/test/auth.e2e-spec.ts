import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { DatabaseService } from '../src/database/database.service';
import { MailService } from '../src/auth/mail.service';
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

    it('changes and recovers a password without revealing account existence', async () => {
        const registration = await request(app.getHttpServer())
            .post('/api/v1/auth/register')
            .send({
                email: 'recovery@example.test',
                password: 'StrongPass123!',
                firstName: 'Recovery',
                lastName: 'Customer',
            })
            .expect(201);
        await app
            .get(DatabaseService)
            .query("UPDATE customers SET role = 'admin' WHERE id = $1", [registration.body.customer.id]);
        let token = registration.body.accessToken as string;
        const mailer = app.get(MailService);
        const sendResetCode = mailer.sendPasswordResetCode as jest.Mock;
        sendResetCode.mockClear();

        const knownEmail = await request(app.getHttpServer())
            .post('/api/v1/auth/password-reset/request')
            .send({ email: 'recovery@example.test' })
            .expect(201);
        const unknownEmail = await request(app.getHttpServer())
            .post('/api/v1/auth/password-reset/request')
            .send({ email: 'unknown@example.test' })
            .expect(201);
        expect(knownEmail.body).toEqual(unknownEmail.body);
        expect(sendResetCode).toHaveBeenCalledTimes(1);
        const resetCode = sendResetCode.mock.calls[0][1] as string;

        await request(app.getHttpServer())
            .post('/api/v1/auth/password-reset/confirm')
            .send({ token: '0'.repeat(64), newPassword: 'NewStrong123!' })
            .expect(400);
        await request(app.getHttpServer())
            .post('/api/v1/auth/password-reset/confirm')
            .send({ token: resetCode, newPassword: 'NewStrong123!' })
            .expect(201);
        await request(app.getHttpServer())
            .get('/api/v1/auth/profile')
            .set('Authorization', 'Bearer ' + registration.body.accessToken)
            .expect(401);
        await request(app.getHttpServer())
            .post('/api/v1/auth/login')
            .send({
                email: 'recovery@example.test',
                password: 'StrongPass123!',
            })
            .expect(401);
        const newLogin = await request(app.getHttpServer())
            .post('/api/v1/auth/login')
            .send({
                email: 'recovery@example.test',
                password: 'NewStrong123!',
            })
            .expect(201);
        token = newLogin.body.accessToken as string;
        expect(newLogin.body.customer.role).toBe('admin');
        await request(app.getHttpServer())
            .get('/api/v1/admin/dashboard')
            .set('Authorization', 'Bearer ' + newLogin.body.accessToken)
            .expect(200);
        await request(app.getHttpServer())
            .post('/api/v1/auth/password-reset/confirm')
            .send({ token: resetCode, newPassword: 'AnotherStrong123!' })
            .expect(400);

        await request(app.getHttpServer())
            .post('/api/v1/auth/refresh')
            .send({ refreshToken: registration.body.refreshToken })
            .expect(401);

        await request(app.getHttpServer())
            .patch('/api/v1/auth/password')
            .set('Authorization', 'Bearer ' + token)
            .send({
                currentPassword: 'WrongStrong123!',
                newPassword: 'ChangedStrong123!',
            })
            .expect(401);
        await request(app.getHttpServer())
            .patch('/api/v1/auth/password')
            .set('Authorization', 'Bearer ' + token)
            .send({
                currentPassword: 'NewStrong123!',
                newPassword: 'ChangedStrong123!',
            })
            .expect(200);
        await request(app.getHttpServer())
            .get('/api/v1/auth/profile')
            .set('Authorization', 'Bearer ' + token)
            .expect(401);
        await request(app.getHttpServer())
            .post('/api/v1/auth/login')
            .send({
                email: 'recovery@example.test',
                password: 'ChangedStrong123!',
            })
            .expect(201);
        expect(token).toBeTruthy();
    });

    it('rotates tokens and revokes existing sessions when a password changes', async () => {
        const registration = await request(app.getHttpServer())
            .post('/api/v1/auth/register')
            .send({
                email: 'password-change@example.test',
                password: 'StrongPass123!',
                firstName: 'Password',
                lastName: 'Change',
            })
            .expect(201);
        const changed = await request(app.getHttpServer())
            .patch('/api/v1/auth/password')
            .set('Authorization', 'Bearer ' + registration.body.accessToken)
            .send({
                currentPassword: 'StrongPass123!',
                newPassword: 'ChangedStrong123!',
            })
            .expect(200);

        expect(changed.body.accessToken).toBeTruthy();
        expect(changed.body.refreshToken).toBeTruthy();
        await request(app.getHttpServer())
            .get('/api/v1/auth/profile')
            .set('Authorization', 'Bearer ' + registration.body.accessToken)
            .expect(401);
        await request(app.getHttpServer())
            .get('/api/v1/auth/profile')
            .set('Authorization', 'Bearer ' + changed.body.accessToken)
            .expect(200);
        await request(app.getHttpServer())
            .post('/api/v1/auth/refresh')
            .send({ refreshToken: registration.body.refreshToken })
            .expect(401);
    });
});
