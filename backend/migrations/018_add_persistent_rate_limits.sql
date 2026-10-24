CREATE TABLE IF NOT EXISTS application_rate_limits (
    key_hash CHAR(64) PRIMARY KEY,
    window_started_at TIMESTAMPTZ NOT NULL,
    hit_count INTEGER NOT NULL CHECK (hit_count > 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_application_rate_limits_updated_at
    ON application_rate_limits(updated_at);
