ALTER TABLE customers
    ADD COLUMN IF NOT EXISTS auth_version INTEGER NOT NULL DEFAULT 0
        CHECK (auth_version >= 0);
