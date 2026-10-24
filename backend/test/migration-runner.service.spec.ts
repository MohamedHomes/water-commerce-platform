import { resolve } from 'path';
import { MigrationRunnerService } from '../src/database/migration-runner.service';
import { loadMigrations } from '../src/database/migration-runner';
import {
    DatabaseClient,
    DatabasePool,
    QueryResultLike,
} from '../src/database/database.types';

describe('MigrationRunnerService', () => {
    it('runs migrations through the pool without reconnecting an acquired client', async () => {
        const migrations = loadMigrations(resolve(__dirname, '..', 'migrations'));
        const statements: string[] = [];
        const connectedClient = {
            connect: jest.fn(async () => {
                throw new Error('Client has already been connected. You cannot reuse a client.');
            }),
            query: async <T>(text: string): Promise<QueryResultLike<T>> => {
                statements.push(text);
                const rows = text.includes('SELECT version, filename, checksum')
                    ? migrations.map(({ version, filename, checksum }) => ({
                        version,
                        filename,
                        checksum,
                    }))
                    : [];
                return { rows: rows as T[], rowCount: rows.length };
            },
            release: jest.fn(),
        } satisfies DatabaseClient & { connect: () => Promise<never> };

        const pool = {
            query: async <T>(): Promise<QueryResultLike<T>> => ({ rows: [], rowCount: 0 }),
            connect: jest.fn(async () => connectedClient),
            end: async () => undefined,
        } satisfies DatabasePool;

        const service = new MigrationRunnerService(pool);
        await service.runMigrations();

        expect(pool.connect).toHaveBeenCalledTimes(1);
        expect(connectedClient.connect).not.toHaveBeenCalled();
        expect(statements[0]).toBe('BEGIN');
        expect(statements).toContain('SELECT pg_advisory_xact_lock(7426581)');
        expect(statements[statements.length - 1]).toBe('COMMIT');
        expect(connectedClient.release).toHaveBeenCalledTimes(1);
    });
});
