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
