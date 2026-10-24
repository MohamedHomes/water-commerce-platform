import { Injectable } from '@nestjs/common';
import { createHash } from 'crypto';
import { DatabaseService } from '../database/database.service';

export interface RateLimitPolicy {
    scope: string;
    maxRequests: number;
    windowSeconds: number;
}

@Injectable()
export class RateLimitService {
    constructor(private readonly database: DatabaseService) { }

    async consume(policy: RateLimitPolicy, clientAddress: string) {
        const keyHash = createHash('sha256')
            .update(`${policy.scope}\0${clientAddress}`)
            .digest('hex');
        const result = await this.database.query<{
            hit_count: number;
            retry_after: number;
        }>(
            `INSERT INTO application_rate_limits (key_hash, window_started_at, hit_count, updated_at)
            VALUES ($1, NOW(), 1, NOW())
            ON CONFLICT (key_hash) DO UPDATE SET
                hit_count = CASE
                    WHEN application_rate_limits.window_started_at
                        <= NOW() - ($2::integer * INTERVAL '1 second') THEN 1
                    ELSE application_rate_limits.hit_count + 1
                END,
                window_started_at = CASE
                    WHEN application_rate_limits.window_started_at
                        <= NOW() - ($2::integer * INTERVAL '1 second') THEN NOW()
                    ELSE application_rate_limits.window_started_at
                END,
                updated_at = NOW()
            RETURNING hit_count,
                GREATEST(1, CEIL(EXTRACT(EPOCH FROM (
                    window_started_at + ($2::integer * INTERVAL '1 second') - NOW()
                )))::integer) AS retry_after`,
            [keyHash, policy.windowSeconds],
        );

        await this.database.query(
            `DELETE FROM application_rate_limits
            WHERE updated_at < NOW() - INTERVAL '24 hours'`,
        );

        const row = result.rows[0];
        return {
            allowed: row.hit_count <= policy.maxRequests,
            retryAfterSeconds: row.retry_after,
        };
    }
}
