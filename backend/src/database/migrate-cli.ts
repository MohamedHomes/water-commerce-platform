import { Pool } from 'pg';
import { runMigrations } from './migration-runner';

async function main() {
    const connectionString = process.env.DATABASE_URL;
    if (!connectionString) {
        console.error('[migrate] DATABASE_URL is required, e.g. postgres://postgres:postgres@localhost:5432/aquaflow');
        process.exit(1);
    }

    const pool = new Pool({ connectionString, max: 1 });
    try {
        const { applied, skipped } = await runMigrations(pool);
        console.log(
            applied.length
                ? `[migrate] applied: ${applied.join(', ')}`
                : '[migrate] no pending migrations',
        );
        console.log(`[migrate] already applied: ${skipped.length}`);
    } finally {
        await pool.end();
    }
}

main().catch((error: Error) => {
    console.error(`[migrate] failed: ${error.message}`);
    process.exit(1);
});
