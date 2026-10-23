import { createHash } from 'crypto';
import * as fs from 'fs';
import * as path from 'path';
import { DatabaseClient, DatabasePool, QueryableClient } from './database.types';

export const MIGRATIONS_DIR = path.resolve(__dirname, '..', '..', 'migrations');

const MIGRATION_FILE_PATTERN = /^(\d{3,})_[a-z0-9_]+\.sql$/i;

export interface MigrationFile {
    version: string;
    filename: string;
    sql: string;
    checksum: string;
}

interface MigrationLedgerRow {
    version: string;
    filename: string;
    checksum: string;
}

export function loadMigrations(dir: string = MIGRATIONS_DIR): MigrationFile[] {
    const files = fs
        .readdirSync(dir)
        .filter((filename) => MIGRATION_FILE_PATTERN.test(filename))
        .sort();

    const migrations = files.map((filename) => {
        const match = MIGRATION_FILE_PATTERN.exec(filename);
        if (!match) {
            throw new Error(`Invalid migration filename: ${filename}`);
        }
        const sql = fs.readFileSync(path.join(dir, filename), 'utf8').replace(/\r\n/g, '\n');
        return {
            version: match[1],
            filename,
            sql,
            checksum: createHash('sha256').update(sql).digest('hex'),
        };
    });
    const versions = new Set<string>();
    for (const migration of migrations) {
        if (versions.has(migration.version)) {
            throw new Error(`Duplicate migration version ${migration.version}`);
        }
        versions.add(migration.version);
    }
    return migrations;
}

async function applyMigrations(
    client: QueryableClient,
    dir: string = MIGRATIONS_DIR,
): Promise<{ applied: string[]; skipped: string[] }> {
    const migrations = loadMigrations(dir);
    await client.query('SELECT pg_advisory_xact_lock(7426581)');
    await client.query(`
        CREATE TABLE IF NOT EXISTS schema_migrations (
            version VARCHAR(32) NOT NULL PRIMARY KEY,
            filename TEXT NOT NULL,
            checksum VARCHAR(64) NOT NULL,
            applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
    `);

    const existing = await client.query<MigrationLedgerRow>(
        'SELECT version, filename, checksum FROM schema_migrations',
    );
    const ledger = new Map(existing.rows.map((row) => [row.version, row]));
    const availableVersions = new Set(migrations.map((migration) => migration.version));
    const applied: string[] = [];
    const skipped: string[] = [];

    for (const row of ledger.values()) {
        if (!availableVersions.has(row.version)) {
            throw new Error(`Applied migration version ${row.version} is missing from the migration directory`);
        }
    }

    for (const migration of migrations) {
        const recorded = ledger.get(migration.version);
        if (recorded) {
            if (recorded.filename !== migration.filename || recorded.checksum !== migration.checksum) {
                throw new Error(
                    `Migration ${migration.filename} was modified after being applied ` +
                    '(checksum mismatch in schema_migrations). Add a new migration instead.',
                );
            }
            skipped.push(migration.filename);
            continue;
        }

        if (client.exec) {
            await client.exec(migration.sql);
        } else {
            await client.query(migration.sql);
        }
        await client.query(
            'INSERT INTO schema_migrations (version, filename, checksum) VALUES ($1, $2, $3)',
            [migration.version, migration.filename, migration.checksum],
        );
        applied.push(migration.filename);
    }

    return { applied, skipped };
}

export async function runMigrations(
    database: QueryableClient | DatabasePool,
    dir: string = MIGRATIONS_DIR,
): Promise<{ applied: string[]; skipped: string[] }> {
    if (!('connect' in database) || typeof database.connect !== 'function') {
        return applyMigrations(database, dir);
    }

    const client: DatabaseClient = await database.connect();
    try {
        await client.query('BEGIN');
        const result = await applyMigrations(client, dir);
        await client.query('COMMIT');
        return result;
    } catch (error) {
        try {
            await client.query('ROLLBACK');
        } catch (rollbackError) {
            const detail = rollbackError instanceof Error ? rollbackError.stack : String(rollbackError);
            console.error('Migration transaction rollback failed', detail);
        }
        throw error;
    } finally {
        client.release();
    }
}

export async function pendingMigrations(
    client: QueryableClient,
    dir: string = MIGRATIONS_DIR,
): Promise<string[]> {
    const migrations = loadMigrations(dir);
    const existing = await client.query<{ version: string }>(
        'SELECT version FROM schema_migrations',
    );
    const appliedVersions = new Set(existing.rows.map((row) => row.version));
    return migrations
        .filter((migration) => !appliedVersions.has(migration.version))
        .map((migration) => migration.filename);
}
