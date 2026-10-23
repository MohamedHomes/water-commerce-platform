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
