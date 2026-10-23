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
