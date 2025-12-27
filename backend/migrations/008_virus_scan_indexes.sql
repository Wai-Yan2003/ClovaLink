-- Partial unique index to support upsert for pending/scanning jobs
CREATE UNIQUE INDEX IF NOT EXISTS idx_virus_scan_jobs_file_pending 
ON virus_scan_jobs(file_id) 
WHERE status IN ('pending', 'scanning');

