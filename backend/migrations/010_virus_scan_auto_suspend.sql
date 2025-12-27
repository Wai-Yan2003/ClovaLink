-- Add auto-suspend settings to virus_scan_settings
ALTER TABLE virus_scan_settings 
ADD COLUMN IF NOT EXISTS auto_suspend_uploader BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE virus_scan_settings 
ADD COLUMN IF NOT EXISTS suspend_threshold INTEGER NOT NULL DEFAULT 1;

-- Track user malware upload counts per tenant
CREATE TABLE IF NOT EXISTS user_malware_counts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    count INTEGER NOT NULL DEFAULT 0,
    last_offense_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, tenant_id)
);

CREATE INDEX IF NOT EXISTS idx_user_malware_counts_user ON user_malware_counts(user_id);
CREATE INDEX IF NOT EXISTS idx_user_malware_counts_tenant ON user_malware_counts(tenant_id);

