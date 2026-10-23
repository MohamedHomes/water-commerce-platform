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
- pricing must be recalculated server-side before order creation
