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
