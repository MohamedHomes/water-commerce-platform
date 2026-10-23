// Temporary offline smoke check: runs the full migration chain against PGlite.
const path = require('path');
const { PGlite } = require('@electric-sql/pglite');

async function main() {
    const { runMigrations } = require(path.join(__dirname, 'dist', 'database', 'migration-runner.js'));
    const db = new PGlite();
    const pool = {
        query: async (text, params) => {
            if (!params || params.length === 0) {
                const results = await db.exec(text);
                const last = results[results.length - 1];
                return { rows: (last && last.rows) || [], rowCount: (last && last.rowCount) ?? 0 };
            }
            const res = await db.query(text, params);
            return { rows: res.rows, rowCount: res.rowCount ?? res.rows.length };
        },
        connect: async () => ({
            query: async (text, params) => pool.query(text, params),
            release: () => { },
        }),
        end: async () => db.close(),
    };

    const first = await runMigrations(pool);
    console.log('first run applied:', JSON.stringify(first.applied));
    const second = await runMigrations(pool);
    console.log('second run applied:', second.applied.length, 'skipped:', second.skipped.length);

    const counts = await pool.query(
        `SELECT (SELECT count(*) FROM categories)::int AS categories,
                (SELECT count(*) FROM brands)::int AS brands,
                (SELECT count(*) FROM products)::int AS products,
                (SELECT count(*) FROM product_variants)::int AS variants`);
    console.log('seed counts:', JSON.stringify(counts.rows[0]));

    const cartFk = await pool.query(
        `SELECT conname FROM pg_constraint WHERE conrelid = 'carts'::regclass AND contype = 'f'`);
    console.log('carts FKs:', JSON.stringify(cartFk.rows));

    const itemType = await pool.query(
        `SELECT data_type FROM information_schema.columns WHERE table_name = 'cart_items' AND column_name = 'product_id'`);
    console.log('cart_items.product_id type:', itemType.rows[0].data_type);

    const coCols = await pool.query(
        `SELECT column_name FROM information_schema.columns WHERE table_name = 'checkout_sessions' AND column_name IN ('delivery_option', 'delivery_zone_id') ORDER BY column_name`);
    console.log('checkout_sessions cols:', JSON.stringify(coCols.rows));

    const addrNull = await pool.query(
        `SELECT is_nullable FROM information_schema.columns WHERE table_name = 'customer_addresses' AND column_name = 'city_id'`);
    console.log('customer_addresses.city_id nullable:', addrNull.rows[0].is_nullable);

    await db.close();
    console.log('MIGRATION_SMOKE_OK');
}

main().catch((e) => { console.error('MIGRATION_SMOKE_FAIL:', e.message); process.exit(1); });
