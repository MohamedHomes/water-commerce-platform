import { Inject, Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { DATABASE_POOL, DatabasePool, QueryableClient, QueryResultLike } from './database.types';

export type QueryExecutor = QueryableClient;
export type QueryResult<T> = QueryResultLike<T>;

@Injectable()
export class DatabaseService implements OnModuleInit, OnModuleDestroy {
    private readonly logger = new Logger(DatabaseService.name);

    constructor(@Inject(DATABASE_POOL) private readonly pool: DatabasePool) { }

    async onModuleInit(): Promise<void> {
        await this.pool.query('SELECT 1');
    }

    query<T = Record<string, unknown>>(text: string, params?: any[]): Promise<QueryResultLike<T>> {
        return this.pool.query<T>(text, params);
    }

    async withTransaction<T>(fn: (client: QueryableClient) => Promise<T>): Promise<T> {
        const client = await this.pool.connect();
        try {
            await client.query('BEGIN');
            const result = await fn(client);
            await client.query('COMMIT');
            return result;
        } catch (error) {
            try {
                await client.query('ROLLBACK');
            } catch (rollbackError) {
                const detail = rollbackError instanceof Error ? rollbackError.stack : String(rollbackError);
                this.logger.error('Database rollback failed', detail);
            }
            throw error;
        } finally {
            client.release();
        }
    }

    async ping(): Promise<boolean> {
        await this.pool.query('SELECT 1');
        return true;
    }

    async onModuleDestroy(): Promise<void> {
        await this.pool.end();
    }
}
