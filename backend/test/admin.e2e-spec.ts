import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { DatabaseService } from '../src/database/database.service';
import { createTestApplication } from './database-test-utils';

describe('Admin operations', () => {
    let app: INestApplication;
    let close: () => Promise<void>;

    beforeAll(async () => {
        const setup = await createTestApplication();
        app = setup.app;
        close = setup.close;
    }, 15000);

    afterAll(async () => {
        await close();
    }, 15000);

    async function register(email: string) {
        const response = await request(app.getHttpServer())
            .post('/api/v1/auth/register')
            .send({
                email,
                password: 'StrongPass123!',
                firstName: 'Admin',
                lastName: 'Test',
            })
            .expect(201);
        return {
            id: response.body.customer.id as string,
            customerToken: response.body.accessToken as string,
        };
    }

    it('limits admin operations to database-authorized admins and audits promotion changes', async () => {
        const account = await register('admin-operations@example.com');
        const customerProfile = await request(app.getHttpServer())
            .get('/api/v1/auth/profile')
            .set('Authorization', `Bearer ${account.customerToken}`)
            .expect(200);
        expect(customerProfile.body.role).toBe('customer');
        await request(app.getHttpServer())
            .get('/api/v1/admin/dashboard')
            .set('Authorization', `Bearer ${account.customerToken}`)
            .expect(403);

        const database = app.get(DatabaseService);
        await database.query(
            "UPDATE customers SET role = 'admin' WHERE id = $1",
            [account.id],
        );
        const login = await request(app.getHttpServer())
            .post('/api/v1/auth/login')
            .send({ email: 'admin-operations@example.com', password: 'StrongPass123!' })
            .expect(201);
        const adminToken = login.body.accessToken as string;
        expect(login.body.customer.role).toBe('admin');

        const dashboard = await request(app.getHttpServer())
            .get('/api/v1/admin/dashboard')
            .set('Authorization', `Bearer ${adminToken}`)
            .expect(200);
        expect(dashboard.body).toMatchObject({
            totalOrders: expect.any(Number),
            paidRevenue: expect.any(Number),
            activeProducts: expect.any(Number),
            currency: 'SAR',
        });
        const orderQueue = await request(app.getHttpServer())
            .get('/api/v1/admin/orders?page=1&limit=10')
            .set('Authorization', `Bearer ${adminToken}`)
            .expect(200);
        expect(orderQueue.body).toMatchObject({
            items: expect.any(Array),
            total: expect.any(Number),
        });

        const created = await request(app.getHttpServer())
            .post('/api/v1/admin/promotions')
            .set('Authorization', `Bearer ${adminToken}`)
            .send({
                code: ' admin10 ',
                discountType: 'percentage',
                discountValue: 10,
                maxRedemptions: 10,
                maxPerCustomer: 1,
            })
            .expect(201);
        expect(created.body.code).toBe('ADMIN10');

        await request(app.getHttpServer())
            .post('/api/v1/admin/promotions')
            .set('Authorization', `Bearer ${adminToken}`)
            .send({
                code: 'admin10',
                discountType: 'percentage',
                discountValue: 15,
            })
            .expect(409);

        await request(app.getHttpServer())
            .patch(`/api/v1/admin/promotions/${created.body.id}/active`)
            .set('Authorization', `Bearer ${adminToken}`)
            .send({ isActive: false })
            .expect(200);
        const promotions = await request(app.getHttpServer())
            .get('/api/v1/admin/promotions')
            .set('Authorization', `Bearer ${adminToken}`)
            .expect(200);
        expect(promotions.body.items).toContainEqual(
            expect.objectContaining({ code: 'ADMIN10', is_active: false }),
        );

        const audits = await database.query<{ count: string }>(
            'SELECT COUNT(*)::text AS count FROM admin_audit_logs WHERE admin_customer_id = $1',
            [account.id],
        );
        expect(Number(audits.rows[0].count)).toBe(2);

        const originalStock = await database.query<{ quantity: number }>(
            'SELECT quantity FROM products WHERE id = $1',
            ['prod-1'],
        );
        const inventory = await request(app.getHttpServer())
            .get('/api/v1/admin/inventory')
            .set('Authorization', `Bearer ${adminToken}`)
            .expect(200);
        expect(inventory.body.items).toContainEqual(
            expect.objectContaining({ id: 'prod-1', quantity: originalStock.rows[0].quantity }),
        );
        await request(app.getHttpServer())
            .post('/api/v1/admin/inventory/prod-1/adjustments')
            .set('Authorization', `Bearer ${adminToken}`)
            .send({ quantityDelta: 3 })
            .expect(201);
        const adjustedStock = await database.query<{ quantity: number }>(
            'SELECT quantity FROM products WHERE id = $1',
            ['prod-1'],
        );
        expect(adjustedStock.rows[0].quantity).toBe(originalStock.rows[0].quantity + 3);
        await request(app.getHttpServer())
            .post('/api/v1/admin/inventory/prod-1/adjustments')
            .set('Authorization', `Bearer ${adminToken}`)
            .send({ quantityDelta: -(originalStock.rows[0].quantity + 4) })
            .expect(400);

        const products = await request(app.getHttpServer())
            .get('/api/v1/admin/products')
            .set('Authorization', `Bearer ${adminToken}`)
            .expect(200);
        expect(products.body.items).toContainEqual(
            expect.objectContaining({ id: 'prod-1', name: expect.any(String) }),
        );
        const productUpdate = await request(app.getHttpServer())
            .patch('/api/v1/admin/products/prod-1')
            .set('Authorization', `Bearer ${adminToken}`)
            .send({ price: 5.75, isActive: false })
            .expect(200);
        expect(productUpdate.body).toMatchObject({ id: 'prod-1', price: 5.75, is_active: false });

        const category = await request(app.getHttpServer())
            .post('/api/v1/admin/categories')
            .set('Authorization', `Bearer ${adminToken}`)
            .send({ name: 'Test category', nameAr: 'فئة اختبار', slug: 'test-category' })
            .expect(201);
        const brand = await request(app.getHttpServer())
            .post('/api/v1/admin/brands')
            .set('Authorization', `Bearer ${adminToken}`)
            .send({ name: 'Test brand', nameAr: 'علامة اختبار', slug: 'test-brand' })
            .expect(201);
        const managedProduct = await request(app.getHttpServer())
            .post('/api/v1/admin/products')
            .set('Authorization', `Bearer ${adminToken}`)
            .send({
                name: 'Managed product',
                nameAr: 'منتج مُدار',
                slug: 'managed-product',
                categoryId: category.body.id,
                brandId: brand.body.id,
                description: 'Created from the admin API',
                descriptionAr: 'أُنشئ من واجهة الإدارة',
                price: 12.5,
                quantity: 8,
                packageSize: '2L',
            })
            .expect(201);
        expect(managedProduct.body).toMatchObject({
            name: 'Managed product',
            name_ar: 'منتج مُدار',
            category_id: category.body.id,
            brand_id: brand.body.id,
            quantity: 8,
        });
        const editedCategory = await request(app.getHttpServer())
            .patch(`/api/v1/admin/categories/${category.body.id}`)
            .set('Authorization', `Bearer ${adminToken}`)
            .send({ nameAr: 'فئة محدثة' })
            .expect(200);
        expect(editedCategory.body.name_ar).toBe('فئة محدثة');
        const editedProduct = await request(app.getHttpServer())
            .patch(`/api/v1/admin/products/${managedProduct.body.id}`)
            .set('Authorization', `Bearer ${adminToken}`)
            .send({ categoryId: 'cat-water', nameAr: 'اسم محدث' })
            .expect(200);
        expect(editedProduct.body).toMatchObject({
            category_id: 'cat-water',
            name_ar: 'اسم محدث',
        });
        await request(app.getHttpServer())
            .patch(`/api/v1/admin/products/${managedProduct.body.id}`)
            .set('Authorization', `Bearer ${adminToken}`)
            .send({ slug: 'aquaflow-15l-mineral-water' })
            .expect(409);
        const zeroStockProduct = await request(app.getHttpServer())
            .post('/api/v1/admin/products')
            .set('Authorization', `Bearer ${adminToken}`)
            .send({
                name: 'Zero stock product',
                slug: 'zero-stock-product',
                categoryId: 'cat-water',
                brandId: 'brand-aquaflow',
                price: 3,
                quantity: 0,
            })
            .expect(201);
        expect(zeroStockProduct.body.availability).toBe('out_of_stock');
        await request(app.getHttpServer())
            .post('/api/v1/admin/products')
            .set('Authorization', `Bearer ${adminToken}`)
            .send({
                name: 'Duplicate slug',
                slug: 'managed-product',
                categoryId: 'cat-water',
                brandId: 'brand-aquaflow',
                price: 3,
            })
            .expect(409);

        await database.query(
            "UPDATE customers SET role = 'customer' WHERE id = $1",
            [account.id],
        );
        await request(app.getHttpServer())
            .get('/api/v1/admin/dashboard')
            .set('Authorization', `Bearer ${adminToken}`)
            .expect(403);
    });
});
