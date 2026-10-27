import { Fragment, FormEvent, useCallback, useEffect, useRef, useState } from 'react';
import { AdminLayout } from './AdminLayout';
import { isAdminPath, normalizeAdminPath, pageTitleKey } from './admin-routes';
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
    customerId: string;
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

interface ProductForm {
    name: string;
    nameAr: string;
    slug: string;
    description: string;
    descriptionAr: string;
    categoryId: string;
    brandId: string;
    price: string;
    quantity: string;
    packageSize: string;
}

function emptyProductForm(): ProductForm {
    return {
        name: '',
        nameAr: '',
        slug: '',
        description: '',
        descriptionAr: '',
        categoryId: '',
        brandId: '',
        price: '',
        quantity: '0',
        packageSize: '',
    };
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

class ApiRequestError extends Error {
    constructor(
        message: string,
        readonly status: number,
        readonly retryAfterSeconds?: number,
    ) {
        super(message);
    }
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
        const retryAfter = Number(response.headers.get('Retry-After'));
        throw new ApiRequestError(
            payload.message ?? `Request failed (${response.status})`,
            response.status,
            Number.isFinite(retryAfter) && retryAfter > 0 ? retryAfter : undefined,
        );
    }
    return response.json() as Promise<T>;
}

function App() {
    const [language, setLanguage] = useState<AdminLanguage>(() => loadAdminLanguage((key) => localStorage.getItem(key)));
    const [pathname, setPathname] = useState(() => normalizeAdminPath(window.location.pathname));
    const t = useCallback((key: AdminMessage) => translate(language, key), [language]);
    const format = useCallback(
        (key: AdminMessage, values: Record<string, string | number>) => formatMessage(language, key, values),
        [language],
    );
    const errorMessage = useCallback(
        (requestError: unknown, fallback: AdminMessage) => {
            if (
                requestError instanceof ApiRequestError
                && requestError.status === 429
                && requestError.retryAfterSeconds !== undefined
            ) {
                return format('rateLimitedFor', { seconds: requestError.retryAfterSeconds });
            }
            return requestError instanceof Error ? translateError(language, requestError.message) : t(fallback);
        },
        [format, language, t],
    );
    const [token, setToken] = useState(() => sessionStorage.getItem('aquaflow-admin-token') ?? '');
    const [administrator, setAdministrator] = useState(() => sessionStorage.getItem('aquaflow-admin-email') ?? '');
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [dashboard, setDashboard] = useState<Dashboard | null>(null);
    const [orders, setOrders] = useState<AdminOrder[]>([]);
    const [ordersPage, setOrdersPage] = useState(1);
    const [productsPage, setProductsPage] = useState(1);
    const [ordersTotal, setOrdersTotal] = useState(0);
    const [orderStatus, setOrderStatus] = useState('');
    const [search, setSearch] = useState('');
    const [expandedOrder, setExpandedOrder] = useState('');
    const [productActivity, setProductActivity] = useState('');
    const [productCategory, setProductCategory] = useState('');
    const [productBrand, setProductBrand] = useState('');
    const [productSort, setProductSort] = useState('name');
    const [productPageSize, setProductPageSize] = useState(20);
    const [promotionActivity, setPromotionActivity] = useState('');
    const [deliveryStatus, setDeliveryStatus] = useState('');
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
    const [productDialog, setProductDialog] = useState<'create' | 'edit' | null>(null);
    const [editingProduct, setEditingProduct] = useState<CatalogProduct | null>(null);
    const [productForm, setProductForm] = useState<ProductForm>(emptyProductForm);
    const [productFormInitial, setProductFormInitial] = useState<ProductForm>(emptyProductForm);
    const [newCategory, setNewCategory] = useState({ name: '', nameAr: '', slug: '', description: '', descriptionAr: '' });
    const [newBrand, setNewBrand] = useState({ name: '', nameAr: '', slug: '', description: '', descriptionAr: '' });
    const [code, setCode] = useState('');
    const [discountType, setDiscountType] = useState<'percentage' | 'fixed'>('percentage');
    const [discountValue, setDiscountValue] = useState('');
    const [error, setError] = useState('');
    const [success, setSuccess] = useState('');
    const [loading, setLoading] = useState(false);
    const loginInFlight = useRef(false);
    const pageTitle = t(pageTitleKey(pathname));
    const orderPageCount = Math.max(1, Math.ceil(ordersTotal / 20));
    const safeOrdersPage = Math.min(ordersPage, orderPageCount);
    const searchTerm = search.trim().toLowerCase();
    const filteredOrders = orders.filter((order) =>
        `${order.id} ${order.customerId} ${order.status} ${order.paymentMethod}`.toLowerCase().includes(searchTerm));
    const filteredProducts = products.filter((product) =>
        `${product.name} ${product.name_ar ?? ''} ${product.slug} ${product.category_name} ${product.brand_name}`.toLowerCase().includes(searchTerm)
        && (!productActivity || product.is_active === (productActivity === 'active'))
        && (!productCategory || product.category_id === productCategory)
        && (!productBrand || product.brand_id === productBrand))
        .sort((left, right) => {
            if (productSort === 'price-asc') return left.price - right.price;
            if (productSort === 'price-desc') return right.price - left.price;
            if (productSort === 'stock-asc') return left.quantity - right.quantity;
            if (productSort === 'stock-desc') return right.quantity - left.quantity;
            if (productSort === 'stock-desc') return right.quantity - left.quantity;
            return left.name.localeCompare(right.name);
        });
    const productPageCount = Math.max(1, Math.ceil(filteredProducts.length / productPageSize));
    const safeProductsPage = Math.min(productsPage, productPageCount);
    const visibleProducts = filteredProducts.slice((safeProductsPage - 1) * productPageSize, safeProductsPage * productPageSize);
    const productFormChanged = JSON.stringify(productForm) !== JSON.stringify(productFormInitial);
    const filteredPromotions = promotions.filter((promotion) =>
        promotion.code.toLowerCase().includes(searchTerm)
        && (!promotionActivity || promotion.is_active === (promotionActivity === 'active')));
    const filteredInventory = inventory.filter((item) =>
        `${item.name} ${products.find((product) => product.id === item.id)?.name_ar ?? ''}`.toLowerCase().includes(searchTerm));
    const filteredDeliveries = deliveries.filter((delivery) =>
        `${delivery.order_id} ${delivery.status}`.toLowerCase().includes(searchTerm)
        && (!deliveryStatus || delivery.status === deliveryStatus));
    const filteredReviews = reviews.filter((review) =>
        `${review.product_name} ${review.product_name_ar ?? ''} ${review.comment ?? ''}`.toLowerCase().includes(searchTerm));

    useEffect(() => {
        function handlePopState() {
            setPathname(normalizeAdminPath(window.location.pathname));
            setSearch('');
        }
        window.addEventListener('popstate', handlePopState);
        return () => window.removeEventListener('popstate', handlePopState);
    }, []);

    function navigate(path: string) {
        const nextPath = normalizeAdminPath(path);
        if (nextPath === pathname) return;
        window.history.pushState({}, '', nextPath);
        setPathname(nextPath);
        setSearch('');
        setError('');
        setSuccess('');
        if (nextPath !== '/orders') {
            setOrdersPage(1);
            setOrderStatus('');
        }
    }

    function signOut() {
        sessionStorage.removeItem('aquaflow-admin-token');
        sessionStorage.removeItem('aquaflow-admin-email');
        setToken('');
        setAdministrator('');
        setError('');
        setSuccess('');
        setDashboard(null);
        setOrders([]);
        setPromotions([]);
        setInventory([]);
        setDeliveries([]);
        setReviews([]);
        setProducts([]);
        setCategories([]);
        setBrands([]);
        navigate('/');
    }

    useEffect(() => {
        syncAdminLanguage(language, (key, value) => localStorage.setItem(key, value), document.documentElement);
    }, [language]);

    const refreshPage = useCallback(async (accessToken: string, page = pathname): Promise<boolean> => {
        setLoading(true);
        setError('');
        setSuccess('');
        try {
            const route = normalizeAdminPath(page);
            if (route === '/') {
                const [metrics, orderList] = await Promise.all([
                    apiRequest<Dashboard>('/admin/dashboard', accessToken),
                    apiRequest<{ items: AdminOrder[] }>('/admin/orders?limit=10', accessToken),
                ]);
                setDashboard(metrics);
                setOrders(orderList.items);
            } else if (route === '/orders') {
                const params = new URLSearchParams({ page: String(safeOrdersPage), limit: '20' });
                if (orderStatus) params.set('status', orderStatus);
                const orderList = await apiRequest<{ items: AdminOrder[]; total: number; page: number }>(
                    `/admin/orders?${params.toString()}`,
                    accessToken,
                );
                setOrders(orderList.items);
                setOrdersTotal(orderList.total);
                if (orderList.page !== ordersPage) setOrdersPage(orderList.page);
            } else if (route === '/products') {
                const [productList, terms] = await Promise.all([
                    apiRequest<{ items: CatalogProduct[] }>('/admin/products', accessToken),
                    apiRequest<{ categories: CatalogTerm[]; brands: CatalogTerm[] }>('/admin/catalog-terms', accessToken),
                ]);
                setProducts(productList.items);
                setCategories(terms.categories);
                setBrands(terms.brands);
            } else if (route === '/categories' || route === '/brands' || route === '/catalog-terms') {
                const terms = await apiRequest<{ categories: CatalogTerm[]; brands: CatalogTerm[] }>(
                    '/admin/catalog-terms',
                    accessToken,
                );
                setCategories(terms.categories);
                setBrands(terms.brands);
            } else if (route === '/promotions') {
                const result = await apiRequest<{ items: Promotion[] }>('/admin/promotions', accessToken);
                setPromotions(result.items);
            } else if (route === '/inventory') {
                const result = await apiRequest<{ items: InventoryItem[] }>('/admin/inventory', accessToken);
                setInventory(result.items);
            } else if (route === '/deliveries') {
                const result = await apiRequest<{ items: DeliveryItem[] }>('/admin/deliveries', accessToken);
                setDeliveries(result.items);
            } else if (route === '/reviews') {
                const result = await apiRequest<{ items: ProductReview[] }>('/admin/reviews', accessToken);
                setReviews(result.items);
            }
            return true;
        } catch (requestError) {
            if (requestError instanceof ApiRequestError && requestError.status === 401) {
                setEmail(administrator);
                sessionStorage.removeItem('aquaflow-admin-token');
                sessionStorage.removeItem('aquaflow-admin-email');
                setToken('');
                setAdministrator('');
            }
            setError(errorMessage(requestError, 'requestFailed'));
            return false;
        } finally {
            setLoading(false);
        }
    }, [administrator, errorMessage, orderStatus, ordersPage, pathname, safeOrdersPage]);

    async function runMutation(fallback: AdminMessage, action: () => Promise<void>): Promise<boolean> {
        if (!token || loading) return false;
        setLoading(true);
        setError('');
        setSuccess('');
        try {
            await action();
            if (await refreshPage(token)) setSuccess(t('savedSuccessfully'));
            return true;
        } catch (requestError) {
            if (requestError instanceof ApiRequestError && requestError.status === 401) {
                setEmail(administrator);
                sessionStorage.removeItem('aquaflow-admin-token');
                sessionStorage.removeItem('aquaflow-admin-email');
                setToken('');
                setAdministrator('');
            }
            setError(errorMessage(requestError, fallback));
            return false;
        } finally {
            setLoading(false);
        }
    }

    useEffect(() => {
        if (token && isAdminPath(pathname)) void refreshPage(token, pathname);
    }, [token, pathname, orderStatus, ordersPage, refreshPage]);

    async function login(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();
        if (loginInFlight.current) return;
        loginInFlight.current = true;
        setLoading(true);
        setError('');
        try {
            const response = await fetch(`${apiBaseUrl}/auth/login`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ email, password }),
            });
            const payload = await response.json() as LoginResponse & { message?: string };
            if (!response.ok) {
                const retryAfter = Number(response.headers.get('Retry-After'));
                throw new ApiRequestError(
                    payload.message ?? 'Sign in failed',
                    response.status,
                    Number.isFinite(retryAfter) && retryAfter > 0 ? retryAfter : undefined,
                );
            }
            if (payload.customer.role !== 'admin') throw new Error(t('notAuthorized'));
            sessionStorage.setItem('aquaflow-admin-token', payload.accessToken);
            sessionStorage.setItem('aquaflow-admin-email', email);
            setAdministrator(email);
            setToken(payload.accessToken);
            setPassword('');
        } catch (requestError) {
            setError(errorMessage(requestError, 'loginFailed'));
        } finally {
            loginInFlight.current = false;
            setLoading(false);
        }
    }

    async function createPromotion(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();
        await runMutation('promotionCreated', async () => {
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
        });
    }

    async function togglePromotion(promotion: Promotion) {
        if (promotion.is_active && !window.confirm(t('confirmDisablePromotion'))) return;
        await runMutation('promotionUpdated', async () => {
            await apiRequest(`/admin/promotions/${promotion.id}/active`, token, {
                method: 'PATCH',
                body: JSON.stringify({ isActive: !promotion.is_active }),
            });
        });
    }

    async function adjustInventory(item: InventoryItem, quantityDelta: number) {
        if (!Number.isInteger(quantityDelta) || quantityDelta === 0) return;
        if (!window.confirm(format('confirmInventoryAdjustment', {
            delta: quantityDelta,
            product: displayName(item.name, products.find((product) => product.id === item.id)?.name_ar),
        }))) return;
        await runMutation('inventoryUpdated', async () => {
            await apiRequest(`/admin/inventory/${encodeURIComponent(item.id)}/adjustments`, token, {
                method: 'POST',
                body: JSON.stringify({ quantityDelta }),
            });
        });
    }

    async function updateDelivery(delivery: DeliveryItem, status: string) {
        if (!window.confirm(format('confirmDeliveryTransition', { status: translateStatus(language, status) }))) return;
        await runMutation('deliveryUpdated', async () => {
            await apiRequest(`/admin/deliveries/${delivery.id}/status`, token, {
                method: 'PATCH',
                body: JSON.stringify({
                    status,
                    note: `Operations updated status to ${status}`,
                }),
            });
        });
    }

    async function moderateReview(review: ProductReview, status: 'approved' | 'rejected') {
        if (status === 'rejected' && !window.confirm(t('confirmRejectReview'))) return;
        await runMutation('moderationFailed', async () => {
            await apiRequest(`/admin/reviews/${review.id}/status`, token, {
                method: 'PATCH',
                body: JSON.stringify({ status }),
            });
        });
    }

    async function updateProduct(product: CatalogProduct, changes: { isActive: boolean }) {
        if (changes.isActive === false && !window.confirm(format('confirmDeactivateProduct', {
            product: displayName(product.name, product.name_ar),
        }))) return;
        await runMutation('productUpdated', async () => {
            await apiRequest(`/admin/products/${encodeURIComponent(product.id)}`, token, {
                method: 'PATCH',
                body: JSON.stringify(changes),
            });
        });
    }

    function openProductDialog(mode: 'create' | 'edit', product?: CatalogProduct) {
        const form = product ? {
            name: product.name,
            nameAr: product.name_ar ?? '',
            slug: product.slug,
            description: product.description ?? '',
            descriptionAr: product.description_ar ?? '',
            categoryId: product.category_id,
            brandId: product.brand_id,
            price: String(product.price),
            quantity: String(product.quantity),
            packageSize: '',
        } : emptyProductForm();
        setEditingProduct(product ?? null);
        setProductForm(form);
        setProductFormInitial(form);
        setProductDialog(mode);
        setError('');
        setSuccess('');
    }

    function closeProductDialog() {
        if (loading) return;
        if (productFormChanged && !window.confirm(t('discardProductChanges'))) return;
        setProductDialog(null);
        setEditingProduct(null);
    }

    async function saveProduct(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();
        if (!productDialog || loading) return;
        const values = productForm;
        let saved = false;
        if (productDialog === 'create') {
            saved = await runMutation('catalogItemCreated', async () => {
                await apiRequest('/admin/products', token, {
                    method: 'POST',
                    body: JSON.stringify({
                        name: values.name.trim(),
                        nameAr: values.nameAr.trim() || undefined,
                        slug: values.slug.trim().toLowerCase(),
                        categoryId: values.categoryId,
                        brandId: values.brandId,
                        description: values.description.trim() || undefined,
                        descriptionAr: values.descriptionAr.trim() || undefined,
                        price: Number(values.price),
                        quantity: Number(values.quantity),
                        packageSize: values.packageSize.trim() || undefined,
                    }),
                });
            });
        } else if (editingProduct) {
            const changes: {
                name?: string;
                nameAr?: string;
                slug?: string;
                description?: string;
                descriptionAr?: string;
                categoryId?: string;
                brandId?: string;
                price?: number;
            } = {};
            if (values.name.trim() !== editingProduct.name) changes.name = values.name.trim();
            if (values.nameAr.trim() !== (editingProduct.name_ar ?? '')) changes.nameAr = values.nameAr.trim();
            if (values.slug.trim().toLowerCase() !== editingProduct.slug) changes.slug = values.slug.trim().toLowerCase();
            if (values.description.trim() !== (editingProduct.description ?? '')) changes.description = values.description.trim();
            if (values.descriptionAr.trim() !== (editingProduct.description_ar ?? '')) changes.descriptionAr = values.descriptionAr.trim();
            if (values.categoryId !== editingProduct.category_id) changes.categoryId = values.categoryId;
            if (values.brandId !== editingProduct.brand_id) changes.brandId = values.brandId;
            if (Number(values.price) !== editingProduct.price) changes.price = Number(values.price);
            if (Object.keys(changes).length === 0) {
                setProductDialog(null);
                setEditingProduct(null);
                return;
            }
            saved = await runMutation('catalogItemUpdated', async () => {
                await apiRequest(`/admin/products/${encodeURIComponent(editingProduct.id)}`, token, {
                    method: 'PATCH',
                    body: JSON.stringify(changes),
                });
            });
        }
        if (saved) {
            setProductDialog(null);
            setEditingProduct(null);
        }
    }

    async function createTerm(type: 'categories' | 'brands', event: FormEvent<HTMLFormElement>) {
        event.preventDefault();
        const value = type === 'categories' ? newCategory : newBrand;
        await runMutation('catalogItemCreated', async () => {
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
        });
    }

    async function updateTerm(type: 'categories' | 'brands', term: CatalogTerm) {
        const changes = termEdits[term.id];
        if (!changes || Object.values(changes).every((value) => value === undefined)) return;
        await runMutation('catalogItemUpdated', async () => {
                await apiRequest(`/admin/${type}/${encodeURIComponent(term.id)}`, token, {
                    method: 'PATCH',
                    body: JSON.stringify(changes),
                });
                setTermEdits((previous) => {
                    const next = { ...previous };
                    delete next[term.id];
                    return next;
                });
        });
    }

    function displayName(english: string, arabic?: string | null) {
        return language === 'ar' && arabic ? arabic : english;
    }

    if (!token) {
        return (
            <main className="auth-screen">
                <div className="auth-brand"><span className="brand-mark">A</span><span>AquaFlow Admin</span></div>
                <form className="card login-form" onSubmit={login}>
                    <p className="eyebrow">{t('operationsDashboard')}</p>
                    <h1>{t('administratorSignIn')}</h1>
                    <p className="auth-description">AquaFlow · {t('adminWorkspace')}</p>
                    <label>{t('email')}<input type="email" autoComplete="username" required value={email} onChange={(event) => setEmail(event.target.value)} /></label>
                    <label>{t('password')}<input type="password" autoComplete="current-password" required value={password} onChange={(event) => setPassword(event.target.value)} /></label>
                    {error && <p className="error-banner" role="alert">{error}</p>}
                    <button disabled={loading}>{loading ? t('signingIn') : t('signIn')}</button>
                    <button className="language-toggle auth-language" type="button" onClick={() => setLanguage(language === 'en' ? 'ar' : 'en')}>
                        {t('language')}
                    </button>
                </form>
            </main>
        );
    }

    return (
        <AdminLayout
            pathname={pathname}
            title={pageTitle}
            language={language}
            administrator={administrator || email}
            t={t}
            onNavigate={navigate}
            onLanguageChange={() => setLanguage(language === 'en' ? 'ar' : 'en')}
            onSignOut={signOut}
        >
            {error && <div className="error-banner" role="alert"><span>{error}</span><button className="button button-quiet" onClick={() => void refreshPage(token)}>{t('retry')}</button></div>}
            {success && <p className="success-banner" role="status">{success}</p>}
            {loading && <p className="loading-banner" role="status">{t('refreshing')}</p>}
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
                    <section className="quick-actions" aria-label={t('quickActions')}>
                        {(['/orders', '/products', '/inventory', '/deliveries'] as const).map((path) => (
                            <a className="quick-action-card" key={path} href={path} onClick={(event) => {
                                event.preventDefault();
                                navigate(path);
                            }}>
                                <span>{t(pageTitleKey(path))}</span><span aria-hidden="true">→</span>
                            </a>
                        ))}
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
                </>
            )}
            {pathname === '/orders' && (
                <section className="card panel">
                    <div className="section-heading">
                        <div><h2>{t('orders')}</h2><p>{ordersTotal} {t('results')}</p><p className="api-limitation">{t('paymentStatusUnavailable')}</p></div>
                        <div className="toolbar">
                            <label>{t('filterByStatus')}
                                <select value={orderStatus} onChange={(event) => {
                                    setOrderStatus(event.target.value);
                                    setOrdersPage(1);
                                }}>
                                    <option value="">{t('allStatuses')}</option>
                                    {['payment_pending', 'placed', 'paid', 'cancelled'].map((status) => (
                                        <option key={status} value={status}>{translateStatus(language, status)}</option>
                                    ))}
                                </select>
                            </label>
                            <label className="search-field">{t('searchCurrentPage')}<input type="search" value={search} onChange={(event) => setSearch(event.target.value)} /></label>
                        </div>
                    </div>
                    <div className="table-wrap">
                        <table>
                            <thead><tr><th>{t('order')}</th><th>{t('customerId')}</th><th>{t('status')}</th><th>{t('paymentMethod')}</th><th>{t('total')}</th><th>{t('created')}</th><th>{t('action')}</th></tr></thead>
                            <tbody>
                                {filteredOrders.map((order) => (
                                    <Fragment key={order.id}>
                                        <tr>
                                            <td title={order.id}>{order.id.slice(0, 8)}</td>
                                            <td title={order.customerId}>{order.customerId.slice(0, 8)}</td>
                                            <td><span className={`status-pill status-${order.status}`}>{translateStatus(language, order.status)}</span></td>
                                            <td>{translateStatus(language, order.paymentMethod)}</td>
                                            <td>{order.currency} {order.total.toFixed(2)}</td>
                                            <td>{new Date(order.createdAt).toLocaleString(language === 'ar' ? 'ar-SA' : 'en-SA')}</td>
                                            <td><button className="button button-quiet" onClick={() => setExpandedOrder(expandedOrder === order.id ? '' : order.id)}>{expandedOrder === order.id ? t('hideDetails') : t('viewDetails')}</button></td>
                                        </tr>
                                        {expandedOrder === order.id && (
                                            <tr className="detail-row"><td colSpan={7}>
                                                <strong>{t('orderDetails')}</strong>
                                                <dl className="order-detail-grid">
                                                    <div><dt>{t('orderId')}</dt><dd>{order.id}</dd></div>
                                                    <div><dt>{t('customerId')}</dt><dd>{order.customerId}</dd></div>
                                                    <div><dt>{t('status')}</dt><dd>{translateStatus(language, order.status)}</dd></div>
                                                    <div><dt>{t('payment')}</dt><dd>{translateStatus(language, order.paymentMethod)}</dd></div>
                                                </dl>
                                            </td></tr>
                                        )}
                                    </Fragment>
                                ))}
                                {orders.length > 0 && filteredOrders.length === 0 && <tr><td colSpan={7} className="empty-state">{t('noMatchingResults')}</td></tr>}
                                {orders.length === 0 && !loading && <tr><td colSpan={7} className="empty-state">{t('noOrders')}</td></tr>}
                            </tbody>
                        </table>
                    </div>
                    <div className="pagination">
                        <button className="button button-quiet" disabled={safeOrdersPage <= 1 || loading} onClick={() => setOrdersPage(safeOrdersPage - 1)}>{t('previous')}</button>
                        <span>{t('page')} {safeOrdersPage} / {orderPageCount}</span>
                        <button className="button button-quiet" disabled={safeOrdersPage >= orderPageCount || loading} onClick={() => setOrdersPage(safeOrdersPage + 1)}>{t('next')}</button>
                    </div>
                </section>
            )}
            {pathname === '/promotions' && (
                    <section className="card panel">
                        <div className="section-heading">
                            <h2>{t('promotions')}</h2>
                            <div className="toolbar">
                                <label>{t('status')}<select value={promotionActivity} onChange={(event) => setPromotionActivity(event.target.value)}>
                                    <option value="">{t('allActivity')}</option><option value="active">{t('activeOnly')}</option><option value="inactive">{t('inactiveOnly')}</option>
                                </select></label>
                                <label className="search-field">{t('searchCurrentPage')}<input type="search" value={search} onChange={(event) => setSearch(event.target.value)} /></label>
                            </div>
                        </div>
                        <form className="promotion-form" onSubmit={createPromotion}>
                            <label>{t('code')}<input required maxLength={64} value={code} onChange={(event) => setCode(event.target.value.toUpperCase())} /></label>
                            <label>{t('discountType')}<select value={discountType} onChange={(event) => setDiscountType(event.target.value as 'percentage' | 'fixed')}>
                                <option value="percentage">{t('percentage')}</option><option value="fixed">{t('fixedSar')}</option>
                            </select></label>
                            <label>{t('value')}<input type="number" min="0.01" max={discountType === 'percentage' ? 100 : undefined} step="0.01" required value={discountValue} onChange={(event) => setDiscountValue(event.target.value)} /></label>
                            <button disabled={loading}>{t('createPromotion')}</button>
                        </form>
                        {promotions.length === 0 ? <p className="empty-state">{t('noPromotions')}</p> : (
                            <div className="table-wrap">
                                <table>
                                    <thead><tr><th>{t('code')}</th><th>{t('discount')}</th><th>{t('redemptions')}</th><th>{t('status')}</th><th /></tr></thead>
                                    <tbody>{filteredPromotions.map((promotion) => (
                                        <tr key={promotion.id}>
                                            <td>{promotion.code}</td>
                                            <td>{promotion.discount_type === 'percentage' ? `${promotion.discount_value}%` : format('discountSar', { value: promotion.discount_value })}</td>
                                            <td>{promotion.redemption_count}</td>
                                            <td>{promotion.is_active ? t('active') : t('inactive')}</td>
                                            <td><button className="secondary" onClick={() => void togglePromotion(promotion)}>{promotion.is_active ? t('disable') : t('enable')}</button></td>
                                        </tr>
                                    ))}
                                    {promotions.length > 0 && filteredPromotions.length === 0 && <tr><td colSpan={5} className="empty-state">{t('noMatchingResults')}</td></tr>}
                                    </tbody>
                                </table>
                            </div>
                        )}
                    </section>
            )}
            {pathname === '/inventory' && (
                    <section className="card panel">
                        <h2>{t('inventory')}</h2>
                        <p>{t('inventoryDescription')}</p>
                        <div className="toolbar">
                            <label>{t('filterByStatus')}<select value={deliveryStatus} onChange={(event) => setDeliveryStatus(event.target.value)}>
                                <option value="">{t('allStatuses')}</option>
                                {['pending_dispatch', 'assigned', 'picked_up', 'delivered', 'failed', 'cancelled'].map((status) => <option key={status} value={status}>{translateStatus(language, status)}</option>)}
                            </select></label>
                            <label className="search-field">{t('searchCurrentPage')}<input type="search" value={search} onChange={(event) => setSearch(event.target.value)} /></label>
                        </div>
                        <div className="table-wrap">
                            <table>
                                <thead><tr><th>{t('product')}</th><th>{t('stock')}</th><th>{t('availability')}</th><th>{t('adjustment')}</th></tr></thead>
                                <tbody>{filteredInventory.map((item) => (
                                    <tr key={item.id}>
                                        <td>{displayName(
                                            products.find((product) => product.id === item.id)?.name ?? item.name,
                                            products.find((product) => product.id === item.id)?.name_ar,
                                        )}</td>
                                        <td>{item.quantity}</td>
                                        <td><span className={`status-pill status-${item.availability}`}>{translateStatus(language, item.availability)}</span></td>
                                        <td>
                                            <button className="secondary" aria-label={format('removeOne', { product: item.name })} disabled={loading || item.quantity <= 0} onClick={() => void adjustInventory(item, -1)}>−</button>{' '}
                                            <button aria-label={format('addOne', { product: item.name })} onClick={() => void adjustInventory(item, 1)}>+</button>
                                        </td>
                                    </tr>
                                ))}
                                {inventory.length === 0 && !loading && <tr><td colSpan={4} className="empty-state">{t('noInventory')}</td></tr>}
                                {inventory.length > 0 && filteredInventory.length === 0 && <tr><td colSpan={4} className="empty-state">{t('noMatchingResults')}</td></tr>}
                                </tbody>
                            </table>
                        </div>
                    </section>
            )}
            {pathname === '/deliveries' && (
                    <section className="card panel">
                        <h2>{t('deliveryOperations')}</h2>
                        <p>{t('manualDeliveryDescription')}</p>
                        <label className="search-field">{t('searchPlaceholder')}<input type="search" value={search} onChange={(event) => setSearch(event.target.value)} /></label>
                        <div className="table-wrap">
                            <table>
                                <thead><tr><th>{t('order')}</th><th>{t('status')}</th><th>{t('zoneEstimate')}</th><th>{t('action')}</th></tr></thead>
                                <tbody>{filteredDeliveries.map((delivery) => {
                                    const nextStatus = delivery.status === 'pending_dispatch'
                                        ? 'assigned'
                                        : delivery.status === 'assigned'
                                            ? 'picked_up'
                                            : delivery.status === 'picked_up' ? 'delivered' : null;
                                    return (
                                        <tr key={delivery.id}>
                                            <td title={delivery.order_id}>{delivery.order_id.slice(0, 8)}</td>
                                            <td><span className={`status-pill status-${delivery.status}`}>{translateStatus(language, delivery.status)}</span></td>
                                            <td>{format('minutes', { count: delivery.estimated_minutes })}</td>
                                            <td>
                                                {nextStatus && (
                                                    <button disabled={loading} onClick={() => void updateDelivery(delivery, nextStatus)}>
                                                        {format('markStatus', { status: translateStatus(language, nextStatus) })}
                                                    </button>
                                                )}
                                                {(delivery.status === 'assigned' || delivery.status === 'picked_up') && (
                                                    <button className="secondary" disabled={loading} onClick={() => void updateDelivery(delivery, 'failed')}>
                                                        {t('markDeliveryFailed')}
                                                    </button>
                                                )}
                                                {!nextStatus && delivery.status !== 'assigned' && delivery.status !== 'picked_up' && t('noAction')}
                                            </td>
                                        </tr>
                                    );
                                })}
                                {deliveries.length > 0 && filteredDeliveries.length === 0 && <tr><td colSpan={4} className="empty-state">{t('noMatchingResults')}</td></tr>}
                                {deliveries.length === 0 && !loading && <tr><td colSpan={4} className="empty-state">{t('noDeliveries')}</td></tr>}
                                </tbody>
                            </table>
                        </div>
                    </section>
            )}
            {pathname === '/reviews' && (
                    <section className="card panel">
                        <h2>{t('reviewsAwaitingModeration')}</h2>
                        <label className="search-field">{t('searchPlaceholder')}<input type="search" value={search} onChange={(event) => setSearch(event.target.value)} /></label>
                        {reviews.length === 0 ? <p>{t('noReviews')}</p> : (
                            <div className="table-wrap">
                                <table>
                                    <thead><tr><th>{t('product')}</th><th>{t('customerId')}</th><th>{t('relatedOrder')}</th><th>{t('rating')}</th><th>{t('comment')}</th><th>{t('status')}</th><th>{t('action')}</th></tr></thead>
                                    <tbody>{filteredReviews.map((review) => (
                                        <tr key={review.id}>
                                            <td>{displayName(review.product_name, review.product_name_ar)}</td>
                                            <td title={review.customer_id}>{review.customer_id.slice(0, 8)}</td>
                                            <td title={review.order_id}>{review.order_id.slice(0, 8)}</td>
                                            <td>{review.rating} / 5</td>
                                            <td>{review.comment || '—'}</td>
                                            <td><span className="status-pill">{t('reviewPending')}</span></td>
                                            <td>
                                                <button onClick={() => void moderateReview(review, 'approved')}>{t('approve')}</button>{' '}
                                                <button className="secondary" onClick={() => void moderateReview(review, 'rejected')}>{t('reject')}</button>
                                            </td>
                                        </tr>
                                    ))}
                                    {reviews.length > 0 && filteredReviews.length === 0 && <tr><td colSpan={7} className="empty-state">{t('noMatchingResults')}</td></tr>}
                                    </tbody>
                                </table>
                            </div>
                        )}
                    </section>
            )}
            {(pathname === '/products' || pathname === '/categories' || pathname === '/brands' || pathname === '/catalog-terms') && (
                    <section className="card panel">
                        {pathname === '/products' && (
                        <>
                            <header className="products-page-heading">
                                <div>
                                    <h2>{t('productsManagement')}</h2>
                                    <p>{t('productsPageDescription')}</p>
                                    <span className="product-count">{format('productsLoaded', { count: products.length })}</span>
                                </div>
                                <button onClick={() => openProductDialog('create')} disabled={loading || !categories.length || !brands.length}>
                                    <span aria-hidden="true">＋</span>{t('addProduct')}
                                </button>
                            </header>
                            {(!categories.length || !brands.length) && <p className="api-limitation products-api-note">{t('catalogTermsRequired')}</p>}
                            <div className="product-toolbar">
                                <label className="product-search">{t('searchProducts')}
                                    <input type="search" value={search} onChange={(event) => {
                                        setSearch(event.target.value);
                                        setProductsPage(1);
                                    }} />
                                </label>
                                <label>{t('status')}
                                    <select value={productActivity} onChange={(event) => {
                                        setProductActivity(event.target.value);
                                        setProductsPage(1);
                                    }}>
                                        <option value="">{t('allActivity')}</option><option value="active">{t('activeOnly')}</option><option value="inactive">{t('inactiveOnly')}</option>
                                    </select>
                                </label>
                                <label>{t('category')}<select value={productCategory} onChange={(event) => {
                                    setProductCategory(event.target.value);
                                    setProductsPage(1);
                                }}>
                                    <option value="">{t('allCategories')}</option>
                                    {categories.map((category) => <option key={category.id} value={category.id}>{displayName(category.name, category.name_ar)}</option>)}
                                </select></label>
                                <label>{t('brand')}<select value={productBrand} onChange={(event) => {
                                    setProductBrand(event.target.value);
                                    setProductsPage(1);
                                }}>
                                    <option value="">{t('allBrands')}</option>
                                    {brands.map((brand) => <option key={brand.id} value={brand.id}>{displayName(brand.name, brand.name_ar)}</option>)}
                                </select></label>
                                <label>{t('sortBy')}<select value={productSort} onChange={(event) => {
                                    setProductSort(event.target.value);
                                    setProductsPage(1);
                                }}>
                                    <option value="name">{t('sortName')}</option>
                                    <option value="price-asc">{t('sortPriceLow')}</option>
                                    <option value="price-desc">{t('sortPriceHigh')}</option>
                                    <option value="stock-asc">{t('sortStockLow')}</option>
                                    <option value="stock-desc">{t('sortStockHigh')}</option>
                                </select></label>
                                <label>{t('pageSize')}<select value={productPageSize} onChange={(event) => {
                                    setProductPageSize(Number(event.target.value));
                                    setProductsPage(1);
                                }}>
                                    <option value={20}>20</option><option value={50}>50</option><option value={100}>100</option>
                                </select></label>
                                <button className="button button-quiet" onClick={() => {
                                    setSearch('');
                                    setProductActivity('');
                                    setProductCategory('');
                                    setProductBrand('');
                                    setProductSort('name');
                                    setProductsPage(1);
                                }} disabled={!search && !productActivity && !productCategory && !productBrand && productSort === 'name'}>
                                    {t('clearFilters')}
                                </button>
                            </div>
                            <p className="api-limitation products-api-note">{t('productsApiLimit')}</p>
                        </>
                        )}
                        {pathname !== '/products' && (
                            <div className="section-heading"><h2>{pageTitle}</h2>
                                <label className="search-field">{t('searchCurrentPage')}<input type="search" value={search} onChange={(event) => setSearch(event.target.value)} /></label>
                            </div>
                        )}
                        {(pathname !== '/products') && <div className="catalog-management-grid">
                            {(['categories', 'brands'] as const).filter((type) => pathname === '/catalog-terms' || pathname === `/${type}`).map((type) => {
                                const isCategory = type === 'categories';
                                const terms = (isCategory ? categories : brands).filter((term) =>
                                    `${term.name} ${term.name_ar ?? ''} ${term.slug}`.toLowerCase().includes(searchTerm));
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
                                                })}
                                                {terms.length === 0 && <tr><td colSpan={6} className="empty-state">{searchTerm ? t('noMatchingResults') : t('noTerms')}</td></tr>}
                                                </tbody>
                                            </table>
                                        </div>
                                    </div>
                                );
                            })}
                        </div>}
                        {pathname === '/products' && (
                        <>
                        <div className="table-wrap">
                            <table className="products-table">
                                <thead><tr><th>{t('product')}</th><th>{t('slug')}</th><th>{t('category')}</th><th>{t('brand')}</th><th>{t('priceSar')}</th><th>{t('stock')}</th><th>{t('status')}</th><th>{t('actions')}</th></tr></thead>
                                <tbody>{visibleProducts.map((product) => (
                                    <tr key={product.id}>
                                        <td><span className="product-primary-name" dir="auto">{displayName(product.name, product.name_ar)}</span>
                                            {language === 'ar' && product.name_ar && <span className="product-secondary-name" dir="auto">{product.name}</span>}
                                        </td>
                                        <td><span className="product-identifier" dir="ltr">{product.slug}</span></td>
                                        <td dir="auto">{displayName(product.category_name, product.category_name_ar)}</td>
                                        <td dir="auto">{displayName(product.brand_name, brands.find((brandItem) => brandItem.id === product.brand_id)?.name_ar)}</td>
                                        <td><span className="numeric-value">{product.price.toFixed(2)}</span> <span className="currency-label">SAR</span></td>
                                        <td><span className="numeric-value">{product.quantity}</span></td>
                                        <td><span className={`status-pill ${product.is_active ? 'status-active' : 'status-inactive'}`}>{product.is_active ? t('active') : t('inactive')}</span></td>
                                        <td><div className="product-actions">
                                            <button className="button button-quiet" onClick={() => openProductDialog('edit', product)} disabled={loading}>{t('edit')}</button>
                                            <button className="button button-quiet" onClick={() => void updateProduct(product, { isActive: !product.is_active })} disabled={loading}>
                                                {product.is_active ? t('deactivate') : t('activate')}
                                            </button>
                                        </div></td>
                                    </tr>
                                ))}
                                {products.length === 0 && loading && <tr><td colSpan={8} className="empty-state">{t('loadingProducts')}</td></tr>}
                                {products.length === 0 && !loading && error && <tr><td colSpan={8} className="empty-state">{t('productsLoadFailed')}</td></tr>}
                                {products.length === 0 && !loading && !error && <tr><td colSpan={8} className="empty-state">{t('noProducts')}</td></tr>}
                                {products.length > 0 && filteredProducts.length === 0 && <tr><td colSpan={8} className="empty-state">{t('noMatchingResults')}</td></tr>}
                                </tbody>
                            </table>
                        </div>
                        {filteredProducts.length > productPageSize && (
                            <div className="pagination">
                                <button className="button button-quiet" disabled={safeProductsPage <= 1} onClick={() => setProductsPage(safeProductsPage - 1)}>{t('previous')}</button>
                                <span>{format('pagination', {
                                    start: (safeProductsPage - 1) * productPageSize + 1,
                                    end: Math.min(safeProductsPage * productPageSize, filteredProducts.length),
                                    total: filteredProducts.length,
                                })}</span>
                                <button className="button button-quiet" disabled={safeProductsPage >= productPageCount} onClick={() => setProductsPage(safeProductsPage + 1)}>{t('next')}</button>
                            </div>
                        )}
                        </>
                        )}
                        {pathname === '/products' && productDialog && (
                            <div className="product-modal-backdrop">
                                <section className="product-modal" role="dialog" aria-modal="true" aria-labelledby="product-dialog-title" onKeyDown={(event) => {
                                    if (event.key === 'Escape') closeProductDialog();
                                }}>
                                    <header className="product-modal-header">
                                        <div>
                                            <h2 id="product-dialog-title">{t(productDialog === 'create' ? 'addProduct' : 'editProduct')}</h2>
                                            <p>{t('productFormDescription')}</p>
                                        </div>
                                        <button className="icon-button modal-close" type="button" aria-label={t('close')} onClick={closeProductDialog} disabled={loading}>×</button>
                                    </header>
                                    {error && <p className="error-banner product-form-error" role="alert">{error}</p>}
                                    <form className="product-form" onChange={() => { if (error) setError(''); }} onSubmit={(event) => void saveProduct(event)}>
                                        <fieldset className="product-form-fields" disabled={loading}>
                                        <div className="product-form-section">
                                            <h3>{t('productDetails')}</h3>
                                            <div className="product-form-grid">
                                                <label><span className="field-label">{t('productName')} <span className="field-required">{t('required')}</span></span>
                                                    <input autoFocus required maxLength={200} value={productForm.name} onChange={(event) => setProductForm({ ...productForm, name: event.target.value })} />
                                                </label>
                                                <label><span className="field-label">{t('arabicName')} <span className="field-optional">{t('optional')}</span></span>
                                                    <input maxLength={200} value={productForm.nameAr} onChange={(event) => setProductForm({ ...productForm, nameAr: event.target.value })} />
                                                </label>
                                                <label><span className="field-label">{t('slug')} <span className="field-required">{t('required')}</span></span>
                                                    <input required pattern="[a-z0-9]+(?:-[a-z0-9]+)*" maxLength={200} dir="ltr" value={productForm.slug} onChange={(event) => setProductForm({ ...productForm, slug: event.target.value.toLowerCase() })} />
                                                </label>
                                                <label><span className="field-label">{t('priceSar')} <span className="field-required">{t('required')}</span></span>
                                                    <input type="number" min="0.01" max="1000000" step="0.01" required value={productForm.price} onChange={(event) => setProductForm({ ...productForm, price: event.target.value })} />
                                                </label>
                                            </div>
                                        </div>
                                        <div className="product-form-section">
                                            <h3>{t('classification')}</h3>
                                            <div className="product-form-grid">
                                                <label><span className="field-label">{t('category')} <span className="field-required">{t('required')}</span></span>
                                                    <select required value={productForm.categoryId} onChange={(event) => setProductForm({ ...productForm, categoryId: event.target.value })}>
                                                        <option value="">{t('selectCategory')}</option>
                                                        {categories.map((item) => <option key={item.id} value={item.id}>{displayName(item.name, item.name_ar)}</option>)}
                                                    </select>
                                                </label>
                                                <label><span className="field-label">{t('brand')} <span className="field-required">{t('required')}</span></span>
                                                    <select required value={productForm.brandId} onChange={(event) => setProductForm({ ...productForm, brandId: event.target.value })}>
                                                        <option value="">{t('selectBrand')}</option>
                                                        {brands.map((item) => <option key={item.id} value={item.id}>{displayName(item.name, item.name_ar)}</option>)}
                                                    </select>
                                                </label>
                                                {productDialog === 'create' && <>
                                                    <label><span className="field-label">{t('stock')} <span className="field-required">{t('required')}</span></span>
                                                        <input type="number" min="0" max="1000000" step="1" required value={productForm.quantity} onChange={(event) => setProductForm({ ...productForm, quantity: event.target.value })} />
                                                    </label>
                                                    <label><span className="field-label">{t('packageSize')} <span className="field-optional">{t('optional')}</span></span>
                                                        <input maxLength={80} value={productForm.packageSize} onChange={(event) => setProductForm({ ...productForm, packageSize: event.target.value })} />
                                                    </label>
                                                </>}
                                            </div>
                                            {productDialog === 'edit' && <p className="form-note">{t('productQuantityEditNote')}</p>}
                                        </div>
                                        <div className="product-form-section">
                                            <h3>{t('descriptions')}</h3>
                                            <div className="product-form-grid">
                                                <label><span className="field-label">{t('description')} <span className="field-optional">{t('optional')}</span></span>
                                                    <textarea maxLength={10000} rows={3} value={productForm.description} onChange={(event) => setProductForm({ ...productForm, description: event.target.value })} />
                                                </label>
                                                <label><span className="field-label">{t('arabicDescription')} <span className="field-optional">{t('optional')}</span></span>
                                                    <textarea maxLength={10000} rows={3} value={productForm.descriptionAr} onChange={(event) => setProductForm({ ...productForm, descriptionAr: event.target.value })} />
                                                </label>
                                            </div>
                                            {productDialog === 'create' && <p className="form-note">{t('mediaNotConfigured')}</p>}
                                        </div>
                                        </fieldset>
                                        <footer className="product-form-actions">
                                            <button className="secondary" type="button" onClick={closeProductDialog} disabled={loading}>{t('cancel')}</button>
                                            <button type="submit" disabled={loading || (productDialog === 'edit' && !productFormChanged)}>
                                                {loading ? t('saving') : t('save')}
                                            </button>
                                        </footer>
                                    </form>
                                </section>
                            </div>
                        )}
                    </section>
            )}
            {!isAdminPath(pathname) && (
                <section className="card panel not-found">
                    <span className="not-found-code">404</span>
                    <h2>{t('pageNotFound')}</h2>
                    <p>{t('notFoundDescription')}</p>
                    <button onClick={() => navigate('/')}>{t('backToDashboard')}</button>
                </section>
            )}
        </AdminLayout>
    );
}

function Metric({ label, value }: { label: string; value: string | number }) {
    return <article className="card metric"><span>{label}</span><strong>{value}</strong></article>;
}

export default App;
