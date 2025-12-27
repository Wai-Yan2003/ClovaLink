-- Migration: Add tenant security policies (password policy and IP restrictions)

-- Password policy per tenant
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS password_policy JSONB DEFAULT '{
    "min_length": 8,
    "require_uppercase": true,
    "require_lowercase": true,
    "require_number": true,
    "require_special": false,
    "max_age_days": null,
    "prevent_reuse": 0
}'::jsonb;

-- IP allowlist/blocklist per tenant
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS ip_allowlist TEXT[] DEFAULT '{}';
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS ip_blocklist TEXT[] DEFAULT '{}';
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS ip_restriction_mode VARCHAR(20) DEFAULT 'disabled';
-- Modes: 'disabled', 'allowlist_only', 'blocklist_only', 'both'

-- Add comment for documentation
COMMENT ON COLUMN tenants.password_policy IS 'JSON object with password requirements: min_length, require_uppercase, require_lowercase, require_number, require_special, max_age_days, prevent_reuse';
COMMENT ON COLUMN tenants.ip_allowlist IS 'Array of allowed IP addresses/CIDR ranges';
COMMENT ON COLUMN tenants.ip_blocklist IS 'Array of blocked IP addresses/CIDR ranges';
COMMENT ON COLUMN tenants.ip_restriction_mode IS 'IP restriction mode: disabled, allowlist_only, blocklist_only, or both';

