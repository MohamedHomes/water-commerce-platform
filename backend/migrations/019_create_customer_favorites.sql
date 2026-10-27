CREATE TABLE IF NOT EXISTS customer_favorites (
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    product_id VARCHAR(128) NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (customer_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_customer_favorites_customer_created
    ON customer_favorites(customer_id, created_at DESC);
