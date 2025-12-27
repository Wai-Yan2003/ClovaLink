-- S3 Replication Jobs Table
-- Tracks async replication of files to secondary S3 bucket

CREATE TABLE IF NOT EXISTS replication_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    storage_path TEXT NOT NULL,                    -- S3 key to replicate
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    operation VARCHAR(20) NOT NULL,                -- 'upload' | 'delete'
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending | processing | completed | failed
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 5,
    next_retry_at TIMESTAMPTZ DEFAULT NOW(),
    error_message TEXT,
    source_size_bytes BIGINT,                      -- For progress tracking
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    
    CONSTRAINT valid_operation CHECK (operation IN ('upload', 'delete')),
    CONSTRAINT valid_status CHECK (status IN ('pending', 'processing', 'completed', 'failed'))
);

-- Indexes for efficient job processing
CREATE INDEX IF NOT EXISTS idx_replication_jobs_status ON replication_jobs(status) WHERE status IN ('pending', 'processing');
CREATE INDEX IF NOT EXISTS idx_replication_jobs_next_retry ON replication_jobs(next_retry_at) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_replication_jobs_tenant ON replication_jobs(tenant_id);
CREATE INDEX IF NOT EXISTS idx_replication_jobs_created ON replication_jobs(created_at);
CREATE INDEX IF NOT EXISTS idx_replication_jobs_storage_path ON replication_jobs(storage_path);

-- Prevent duplicate pending jobs for the same storage_path and operation
CREATE UNIQUE INDEX IF NOT EXISTS idx_replication_jobs_unique_pending 
ON replication_jobs(storage_path, operation) 
WHERE status IN ('pending', 'processing');

COMMENT ON TABLE replication_jobs IS 'Tracks async replication of files to secondary S3-compatible storage';
COMMENT ON COLUMN replication_jobs.storage_path IS 'S3 key (path) of the object to replicate';
COMMENT ON COLUMN replication_jobs.operation IS 'upload = copy to secondary, delete = remove from secondary (mirror mode)';
COMMENT ON COLUMN replication_jobs.status IS 'pending = queued, processing = in progress, completed = done, failed = gave up after max retries';

