import { INestApplication } from '@nestjs/common';
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

    it('limits repeated login attempts with a shared database-backed window', async () => {
        for (let attempt = 0; attempt < 10; attempt += 1) {
            await request(app.getHttpServer())
                .post('/api/v1/auth/login')
                .send({ email: 'unknown@example.com', password: 'InvalidPass123!' })
                .expect(401);
        }

        const limited = await request(app.getHttpServer())
            .post('/api/v1/auth/login')
            .send({ email: 'unknown@example.com', password: 'InvalidPass123!' })
            .expect(429);

        expect(Number(limited.headers['retry-after'])).toBeGreaterThan(0);
        const rows = await app.get(DatabaseService).query<{ key_hash: string; hit_count: number }>(
            'SELECT key_hash, hit_count FROM application_rate_limits',
        );
        expect(rows.rows).toHaveLength(1);
        expect(rows.rows[0].key_hash).toMatch(/^[a-f0-9]{64}$/);
        expect(rows.rows[0].hit_count).toBe(11);

        await app.get(DatabaseService).query(
            `UPDATE application_rate_limits
            SET window_started_at = NOW() - INTERVAL '16 minutes'`,
        );
        await request(app.getHttpServer())
            .post('/api/v1/auth/login')
            .send({ email: 'unknown@example.com', password: 'InvalidPass123!' })
            .expect(401);
        const reset = await app.get(DatabaseService).query<{ hit_count: number }>(
            'SELECT hit_count FROM application_rate_limits',
        );
        expect(reset.rows[0].hit_count).toBe(1);
    });

    it('atomically counts concurrent attempts sharing a limiter key', async () => {
        const limiter = app.get(RateLimitService);
        const results = await Promise.all(
            Array.from({ length: 20 }, () => limiter.consume(
                { scope: 'concurrent-test', maxRequests: 10, windowSeconds: 900 },
                '192.0.2.10',
            )),
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
