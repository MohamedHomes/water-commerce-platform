import { FormEvent, useCallback, useEffect, useState } from 'react';
import {
    AdminLanguage,
    AdminMessage,
    formatMessage,
    loadAdminLanguage,
    syncAdminLanguage,
    translate,
    translateError,
    translateStatus,
} from './i18n';

const apiBaseUrl = import.meta.env.VITE_API_URL ?? 'http://localhost:3000/api/v1';

interface Dashboard {
    totalOrders: number;
    openOrders: number;
    awaitingPayment: number;
    paidRevenue: number;
    pendingDispatch: number;
    activeProducts: number;
    currency: string;
}

interface AdminOrder {
    id: string;
    status: string;
    paymentMethod: string;
    total: number;
    currency: string;
    createdAt: string;
}

interface Promotion {
    id: string;
    code: string;
    discount_type: 'percentage' | 'fixed';
    discount_value: string | number;
    is_active: boolean;
    redemption_count: number;
}

interface InventoryItem {
    id: string;
    name: string;
    quantity: number;
    availability: string;
    is_active: boolean;
}

interface DeliveryItem {
    id: string;
    order_id: string;
    status: string;
    estimated_minutes: number;
    updated_at: string;
}

interface ProductReview {
    id: string;
    product_id: string;
    product_name: string;
    product_name_ar: string | null;
    customer_id: string;
    order_id: string;
    rating: number;
    comment: string;
}

interface CatalogProduct {
    id: string;
    name: string;
    name_ar: string | null;
    slug: string;
    description: string | null;
    description_ar: string | null;
    price: number;
    quantity: number;
    availability: string;
    is_active: boolean;
    category_name: string;
    category_name_ar: string | null;
    category_id: string;
    brand_id: string;
    brand_name: string;
}

interface CatalogTerm {
    id: string;
    name: string;
    name_ar: string | null;
    slug: string;
    description: string | null;
    description_ar: string | null;
}

interface LoginResponse {
    accessToken: string;
    customer: { role: string };
}

async function apiRequest<T>(path: string, token: string, options: RequestInit = {}): Promise<T> {
    const response = await fetch(`${apiBaseUrl}${path}`, {
        ...options,
        headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${token}`,
            ...options.headers,
        },
    });
    if (!response.ok) {
        const payload = await response.json().catch(() => ({})) as { message?: string };
        throw new Error(payload.message ?? `Request failed (${response.status})`);
    }
    return response.json() as Promise<T>;
}

function App() {
    const [language, setLanguage] = useState<AdminLanguage>(() => loadAdminLanguage((key) => localStorage.getItem(key)));
    const t = useCallback((key: AdminMessage) => translate(language, key), [language]);
    const format = useCallback(
        (key: AdminMessage, values: Record<string, string | number>) => formatMessage(language, key, values),
        [language],
    );
    const errorMessage = useCallback(
        (requestError: unknown, fallback: AdminMessage) =>
            requestError instanceof Error ? translateError(language, requestError.message) : t(fallback),
        [language, t],
    );
    const [token, setToken] = useState('');
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [dashboard, setDashboard] = useState<Dashboard | null>(null);
    const [orders, setOrders] = useState<AdminOrder[]>([]);
    const [promotions, setPromotions] = useState<Promotion[]>([]);
    const [inventory, setInventory] = useState<InventoryItem[]>([]);
    const [deliveries, setDeliveries] = useState<DeliveryItem[]>([]);
    const [reviews, setReviews] = useState<ProductReview[]>([]);
    const [products, setProducts] = useState<CatalogProduct[]>([]);
    const [categories, setCategories] = useState<CatalogTerm[]>([]);
    const [brands, setBrands] = useState<CatalogTerm[]>([]);
    const [termEdits, setTermEdits] = useState<Record<string, {
        name?: string;
        nameAr?: string;
        slug?: string;
        description?: string;
        descriptionAr?: string;
    }>>({});
    const [productEdits, setProductEdits] = useState<Record<string, {
        name?: string;
        nameAr?: string;
        slug?: string;
        description?: string;
        descriptionAr?: string;
        categoryId?: string;
        brandId?: string;
    }>>({});
    const [newProduct, setNewProduct] = useState({
        name: '', nameAr: '', slug: '', description: '', descriptionAr: '',
        categoryId: '', brandId: '', price: '', quantity: '0', packageSize: '',
    });
    const [newCategory, setNewCategory] = useState({ name: '', nameAr: '', slug: '', description: '', descriptionAr: '' });
    const [newBrand, setNewBrand] = useState({ name: '', nameAr: '', slug: '', description: '', descriptionAr: '' });
    const [priceEdits, setPriceEdits] = useState<Record<string, string>>({});
    const [code, setCode] = useState('');
    const [discountType, setDiscountType] = useState<'percentage' | 'fixed'>('percentage');
    const [discountValue, setDiscountValue] = useState('');
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);

    useEffect(() => {
        syncAdminLanguage(language, (key, value) => localStorage.setItem(key, value), document.documentElement);
    }, [language]);

    const refreshDashboard = useCallback(async (accessToken: string) => {
        setLoading(true);
        setError('');
        try {
            const [metrics, orderList, promotionList, inventoryList, deliveryList, reviewList, productList, catalogTerms] = await Promise.all([
                apiRequest<Dashboard>('/admin/dashboard', accessToken),
                apiRequest<{ items: AdminOrder[] }>('/admin/orders?limit=10', accessToken),
                apiRequest<{ items: Promotion[] }>('/admin/promotions', accessToken),
                apiRequest<{ items: InventoryItem[] }>('/admin/inventory', accessToken),
                apiRequest<{ items: DeliveryItem[] }>('/admin/deliveries', accessToken),
                apiRequest<{ items: ProductReview[] }>('/admin/reviews', accessToken),
                apiRequest<{ items: CatalogProduct[] }>('/admin/products', accessToken),
                apiRequest<{ categories: CatalogTerm[]; brands: CatalogTerm[] }>('/admin/catalog-terms', accessToken),
            ]);
            setDashboard(metrics);
            setOrders(orderList.items);
            setPromotions(promotionList.items);
            setInventory(inventoryList.items);
            setDeliveries(deliveryList.items);
            setReviews(reviewList.items);
            setProducts(productList.items);
            setCategories(catalogTerms.categories);
            setBrands(catalogTerms.brands);
        } catch (requestError) {
            setError(errorMessage(requestError, 'requestFailed'));
        } finally {
            setLoading(false);
        }
    }, [errorMessage]);

    useEffect(() => {
        if (token) void refreshDashboard(token);
    }, [token, refreshDashboard]);

    async function login(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();
        setLoading(true);
        setError('');
        try {
            const response = await fetch(`${apiBaseUrl}/auth/login`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ email, password }),
            });
            const payload = await response.json() as LoginResponse & { message?: string };
            if (!response.ok) throw new Error(payload.message ?? 'Sign in failed');
            if (payload.customer.role !== 'admin') throw new Error(t('notAuthorized'));
            setToken(payload.accessToken);
            setPassword('');
        } catch (requestError) {
            setError(errorMessage(requestError, 'loginFailed'));
        } finally {
            setLoading(false);
        }
    }

    async function createPromotion(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();
        if (!token) return;
        try {
            await apiRequest('/admin/promotions', token, {
                method: 'POST',
                body: JSON.stringify({
                    code,
                    discountType,
                    discountValue: Number(discountValue),
                }),
            });
            setCode('');
            setDiscountValue('');
            await refreshDashboard(token);
        } catch (requestError) {
            setError(errorMessage(requestError, 'promotionCreated'));
        }
    }

    async function togglePromotion(promotion: Promotion) {
        if (!token) return;
        try {
            await apiRequest(`/admin/promotions/${promotion.id}/active`, token, {
                method: 'PATCH',
                body: JSON.stringify({ isActive: !promotion.is_active }),
            });
            await refreshDashboard(token);
        } catch (requestError) {
            setError(errorMessage(requestError, 'promotionUpdated'));
        }
    }

    async function adjustInventory(item: InventoryItem, quantityDelta: number) {
        if (!token) return;
        try {
            await apiRequest(`/admin/inventory/${encodeURIComponent(item.id)}/adjustments`, token, {
                method: 'POST',
                body: JSON.stringify({ quantityDelta }),
            });
            await refreshDashboard(token);
        } catch (requestError) {
            setError(errorMessage(requestError, 'inventoryUpdated'));
        }
    }

    async function updateDelivery(delivery: DeliveryItem, status: string) {
        if (!token) return;
        try {
            await apiRequest(`/admin/deliveries/${delivery.id}/status`, token, {
                method: 'PATCH',
                body: JSON.stringify({
                    status,
                    note: `Operations updated status to ${status}`,
                }),
            });
            await refreshDashboard(token);
        } catch (requestError) {
            setError(errorMessage(requestError, 'deliveryUpdated'));
        }
    }

    async function moderateReview(review: ProductReview, status: 'approved' | 'rejected') {
        if (!token) return;
        try {
            await apiRequest(`/admin/reviews/${review.id}/status`, token, {
                method: 'PATCH',
                body: JSON.stringify({ status }),
            });
            await refreshDashboard(token);
        } catch (requestError) {
            setError(errorMessage(requestError, 'moderationFailed'));
        }
    }

    async function updateProduct(product: CatalogProduct, changes: { price?: number; isActive?: boolean }) {
        if (!token) return;
        try {
            await apiRequest(`/admin/products/${encodeURIComponent(product.id)}`, token, {
                method: 'PATCH',
                body: JSON.stringify(changes),
            });
            await refreshDashboard(token);
        } catch (requestError) {
            setError(errorMessage(requestError, 'productUpdated'));
        }
    }

    async function createProduct(event: FormEvent<HTMLFormElement>) {
            event.preventDefault();
            if (!token) return;
            try {
                await apiRequest('/admin/products', token, {
                    method: 'POST',
                    body: JSON.stringify({
                        ...newProduct,
                        price: Number(newProduct.price),
                        quantity: Number(newProduct.quantity),
                        nameAr: newProduct.nameAr || undefined,
                        description: newProduct.description || undefined,
                        descriptionAr: newProduct.descriptionAr || undefined,
                        packageSize: newProduct.packageSize || undefined,
                    }),
                });
                setNewProduct({
                    name: '', nameAr: '', slug: '', description: '', descriptionAr: '',
                    categoryId: '', brandId: '', price: '', quantity: '0', packageSize: '',
                });
                await refreshDashboard(token);
            } catch (requestError) {
                setError(errorMessage(requestError, 'catalogItemCreated'));
            }
        }

    async function createTerm(type: 'categories' | 'brands', event: FormEvent<HTMLFormElement>) {
            event.preventDefault();
            if (!token) return;
            const value = type === 'categories' ? newCategory : newBrand;
            try {
                await apiRequest(`/admin/${type}`, token, {
                    method: 'POST',
                    body: JSON.stringify({
                        name: value.name,
                        nameAr: value.nameAr || undefined,
                        slug: value.slug,
                        description: value.description || undefined,
                        descriptionAr: value.descriptionAr || undefined,
                    }),
                });
                if (type === 'categories') setNewCategory({ name: '', nameAr: '', slug: '', description: '', descriptionAr: '' });
                else setNewBrand({ name: '', nameAr: '', slug: '', description: '', descriptionAr: '' });
                await refreshDashboard(token);
            } catch (requestError) {
                setError(errorMessage(requestError, 'catalogItemCreated'));
            }
        }

    async function updateTerm(type: 'categories' | 'brands', term: CatalogTerm) {
            if (!token) return;
            const changes = termEdits[term.id];
            if (!changes || Object.values(changes).every((value) => value === undefined)) return;
            try {
                await apiRequest(`/admin/${type}/${encodeURIComponent(term.id)}`, token, {
                    method: 'PATCH',
                    body: JSON.stringify(changes),
                });
                setTermEdits((previous) => {
                    const next = { ...previous };
                    delete next[term.id];
                    return next;
                });
                await refreshDashboard(token);
            } catch (requestError) {
                setError(errorMessage(requestError, 'catalogItemUpdated'));
            }
        }

    async function updateProductDetails(product: CatalogProduct) {
            if (!token) return;
            const changes = productEdits[product.id];
            if (!changes) return;
            try {
                await apiRequest(`/admin/products/${encodeURIComponent(product.id)}`, token, {
                    method: 'PATCH',
                    body: JSON.stringify(changes),
                });
                setProductEdits((previous) => {
                    const next = { ...previous };
                    delete next[product.id];
                    return next;
                });
                await refreshDashboard(token);
            } catch (requestError) {
                setError(errorMessage(requestError, 'catalogItemUpdated'));
            }
        }

    function displayName(english: string, arabic?: string | null) {
        return language === 'ar' && arabic ? arabic : english;
    }

    if (!token) {
        return (
            <main className="app-shell auth-shell">
                <header className="topbar">
                    <div>
                        <p className="eyebrow">{t('operationsDashboard')}</p>
                        <h1>AquaFlow Admin</h1>
                    </div>
                    <button className="secondary" type="button" onClick={() => setLanguage(language === 'en' ? 'ar' : 'en')}>
                        {t('language')}
                    </button>
                </header>
                <form className="card login-form" onSubmit={login}>
                    <h2>{t('administratorSignIn')}</h2>
                    <label>{t('email')}<input type="email" autoComplete="username" required value={email} onChange={(event) => setEmail(event.target.value)} /></label>
                    <label>{t('password')}<input type="password" autoComplete="current-password" required value={password} onChange={(event) => setPassword(event.target.value)} /></label>
                    {error && <p className="error" role="alert">{error}</p>}
                    <button disabled={loading}>{loading ? t('signingIn') : t('signIn')}</button>
                </form>
            </main>
        );
    }

    return (
        <main className="app-shell">
            <header className="topbar">
                <div>
                    <p className="eyebrow">{t('operationsDashboard')}</p>
                    <h1>AquaFlow Admin</h1>
                </div>
                <button className="secondary" type="button" onClick={() => setLanguage(language === 'en' ? 'ar' : 'en')}>
                    {t('language')}
                </button>
                <button className="secondary" onClick={() => {
                    setToken('');
                    setDashboard(null);
                    setOrders([]);
                    setPromotions([]);
                    setInventory([]);
                    setDeliveries([]);
                    setReviews([]);
                    setProducts([]);
                    setCategories([]);
                    setBrands([]);
                    setPriceEdits({});
                }}>{t('signOut')}</button>
            </header>
            {error && <p className="error" role="alert">{error}</p>}
            {loading && <p role="status">{t('refreshing')}</p>}
            {dashboard && (
                <>
                    <section className="grid" aria-label={t('operationsMetrics')}>
                        <Metric label={t('allOrders')} value={dashboard.totalOrders} />
                        <Metric label={t('openOrders')} value={dashboard.openOrders} />
                        <Metric label={t('awaitingPayment')} value={dashboard.awaitingPayment} />
                        <Metric label={t('paidRevenue')} value={`${dashboard.currency} ${dashboard.paidRevenue.toFixed(2)}`} />
                        <Metric label={t('pendingDispatch')} value={dashboard.pendingDispatch} />
                        <Metric label={t('activeProducts')} value={dashboard.activeProducts} />
                    </section>
                    <section className="card panel">
                        <h2>{t('recentOrders')}</h2>
                        {orders.length === 0 ? <p>{t('noOrders')}</p> : (
                            <div className="table-wrap">
                                <table>
                                    <thead><tr><th>{t('order')}</th><th>{t('status')}</th><th>{t('payment')}</th><th>{t('total')}</th><th>{t('created')}</th></tr></thead>
                                    <tbody>{orders.map((order) => (
                                        <tr key={order.id}>
                                            <td>{order.id.slice(0, 8)}</td>
                                            <td>{translateStatus(language, order.status)}</td>
                                            <td>{translateStatus(language, order.paymentMethod)}</td>
                                            <td>{order.currency} {order.total.toFixed(2)}</td>
                                            <td>{new Date(order.createdAt).toLocaleString(language === 'ar' ? 'ar-SA' : 'en-SA')}</td>
                                        </tr>
                                    ))}</tbody>
                                </table>
                            </div>
                        )}
                    </section>
                    <section className="card panel">
                        <h2>{t('promotions')}</h2>
                        <form className="promotion-form" onSubmit={createPromotion}>
                            <label>{t('code')}<input required maxLength={64} value={code} onChange={(event) => setCode(event.target.value.toUpperCase())} /></label>
                            <label>{t('discountType')}<select value={discountType} onChange={(event) => setDiscountType(event.target.value as 'percentage' | 'fixed')}>
                                <option value="percentage">{t('percentage')}</option><option value="fixed">{t('fixedSar')}</option>
                            </select></label>
                            <label>{t('value')}<input type="number" min="0.01" max={discountType === 'percentage' ? 100 : undefined} step="0.01" required value={discountValue} onChange={(event) => setDiscountValue(event.target.value)} /></label>
                            <button disabled={loading}>{t('createPromotion')}</button>
                        </form>
                        {promotions.length === 0 ? <p>{t('noPromotions')}</p> : (
                            <div className="table-wrap">
                                <table>
                                    <thead><tr><th>{t('code')}</th><th>{t('discount')}</th><th>{t('redemptions')}</th><th>{t('status')}</th><th /></tr></thead>
                                    <tbody>{promotions.map((promotion) => (
                                        <tr key={promotion.id}>
                                            <td>{promotion.code}</td>
                                            <td>{promotion.discount_type === 'percentage' ? `${promotion.discount_value}%` : format('discountSar', { value: promotion.discount_value })}</td>
                                            <td>{promotion.redemption_count}</td>
                                            <td>{promotion.is_active ? t('active') : t('inactive')}</td>
                                            <td><button className="secondary" onClick={() => void togglePromotion(promotion)}>{promotion.is_active ? t('disable') : t('enable')}</button></td>
                                        </tr>
                                    ))}</tbody>
                                </table>
                            </div>
                        )}
                    </section>
                    <section className="card panel">
                        <h2>{t('inventory')}</h2>
                        <p>{t('inventoryDescription')}</p>
                        <div className="table-wrap">
                            <table>
                                <thead><tr><th>{t('product')}</th><th>{t('stock')}</th><th>{t('availability')}</th><th>{t('adjustment')}</th></tr></thead>
                                <tbody>{inventory.map((item) => (
                                    <tr key={item.id}>
                                        <td>{displayName(
                                            products.find((product) => product.id === item.id)?.name ?? item.name,
                                            products.find((product) => product.id === item.id)?.name_ar,
                                        )}</td>
                                        <td>{item.quantity}</td>
                                        <td>{translateStatus(language, item.availability)}</td>
                                        <td>
                                            <button className="secondary" aria-label={format('removeOne', { product: item.name })} onClick={() => void adjustInventory(item, -1)}>−</button>{' '}
                                            <button aria-label={format('addOne', { product: item.name })} onClick={() => void adjustInventory(item, 1)}>+</button>
                                        </td>
                                    </tr>
                                ))}</tbody>
                            </table>
                        </div>
                    </section>
                    <section className="card panel">
                        <h2>{t('deliveryOperations')}</h2>
                        <p>{t('manualDeliveryDescription')}</p>
                        <div className="table-wrap">
                            <table>
                                <thead><tr><th>{t('order')}</th><th>{t('status')}</th><th>{t('zoneEstimate')}</th><th>{t('action')}</th></tr></thead>
                                <tbody>{deliveries.map((delivery) => {
                                    const nextStatus = delivery.status === 'pending_dispatch'
                                        ? 'assigned'
                                        : delivery.status === 'assigned'
                                            ? 'picked_up'
                                            : delivery.status === 'picked_up' ? 'delivered' : null;
                                    return (
                                        <tr key={delivery.id}>
                                            <td>{delivery.order_id.slice(0, 8)}</td>
                                            <td>{translateStatus(language, delivery.status)}</td>
                                            <td>{format('minutes', { count: delivery.estimated_minutes })}</td>
                                            <td>{nextStatus
                                                ? <button onClick={() => void updateDelivery(delivery, nextStatus)}>{format('markStatus', { status: translateStatus(language, nextStatus) })}</button>
                                                : t('noAction')}</td>
                                        </tr>
                                    );
                                })}</tbody>
                            </table>
                        </div>
                    </section>
                    <section className="card panel">
                        <h2>{t('reviewsAwaitingModeration')}</h2>
                        {reviews.length === 0 ? <p>{t('noReviews')}</p> : (
                            <div className="table-wrap">
                                <table>
                                    <thead><tr><th>{t('product')}</th><th>{t('rating')}</th><th>{t('comment')}</th><th>{t('action')}</th></tr></thead>
                                    <tbody>{reviews.map((review) => (
                                        <tr key={review.id}>
                                            <td>{displayName(review.product_name, review.product_name_ar)}</td>
                                            <td>{review.rating} / 5</td>
                                            <td>{review.comment || '—'}</td>
                                            <td>
                                                <button onClick={() => void moderateReview(review, 'approved')}>{t('approve')}</button>{' '}
                                                <button className="secondary" onClick={() => void moderateReview(review, 'rejected')}>{t('reject')}</button>
                                            </td>
                                        </tr>
                                    ))}</tbody>
                                </table>
                            </div>
                        )}
                    </section>
                    <section className="card panel">
                        <h2>{t('catalogOperations')}</h2>
                        <p>{t('mediaNotConfigured')}</p>
                        <h3>{t('createProduct')}</h3>
                        <form className="catalog-form" onSubmit={createProduct}>
                            <label>{t('productName')}<input required maxLength={200} value={newProduct.name} onChange={(event) => setNewProduct({ ...newProduct, name: event.target.value })} /></label>
                            <label>{t('arabicName')}<input maxLength={200} value={newProduct.nameAr} onChange={(event) => setNewProduct({ ...newProduct, nameAr: event.target.value })} /></label>
                            <label>{t('slug')}<input required pattern="[a-z0-9]+(?:-[a-z0-9]+)*" maxLength={200} value={newProduct.slug} onChange={(event) => setNewProduct({ ...newProduct, slug: event.target.value.toLowerCase() })} /></label>
                            <label>{t('category')}<select required value={newProduct.categoryId} onChange={(event) => setNewProduct({ ...newProduct, categoryId: event.target.value })}><option value="">{t('selectCategory')}</option>{categories.map((item) => <option key={item.id} value={item.id}>{displayName(item.name, item.name_ar)}</option>)}</select></label>
                            <label>{t('brand')}<select required value={newProduct.brandId} onChange={(event) => setNewProduct({ ...newProduct, brandId: event.target.value })}><option value="">{t('selectBrand')}</option>{brands.map((item) => <option key={item.id} value={item.id}>{displayName(item.name, item.name_ar)}</option>)}</select></label>
                            <label>{t('priceSar')}<input type="number" min="0.01" step="0.01" required value={newProduct.price} onChange={(event) => setNewProduct({ ...newProduct, price: event.target.value })} /></label>
                            <label>{t('stock')}<input type="number" min="0" step="1" required value={newProduct.quantity} onChange={(event) => setNewProduct({ ...newProduct, quantity: event.target.value })} /></label>
                            <label>{t('packageSize')}<input maxLength={80} value={newProduct.packageSize} onChange={(event) => setNewProduct({ ...newProduct, packageSize: event.target.value })} /></label>
                            <label>{t('description')}<input maxLength={10000} value={newProduct.description} onChange={(event) => setNewProduct({ ...newProduct, description: event.target.value })} /></label>
                            <label>{t('arabicDescription')}<input maxLength={10000} value={newProduct.descriptionAr} onChange={(event) => setNewProduct({ ...newProduct, descriptionAr: event.target.value })} /></label>
                            <label>{t('productMedia')}<input type="file" disabled aria-disabled="true" /></label>
                            <button disabled={loading || !categories.length || !brands.length}>{t('createProduct')}</button>
                        </form>
                        <div className="catalog-management-grid">
                            {(['categories', 'brands'] as const).map((type) => {
                                const isCategory = type === 'categories';
                                const terms = isCategory ? categories : brands;
                                const form = isCategory ? newCategory : newBrand;
                                const setForm = isCategory ? setNewCategory : setNewBrand;
                                return (
                                    <div key={type}>
                                        <h3>{t(type)}</h3>
                                        <form className="catalog-form" onSubmit={(event) => void createTerm(type, event)}>
                                            <label>{t('productName')}<input required maxLength={150} value={form.name} onChange={(event) => setForm({ ...form, name: event.target.value })} /></label>
                                            <label>{t('arabicName')}<input maxLength={150} value={form.nameAr} onChange={(event) => setForm({ ...form, nameAr: event.target.value })} /></label>
                                            <label>{t('slug')}<input required pattern="[a-z0-9]+(?:-[a-z0-9]+)*" maxLength={150} value={form.slug} onChange={(event) => setForm({ ...form, slug: event.target.value.toLowerCase() })} /></label>
                                            <label>{t('description')}<input maxLength={10000} value={form.description} onChange={(event) => setForm({ ...form, description: event.target.value })} /></label>
                                            <label>{t('arabicDescription')}<input maxLength={10000} value={form.descriptionAr} onChange={(event) => setForm({ ...form, descriptionAr: event.target.value })} /></label>
                                            <button disabled={loading}>{isCategory ? t('createCategory') : t('createBrand')}</button>
                                        </form>
                                        <div className="table-wrap">
                                            <table>
                                                <thead><tr><th>{t('productName')}</th><th>{t('arabicName')}</th><th>{t('slug')}</th><th>{t('description')}</th><th>{t('arabicDescription')}</th><th>{t('action')}</th></tr></thead>
                                                <tbody>{terms.map((term) => {
                                                    const edit = termEdits[term.id] ?? {};
                                                    return <tr key={term.id}>
                                                        <td><input aria-label={`${t('productName')} ${term.name}`} value={edit.name ?? term.name} onChange={(event) => setTermEdits({ ...termEdits, [term.id]: { ...edit, name: event.target.value } })} /></td>
                                                        <td><input aria-label={`${t('arabicName')} ${term.name}`} value={edit.nameAr ?? term.name_ar ?? ''} onChange={(event) => setTermEdits({ ...termEdits, [term.id]: { ...edit, nameAr: event.target.value } })} /></td>
                                                        <td><input aria-label={`${t('slug')} ${term.name}`} value={edit.slug ?? term.slug} onChange={(event) => setTermEdits({ ...termEdits, [term.id]: { ...edit, slug: event.target.value } })} /></td>
                                                        <td><input aria-label={`${t('description')} ${term.name}`} value={edit.description ?? term.description ?? ''} onChange={(event) => setTermEdits({ ...termEdits, [term.id]: { ...edit, description: event.target.value } })} /></td>
                                                        <td><input aria-label={`${t('arabicDescription')} ${term.name}`} value={edit.descriptionAr ?? term.description_ar ?? ''} onChange={(event) => setTermEdits({ ...termEdits, [term.id]: { ...edit, descriptionAr: event.target.value } })} /></td>
                                                        <td><button className="secondary" onClick={() => void updateTerm(type, term)}>{t('saveChanges')}</button></td>
                                                    </tr>;
                                                })}</tbody>
                                            </table>
                                        </div>
                                    </div>
                                );
                            })}
                        </div>
                        <div className="table-wrap">
                            <table>
                                <thead><tr><th>{t('product')}</th><th>{t('category')}</th><th>{t('brand')}</th><th>{t('stock')}</th><th>{t('priceSar')}</th><th>{t('status')}</th></tr></thead>
                                <tbody>{products.map((product) => (
                                    <tr key={product.id}>
                                        <td>
                                            <input aria-label={`${t('productName')} ${product.name}`} value={productEdits[product.id]?.name ?? product.name} onChange={(event) => setProductEdits({ ...productEdits, [product.id]: { ...productEdits[product.id], name: event.target.value } })} />
                                            <input aria-label={`${t('arabicName')} ${product.name}`} value={productEdits[product.id]?.nameAr ?? product.name_ar ?? ''} onChange={(event) => setProductEdits({ ...productEdits, [product.id]: { ...productEdits[product.id], nameAr: event.target.value } })} />
                                            <input aria-label={`${t('slug')} ${product.name}`} value={productEdits[product.id]?.slug ?? product.slug} onChange={(event) => setProductEdits({ ...productEdits, [product.id]: { ...productEdits[product.id], slug: event.target.value.toLowerCase() } })} />
                                            <input aria-label={`${t('description')} ${product.name}`} value={productEdits[product.id]?.description ?? product.description ?? ''} onChange={(event) => setProductEdits({ ...productEdits, [product.id]: { ...productEdits[product.id], description: event.target.value } })} />
                                            <input aria-label={`${t('arabicDescription')} ${product.name}`} value={productEdits[product.id]?.descriptionAr ?? product.description_ar ?? ''} onChange={(event) => setProductEdits({ ...productEdits, [product.id]: { ...productEdits[product.id], descriptionAr: event.target.value } })} />
                                            <button className="secondary" onClick={() => void updateProductDetails(product)}>{t('saveChanges')}</button>
                                        </td>
                                        <td>
                                            {displayName(product.category_name, product.category_name_ar)}
                                            <select aria-label={`${t('category')} ${product.name}`} value={productEdits[product.id]?.categoryId ?? product.category_id} onChange={(event) => setProductEdits({ ...productEdits, [product.id]: { ...productEdits[product.id], categoryId: event.target.value } })}>
                                                {categories.map((item) => <option key={item.id} value={item.id}>{displayName(item.name, item.name_ar)}</option>)}
                                            </select>
                                        </td>
                                        <td>
                                            {displayName(product.brand_name, brands.find((brandItem) => brandItem.id === product.brand_id)?.name_ar)}
                                            <select aria-label={`${t('brand')} ${product.name}`} value={productEdits[product.id]?.brandId ?? product.brand_id} onChange={(event) => setProductEdits({ ...productEdits, [product.id]: { ...productEdits[product.id], brandId: event.target.value } })}>
                                                {brands.map((item) => <option key={item.id} value={item.id}>{displayName(item.name, item.name_ar)}</option>)}
                                            </select>
                                        </td>
                                        <td>{product.quantity}</td>
                                        <td>
                                            <form className="inline-form" onSubmit={(event) => {
                                                event.preventDefault();
                                                const value = Number(priceEdits[product.id]);
                                                if (Number.isFinite(value) && value > 0) {
                                                    void updateProduct(product, { price: value });
                                                }
                                            }}>
                                                <input
                                                    aria-label={format('priceFor', { product: displayName(product.name, product.name_ar) })}
                                                    type="number"
                                                    min="0.01"
                                                    step="0.01"
                                                    value={priceEdits[product.id] ?? product.price}
                                                    onChange={(event) => setPriceEdits({
                                                        ...priceEdits,
                                                        [product.id]: event.target.value,
                                                    })}
                                                />
                                                <button className="secondary">{t('save')}</button>
                                            </form>
                                        </td>
                                        <td>
                                            <button className={product.is_active ? 'secondary' : ''} onClick={() => void updateProduct(product, { isActive: !product.is_active })}>
                                                {product.is_active ? t('active') : t('inactive')}
                                            </button>
                                        </td>
                                    </tr>
                                ))}</tbody>
                            </table>
                        </div>
                    </section>
                </>
            )}
        </main>
    );
}

function Metric({ label, value }: { label: string; value: string | number }) {
    return <article className="card metric"><span>{label}</span><strong>{value}</strong></article>;
}

export default App;
