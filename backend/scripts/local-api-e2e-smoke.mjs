import 'dotenv/config';
import { randomBytes } from 'node:crypto';
import pg from 'pg';

const { Client } = pg;
const apiBase = 'http://127.0.0.1:3000/api/v1';
const tag = `qa-${Date.now()}-${randomBytes(4).toString('hex')}`;
const customers = [];
let checks = 0;

function pass(name, status) {
    checks += 1;
    console.log(`PASS ${name} (HTTP ${status})`);
}

async function request(name, path, options = {}) {
    const headers = {};
    if (options.token) headers.Authorization = `Bearer ${options.token}`;
    if (options.body !== undefined) headers['Content-Type'] = 'application/json';

    const response = await fetch(`${apiBase}${path}`, {
        method: options.method ?? 'GET',
        headers,
        body: options.body === undefined ? undefined : JSON.stringify(options.body),
    });
    const text = await response.text();
    let body = null;
    try {
        body = text ? JSON.parse(text) : null;
    } catch {
        body = null;
    }

    if (!options.expected.includes(response.status)) {
        throw new Error(`${name}: expected HTTP ${options.expected.join('/')} but received ${response.status}`);
    }
    pass(name, response.status);
    return body;
}

async function register(label) {
    const email = `${label}-${tag}@example.invalid`;
    const password = `${randomBytes(24).toString('base64url')}Aa1!`;
    const body = await request(`registration ${label}`, '/auth/register', {
        method: 'POST',
        body: { email, password, firstName: 'QA', lastName: 'Temporary' },
        expected: [201],
    });
    if (body.customer.role !== 'customer') {
        throw new Error('Public registration did not retain the customer role');
    }
    customers.push({ id: body.customer.id });
    return { id: body.customer.id, email, password, token: body.accessToken, refreshToken: body.refreshToken };
}

async function cleanup(client) {
    if (customers.length === 0) return;

    const ids = customers.map(({ id }) => id);
    await client.query('BEGIN');
    try {
        const orders = await client.query(
            'SELECT COUNT(*)::int AS count FROM orders WHERE customer_id = ANY($1::uuid[])',
            [ids],
        );
        if (orders.rows[0].count !== 0) {
            throw new Error('Temporary customer has an order; preserving the account and related data');
        }

        const sessions = await client.query(
            'DELETE FROM checkout_sessions WHERE customer_id = ANY($1::uuid[])',
            [ids],
        );
        const deleted = await client.query(
            `DELETE FROM customers
             WHERE id = ANY($1::uuid[])
               AND role = 'customer'
               AND NOT EXISTS (SELECT 1 FROM orders WHERE orders.customer_id = customers.id)
             RETURNING id`,
            [ids],
        );
        if (deleted.rowCount !== ids.length) {
            throw new Error('Temporary customer cleanup count did not match');
        }
        await client.query('COMMIT');
        pass(`safe cleanup (${deleted.rowCount} temporary accounts, ${sessions.rowCount} checkout sessions)`, 200);
    } catch (error) {
        await client.query('ROLLBACK').catch(() => {});
        throw error;
    }
}

async function main() {
    if (!process.env.DATABASE_URL) {
        throw new Error('DATABASE_URL is missing; configure the ignored backend/.env first');
    }

    const client = new Client({ connectionString: process.env.DATABASE_URL });
    try {
        await client.connect();
        const target = (await client.query(
            `SELECT current_database() AS database,
                    inet_server_addr()::text AS host,
                    inet_server_port() AS port`,
        )).rows[0];
        if (
            target.database !== 'aquaflow'
            || !target.host.startsWith('127.0.0.1')
            || Number(target.port) !== 5432
        ) {
            throw new Error('Refusing to run against a database other than local aquaflow on 127.0.0.1:5432');
        }
        console.log('PASS database target verified (local aquaflow, port 5432)');

        let result = await request('categories', '/catalog/categories', { expected: [200] });
        if (result.items.length === 0) throw new Error('Expected seeded catalog categories');
        result = await request('brands', '/catalog/brands', { expected: [200] });
        if (result.items.length === 0) throw new Error('Expected seeded catalog brands');
        result = await request('catalog search and pagination', '/catalog/products?q=water&page=1&limit=2', {
            expected: [200],
        });
        if (result.items.length === 0 || result.items.length > 2) throw new Error('Catalog page shape was invalid');
        await request('product details', '/catalog/products/prod-1', { expected: [200] });
        await request('unknown product', '/catalog/products/qa-not-found', { expected: [404] });
        await request('invalid login credentials', '/auth/login', {
            method: 'POST',
            body: { email: `missing-${tag}@example.invalid`, password: 'InvalidPass123!' },
            expected: [401],
        });
        await request('invalid registration input', '/auth/register', {
            method: 'POST',
            body: { email: 'invalid-email', password: 'x' },
            expected: [400],
        });

        const customer = await register('flow');
        await request('duplicate registration', '/auth/register', {
            method: 'POST',
            body: { email: customer.email, password: 'DifferentPass123!', firstName: 'QA', lastName: 'Duplicate' },
            expected: [400],
        });
        await request('public admin-role assignment rejected', '/auth/register', {
            method: 'POST',
            body: {
                email: `role-${tag}@example.invalid`,
                password: 'StrongPass123!',
                firstName: 'QA',
                lastName: 'Role',
                role: 'admin',
            },
            expected: [400],
        });
        result = await request('valid login', '/auth/login', {
            method: 'POST',
            body: { email: customer.email, password: customer.password },
            expected: [201],
        });
        if (result.customer.role !== 'customer') throw new Error('Login returned an unexpected role');
        customer.token = result.accessToken;
        customer.refreshToken = result.refreshToken;
        await request('profile read', '/auth/profile', { token: customer.token, expected: [200] });
        await request('profile update', '/auth/profile', {
            method: 'PATCH',
            token: customer.token,
            body: { firstName: 'Updated QA' },
            expected: [200],
        });
        result = await request('refresh token', '/auth/refresh', {
            method: 'POST',
            body: { refreshToken: customer.refreshToken },
            expected: [201],
        });
        customer.token = result.accessToken;
        await request('missing bearer rejected', '/cart', { expected: [401] });
        await request('invalid bearer rejected', '/cart', { token: 'invalid-token', expected: [401] });
        await request('anonymous admin API rejected', '/admin/dashboard', { expected: [401] });
        await request('customer admin dashboard access rejected', '/admin/dashboard', {
            token: customer.token,
            expected: [403],
        });
        await request('customer admin catalog access rejected', '/admin/products', {
            token: customer.token,
            expected: [403],
        });

        const other = await register('isolation');
        result = await request('new customer cart isolation', '/cart', { token: other.token, expected: [200] });
        if (result.items.length !== 0) throw new Error('New customer cart was not empty');
        await request('cities', '/addresses/cities', { token: customer.token, expected: [200] });
        await request('delivery zones', '/addresses/delivery-zones?city=Riyadh', {
            token: customer.token,
            expected: [200],
        });
        await request('zero quantity rejected', '/cart/items', {
            method: 'POST',
            token: customer.token,
            body: { productId: 'prod-1', quantity: 0 },
            expected: [400],
        });
        await request('add cart item', '/cart/items', {
            method: 'POST',
            token: customer.token,
            body: { productId: 'prod-1', quantity: 2 },
            expected: [201],
        });
        result = await request('update cart quantity', '/cart/items/prod-1', {
            method: 'PATCH',
            token: customer.token,
            body: { quantity: 3 },
            expected: [200],
        });
        if (result.items[0].quantity !== 3) throw new Error('Cart quantity was not updated');
        result = await request('server cart validation', '/cart/validate', {
            method: 'POST',
            token: customer.token,
            expected: [200],
        });
        if (!result.valid || !(result.summary.total > 0)) throw new Error('Server cart validation or pricing failed');
        await request('remove cart item', '/cart/items/prod-1', {
            method: 'DELETE',
            token: customer.token,
            expected: [200],
        });

        const address = {
            label: 'QA Home',
            recipientName: 'QA Temporary',
            phone: '+966500000111',
            city: 'Riyadh',
            district: 'Central',
            street: 'QA Road',
            building: 'QA-1',
        };
        result = await request('create address', '/addresses', {
            method: 'POST',
            token: customer.token,
            body: address,
            expected: [201],
        });
        const addressId = result.id;
        const secondAddress = await request('create second address', '/addresses', {
            method: 'POST',
            token: customer.token,
            body: { ...address, label: 'QA Work', building: 'QA-2', isDefault: false },
            expected: [201],
        });
        await request('set default address', `/addresses/${secondAddress.id}/default`, {
            method: 'POST',
            token: customer.token,
            expected: [201],
        });
        await request('update address', `/addresses/${addressId}`, {
            method: 'PATCH',
            token: customer.token,
            body: { street: 'QA Updated Road' },
            expected: [200],
        });
        await request('incomplete coordinates rejected', '/addresses', {
            method: 'POST',
            token: customer.token,
            body: { ...address, label: 'QA Invalid', latitude: 24.7 },
            expected: [400],
        });
        await request('cross-customer address update denied', `/addresses/${addressId}`, {
            method: 'PATCH',
            token: other.token,
            body: { street: 'Unauthorized' },
            expected: [404],
        });

        await request('checkout without cart rejected', '/checkout/prepare', {
            method: 'POST',
            token: customer.token,
            body: {
                addressId,
                deliveryZoneId: 'zone-riyadh-central',
                deliveryOption: 'standard',
                paymentMethod: 'cash',
            },
            expected: [400],
        });
        await request('re-add item for checkout', '/cart/items', {
            method: 'POST',
            token: customer.token,
            body: { productId: 'prod-1', quantity: 1 },
            expected: [201],
        });
        await request('zone from another city rejected', '/checkout/prepare', {
            method: 'POST',
            token: customer.token,
            body: {
                addressId,
                deliveryZoneId: 'zone-jeddah-central',
                deliveryOption: 'standard',
                paymentMethod: 'cash',
            },
            expected: [400],
        });
        const checkout = await request('prepare checkout', '/checkout/prepare', {
            method: 'POST',
            token: customer.token,
            body: {
                addressId,
                deliveryZoneId: 'zone-riyadh-central',
                deliveryOption: 'standard',
                paymentMethod: 'cash',
            },
            expected: [201],
        });
        await request('read owned checkout', `/checkout/${checkout.checkoutId}`, {
            token: customer.token,
            expected: [200],
        });
        await request('other customer checkout denied', `/checkout/${checkout.checkoutId}`, {
            token: other.token,
            expected: [404],
        });
        result = await request('empty order history', '/orders', { token: customer.token, expected: [200] });
        if (result.items.length !== 0) throw new Error('Temporary customer unexpectedly has an order');
        result = await request('notification inbox shape', '/notifications', {
            token: customer.token,
            expected: [200],
        });
        if (!Array.isArray(result.items)) throw new Error('Notification response shape was invalid');
        await request('clear cart', '/cart', { method: 'DELETE', token: customer.token, expected: [200] });

        await cleanup(client);
        console.log(`LOCAL_E2E_SUMMARY ${JSON.stringify({
            checks,
            temporaryAccountsCreatedAndRemoved: customers.length,
            ordersCreated: 0,
            credentialsAndTokensPrinted: false,
        })}`);
    } catch (error) {
        console.error(`LOCAL_E2E_FAILED ${error instanceof Error ? error.message : 'unknown error'}`);
        try {
            await cleanup(client);
        } catch (cleanupError) {
            console.error(`SAFE_CLEANUP_BLOCKED ${cleanupError instanceof Error ? cleanupError.message : 'unknown error'}`);
        }
        process.exitCode = 1;
    } finally {
        await client.end().catch(() => {});
    }
}

await main();
