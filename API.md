# API Contract Foundation

## Base Path

`/api/v1`

## Core endpoints

- `POST /api/v1/auth/login`
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/refresh`
- `GET /api/v1/products`
- `GET /api/v1/catalog/products/:productId/reviews`
- `POST /api/v1/catalog/products/:productId/reviews`
- `GET /api/v1/catalog/categories`
- `GET /api/v1/catalog/brands`
- `GET /api/v1/catalog/products`
- `GET /api/v1/categories`
- `GET /api/v1/brands`
- `GET /api/v1/cart`
- `POST /api/v1/cart/items`
- `PATCH /api/v1/cart/items/:productId`
- `DELETE /api/v1/cart/items/:productId`
- `DELETE /api/v1/cart`
- `POST /api/v1/cart/validate`
- `POST /api/v1/checkout/prepare`
- `GET /api/v1/checkout/:checkoutId`
- `POST /api/v1/orders`
- `GET /api/v1/orders`
- `GET /api/v1/orders/:id`
- `POST /api/v1/orders/:id/cancel`
- `POST /api/v1/orders/:id/reorder`
- `GET /api/v1/addresses`
- `POST /api/v1/addresses`
- `PATCH /api/v1/addresses/:id`
- `DELETE /api/v1/addresses/:id`
- `POST /api/v1/payments/intents`
- `GET /api/v1/payments/orders/:orderId`
- `POST /api/v1/payments/webhook`
- `GET /api/v1/deliveries/orders/:orderId`
- `GET /api/v1/notifications`
- `PATCH /api/v1/notifications/:id/read`
- `GET /api/v1/admin/dashboard`
- `GET /api/v1/admin/orders`
- `GET /api/v1/admin/promotions`
- `POST /api/v1/admin/promotions`
- `PATCH /api/v1/admin/promotions/:id/active`
- `GET /api/v1/admin/inventory`
- `POST /api/v1/admin/inventory/:productId/adjustments`
- `GET /api/v1/admin/deliveries`
- `PATCH /api/v1/admin/deliveries/:id/status`
- `GET /api/v1/admin/reviews`
- `PATCH /api/v1/admin/reviews/:id/status`
- `GET /api/v1/admin/products`
- `GET /api/v1/admin/catalog-terms`
- `POST /api/v1/admin/categories`
- `PATCH /api/v1/admin/categories/:id`
- `POST /api/v1/admin/brands`
- `PATCH /api/v1/admin/brands/:id`
- `POST /api/v1/admin/products`
- `PATCH /api/v1/admin/products/:id`
- `GET /health`
- `GET /health/live`
- `GET /health/ready`

### Orders

- `POST /api/v1/orders` accepts `{ "checkoutId": "<checkout UUID>" }`. The
  backend verifies the customer's unexpired checkout, current cart, prices,
  product availability, and address before creating an immutable order
  snapshot. Repeating the request for the same checkout returns the existing
  order.
- `POST /api/v1/checkout/prepare` optionally accepts `promotionCode`. Codes are
  normalized case-insensitively and validated against active promotion dates,
  minimum subtotal, and redemption limits. The backend calculates the discount;
  the client cannot submit a discount amount. A single promotion may apply to a
  checkout, and the discounted subtotal is used to calculate any service fee.
  Redemptions are committed atomically with order creation. Promotion
  availability is checked again when the order is placed.
- Card orders are recorded as `payment_pending`; this endpoint does not capture
  payment. Cash orders are recorded as `placed`.
- Each successfully placed order reserves product-level stock in the same
  transaction; an eligible cancellation releases that reservation.
- `GET /api/v1/orders` supports `page` and `limit` query parameters (1-based,
  with a maximum limit of 100). Order and checkout resources are customer
  isolated.
- Cancellation is available while an order is `placed` or `payment_pending`.
  Reorder adds the saved product quantities to the active cart using current
  product prices and stock validation.

### Payments

- `POST /api/v1/payments/intents` requires customer authentication and accepts
  `{ "orderId": "<order UUID>", "idempotencyKey": "<unique key>" }`. The order
  must belong to the customer, be a card order, and be awaiting payment.
  Repeating the same key for that order returns the same persisted intent;
  reusing it for a different order is rejected.
- `GET /api/v1/payments/orders/:orderId` returns only the authenticated
  customer's payment attempts for that order.
- `POST /api/v1/payments/webhook` is unauthenticated at the application layer
  and requires `x-payment-signature`, an HMAC-SHA256 hex digest over the exact
  raw request body. Provider adapters must verify the signature and return a
  validated event with the payment ID, event ID, amount, currency, and success
  or failure type. Replayed events are harmless; reusing an event ID with a
  different payload is rejected.
- A verified success transitions the intent to `succeeded` and the order to
  `paid`; a verified failure marks only that attempt failed and allows another
  idempotency key. Webhook processing never accepts client-supplied card data.
- The runtime has no configured payment processor. Outside automated tests,
  intent creation and webhook processing return service unavailable. The
  deterministic test adapter is enabled only when `NODE_ENV=test`; its intents
  do not collect money or provide a checkout URL.

### Delivery tracking

- `GET /api/v1/deliveries/orders/:orderId` returns a customer-owned delivery
  record and its status event timeline for cash orders and paid card orders.
- Delivery records begin in `pending_dispatch`; cancellation before dispatch
  records a cancelled event. The platform has no driver dispatch provider,
  assignment operations, or live location feed configured. `trackingAvailable`
  is therefore `false`; an estimate is a zone-level estimate, not an ETA from
  an assigned driver.

### Notifications

- `GET /api/v1/notifications?limit=50` returns the authenticated customer's
  newest in-app notifications (limit 1–100).
- `PATCH /api/v1/notifications/:id/read` marks a notification read
  idempotently. Customers cannot read or modify another customer's
  notifications.
- Order placement/cancellation and verified payment success/failure create
  persistent in-app updates. Email, SMS, and push delivery are not configured.

### Admin operations

- Admin endpoints require a valid access token and a customer account whose
  current database role is `admin`. The role is checked from PostgreSQL on each
  request; public registration always creates a customer.
- `GET /api/v1/admin/dashboard` returns current order, payment, dispatch, and
  active-product counts and paid revenue.
- `GET /api/v1/admin/orders` supports optional `status`, `page`, and `limit`
  filters and returns a paginated operations queue.
- Admins can create and activate/deactivate promotion codes. Privileged
  promotion changes are recorded in the audit log.
- `GET /api/v1/admin/inventory` lists the current product-level stock pool.
  Inventory adjustments accept a non-zero integer delta, reject negative
  resulting stock, and atomically write a movement and audit record.
- Admin delivery updates follow `pending_dispatch` → `assigned` → `picked_up`
  → `delivered`; `failed` is available from assigned or picked-up. Invalid
  transitions are rejected, and accepted updates append a customer-visible
  event and administrator audit record. These are manual status updates, not
  evidence of a connected dispatch provider or driver location.
- Order queue endpoints are read-only. No dispatch, fulfillment, or payment
  override operation is exposed.
- Admins can list pending product reviews and approve or reject each once;
  moderation decisions are audited.
- `GET /api/v1/admin/catalog-terms` returns category and brand records.
  Admins can create and update categories and brands with English names/slugs
  and optional Arabic names/descriptions.
- Admin product creation requires an existing category and brand, a unique
  lowercase URL slug, a positive price, and a non-negative integer stock
  quantity. Optional Arabic product names/descriptions and package size are
  accepted. Product updates support validated bilingual text, category/brand,
  price, and active-state changes. Catalog changes are audited. Public
  customers cannot edit catalog data.
- Product media storage is not configured. Admin catalog operations do not
  accept arbitrary image URLs or claim an upload has been stored.

### Bilingual catalog and customer snapshots

- Catalog category, brand, and product responses retain their existing
  English fields and add optional `nameAr` and `descriptionAr` fields. Search
  matches English and Arabic names/descriptions. Existing records are
  preserved; migration 017 adds nullable Arabic columns and fills translations
  only for the deterministic baseline seed records.
- Cart items include optional `nameAr`. Checkout/order snapshots preserve the
  bilingual product name so mobile clients can display the appropriate locale
  without changing trusted pricing or historical English names.

### Product reviews

- `GET /api/v1/catalog/products/:productId/reviews` returns only approved
  reviews and their average/count summary.
- `POST /api/v1/catalog/products/:productId/reviews` requires authentication
  and `{ "orderId": "<order UUID>", "rating": 1, "comment": "..." }`. It is
  accepted only when the customer's delivered order snapshot contains that
  product. One review per product/order is permitted and submitted reviews
  remain private until admin approval.

## Error Format

```json
{
  "code": "PRODUCT_OUT_OF_STOCK",
  "message": "The requested product is currently unavailable.",
  "details": {},
  "correlationId": "..."
}
```

## Rate limits

Authentication rate limits are shared through PostgreSQL and return HTTP 429
with a `Retry-After` header when exceeded:

- login: 10 requests per client address per 15 minutes
- registration: 20 requests per client address per 15 minutes
- refresh: 30 requests per client address per 15 minutes
- logout: 30 requests per client address per 15 minutes
- profile updates: 10 requests per client address per 15 minutes

The database stores a SHA-256 digest of the limiter scope/address key, not the
plain address. Counts use an atomic database upsert, so multiple backend
instances share the same window. Rate-limit database errors fail closed for
the guarded request; the service does not fall back to in-memory counters.
Behind a reverse proxy, configure trusted proxy handling explicitly before
relying on client-address-based limits. These application limits are not a
replacement for a deployment-level edge/WAF policy.

## Quality requirements

- validation and pagination
- filtering and sorting
- consistent HTTP status codes
- correlation IDs and request IDs
- structured logs and no stack traces in client responses
