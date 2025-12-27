-- ============================================================================
-- ClovaLink Database Schema v1.0
-- Multi-Tenant File Management & Compliance Platform
-- ============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- CORE TABLES
-- ============================================================================

-- Tenants/Companies table
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    domain VARCHAR(255) UNIQUE NOT NULL,
    plan VARCHAR(50) NOT NULL DEFAULT 'Starter',
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    compliance_mode VARCHAR(50) NOT NULL DEFAULT 'Standard',
    encryption_standard VARCHAR(100) NOT NULL DEFAULT 'ChaCha20-Poly1305',
    storage_quota_bytes BIGINT,
    storage_used_bytes BIGINT DEFAULT 0,
    retention_policy_days INTEGER NOT NULL DEFAULT 30,
    max_upload_size_bytes BIGINT DEFAULT 1073741824,
    -- SMTP Configuration
    smtp_host TEXT,
    smtp_port INTEGER,
    smtp_username TEXT,
    smtp_password TEXT,
    smtp_from TEXT,
    smtp_secure BOOLEAN DEFAULT true,
    -- Auth settings
    enable_totp BOOLEAN DEFAULT false,
    enable_passkeys BOOLEAN DEFAULT false,
    -- Compliance settings
    mfa_required BOOLEAN DEFAULT false,
    session_timeout_minutes INTEGER DEFAULT 30,
    public_sharing_enabled BOOLEAN DEFAULT true,
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Departments table
CREATE TABLE departments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, name)
);

-- Roles table
CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    base_role VARCHAR(50) NOT NULL,
    is_system BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Role permissions table
CREATE TABLE role_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission VARCHAR(100) NOT NULL,
    granted BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(role_id, permission)
);

-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
    custom_role_id UUID REFERENCES roles(id) ON DELETE SET NULL,
    email VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'Employee',
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    avatar_url TEXT,
    -- Multi-access
    allowed_tenant_ids UUID[],
    allowed_department_ids UUID[],
    -- Auth
    totp_secret TEXT,
    recovery_token TEXT,
    recovery_token_expires_at TIMESTAMPTZ,
    password_changed_at TIMESTAMPTZ,
    -- Suspension
    suspended_at TIMESTAMPTZ,
    suspended_until TIMESTAMPTZ,
    suspension_reason TEXT,
    -- Dashboard/Widget config
    dashboard_layout JSONB,
    widget_config JSONB DEFAULT '{
        "visible_widgets": ["stats-1", "stats-2", "stats-3", "stats-4", "activity", "requests", "storage", "departments"],
        "widget_settings": {},
        "custom_widgets": []
    }'::jsonb,
    -- Timestamps
    last_active_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, email)
);

-- User sessions table
CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    device_info TEXT,
    ip_address INET,
    last_active_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    is_revoked BOOLEAN DEFAULT false
);

-- User preferences table
CREATE TABLE user_preferences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    starred_files TEXT[] DEFAULT '{}',
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id)
);

-- ============================================================================
-- FILE MANAGEMENT TABLES
-- ============================================================================

-- Files metadata table
CREATE TABLE files_metadata (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    storage_path TEXT NOT NULL,
    size_bytes BIGINT NOT NULL,
    content_type VARCHAR(255),
    is_directory BOOLEAN NOT NULL DEFAULT false,
    owner_id UUID REFERENCES users(id),
    parent_path TEXT,
    visibility VARCHAR(20) NOT NULL DEFAULT 'department',
    is_company_folder BOOLEAN DEFAULT FALSE,
    -- Versioning (for SOX compliance)
    version INTEGER DEFAULT 1,
    version_parent_id UUID REFERENCES files_metadata(id),
    is_immutable BOOLEAN DEFAULT false,
    -- Locking
    is_locked BOOLEAN NOT NULL DEFAULT false,
    locked_by UUID REFERENCES users(id) ON DELETE SET NULL,
    locked_at TIMESTAMPTZ,
    lock_password_hash VARCHAR(255),
    lock_requires_role VARCHAR(50),
    -- Content-addressed storage
    content_hash VARCHAR(64),
    ulid VARCHAR(26),
    -- Soft delete
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    deleted_at TIMESTAMPTZ,
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- File shares table
CREATE TABLE file_shares (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    file_id UUID NOT NULL REFERENCES files_metadata(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    token VARCHAR(32) UNIQUE NOT NULL,
    created_by UUID NOT NULL REFERENCES users(id),
    is_public BOOLEAN NOT NULL DEFAULT false,
    is_directory BOOLEAN NOT NULL DEFAULT false,
    expires_at TIMESTAMPTZ,
    download_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- File requests table
CREATE TABLE file_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    destination_path TEXT NOT NULL,
    token VARCHAR(255) UNIQUE NOT NULL,
    created_by UUID NOT NULL REFERENCES users(id),
    expires_at TIMESTAMPTZ NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    visibility VARCHAR(20) NOT NULL DEFAULT 'department',
    upload_count INTEGER NOT NULL DEFAULT 0,
    max_uploads INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- File request uploads table
CREATE TABLE file_request_uploads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    file_request_id UUID NOT NULL REFERENCES file_requests(id) ON DELETE CASCADE,
    file_metadata_id UUID REFERENCES files_metadata(id) ON DELETE SET NULL,
    filename VARCHAR(255) NOT NULL,
    original_filename VARCHAR(255) NOT NULL,
    size_bytes BIGINT NOT NULL,
    content_type VARCHAR(255),
    storage_path TEXT NOT NULL,
    uploaded_by_email VARCHAR(255),
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- COMPLIANCE & AUDIT TABLES
-- ============================================================================

-- Audit logs table
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id),
    action VARCHAR(255) NOT NULL,
    resource_type VARCHAR(100) NOT NULL,
    resource_id UUID,
    metadata JSONB,
    ip_address INET,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Audit settings table
CREATE TABLE audit_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    log_logins BOOLEAN DEFAULT true,
    log_file_operations BOOLEAN DEFAULT true,
    log_user_changes BOOLEAN DEFAULT true,
    log_settings_changes BOOLEAN DEFAULT true,
    log_role_changes BOOLEAN DEFAULT true,
    retention_days INTEGER DEFAULT 90,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id)
);

-- User consent table (GDPR)
CREATE TABLE user_consent (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    consent_type VARCHAR(100) NOT NULL,
    granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Deletion requests table (GDPR)
CREATE TABLE deletion_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    requested_by UUID NOT NULL REFERENCES users(id),
    request_type VARCHAR(50) NOT NULL DEFAULT 'user_data',
    resource_id UUID,
    reason TEXT,
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    rejection_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- File exports table (GDPR tracking)
CREATE TABLE file_exports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    file_id UUID REFERENCES files_metadata(id) ON DELETE SET NULL,
    export_type VARCHAR(50) NOT NULL,
    file_count INTEGER DEFAULT 1,
    total_size_bytes BIGINT,
    exported_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ip_address INET,
    metadata JSONB
);

-- ============================================================================
-- NOTIFICATIONS TABLES
-- ============================================================================

-- Notifications table
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    notification_type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',
    is_read BOOLEAN NOT NULL DEFAULT false,
    email_sent BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Notification preferences table
CREATE TABLE notification_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_type VARCHAR(50) NOT NULL,
    email_enabled BOOLEAN NOT NULL DEFAULT true,
    in_app_enabled BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, event_type)
);

-- Tenant notification settings table
CREATE TABLE tenant_notification_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    event_type VARCHAR(50) NOT NULL,
    role VARCHAR(50) DEFAULT NULL,
    enabled BOOLEAN NOT NULL DEFAULT true,
    email_enforced BOOLEAN NOT NULL DEFAULT false,
    in_app_enforced BOOLEAN NOT NULL DEFAULT false,
    default_email BOOLEAN NOT NULL DEFAULT true,
    default_in_app BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT tenant_notification_settings_unique UNIQUE(tenant_id, event_type, role)
);

-- ============================================================================
-- EXTENSIONS TABLES
-- ============================================================================

-- Extensions table
CREATE TABLE extensions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) NOT NULL,
    description TEXT,
    extension_type VARCHAR(50) NOT NULL,
    manifest_url TEXT NOT NULL,
    webhook_url TEXT,
    public_key TEXT,
    signature_algorithm VARCHAR(20) NOT NULL DEFAULT 'hmac_sha256',
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    allowed_tenant_ids UUID[] DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, slug)
);

-- Extension versions table
CREATE TABLE extension_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    extension_id UUID NOT NULL REFERENCES extensions(id) ON DELETE CASCADE,
    version VARCHAR(50) NOT NULL,
    manifest JSONB NOT NULL,
    changelog TEXT,
    is_current BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(extension_id, version)
);

-- Extension installations table
CREATE TABLE extension_installations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    extension_id UUID NOT NULL REFERENCES extensions(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    version_id UUID NOT NULL REFERENCES extension_versions(id),
    enabled BOOLEAN NOT NULL DEFAULT true,
    settings JSONB NOT NULL DEFAULT '{}',
    installed_by UUID REFERENCES users(id),
    installed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(extension_id, tenant_id)
);

-- Extension permissions table
CREATE TABLE extension_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    installation_id UUID NOT NULL REFERENCES extension_installations(id) ON DELETE CASCADE,
    permission VARCHAR(100) NOT NULL,
    granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(installation_id, permission)
);

-- Extension event triggers table
CREATE TABLE extension_event_triggers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    extension_id UUID NOT NULL REFERENCES extensions(id) ON DELETE CASCADE,
    event_type VARCHAR(100) NOT NULL,
    filter_config JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Automation jobs table
CREATE TABLE automation_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    extension_id UUID NOT NULL REFERENCES extensions(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    cron_expression VARCHAR(100),
    next_run_at TIMESTAMPTZ NOT NULL,
    last_run_at TIMESTAMPTZ,
    last_status VARCHAR(50),
    last_error TEXT,
    enabled BOOLEAN NOT NULL DEFAULT true,
    config JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Extension webhook logs table
CREATE TABLE extension_webhook_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    extension_id UUID NOT NULL REFERENCES extensions(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    event_type VARCHAR(100) NOT NULL,
    payload JSONB,
    request_headers JSONB,
    response_status INTEGER,
    response_body TEXT,
    duration_ms INTEGER,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- GLOBAL SETTINGS TABLE
-- ============================================================================

CREATE TABLE global_settings (
    key VARCHAR(100) PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES users(id)
);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Users indexes
CREATE INDEX idx_users_tenant ON users(tenant_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_users_suspension ON users(suspended_at, suspended_until) WHERE suspended_at IS NOT NULL;
CREATE INDEX idx_users_widget_config ON users USING GIN (widget_config);
CREATE INDEX idx_users_allowed_depts ON users USING GIN (allowed_department_ids);

-- User sessions indexes
CREATE INDEX idx_user_sessions_user ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_token ON user_sessions(token_hash);
CREATE INDEX idx_user_sessions_expires ON user_sessions(expires_at);
CREATE INDEX idx_user_sessions_active ON user_sessions(user_id) WHERE is_revoked = false;

-- Files indexes
CREATE INDEX idx_files_metadata_tenant ON files_metadata(tenant_id);
CREATE INDEX idx_files_metadata_parent ON files_metadata(parent_path);
CREATE INDEX idx_files_metadata_deleted ON files_metadata(is_deleted);
CREATE INDEX idx_files_metadata_department ON files_metadata(department_id);
CREATE INDEX idx_files_metadata_visibility ON files_metadata(visibility);
CREATE INDEX idx_files_metadata_private_owner ON files_metadata(visibility, owner_id) WHERE visibility = 'private';
CREATE INDEX idx_files_metadata_locked ON files_metadata(is_locked) WHERE is_locked = true;
CREATE INDEX idx_files_metadata_version_parent ON files_metadata(version_parent_id);
CREATE INDEX idx_files_parent_size ON files_metadata(parent_path, size_bytes) WHERE is_deleted = false;
CREATE INDEX idx_files_content_dedup ON files_metadata(tenant_id, department_id, content_hash) WHERE is_deleted = false AND is_directory = false AND content_hash IS NOT NULL;
CREATE UNIQUE INDEX idx_files_ulid ON files_metadata(ulid) WHERE ulid IS NOT NULL;
CREATE INDEX idx_files_storage_path_refs ON files_metadata(storage_path) WHERE is_deleted = false AND is_directory = false;

-- File shares indexes
CREATE INDEX idx_file_shares_token ON file_shares(token);
CREATE INDEX idx_file_shares_file_id ON file_shares(file_id);
CREATE INDEX idx_file_shares_tenant_id ON file_shares(tenant_id);

-- File requests indexes
CREATE INDEX idx_file_requests_tenant ON file_requests(tenant_id);
CREATE INDEX idx_file_requests_token ON file_requests(token);
CREATE INDEX idx_file_requests_status ON file_requests(status);
CREATE INDEX idx_file_requests_expires ON file_requests(expires_at);
CREATE INDEX idx_file_requests_department ON file_requests(department_id);
CREATE INDEX idx_file_requests_visibility ON file_requests(visibility);
CREATE INDEX idx_file_requests_private_creator ON file_requests(visibility, created_by) WHERE visibility = 'private';
CREATE INDEX idx_file_request_uploads_file ON file_request_uploads(file_metadata_id);

-- Audit indexes
CREATE INDEX idx_audit_logs_tenant ON audit_logs(tenant_id);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_settings_tenant ON audit_settings(tenant_id);

-- Compliance indexes
CREATE INDEX idx_user_consent_user ON user_consent(user_id);
CREATE INDEX idx_user_consent_tenant ON user_consent(tenant_id);
CREATE INDEX idx_user_consent_type ON user_consent(consent_type);
CREATE INDEX idx_deletion_requests_tenant ON deletion_requests(tenant_id);
CREATE INDEX idx_deletion_requests_status ON deletion_requests(status);
CREATE INDEX idx_deletion_requests_user ON deletion_requests(user_id);
CREATE INDEX idx_file_exports_tenant ON file_exports(tenant_id);
CREATE INDEX idx_file_exports_user ON file_exports(user_id);

-- Notifications indexes
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_tenant_id ON notifications(tenant_id);
CREATE INDEX idx_notifications_user_unread ON notifications(user_id, is_read) WHERE is_read = false;
CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX idx_notifications_type ON notifications(notification_type);
CREATE INDEX idx_notification_preferences_user_id ON notification_preferences(user_id);
CREATE INDEX idx_tenant_notification_settings_tenant ON tenant_notification_settings(tenant_id);
CREATE INDEX idx_tenant_notification_settings_role ON tenant_notification_settings(tenant_id, role);

-- Roles indexes
CREATE UNIQUE INDEX idx_roles_tenant_name ON roles(COALESCE(tenant_id, '00000000-0000-0000-0000-000000000000'::uuid), name);
CREATE INDEX idx_roles_tenant ON roles(tenant_id);
CREATE INDEX idx_roles_base_role ON roles(base_role);
CREATE INDEX idx_role_permissions_role ON role_permissions(role_id);

-- Extensions indexes
CREATE INDEX idx_extensions_tenant ON extensions(tenant_id);
CREATE INDEX idx_extensions_type ON extensions(extension_type);
CREATE INDEX idx_extensions_status ON extensions(status);
CREATE INDEX idx_extensions_allowed_tenants ON extensions USING GIN (allowed_tenant_ids);
CREATE INDEX idx_extension_versions_extension ON extension_versions(extension_id);
CREATE INDEX idx_extension_versions_current ON extension_versions(extension_id) WHERE is_current = true;
CREATE INDEX idx_ext_installations_tenant ON extension_installations(tenant_id);
CREATE INDEX idx_ext_installations_extension ON extension_installations(extension_id);
CREATE INDEX idx_ext_installations_enabled ON extension_installations(tenant_id) WHERE enabled = true;
CREATE INDEX idx_ext_permissions_installation ON extension_permissions(installation_id);
CREATE INDEX idx_ext_event_triggers_extension ON extension_event_triggers(extension_id);
CREATE INDEX idx_ext_event_triggers_type ON extension_event_triggers(event_type);
CREATE INDEX idx_automation_jobs_next_run ON automation_jobs(next_run_at) WHERE enabled = true;
CREATE INDEX idx_automation_jobs_tenant ON automation_jobs(tenant_id);
CREATE INDEX idx_automation_jobs_extension ON automation_jobs(extension_id);
CREATE INDEX idx_webhook_logs_extension ON extension_webhook_logs(extension_id);
CREATE INDEX idx_webhook_logs_tenant ON extension_webhook_logs(tenant_id);
CREATE INDEX idx_webhook_logs_created ON extension_webhook_logs(created_at);

-- ============================================================================
-- FUNCTIONS & TRIGGERS
-- ============================================================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Ensure only one current version per extension
CREATE OR REPLACE FUNCTION ensure_single_current_version()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_current = true THEN
        UPDATE extension_versions 
        SET is_current = false 
        WHERE extension_id = NEW.extension_id AND id != NEW.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_tenants_updated_at BEFORE UPDATE ON tenants
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_file_requests_updated_at BEFORE UPDATE ON file_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_files_metadata_updated_at BEFORE UPDATE ON files_metadata
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_preferences_updated_at BEFORE UPDATE ON user_preferences
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_roles_updated_at BEFORE UPDATE ON roles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_audit_settings_updated_at BEFORE UPDATE ON audit_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_consent_updated_at BEFORE UPDATE ON user_consent
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_deletion_requests_updated_at BEFORE UPDATE ON deletion_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_extensions_updated_at BEFORE UPDATE ON extensions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_automation_jobs_updated_at BEFORE UPDATE ON automation_jobs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER ensure_single_current_version_trigger
    BEFORE INSERT OR UPDATE ON extension_versions
    FOR EACH ROW EXECUTE FUNCTION ensure_single_current_version();

-- ============================================================================
-- VIEWS
-- ============================================================================

-- View for accessible extensions per tenant
CREATE OR REPLACE VIEW accessible_extensions AS
SELECT 
    e.*,
    t.id as accessor_tenant_id
FROM extensions e
CROSS JOIN tenants t
WHERE 
    e.status = 'active'
    AND (
        e.tenant_id = t.id
        OR t.id = ANY(e.allowed_tenant_ids)
    );

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE tenants IS 'Companies/organizations using the platform';
COMMENT ON TABLE users IS 'User accounts with tenant association and RBAC';
COMMENT ON TABLE files_metadata IS 'File and folder metadata with versioning support';
COMMENT ON TABLE file_shares IS 'Share tokens for secure file sharing without exposing UUIDs';
COMMENT ON TABLE audit_logs IS 'Compliance and security audit trail';
COMMENT ON TABLE notifications IS 'In-app and email notifications';
COMMENT ON TABLE extensions IS 'Registered extensions (UI, file processors, automation)';
COMMENT ON TABLE global_settings IS 'App-wide settings managed by SuperAdmin';

COMMENT ON COLUMN files_metadata.content_hash IS 'Blake3 hash of file content for per-department deduplication';
COMMENT ON COLUMN files_metadata.ulid IS 'ULID identifier - time-ordered, sortable alternative to UUID';
COMMENT ON COLUMN files_metadata.visibility IS 'department = shared with department, private = owner-only';
COMMENT ON COLUMN file_shares.is_public IS 'If true, anyone with link can download; if false, must be logged in';
COMMENT ON COLUMN users.allowed_department_ids IS 'Additional departments user can access beyond primary';
COMMENT ON COLUMN users.allowed_tenant_ids IS 'Additional tenants user can access (for SuperAdmin)';

