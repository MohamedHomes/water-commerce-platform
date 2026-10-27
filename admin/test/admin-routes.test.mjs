import assert from 'node:assert/strict';
import test from 'node:test';
import {
    adminNavigation,
    isAdminPath,
    normalizeAdminPath,
    pageTitleKey,
} from '../src/admin-routes.ts';

test('admin pages have distinct stable paths and titles', () => {
    assert.deepEqual(adminNavigation.map(({ path }) => path), [
        '/',
        '/orders',
        '/deliveries',
        '/products',
        '/categories',
        '/brands',
        '/inventory',
        '/promotions',
        '/reviews',
    ]);
    assert.equal(pageTitleKey('/products'), 'products');
    assert.equal(pageTitleKey('/catalog-terms'), 'catalogTerms');
});

test('route matching accepts trailing slashes and rejects unknown paths', () => {
    assert.equal(normalizeAdminPath('/orders///'), '/orders');
    assert.equal(isAdminPath('/orders/'), true);
    assert.equal(isAdminPath('/catalog-terms'), true);
    assert.equal(isAdminPath('/admin/secret'), false);
    assert.equal(pageTitleKey('/missing'), 'pageNotFound');
});
