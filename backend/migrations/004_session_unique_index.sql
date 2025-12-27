-- Add unique constraint for session upsert: one active session per device per user
-- This prevents duplicate sessions from the same browser/device
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_sessions_unique_active 
ON user_sessions(user_id, fingerprint_hash) 
WHERE is_revoked = false AND fingerprint_hash IS NOT NULL;

