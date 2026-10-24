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
    customer_id: string;
    order_id: string;
    rating: number;
    comment: string;
}

interface CatalogProduct {
    id: string;
    name: string;
    price: number;
    quantity: number;
    availability: string;
    is_active: boolean;
    category_name: string;
    brand_name: string;
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
            const [metrics, orderList, promotionList, inventoryList, deliveryList, reviewList, productList] = await Promise.all([
                apiRequest<Dashboard>('/admin/dashboard', accessToken),
                apiRequest<{ items: AdminOrder[] }>('/admin/orders?limit=10', accessToken),
                apiRequest<{ items: Promotion[] }>('/admin/promotions', accessToken),
                apiRequest<{ items: InventoryItem[] }>('/admin/inventory', accessToken),
                apiRequest<{ items: DeliveryItem[] }>('/admin/deliveries', accessToken),
                apiRequest<{ items: ProductReview[] }>('/admin/reviews', accessToken),
                apiRequest<{ items: CatalogProduct[] }>('/admin/products', accessToken),
            ]);
            setDashboard(metrics);
            setOrders(orderList.items);
            setPromotions(promotionList.items);
            setInventory(inventoryList.items);
            setDeliveries(deliveryList.items);
            setReviews(reviewList.items);
            setProducts(productList.items);
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
                                        <td>{item.name}</td>
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
                                            <td>{review.product_name}</td>
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
                        <div className="table-wrap">
                            <table>
                                <thead><tr><th>{t('product')}</th><th>{t('category')}</th><th>{t('stock')}</th><th>{t('priceSar')}</th><th>{t('status')}</th></tr></thead>
                                <tbody>{products.map((product) => (
                                    <tr key={product.id}>
                                        <td>{product.name}</td>
                                        <td>{product.category_name}</td>
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
                                                    aria-label={format('priceFor', { product: product.name })}
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
