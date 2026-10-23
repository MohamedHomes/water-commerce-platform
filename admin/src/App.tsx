import { FormEvent, useCallback, useEffect, useState } from 'react';

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
            setError(requestError instanceof Error ? requestError.message : 'Unable to load operations data');
        } finally {
            setLoading(false);
        }
    }, []);

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
            if (payload.customer.role !== 'admin') throw new Error('This account is not authorized for administration');
            setToken(payload.accessToken);
            setPassword('');
        } catch (requestError) {
            setError(requestError instanceof Error ? requestError.message : 'Sign in failed');
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
            setError(requestError instanceof Error ? requestError.message : 'Promotion could not be saved');
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
            setError(requestError instanceof Error ? requestError.message : 'Promotion could not be updated');
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
            setError(requestError instanceof Error ? requestError.message : 'Inventory could not be adjusted');
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
            setError(requestError instanceof Error ? requestError.message : 'Delivery status could not be updated');
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
            setError(requestError instanceof Error ? requestError.message : 'Review moderation failed');
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
            setError(requestError instanceof Error ? requestError.message : 'Product could not be updated');
        }
    }

    if (!token) {
        return (
            <main className="app-shell auth-shell">
                <header className="topbar">
                    <div>
                        <p className="eyebrow">Operations dashboard</p>
                        <h1>AquaFlow Admin</h1>
                    </div>
                </header>
                <form className="card login-form" onSubmit={login}>
                    <h2>Administrator sign in</h2>
                    <label>Email<input type="email" autoComplete="username" required value={email} onChange={(event) => setEmail(event.target.value)} /></label>
                    <label>Password<input type="password" autoComplete="current-password" required value={password} onChange={(event) => setPassword(event.target.value)} /></label>
                    {error && <p className="error" role="alert">{error}</p>}
                    <button disabled={loading}>{loading ? 'Signing in…' : 'Sign in'}</button>
                </form>
            </main>
        );
    }

    return (
        <main className="app-shell">
            <header className="topbar">
                <div>
                    <p className="eyebrow">Operations dashboard</p>
                    <h1>AquaFlow Admin</h1>
                </div>
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
                }}>Sign out</button>
            </header>
            {error && <p className="error" role="alert">{error}</p>}
            {loading && <p role="status">Refreshing operations data…</p>}
            {dashboard && (
                <>
                    <section className="grid" aria-label="Operations metrics">
                        <Metric label="All orders" value={dashboard.totalOrders} />
                        <Metric label="Open orders" value={dashboard.openOrders} />
                        <Metric label="Awaiting payment" value={dashboard.awaitingPayment} />
                        <Metric label="Paid revenue" value={`${dashboard.currency} ${dashboard.paidRevenue.toFixed(2)}`} />
                        <Metric label="Pending dispatch" value={dashboard.pendingDispatch} />
                        <Metric label="Active products" value={dashboard.activeProducts} />
                    </section>
                    <section className="card panel">
                        <h2>Recent orders</h2>
                        {orders.length === 0 ? <p>No orders yet.</p> : (
                            <div className="table-wrap">
                                <table>
                                    <thead><tr><th>Order</th><th>Status</th><th>Payment</th><th>Total</th><th>Created</th></tr></thead>
                                    <tbody>{orders.map((order) => (
                                        <tr key={order.id}>
                                            <td>{order.id.slice(0, 8)}</td>
                                            <td>{order.status}</td>
                                            <td>{order.paymentMethod}</td>
                                            <td>{order.currency} {order.total.toFixed(2)}</td>
                                            <td>{new Date(order.createdAt).toLocaleString()}</td>
                                        </tr>
                                    ))}</tbody>
                                </table>
                            </div>
                        )}
                    </section>
                    <section className="card panel">
                        <h2>Promotions</h2>
                        <form className="promotion-form" onSubmit={createPromotion}>
                            <label>Code<input required maxLength={64} value={code} onChange={(event) => setCode(event.target.value.toUpperCase())} /></label>
                            <label>Discount type<select value={discountType} onChange={(event) => setDiscountType(event.target.value as 'percentage' | 'fixed')}>
                                <option value="percentage">Percentage</option><option value="fixed">Fixed SAR</option>
                            </select></label>
                            <label>Value<input type="number" min="0.01" max={discountType === 'percentage' ? 100 : undefined} step="0.01" required value={discountValue} onChange={(event) => setDiscountValue(event.target.value)} /></label>
                            <button disabled={loading}>Create promotion</button>
                        </form>
                        {promotions.length === 0 ? <p>No promotions configured.</p> : (
                            <div className="table-wrap">
                                <table>
                                    <thead><tr><th>Code</th><th>Discount</th><th>Redemptions</th><th>Status</th><th /></tr></thead>
                                    <tbody>{promotions.map((promotion) => (
                                        <tr key={promotion.id}>
                                            <td>{promotion.code}</td>
                                            <td>{promotion.discount_value}{promotion.discount_type === 'percentage' ? '%' : ' SAR'}</td>
                                            <td>{promotion.redemption_count}</td>
                                            <td>{promotion.is_active ? 'Active' : 'Inactive'}</td>
                                            <td><button className="secondary" onClick={() => void togglePromotion(promotion)}>{promotion.is_active ? 'Disable' : 'Enable'}</button></td>
                                        </tr>
                                    ))}</tbody>
                                </table>
                            </div>
                        )}
                    </section>
                    <section className="card panel">
                        <h2>Inventory</h2>
                        <p>Product-level stock pool; adjustments are recorded in the audit ledger.</p>
                        <div className="table-wrap">
                            <table>
                                <thead><tr><th>Product</th><th>Stock</th><th>Availability</th><th>Adjustment</th></tr></thead>
                                <tbody>{inventory.map((item) => (
                                    <tr key={item.id}>
                                        <td>{item.name}</td>
                                        <td>{item.quantity}</td>
                                        <td>{item.availability}</td>
                                        <td>
                                            <button className="secondary" aria-label={`Remove one ${item.name}`} onClick={() => void adjustInventory(item, -1)}>−</button>{' '}
                                            <button aria-label={`Add one ${item.name}`} onClick={() => void adjustInventory(item, 1)}>+</button>
                                        </td>
                                    </tr>
                                ))}</tbody>
                            </table>
                        </div>
                    </section>
                    <section className="card panel">
                        <h2>Delivery operations</h2>
                        <p>Manual status updates only. No driver assignment or live location feed is connected.</p>
                        <div className="table-wrap">
                            <table>
                                <thead><tr><th>Order</th><th>Status</th><th>Zone estimate</th><th>Action</th></tr></thead>
                                <tbody>{deliveries.map((delivery) => {
                                    const nextStatus = delivery.status === 'pending_dispatch'
                                        ? 'assigned'
                                        : delivery.status === 'assigned'
                                            ? 'picked_up'
                                            : delivery.status === 'picked_up' ? 'delivered' : null;
                                    return (
                                        <tr key={delivery.id}>
                                            <td>{delivery.order_id.slice(0, 8)}</td>
                                            <td>{delivery.status}</td>
                                            <td>{delivery.estimated_minutes} min</td>
                                            <td>{nextStatus
                                                ? <button onClick={() => void updateDelivery(delivery, nextStatus)}>Mark {nextStatus.replace('_', ' ')}</button>
                                                : 'No action available'}</td>
                                        </tr>
                                    );
                                })}</tbody>
                            </table>
                        </div>
                    </section>
                    <section className="card panel">
                        <h2>Reviews awaiting moderation</h2>
                        {reviews.length === 0 ? <p>No reviews require moderation.</p> : (
                            <div className="table-wrap">
                                <table>
                                    <thead><tr><th>Product</th><th>Rating</th><th>Comment</th><th>Action</th></tr></thead>
                                    <tbody>{reviews.map((review) => (
                                        <tr key={review.id}>
                                            <td>{review.product_name}</td>
                                            <td>{review.rating} / 5</td>
                                            <td>{review.comment || '—'}</td>
                                            <td>
                                                <button onClick={() => void moderateReview(review, 'approved')}>Approve</button>{' '}
                                                <button className="secondary" onClick={() => void moderateReview(review, 'rejected')}>Reject</button>
                                            </td>
                                        </tr>
                                    ))}</tbody>
                                </table>
                            </div>
                        )}
                    </section>
                    <section className="card panel">
                        <h2>Catalog operations</h2>
                        <div className="table-wrap">
                            <table>
                                <thead><tr><th>Product</th><th>Category</th><th>Stock</th><th>Price (SAR)</th><th>Status</th></tr></thead>
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
                                                    aria-label={`Price for ${product.name}`}
                                                    type="number"
                                                    min="0.01"
                                                    step="0.01"
                                                    value={priceEdits[product.id] ?? product.price}
                                                    onChange={(event) => setPriceEdits({
                                                        ...priceEdits,
                                                        [product.id]: event.target.value,
                                                    })}
                                                />
                                                <button className="secondary">Save</button>
                                            </form>
                                        </td>
                                        <td>
                                            <button className={product.is_active ? 'secondary' : ''} onClick={() => void updateProduct(product, { isActive: !product.is_active })}>
                                                {product.is_active ? 'Active' : 'Inactive'}
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
