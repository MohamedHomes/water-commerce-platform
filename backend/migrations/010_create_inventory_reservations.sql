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
