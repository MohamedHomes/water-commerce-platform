ALTER TABLE customers
    ADD COLUMN IF NOT EXISTS role VARCHAR(16) NOT NULL DEFAULT 'customer'
        CHECK (role IN ('customer', 'admin'));

CREATE TABLE IF NOT EXISTS admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    action VARCHAR(64) NOT NULL,
    resource_type VARCHAR(64) NOT NULL,
    resource_id UUID NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_created_at
    ON admin_audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_actor_created
    ON admin_audit_logs(admin_customer_id, created_at DESC);
