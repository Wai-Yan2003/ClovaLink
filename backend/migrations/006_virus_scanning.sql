-- Virus Scanning Feature
-- Per-tenant configuration, job queue, and scan results

-- Per-tenant virus scan settings
CREATE TABLE IF NOT EXISTS virus_scan_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    enabled BOOLEAN NOT NULL DEFAULT true,
    file_types TEXT[] DEFAULT '{}', -- Empty means scan all files
    max_file_size_mb INTEGER DEFAULT 100, -- Skip files larger than this
    action_on_detect VARCHAR(20) NOT NULL DEFAULT 'quarantine', -- 'delete', 'quarantine', 'flag'
    notify_admin BOOLEAN NOT NULL DEFAULT true,
    notify_uploader BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id)
);

-- Virus scan job queue
CREATE TABLE IF NOT EXISTS virus_scan_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    file_id UUID NOT NULL REFERENCES files_metadata(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- 'pending', 'scanning', 'completed', 'failed', 'skipped'
    priority INTEGER NOT NULL DEFAULT 0, -- Higher = more urgent
    retry_count INTEGER NOT NULL DEFAULT 0,
    last_attempt_at TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Virus scan results and metrics
CREATE TABLE IF NOT EXISTS virus_scan_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    file_id UUID NOT NULL REFERENCES files_metadata(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    scan_job_id UUID REFERENCES virus_scan_jobs(id) ON DELETE SET NULL,
    is_infected BOOLEAN NOT NULL DEFAULT false,
    threat_name TEXT, -- Name of detected virus/malware
    file_size_bytes BIGINT NOT NULL,
    scan_duration_ms INTEGER NOT NULL, -- For performance metrics
    scanner_version TEXT, -- ClamAV version
    signature_version TEXT, -- Virus definition version
    action_taken VARCHAR(20), -- 'deleted', 'quarantined', 'flagged', 'none'
    scanned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    scanned_by TEXT DEFAULT 'clamav' -- Scanner identifier
);

-- Quarantined files (for 'quarantine' action)
CREATE TABLE IF NOT EXISTS quarantined_files (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    original_file_id UUID NOT NULL, -- Don't FK since file may be deleted
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    original_filename TEXT NOT NULL,
    original_path TEXT NOT NULL,
    storage_path TEXT NOT NULL, -- Where quarantined file is stored
    threat_name TEXT NOT NULL,
    quarantined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    quarantined_by UUID REFERENCES users(id), -- System or user who triggered
    released_at TIMESTAMPTZ, -- If admin releases the file
    released_by UUID REFERENCES users(id),
    permanently_deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES users(id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_virus_scan_jobs_status ON virus_scan_jobs(status);
CREATE INDEX IF NOT EXISTS idx_virus_scan_jobs_tenant ON virus_scan_jobs(tenant_id);
CREATE INDEX IF NOT EXISTS idx_virus_scan_jobs_pending ON virus_scan_jobs(created_at) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_virus_scan_results_tenant ON virus_scan_results(tenant_id);
CREATE INDEX IF NOT EXISTS idx_virus_scan_results_infected ON virus_scan_results(tenant_id, is_infected) WHERE is_infected = true;
CREATE INDEX IF NOT EXISTS idx_virus_scan_results_scanned_at ON virus_scan_results(scanned_at DESC);
CREATE INDEX IF NOT EXISTS idx_quarantined_files_tenant ON quarantined_files(tenant_id);

-- Add scan_status to files_metadata table
ALTER TABLE files_metadata ADD COLUMN IF NOT EXISTS scan_status VARCHAR(20) DEFAULT 'pending';
-- 'pending', 'clean', 'infected', 'skipped', 'error'

-- Index for finding unscanned files
CREATE INDEX IF NOT EXISTS idx_files_scan_status ON files_metadata(scan_status) WHERE scan_status = 'pending';


