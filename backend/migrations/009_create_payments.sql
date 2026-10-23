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
