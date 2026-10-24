-- GENERATED from backend/migrations in filename order.
-- Apply only to a new, empty database. The backend migration runner remains canonical.
BEGIN;

-- BEGIN 001_create_customers.sql
CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  phone VARCHAR(30),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_customers_email ON customers (email);
-- END 001_create_customers.sql

-- BEGIN 002_create_catalog_schema.sql
CREATE TABLE IF NOT EXISTS categories (
  id UUID PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  slug VARCHAR(150) NOT NULL UNIQUE,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS brands (
  id UUID PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  slug VARCHAR(150) NOT NULL UNIQUE,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  slug VARCHAR(200) NOT NULL UNIQUE,
  category_id UUID NOT NULL REFERENCES categories(id),
  brand_id UUID NOT NULL REFERENCES brands(id),
  description TEXT,
  price NUMERIC(10,2) NOT NULL,
  compare_at_price NUMERIC(10,2),
  discount_percent NUMERIC(5,2),
  availability VARCHAR(30) NOT NULL DEFAULT 'in_stock',
  image_url TEXT,
  package_size VARCHAR(80),
  quantity INTEGER NOT NULL DEFAULT 0,
  volume VARCHAR(40),
  weight VARCHAR(40),
  dimensions VARCHAR(80),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS product_variants (
  id UUID PRIMARY KEY,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  sku VARCHAR(80) NOT NULL UNIQUE,
  barcode VARCHAR(80) UNIQUE,
  package_size VARCHAR(80),
  quantity INTEGER NOT NULL DEFAULT 0,
  volume VARCHAR(40),
  weight VARCHAR(40),
  dimensions VARCHAR(80),
  price NUMERIC(10,2) NOT NULL,
  compare_at_price NUMERIC(10,2),
  discount_percent NUMERIC(5,2),
  is_available BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_products_category ON products (category_id);
CREATE INDEX IF NOT EXISTS idx_products_brand ON products (brand_id);
CREATE INDEX IF NOT EXISTS idx_products_name ON products (name);
CREATE INDEX IF NOT EXISTS idx_variants_sku ON product_variants (sku);
-- END 002_create_catalog_schema.sql

-- BEGIN 003_create_search_indexes.sql
CREATE INDEX IF NOT EXISTS idx_products_search_name ON products USING gin (to_tsvector('english', name));
CREATE INDEX IF NOT EXISTS idx_products_search_description ON products USING gin (to_tsvector('english', description));
CREATE INDEX IF NOT EXISTS idx_products_price ON products (price);
-- END 003_create_search_indexes.sql

-- BEGIN 004_create_cart_schema.sql
CREATE TABLE IF NOT EXISTS carts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'active',
    currency VARCHAR(8) NOT NULL DEFAULT 'SAR',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NULL,
    UNIQUE (customer_id, status)
);

CREATE TABLE IF NOT EXISTS cart_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID NOT NULL REFERENCES carts(id) ON DELETE CASCADE,
    product_id VARCHAR(128) NOT NULL,
    variant_id VARCHAR(128) NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12, 2) NOT NULL,
    compare_at_price NUMERIC(12, 2) NULL,
    discount_percent NUMERIC(5, 2) NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (cart_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_carts_customer_id ON carts(customer_id);
CREATE INDEX IF NOT EXISTS idx_cart_items_cart_id ON cart_items(cart_id);
-- END 004_create_cart_schema.sql

-- BEGIN 005_create_addresses_and_checkout.sql
CREATE TABLE IF NOT EXISTS cities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(128) NOT NULL,
    country_code VARCHAR(8) NOT NULL DEFAULT 'SA',
    region VARCHAR(64) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_cities_name_country UNIQUE (name, country_code)
);

CREATE TABLE IF NOT EXISTS delivery_zones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    city_id UUID NOT NULL REFERENCES cities(id) ON DELETE RESTRICT,
    name VARCHAR(128) NOT NULL,
    base_fee NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (base_fee >= 0),
    express_fee NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (express_fee >= 0),
    estimated_minutes INTEGER NOT NULL DEFAULT 30 CHECK (estimated_minutes > 0),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_delivery_zones_city_name UNIQUE (city_id, name)
);

CREATE TABLE IF NOT EXISTS customer_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    city_id UUID NOT NULL REFERENCES cities(id) ON DELETE RESTRICT,
    label VARCHAR(64) NOT NULL,
    recipient_name VARCHAR(128) NOT NULL,
    phone VARCHAR(32) NOT NULL,
    city VARCHAR(128) NOT NULL,
    district VARCHAR(128) NOT NULL,
    street VARCHAR(255) NOT NULL,
    building VARCHAR(128) NOT NULL,
    apartment VARCHAR(64) NULL,
    floor VARCHAR(32) NULL,
    latitude NUMERIC(9, 6) NULL CHECK (latitude BETWEEN -90 AND 90),
    longitude NUMERIC(9, 6) NULL CHECK (longitude BETWEEN -180 AND 180),
    notes TEXT NULL,
    is_default BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_customer_addresses_coordinate_pair CHECK ((latitude IS NULL) = (longitude IS NULL)),
    CONSTRAINT uq_customer_addresses_owner UNIQUE (id, customer_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_customer_addresses_default
    ON customer_addresses(customer_id)
    WHERE is_default = true;

CREATE TABLE IF NOT EXISTS checkout_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    address_id UUID NOT NULL,
    delivery_zone_id UUID NULL REFERENCES delivery_zones(id) ON DELETE SET NULL,
    cart_snapshot JSONB NOT NULL,
    subtotal NUMERIC(12, 2) NOT NULL CHECK (subtotal >= 0),
    delivery_fee NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (delivery_fee >= 0),
    service_fee NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (service_fee >= 0),
    total NUMERIC(12, 2) NOT NULL CHECK (total >= 0),
    currency VARCHAR(8) NOT NULL DEFAULT 'SAR',
    payment_method VARCHAR(32) NOT NULL DEFAULT 'card',
    status VARCHAR(32) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'payment_pending', 'confirmed', 'expired', 'cancelled')),
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_checkout_sessions_customer_address
        FOREIGN KEY (address_id, customer_id)
        REFERENCES customer_addresses(id, customer_id)
        ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_delivery_zones_city_id ON delivery_zones(city_id);
CREATE INDEX IF NOT EXISTS idx_customer_addresses_customer_id ON customer_addresses(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_addresses_city_id ON customer_addresses(city_id);
CREATE INDEX IF NOT EXISTS idx_checkout_sessions_customer_id ON checkout_sessions(customer_id);
CREATE INDEX IF NOT EXISTS idx_checkout_sessions_expires_at ON checkout_sessions(expires_at);
-- END 005_create_addresses_and_checkout.sql

-- BEGIN 006_reconcile_persistence_schema.sql
ALTER TABLE products
    DROP CONSTRAINT IF EXISTS products_category_id_fkey,
    DROP CONSTRAINT IF EXISTS products_brand_id_fkey;

ALTER TABLE product_variants
    DROP CONSTRAINT IF EXISTS product_variants_product_id_fkey;

ALTER TABLE carts
    DROP CONSTRAINT IF EXISTS carts_customer_id_fkey,
    DROP CONSTRAINT IF EXISTS fk_carts_customer;

ALTER TABLE cart_items
    DROP CONSTRAINT IF EXISTS cart_items_product_id_fkey,
    DROP CONSTRAINT IF EXISTS fk_cart_items_product,
    DROP CONSTRAINT IF EXISTS cart_items_variant_id_fkey;

ALTER TABLE delivery_zones
    DROP CONSTRAINT IF EXISTS delivery_zones_city_id_fkey,
    ALTER COLUMN id DROP DEFAULT;

ALTER TABLE customer_addresses
    DROP CONSTRAINT IF EXISTS customer_addresses_city_id_fkey;

ALTER TABLE checkout_sessions
    DROP CONSTRAINT IF EXISTS checkout_sessions_delivery_zone_id_fkey;

ALTER TABLE categories
    ALTER COLUMN id TYPE VARCHAR(128) USING id::text;

ALTER TABLE brands
    ALTER COLUMN id TYPE VARCHAR(128) USING id::text;

ALTER TABLE products
    ALTER COLUMN id TYPE VARCHAR(128) USING id::text,
    ALTER COLUMN category_id TYPE VARCHAR(128) USING category_id::text,
    ALTER COLUMN brand_id TYPE VARCHAR(128) USING brand_id::text;

ALTER TABLE product_variants
    ALTER COLUMN id TYPE VARCHAR(128) USING id::text,
    ALTER COLUMN product_id TYPE VARCHAR(128) USING product_id::text;

ALTER TABLE cart_items
    ALTER COLUMN product_id TYPE VARCHAR(128) USING product_id::text,
    ALTER COLUMN variant_id TYPE VARCHAR(128) USING variant_id::text;

ALTER TABLE cities
    ALTER COLUMN id DROP DEFAULT,
    ALTER COLUMN id TYPE VARCHAR(128) USING id::text,
    ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;

ALTER TABLE delivery_zones
    ALTER COLUMN id TYPE VARCHAR(128) USING id::text,
    ALTER COLUMN city_id TYPE VARCHAR(128) USING city_id::text,
    ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;

ALTER TABLE customer_addresses
    ALTER COLUMN city_id TYPE VARCHAR(128) USING city_id::text;

ALTER TABLE checkout_sessions
    ALTER COLUMN delivery_zone_id TYPE VARCHAR(128) USING delivery_zone_id::text,
    ADD COLUMN IF NOT EXISTS delivery_option VARCHAR(32) NOT NULL DEFAULT 'standard';

ALTER TABLE products
    ADD CONSTRAINT products_category_id_fkey
        FOREIGN KEY (category_id) REFERENCES categories(id),
    ADD CONSTRAINT products_brand_id_fkey
        FOREIGN KEY (brand_id) REFERENCES brands(id);

ALTER TABLE product_variants
    ADD CONSTRAINT product_variants_product_id_fkey
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE;

ALTER TABLE carts
    ADD CONSTRAINT fk_carts_customer
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE;

ALTER TABLE cart_items
    ADD CONSTRAINT fk_cart_items_product
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    ADD CONSTRAINT cart_items_variant_id_fkey
        FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE SET NULL;

ALTER TABLE delivery_zones
    ADD CONSTRAINT delivery_zones_city_id_fkey
        FOREIGN KEY (city_id) REFERENCES cities(id) ON DELETE RESTRICT;

ALTER TABLE customer_addresses
    ADD CONSTRAINT customer_addresses_city_id_fkey
        FOREIGN KEY (city_id) REFERENCES cities(id) ON DELETE RESTRICT;

ALTER TABLE checkout_sessions
    ADD CONSTRAINT checkout_sessions_delivery_zone_id_fkey
        FOREIGN KEY (delivery_zone_id) REFERENCES delivery_zones(id) ON DELETE SET NULL,
    ADD CONSTRAINT ck_checkout_sessions_delivery_option
        CHECK (delivery_option IN ('standard', 'express'));
-- END 006_reconcile_persistence_schema.sql

-- BEGIN 007_seed_catalog_and_delivery.sql
-- 007: deterministic seed of the initial catalog, cities, and delivery zones.
-- Replaces the previous in-memory fixtures/config while preserving existing API IDs.

INSERT INTO categories (id, name, slug, description, created_at, updated_at) VALUES
    ('cat-water', 'Bottled Water', 'bottled-water', 'Still and sparkling water', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
    ('cat-boxes', 'Water Boxes', 'water-boxes', 'Water ready to drink cartons', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
    ('cat-bulk', 'Bulk Supply', 'bulk-supply', 'Commercial and household bulk supply', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z')
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    slug = EXCLUDED.slug,
    description = EXCLUDED.description,
    updated_at = EXCLUDED.updated_at;

INSERT INTO brands (id, name, slug, description, created_at, updated_at) VALUES
    ('brand-aquaflow', 'AquaFlow', 'aquaflow', NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
    ('brand-nature', 'Nature Spring', 'nature-spring', NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
    ('brand-pure', 'PureDrop', 'puredrop', NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z')
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    slug = EXCLUDED.slug,
    description = EXCLUDED.description,
    updated_at = EXCLUDED.updated_at;

INSERT INTO products (
    id, name, slug, category_id, brand_id, description, price, compare_at_price,
    discount_percent, availability, image_url, package_size, quantity, volume,
    weight, dimensions, is_active, created_at, updated_at
) VALUES
    (
        'prod-1', 'AquaFlow 1.5L Mineral Water', 'aquaflow-15l-mineral-water',
        'cat-water', 'brand-aquaflow',
        'Refreshing mineral water for everyday hydration.',
        4.50, 5.50, 18, 'in_stock', 'https://images.example.com/water-15l.png',
        '1.5L bottle', 120, '1.5L', '1.5kg', '18 x 7 x 7 cm', TRUE,
        '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'
    ),
    (
        'prod-2', 'PureDrop Family Pack', 'puredrop-family-pack',
        'cat-bulk', 'brand-pure',
        'High-quality water for households and recurring deliveries.',
        24.00, 30.00, 20, 'low_stock', 'https://images.example.com/family-pack.png',
        '12 x 1.5L', 36, '18L', '18kg', '40 x 30 x 20 cm', TRUE,
        '2026-01-10T00:00:00Z', '2026-01-10T00:00:00Z'
    ),
    (
        'prod-3', 'Nature Spring 330ml Can', 'nature-spring-330ml-can',
        'cat-water', 'brand-nature',
        'Lightweight, easy-drink sparkling water.',
        2.75, 3.25, 15, 'in_stock', 'https://images.example.com/sparkling-can.png',
        '330ml can', 200, '330ml', '0.4kg', '12 x 6 x 6 cm', TRUE,
        '2026-02-01T00:00:00Z', '2026-02-01T00:00:00Z'
    )
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    slug = EXCLUDED.slug,
    category_id = EXCLUDED.category_id,
    brand_id = EXCLUDED.brand_id,
    description = EXCLUDED.description,
    price = EXCLUDED.price,
    compare_at_price = EXCLUDED.compare_at_price,
    discount_percent = EXCLUDED.discount_percent,
    availability = EXCLUDED.availability,
    image_url = EXCLUDED.image_url,
    package_size = EXCLUDED.package_size,
    quantity = EXCLUDED.quantity,
    volume = EXCLUDED.volume,
    weight = EXCLUDED.weight,
    dimensions = EXCLUDED.dimensions,
    is_active = EXCLUDED.is_active,
    updated_at = EXCLUDED.updated_at;

INSERT INTO product_variants (
    id, product_id, sku, barcode, package_size, quantity, volume, weight,
    dimensions, price, compare_at_price, discount_percent, is_available, created_at, updated_at
) VALUES
    ('var-1', 'prod-1',
        'AF-15L-001', '1234567890123', '1.5L bottle', 12, '1.5L', '1.5kg', '18 x 7 x 7 cm',
        4.50, 5.50, 18, TRUE, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
    ('var-2', 'prod-2',
        'PD-12X15L', '2345678901234', '12 x 1.5L', 4, '18L', '18kg', '40 x 30 x 20 cm',
        24.00, 30.00, 20, TRUE, '2026-01-10T00:00:00Z', '2026-01-10T00:00:00Z'),
    ('var-3', 'prod-3',
        'NS-330ML-001', '3456789012345', '330ml can', 15, '330ml', '0.4kg', '12 x 6 x 6 cm',
        2.75, 3.25, 15, TRUE, '2026-02-01T00:00:00Z', '2026-02-01T00:00:00Z')
ON CONFLICT (id) DO UPDATE SET
    product_id = EXCLUDED.product_id,
    sku = EXCLUDED.sku,
    barcode = EXCLUDED.barcode,
    package_size = EXCLUDED.package_size,
    quantity = EXCLUDED.quantity,
    volume = EXCLUDED.volume,
    weight = EXCLUDED.weight,
    dimensions = EXCLUDED.dimensions,
    price = EXCLUDED.price,
    compare_at_price = EXCLUDED.compare_at_price,
    discount_percent = EXCLUDED.discount_percent,
    is_available = EXCLUDED.is_available,
    updated_at = EXCLUDED.updated_at;

INSERT INTO cities (id, name, country_code, region, is_active, created_at, updated_at) VALUES
    ('city-riyadh', 'Riyadh', 'SA', 'Central', TRUE, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
    ('city-jeddah', 'Jeddah', 'SA', 'Western', TRUE, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z')
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    country_code = EXCLUDED.country_code,
    region = EXCLUDED.region,
    is_active = TRUE,
    updated_at = EXCLUDED.updated_at;

INSERT INTO delivery_zones (id, city_id, name, base_fee, express_fee, estimated_minutes, is_active, created_at, updated_at) VALUES
    ('zone-riyadh-central', 'city-riyadh', 'Central Riyadh', 12, 10, 30, TRUE, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
    ('zone-jeddah-central', 'city-jeddah', 'Central Jeddah', 14, 10, 35, TRUE, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z')
ON CONFLICT (id) DO UPDATE SET
    city_id = EXCLUDED.city_id,
    name = EXCLUDED.name,
    base_fee = EXCLUDED.base_fee,
    express_fee = EXCLUDED.express_fee,
    estimated_minutes = EXCLUDED.estimated_minutes,
    is_active = TRUE,
    updated_at = EXCLUDED.updated_at;
-- END 007_seed_catalog_and_delivery.sql

-- BEGIN 008_create_orders.sql
CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    checkout_session_id UUID NOT NULL UNIQUE REFERENCES checkout_sessions(id) ON DELETE RESTRICT,
    status VARCHAR(32) NOT NULL CHECK (status IN ('payment_pending', 'placed', 'cancelled')),
    payment_method VARCHAR(32) NOT NULL CHECK (payment_method IN ('card', 'cash')),
    delivery_option VARCHAR(32) NOT NULL CHECK (delivery_option IN ('standard', 'express')),
    address_snapshot JSONB NOT NULL,
    delivery_zone_snapshot JSONB NOT NULL,
    cart_snapshot JSONB NOT NULL,
    subtotal NUMERIC(12, 2) NOT NULL CHECK (subtotal >= 0),
    delivery_fee NUMERIC(12, 2) NOT NULL CHECK (delivery_fee >= 0),
    service_fee NUMERIC(12, 2) NOT NULL CHECK (service_fee >= 0),
    total NUMERIC(12, 2) NOT NULL CHECK (total >= 0),
    currency VARCHAR(8) NOT NULL DEFAULT 'SAR',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    cancelled_at TIMESTAMPTZ NULL
);

CREATE INDEX IF NOT EXISTS idx_orders_customer_created
    ON orders(customer_id, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_orders_status_created
    ON orders(status, created_at DESC);
-- END 008_create_orders.sql

-- BEGIN 009_create_payments.sql
ALTER TABLE orders
    DROP CONSTRAINT IF EXISTS orders_status_check,
    ADD CONSTRAINT orders_status_check
        CHECK (status IN ('payment_pending', 'placed', 'paid', 'cancelled'));

CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    provider VARCHAR(64) NOT NULL,
    idempotency_key VARCHAR(128) NOT NULL,
    provider_payment_id VARCHAR(255) NULL,
    status VARCHAR(32) NOT NULL
        CHECK (status IN ('creating', 'pending', 'succeeded', 'failed', 'cancelled')),
    amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
    currency VARCHAR(8) NOT NULL,
    checkout_url TEXT NULL,
    failure_code VARCHAR(128) NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_payments_customer_idempotency UNIQUE (customer_id, idempotency_key),
    CONSTRAINT uq_payments_provider_payment UNIQUE (provider, provider_payment_id)
);

CREATE INDEX IF NOT EXISTS idx_payments_order_created
    ON payments(order_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_payments_customer_created
    ON payments(customer_id, created_at DESC);

CREATE TABLE IF NOT EXISTS payment_webhook_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider VARCHAR(64) NOT NULL,
    provider_event_id VARCHAR(255) NOT NULL,
    payment_id UUID NOT NULL REFERENCES payments(id) ON DELETE RESTRICT,
    event_type VARCHAR(64) NOT NULL,
    payload_sha256 VARCHAR(64) NOT NULL,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_payment_webhook_provider_event UNIQUE (provider, provider_event_id)
);
-- END 009_create_payments.sql

-- BEGIN 010_create_inventory_reservations.sql
ALTER TABLE products
    ADD CONSTRAINT ck_products_quantity_nonnegative CHECK (quantity >= 0);

CREATE TABLE IF NOT EXISTS inventory_reservations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
    product_id VARCHAR(128) NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    status VARCHAR(24) NOT NULL DEFAULT 'reserved'
        CHECK (status IN ('reserved', 'released')),
    reserved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    released_at TIMESTAMPTZ NULL,
    CONSTRAINT uq_inventory_reservations_order_product UNIQUE (order_id, product_id),
    CONSTRAINT ck_inventory_reservations_release_time
        CHECK ((status = 'released') = (released_at IS NOT NULL))
);

CREATE INDEX IF NOT EXISTS idx_inventory_reservations_active_product
    ON inventory_reservations(product_id, reserved_at)
    WHERE status = 'reserved';

CREATE TABLE IF NOT EXISTS inventory_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
    product_id VARCHAR(128) NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    quantity_delta INTEGER NOT NULL CHECK (quantity_delta <> 0),
    reason VARCHAR(32) NOT NULL CHECK (reason IN ('order_reserved', 'order_cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_inventory_movement_reason UNIQUE (order_id, product_id, reason)
);

CREATE INDEX IF NOT EXISTS idx_inventory_movements_product_created
    ON inventory_movements(product_id, created_at DESC);
-- END 010_create_inventory_reservations.sql

-- BEGIN 011_create_deliveries.sql
CREATE TABLE IF NOT EXISTS deliveries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL UNIQUE REFERENCES orders(id) ON DELETE RESTRICT,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    status VARCHAR(32) NOT NULL DEFAULT 'pending_dispatch'
        CHECK (status IN ('pending_dispatch', 'assigned', 'picked_up', 'delivered', 'failed', 'cancelled')),
    estimated_minutes INTEGER NOT NULL CHECK (estimated_minutes > 0),
    tracking_code VARCHAR(64) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    delivered_at TIMESTAMPTZ NULL
);

CREATE INDEX IF NOT EXISTS idx_deliveries_customer_created
    ON deliveries(customer_id, created_at DESC);

CREATE TABLE IF NOT EXISTS delivery_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    delivery_id UUID NOT NULL REFERENCES deliveries(id) ON DELETE RESTRICT,
    status VARCHAR(32) NOT NULL
        CHECK (status IN ('pending_dispatch', 'assigned', 'picked_up', 'delivered', 'failed', 'cancelled')),
    note VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_delivery_events_delivery_created
    ON delivery_events(delivery_id, created_at, id);
-- END 011_create_deliveries.sql

-- BEGIN 012_create_notifications.sql
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    type VARCHAR(64) NOT NULL,
    title VARCHAR(160) NOT NULL,
    body VARCHAR(500) NOT NULL,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    deduplication_key VARCHAR(160) NOT NULL,
    read_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_notifications_customer_deduplication
        UNIQUE (customer_id, deduplication_key)
);

CREATE INDEX IF NOT EXISTS idx_notifications_customer_created
    ON notifications(customer_id, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_unread
    ON notifications(customer_id, created_at DESC)
    WHERE read_at IS NULL;
-- END 012_create_notifications.sql

-- BEGIN 013_create_promotions.sql
CREATE TABLE IF NOT EXISTS promotions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(64) NOT NULL,
    discount_type VARCHAR(16) NOT NULL CHECK (discount_type IN ('percentage', 'fixed')),
    discount_value NUMERIC(12, 2) NOT NULL CHECK (discount_value > 0),
    max_discount NUMERIC(12, 2) NULL CHECK (max_discount IS NULL OR max_discount > 0),
    minimum_subtotal NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (minimum_subtotal >= 0),
    max_redemptions INTEGER NULL CHECK (max_redemptions IS NULL OR max_redemptions > 0),
    max_per_customer INTEGER NOT NULL DEFAULT 1 CHECK (max_per_customer > 0),
    starts_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ends_at TIMESTAMPTZ NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (ends_at IS NULL OR ends_at > starts_at),
    CHECK (discount_type != 'percentage' OR discount_value <= 100)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_promotions_code_ci
    ON promotions(UPPER(code));

CREATE TABLE IF NOT EXISTS promotion_redemptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    promotion_id UUID NOT NULL REFERENCES promotions(id) ON DELETE RESTRICT,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    order_id UUID NOT NULL UNIQUE REFERENCES orders(id) ON DELETE RESTRICT,
    discount_amount NUMERIC(12, 2) NOT NULL CHECK (discount_amount > 0),
    redeemed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (promotion_id, customer_id, order_id)
);

CREATE INDEX IF NOT EXISTS idx_promotion_redemptions_promotion
    ON promotion_redemptions(promotion_id);
CREATE INDEX IF NOT EXISTS idx_promotion_redemptions_customer
    ON promotion_redemptions(promotion_id, customer_id);

ALTER TABLE checkout_sessions
    ADD COLUMN IF NOT EXISTS promotion_id UUID NULL REFERENCES promotions(id) ON DELETE RESTRICT,
    ADD COLUMN IF NOT EXISTS promotion_code VARCHAR(64) NULL,
    ADD COLUMN IF NOT EXISTS discount_amount NUMERIC(12, 2) NOT NULL DEFAULT 0
        CHECK (discount_amount >= 0 AND discount_amount <= subtotal);

ALTER TABLE orders
    ADD COLUMN IF NOT EXISTS promotion_id UUID NULL REFERENCES promotions(id) ON DELETE RESTRICT,
    ADD COLUMN IF NOT EXISTS promotion_code VARCHAR(64) NULL,
    ADD COLUMN IF NOT EXISTS discount_amount NUMERIC(12, 2) NOT NULL DEFAULT 0
        CHECK (discount_amount >= 0 AND discount_amount <= subtotal);
-- END 013_create_promotions.sql

-- BEGIN 014_add_customer_roles_and_admin_audit.sql
ALTER TABLE customers
    ADD COLUMN IF NOT EXISTS role VARCHAR(16) NOT NULL DEFAULT 'customer'
        CHECK (role IN ('customer', 'admin'));

CREATE TABLE IF NOT EXISTS admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    action VARCHAR(64) NOT NULL,
    resource_type VARCHAR(64) NOT NULL,
    resource_id UUID NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_created_at
    ON admin_audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_actor_created
    ON admin_audit_logs(admin_customer_id, created_at DESC);
-- END 014_add_customer_roles_and_admin_audit.sql

-- BEGIN 015_add_admin_inventory_adjustments.sql
ALTER TABLE inventory_movements
    ALTER COLUMN order_id DROP NOT NULL,
    ADD COLUMN IF NOT EXISTS admin_customer_id UUID NULL
        REFERENCES customers(id) ON DELETE RESTRICT;

ALTER TABLE inventory_movements
    DROP CONSTRAINT IF EXISTS inventory_movements_reason_check,
    ADD CONSTRAINT ck_inventory_movements_reason
        CHECK (reason IN ('order_reserved', 'order_cancelled', 'inventory_adjustment'));

CREATE INDEX IF NOT EXISTS idx_inventory_movements_admin_created
    ON inventory_movements(admin_customer_id, created_at DESC)
    WHERE admin_customer_id IS NOT NULL;
-- END 015_add_admin_inventory_adjustments.sql

-- BEGIN 016_create_product_reviews.sql
CREATE TABLE IF NOT EXISTS product_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id VARCHAR(128) NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
    rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment VARCHAR(1000) NOT NULL DEFAULT '',
    status VARCHAR(16) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'rejected')),
    moderated_by UUID NULL REFERENCES customers(id) ON DELETE RESTRICT,
    moderated_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (order_id, product_id),
    CHECK ((status = 'pending') = (moderated_at IS NULL))
);

CREATE INDEX IF NOT EXISTS idx_product_reviews_public
    ON product_reviews(product_id, created_at DESC)
    WHERE status = 'approved';
CREATE INDEX IF NOT EXISTS idx_product_reviews_moderation
    ON product_reviews(status, created_at DESC);
-- END 016_create_product_reviews.sql

-- BEGIN 017_add_catalog_localizations.sql
ALTER TABLE categories
    ADD COLUMN IF NOT EXISTS name_ar VARCHAR(150),
    ADD COLUMN IF NOT EXISTS description_ar TEXT;

ALTER TABLE brands
    ADD COLUMN IF NOT EXISTS name_ar VARCHAR(150),
    ADD COLUMN IF NOT EXISTS description_ar TEXT;

ALTER TABLE products
    ADD COLUMN IF NOT EXISTS name_ar VARCHAR(200),
    ADD COLUMN IF NOT EXISTS description_ar TEXT;

UPDATE categories
SET name_ar = CASE id
        WHEN 'cat-water' THEN 'مياه معبأة'
        WHEN 'cat-boxes' THEN 'عبوات مياه'
        WHEN 'cat-bulk' THEN 'توريد بالجملة'
        ELSE name_ar
    END,
    description_ar = CASE id
        WHEN 'cat-water' THEN 'مياه عادية وفوارة'
        WHEN 'cat-boxes' THEN 'عبوات مياه جاهزة للشرب'
        WHEN 'cat-bulk' THEN 'توريد كميات كبيرة للمنازل والمنشآت'
        ELSE description_ar
    END
WHERE id IN ('cat-water', 'cat-boxes', 'cat-bulk');

UPDATE brands
SET name_ar = CASE id
        WHEN 'brand-aquaflow' THEN 'أكوافلو'
        WHEN 'brand-nature' THEN 'نيتشر سبرينغ'
        WHEN 'brand-pure' THEN 'بيور دروب'
        ELSE name_ar
    END
WHERE id IN ('brand-aquaflow', 'brand-nature', 'brand-pure');

UPDATE products
SET name_ar = CASE id
        WHEN 'prod-1' THEN 'مياه أكوافلو المعدنية ١٫٥ لتر'
        WHEN 'prod-2' THEN 'عبوة بيور دروب العائلية'
        WHEN 'prod-3' THEN 'مياه نيتشر سبرينغ ٣٣٠ مل'
        ELSE name_ar
    END,
    description_ar = CASE id
        WHEN 'prod-1' THEN 'مياه معدنية منعشة لترطيب يومي.'
        WHEN 'prod-2' THEN 'مياه عالية الجودة للمنازل والتوصيل الدوري.'
        WHEN 'prod-3' THEN 'مياه فوارة خفيفة وسهلة الشرب.'
        ELSE description_ar
    END
WHERE id IN ('prod-1', 'prod-2', 'prod-3');
-- END 017_add_catalog_localizations.sql

-- BEGIN 018_add_persistent_rate_limits.sql
CREATE TABLE IF NOT EXISTS application_rate_limits (
    key_hash CHAR(64) PRIMARY KEY,
    window_started_at TIMESTAMPTZ NOT NULL,
    hit_count INTEGER NOT NULL CHECK (hit_count > 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_application_rate_limits_updated_at
    ON application_rate_limits(updated_at);
-- END 018_add_persistent_rate_limits.sql

-- Match the ledger schema maintained by backend/src/database/migration-runner.ts.
CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(32) NOT NULL PRIMARY KEY,
    filename TEXT NOT NULL,
    checksum VARCHAR(64) NOT NULL,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
INSERT INTO schema_migrations (version, filename, checksum) VALUES
    ('001', '001_create_customers.sql', 'dfb53d3cde8301979a99e00ff6d7fcefab776d59fd4b8c084dcd290d476dbb0a'),
    ('002', '002_create_catalog_schema.sql', 'ba345976b129e942d571a49e8f3f8f3001633d9e663f5be7ac068b7d6fa65ecf'),
    ('003', '003_create_search_indexes.sql', 'a9ea43ff8f04833137ffc3cf4c3c93cd24d48eb2400d193fdab389bcbe1653c1'),
    ('004', '004_create_cart_schema.sql', 'f36d6fff9c37a3493d84f4622fad5752e661e127eb62343d2db6d1598749574c'),
    ('005', '005_create_addresses_and_checkout.sql', 'a5f28de9e950a8187ab09c01e7958c90d3685ee488c53df2fa181c0da17c3fa3'),
    ('006', '006_reconcile_persistence_schema.sql', '6ab6aa6ae4ee9633407d0ffd9d961ecedb99142357dbd12a351004a493b4e06d'),
    ('007', '007_seed_catalog_and_delivery.sql', '1cc8df697dddb17f76ede2ac0537762fe70a541b409c8be0e1f2b8875c7618b3'),
    ('008', '008_create_orders.sql', '5d1e7c4e381aee66838c92f64b6640c845a0cdb3077ac23df78d9a4e5558c93d'),
    ('009', '009_create_payments.sql', '0b2d0cbc98b54f9b6f367fd8b409bef38f498bcbc0ef53c9879ce46f1080b038'),
    ('010', '010_create_inventory_reservations.sql', 'c285189a7dc42cabe52041a24639dd31c71cd4181b98d777920020f38ee06a54'),
    ('011', '011_create_deliveries.sql', 'bc4e8f5ba65497686d9a2efe08e74697eefae6765ac6cc0c7f75867c11406979'),
    ('012', '012_create_notifications.sql', '98e3c76a01412709c181c3034bdc69659e0ded7ea63bface4d79089d86f74656'),
    ('013', '013_create_promotions.sql', '0842ecf091c84bdabb485d3463e908b9a14675bcff05f6a120cc33448333c398'),
    ('014', '014_add_customer_roles_and_admin_audit.sql', 'db8339e34a0dac53582c9cdd2094927a0ebf62fd56bee69ee9848377b9fc3d18'),
    ('015', '015_add_admin_inventory_adjustments.sql', '8df2943022388867610e319b80f919556524d93da8e77683f1b1bd2b71cd66fb'),
    ('016', '016_create_product_reviews.sql', 'b31bd3ff83fb20ba2e6de4f184ab71e14e9fc694f6739df35d17f653306066b7'),
    ('017', '017_add_catalog_localizations.sql', 'd727d7bd17954069aacafcb6c92e5ff80d2c23a91543c7c7406851ff7e99356f'),
    ('018', '018_add_persistent_rate_limits.sql', '44e83b935c43d450bf64866e99961a308e6e97954392cf636b363717b24ff4fc');
COMMIT;
