import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { createTestApplication } from './database-test-utils';

describe('AppController (e2e)', () => {
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

    it('/api/v1/health (GET)', async () => {
        const response = await request(app.getHttpServer())
            .get('/api/v1/health')
            .expect(200);

        expect(response.body).toMatchObject({
            status: 'ok',
            service: 'aquaflow-backend',
        });
    });

    it('/api/v1/health/live (GET)', async () => {
        const response = await request(app.getHttpServer())
            .get('/api/v1/health/live')
            .expect(200);

        expect(response.body).toMatchObject({
            status: 'live',
        });
    });

    it('/api/v1/health/ready (GET)', async () => {
        const response = await request(app.getHttpServer())
            .get('/api/v1/health/ready')
            .expect(200);

        expect(response.body).toMatchObject({
            status: 'ready',
        });
        expect(response.body.checks).toHaveProperty('database');
        expect(response.body.checks.database).toBe('connected');
        expect(response.body.checks).toHaveProperty('cache');
    });
});
