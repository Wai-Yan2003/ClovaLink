-- Add fingerprint_hash column for session security
-- The fingerprint is a hash of User-Agent + Accept-Language + partial IP (first 3 octets)
-- This helps detect token theft by validating the fingerprint on each request

ALTER TABLE user_sessions ADD COLUMN IF NOT EXISTS fingerprint_hash VARCHAR(64);

-- Index for faster fingerprint lookups
CREATE INDEX IF NOT EXISTS idx_user_sessions_fingerprint ON user_sessions(fingerprint_hash) WHERE fingerprint_hash IS NOT NULL;

