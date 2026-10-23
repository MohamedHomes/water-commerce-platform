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
