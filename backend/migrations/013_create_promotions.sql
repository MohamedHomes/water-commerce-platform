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
