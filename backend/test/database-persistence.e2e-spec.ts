import { INestApplication } from '@nestjs/common';
import { readFileSync } from 'fs';
import { resolve } from 'path';
import request from 'supertest';
import { PGlite } from '@electric-sql/pglite';
import { MigrationRunnerService } from '../src/database/migration-runner.service';
import { loadMigrations, runMigrations } from '../src/database/migration-runner';
import { createTestApplication, PGliteDatabaseAdapter } from './database-test-utils';

describe('PostgreSQL persistence integration (PGlite)', () => {
    let app: INestApplication;
    let closeApp: () => Promise<void>;
    let database: PGliteDatabaseAdapter;
    let token: string;
    let customerId: string;
    let addressId: string;
    let checkoutId: string;

    beforeAll(async () => {
        database = new PGliteDatabaseAdapter();
        let setup = await createTestApplication(database);
        app = setup.app;
        closeApp = setup.close;

        const migrationRunner = app.get(MigrationRunnerService);
        await migrationRunner.runMigrations();
        const applied = await database.query<{ count: string }>(
            'SELECT COUNT(*)::text AS count FROM schema_migrations',
        );
        expect(Number(applied.rows[0].count)).toBe(16);

        const registration = await request(app.getHttpServer())
            .post('/api/v1/auth/register')
            .send({
                email: 'persistence@example.com',
                password: 'StrongPass123!',
                firstName: 'Persisted',
                lastName: 'Customer',
            })
            .expect(201);
        token = registration.body.accessToken;
        customerId = registration.body.customer.id;

        await request(app.getHttpServer())
            .post('/api/v1/cart/items')
            .set('Authorization', `Bearer ${token}`)
            .send({ productId: 'prod-1', quantity: 2 })
            .expect(201);

        const address = await request(app.getHttpServer())
            .post('/api/v1/addresses')
            .set('Authorization', `Bearer ${token}`)
            .send({
                label: 'Home',
                recipientName: 'Persisted Customer',
                phone: '+966500000111',
                city: 'Riyadh',
                district: 'Central',
                street: 'Main Street',
                building: '12',
            })
            .expect(201);
        addressId = address.body.id;

        const checkout = await request(app.getHttpServer())
            .post('/api/v1/checkout/prepare')
            .set('Authorization', `Bearer ${token}`)
            .send({
                addressId,
                deliveryZoneId: 'zone-riyadh-central',
                deliveryOption: 'standard',
                paymentMethod: 'card',
            })
            .expect(201);
        checkoutId = checkout.body.checkoutId;
    });

    afterAll(async () => {
        if (closeApp) {
            await closeApp();
        }
        if (database) {
            await database.close();
        }
    });

    it('executes the consolidated setup and stays aligned with the migration runner', async () => {
        const setupDatabase = new PGlite();
        try {
            const setupSql = readFileSync(
                resolve(__dirname, '..', '..', 'infrastructure', 'database', 'full_database_setup.sql'),
                'utf8',
            );
            await setupDatabase.exec(setupSql);

            const migrations = loadMigrations(resolve(__dirname, '..', 'migrations'));
            const ledger = await setupDatabase.query<{
                version: string;
                filename: string;
                checksum: string;
            }>(
                'SELECT version, filename, checksum FROM schema_migrations ORDER BY version',
            );
            expect(ledger.rows).toEqual(migrations.map(({ version, filename, checksum }) => ({
                version,
                filename,
                checksum,
            })));

            const adapter = new PGliteDatabaseAdapter(setupDatabase);
            const rerun = await runMigrations(adapter, resolve(__dirname, '..', 'migrations'));
            expect(rerun).toEqual({
                applied: [],
                skipped: migrations.map(({ filename }) => filename),
            });
            const products = await setupDatabase.query<{ count: string }>(
                'SELECT COUNT(*)::text AS count FROM products',
            );
            expect(Number(products.rows[0].count)).toBeGreaterThan(0);
        } finally {
            await setupDatabase.close();
        }
    });

    it('retains customer, catalog, cart, address, and checkout data after an application restart', async () => {
        await closeApp();
        const restarted = await createTestApplication(database);
        app = restarted.app;
        closeApp = restarted.close;

        const login = await request(app.getHttpServer())
            .post('/api/v1/auth/login')
            .send({ email: 'persistence@example.com', password: 'StrongPass123!' })
            .expect(201);
        expect(login.body.customer.id).toBe(customerId);

        const products = await request(app.getHttpServer())
            .get('/api/v1/catalog/products/prod-1')
            .expect(200);
        expect(products.body.name).toBe('AquaFlow 1.5L Mineral Water');

        const cart = await request(app.getHttpServer())
            .get('/api/v1/cart')
            .set('Authorization', `Bearer ${token}`)
            .expect(200);
        expect(cart.body.items).toEqual([
            expect.objectContaining({ productId: 'prod-1', quantity: 2 }),
        ]);

        const addresses = await request(app.getHttpServer())
            .get('/api/v1/addresses')
            .set('Authorization', `Bearer ${token}`)
            .expect(200);
        expect(addresses.body.items).toEqual([
            expect.objectContaining({ id: addressId, customerId }),
        ]);

        const checkout = await request(app.getHttpServer())
            .get(`/api/v1/checkout/${checkoutId}`)
            .set('Authorization', `Bearer ${token}`)
            .expect(200);
        expect(checkout.body.customerId).toBe(customerId);
        expect(checkout.body.cart.items[0].productId).toBe('prod-1');
    });
});
