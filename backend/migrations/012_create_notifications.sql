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
