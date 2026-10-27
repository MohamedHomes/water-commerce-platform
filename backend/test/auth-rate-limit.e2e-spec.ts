import { INestApplication } from '@nestjs/common';
import { beforeEach } from '@jest/globals';
import request from 'supertest';
import { DatabaseService } from '../src/database/database.service';
import { RateLimitService } from '../src/auth/rate-limit.service';
import { createTestApplication } from './database-test-utils';

describe('Persistent authentication rate limits', () => {
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

    beforeEach(async () => {
        await app.get(DatabaseService).query('DELETE FROM application_rate_limits');
    });

    it('limits repeated attempts per email without exhausting the shared local IP bucket', async () => {
        for (let attempt = 0; attempt < 10; attempt += 1) {
            await request(app.getHttpServer())
                .post('/api/v1/auth/login')
                .send({ email: 'unknown@example.com', password: 'InvalidPass123!' })
                .expect(401);
        }

        const limited = await request(app.getHttpServer())
            .post('/api/v1/auth/login')
            .send({ email: 'UNKNOWN@example.com', password: 'InvalidPass123!' })
            .expect(429);

        expect(Number(limited.headers['retry-after'])).toBeGreaterThan(0);
        await request(app.getHttpServer())
            .post('/api/v1/auth/login')
            .send({
                email: 'another-account@example.com',
                password: 'InvalidPass123!',
            })
            .expect(401);

        const rows = await app
            .get(DatabaseService)
            .query<{ key_hash: string; hit_count: number }>('SELECT key_hash, hit_count FROM application_rate_limits');
        expect(rows.rows).toHaveLength(3);
        expect(rows.rows.every((row) => /^[a-f0-9]{64}$/.test(row.key_hash))).toBe(true);
        expect(rows.rows.map((row) => row.hit_count).sort((a, b) => a - b)).toEqual([1, 11, 12]);

        await app.get(DatabaseService).query(
            `UPDATE application_rate_limits
            SET window_started_at = NOW() - INTERVAL '16 minutes'`,
        );
        await request(app.getHttpServer())
            .post('/api/v1/auth/login')
            .send({ email: 'unknown@example.com', password: 'InvalidPass123!' })
            .expect(401);
        const reset = await app
            .get(DatabaseService)
            .query<{ hit_count: number }>('SELECT hit_count FROM application_rate_limits');
        expect(reset.rows.map((row) => row.hit_count)).toEqual([1, 1, 1]);
    });

    it('retains a shared per-address ceiling across different login identities', async () => {
        for (let attempt = 0; attempt < 100; attempt += 1) {
            await request(app.getHttpServer())
                .post('/api/v1/auth/login')
                .send({
                    email: `address-limit-${attempt}@example.com`,
                    password: 'InvalidPass123!',
                })
                .expect(401);
        }

        const limited = await request(app.getHttpServer())
            .post('/api/v1/auth/login')
            .send({
                email: 'address-limit-final@example.com',
                password: 'InvalidPass123!',
            })
            .expect(429);

        expect(Number(limited.headers['retry-after'])).toBeGreaterThan(0);
    });

    it('atomically counts concurrent attempts sharing a limiter key', async () => {
        const limiter = app.get(RateLimitService);
        const results = await Promise.all(
            Array.from({ length: 20 }, () =>
                limiter.consume({ scope: 'concurrent-test', maxRequests: 10, windowSeconds: 900 }, '192.0.2.10'),
            ),
        );
        expect(results.filter((result) => result.allowed)).toHaveLength(10);
        expect(results.filter((result) => !result.allowed)).toHaveLength(10);
        const separateAddress = await limiter.consume(
            { scope: 'concurrent-test', maxRequests: 10, windowSeconds: 900 },
            '198.51.100.20',
        );
        expect(separateAddress.allowed).toBe(true);
    });
});
