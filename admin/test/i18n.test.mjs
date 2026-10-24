import assert from 'node:assert/strict';
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
