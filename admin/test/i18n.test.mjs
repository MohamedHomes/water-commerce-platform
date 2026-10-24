import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import test from 'node:test';
import {
    formatMessage,
    loadAdminLanguage,
    syncAdminLanguage,
    translate,
    translateError,
    translateStatus,
} from '../src/i18n.ts';

test('admin messages and interpolated actions are translated into Arabic', () => {
    assert.equal(translate('ar', 'signIn'), 'تسجيل الدخول');
    assert.equal(formatMessage('ar', 'removeOne', { product: 'Bottle' }), 'إزالة وحدة من Bottle');
    assert.equal(translateStatus('ar', 'payment_pending'), 'بانتظار الدفع');
    assert.equal(translateError('ar', 'Inventory cannot be reduced below zero'), 'لا يمكن خفض المخزون إلى أقل من صفر');
    assert.equal(translateError('ar', 'Too many requests'), 'طلبات كثيرة جداً. يرجى المحاولة لاحقاً.');
});

test('English remains the default source copy and unknown statuses remain readable', () => {
    assert.equal(translate('en', 'operationsDashboard'), 'Operations dashboard');
    assert.equal(translateStatus('en', 'custom_status'), 'custom status');
});

test('language preference restores from storage and applies document direction', () => {
    let persistedLanguage = 'ar';
    const read = (key) => key === 'aquaflow-admin-language' ? persistedLanguage : null;
    const root = { lang: 'en', dir: 'ltr' };

    assert.equal(loadAdminLanguage(read), 'ar');
    syncAdminLanguage('ar', (_, value) => { persistedLanguage = value; }, root);
    assert.deepEqual(root, { lang: 'ar', dir: 'rtl' });

    syncAdminLanguage('en', (_, value) => { persistedLanguage = value; }, root);
    assert.equal(loadAdminLanguage(read), 'en');
    assert.deepEqual(root, { lang: 'en', dir: 'ltr' });
});

test('admin catalogs have matching unique keys and cover every typed UI reference', async () => {
    const sourceDirectory = resolve(dirname(fileURLToPath(import.meta.url)), '../src');
    const catalog = await readFile(resolve(sourceDirectory, 'i18n.ts'), 'utf8');
    const app = await readFile(resolve(sourceDirectory, 'App.tsx'), 'utf8');
    const extractKeys = (language) => {
        const block = new RegExp(`\\b${language}:\\s*\\{([\\s\\S]*?)\\n\\s*\\},`).exec(catalog)?.[1];
        assert.ok(block, `missing ${language} message catalog`);
        return [...block.matchAll(/^\s*(\w+):\s*'[^']*',?$/gm)].map((match) => match[1]);
    };
    const englishKeys = extractKeys('en');
    const arabicKeys = extractKeys('ar');
    assert.equal(new Set(englishKeys).size, englishKeys.length, 'duplicate English translation keys');
    assert.equal(new Set(arabicKeys).size, arabicKeys.length, 'duplicate Arabic translation keys');
    assert.deepEqual([...arabicKeys].sort(), [...englishKeys].sort(), 'English and Arabic catalogs must match');

    const references = new Set([
        ...[...app.matchAll(/\bt\('(\w+)'\)/g)].map((match) => match[1]),
        ...[...app.matchAll(/\bformat\('(\w+)'/g)].map((match) => match[1]),
    ]);
    assert.deepEqual([...references].filter((key) => !englishKeys.includes(key)), []);
});
