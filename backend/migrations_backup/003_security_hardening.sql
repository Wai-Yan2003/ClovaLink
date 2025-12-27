-- ============================================================================
-- ClovaLink Security Hardening Migration
-- ============================================================================

-- Add share_policy column to file_shares for permissioned vs tenant-wide shares
-- Default to 'permissioned' for security (requires user to have access to the file)
ALTER TABLE file_shares ADD COLUMN IF NOT EXISTS share_policy VARCHAR(20) DEFAULT 'permissioned';

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_file_shares_share_policy ON file_shares(share_policy);

-- Comment explaining the column
COMMENT ON COLUMN file_shares.share_policy IS 
    'Share access policy: "permissioned" (default) requires user to pass can_access_file check, "tenant_wide" allows any user in the tenant';

