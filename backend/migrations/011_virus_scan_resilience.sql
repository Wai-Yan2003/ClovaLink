-- Add exponential backoff support for virus scan jobs
-- This column stores when a failed job should next be retried

ALTER TABLE virus_scan_jobs
ADD COLUMN IF NOT EXISTS next_retry_at TIMESTAMPTZ;

-- Index for efficient job fetching with retry time
CREATE INDEX IF NOT EXISTS idx_virus_scan_jobs_next_retry 
ON virus_scan_jobs(status, next_retry_at) 
WHERE status = 'pending';

-- Add comment explaining the column
COMMENT ON COLUMN virus_scan_jobs.next_retry_at IS 
'When this job should be retried (exponential backoff: 30s, 2min, 10min)';



