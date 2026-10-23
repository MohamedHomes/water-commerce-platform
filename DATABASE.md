# Database Foundation

## Database Stack

- PostgreSQL for transactional data
- Redis for caching and transient operational state
- Object storage for media and documents

## Initial Domain Entities

- users
- roles
- permissions
- user_roles
- addresses
- cities
- delivery_zones
- brands
- categories
- products
- product_variants
- product_images
- product_categories
- warehouses
- inventory
- inventory_reservations
- carts
- cart_items
- orders
- order_items
- order_status_history
- payments
- payment_transactions
- refunds
- promotions
- promotion_rules
- coupons
- coupon_redemptions
- favorites
- drivers
- deliveries
- driver_locations
- proof_of_delivery
- reviews
- notifications
- notification_deliveries
- subscriptions
- subscription_items
- audit_logs

## Migration Policy

- use migrations for all schema changes
- never alter production schema manually
- preserve schema history and versioning
- keep backward compatibility during sprint rollout

The backend requires `DATABASE_URL`; it does not fall back to process-local storage.
On startup it acquires a PostgreSQL advisory transaction lock, applies numbered
files from `backend/migrations` in filename order, and records their SHA-256
checksums in `schema_migrations`. Applied migration files are immutable: add a
new numbered migration instead of editing an applied file.

Migrations `001`-`005` are retained as the original schema history. Migration
`006` reconciles the API's stable string identifiers with catalog, delivery,
cart, and checkout foreign keys. Migration `007` seeds the deterministic
baseline catalog, cities, and delivery zones used by the current API. Migration
`008` adds customer orders with immutable address, delivery-zone, cart, and
pricing snapshots. Migration `009` adds payment intents and a deduplicated
webhook event ledger, and permits the `paid` order state.
Migration `010` adds order-level stock reservations and an immutable inventory
movement ledger; the current implementation uses the catalog's product
quantity as a single stock pool. Orders lock affected product rows before
rechecking availability, decrementing stock, and inserting reservations in the
same transaction. Eligible cancellations restore only still-reserved
quantities; reservations on paid orders remain held for fulfillment.
Migration `011` adds customer-owned delivery records and append-only status
events. Delivery records are opened only for cash orders or successfully paid
card orders; external dispatch and driver tracking remain unavailable.
Migration `012` adds a customer-scoped notification inbox with unique event
deduplication keys and read timestamps.
Migration `013` adds promotion definitions/redemptions and persists promotion
snapshots and discounts on checkout sessions and orders. Redemption limits are
rechecked under a promotion row lock and the redemption is written in the order
transaction.
Migration `014` adds customer/admin roles and a privileged-action audit log.
Customer registration defaults to the customer role; admin elevation is an
operator-controlled database action. No default customer-facing coupon is
seeded.
Migration `015` extends the inventory movement ledger for audited admin
adjustments while retaining order-linked reserve/release movements.
Migration `016` adds verified-purchase product reviews with pending moderation,
approved-public visibility, and moderator attribution.

For local PostgreSQL 16 verification, start the repository's database service
with `docker compose up -d postgres`, configure `DATABASE_URL` for that
instance, and start the backend. Successful backend startup means the connection
was checked and pending migrations completed. PGlite integration tests exercise
the PostgreSQL-compatible migration SQL and persistence behavior, but are not a
substitute for running this check against PostgreSQL 16.

## Core integrity rules

- all order states must be auditable
- historical order snapshots must remain immutable
- payment intent idempotency keys are unique per customer
- payment webhook events are deduplicated per provider event ID
- product stock cannot become negative
- inventory reservations must prevent overselling and cancellation must release
  reserved quantities exactly once
- delivery state history is append-only and customer visibility is scoped to
  the owning order
- notification event creation is idempotent per customer and event key
- promotion values and discounts are server-calculated; redemption records are
  tied to a customer and immutable order
- admin privilege changes are not self-service and privileged promotion edits
  are audited
- manual stock adjustments lock the product row, preserve non-negative stock,
  and persist a movement record and administrator audit entry atomically
- admin catalog price and active-state updates are audited
- public review queries include approved reviews only; a submission requires
  a delivered order containing the reviewed product
- pricing must be recalculated server-side before order creation
