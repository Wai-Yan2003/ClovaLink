-- ============================================================================
-- ClovaLink Database Schema v1.0
-- Multi-Tenant File Management & Compliance Platform
-- ============================================================================
-- This consolidated schema includes all tables, indexes, functions, and triggers
-- for a complete ClovaLink deployment.
-- ============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- CORE TABLES
-- ============================================================================

-- Tenants/Companies table
CREATE TABLE IF NOT EXISTS tenants (
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
    -- Data export setting (GDPR)
    data_export_enabled BOOLEAN DEFAULT true,
    -- Blocked file extensions
    blocked_extensions TEXT[] DEFAULT ARRAY[]::TEXT[],
    -- Password policy (per-tenant)
    password_policy JSONB DEFAULT '{
        "min_length": 8,
        "require_uppercase": true,
        "require_lowercase": true,
        "require_number": true,
        "require_special": false,
        "max_age_days": null,
        "prevent_reuse": 0
    }'::jsonb,
    -- IP restrictions (per-tenant)
    ip_allowlist TEXT[] DEFAULT '{}',
    ip_blocklist TEXT[] DEFAULT '{}',
    ip_restriction_mode VARCHAR(20) DEFAULT 'disabled',
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Departments table
CREATE TABLE IF NOT EXISTS departments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, name)
);

-- Roles table
CREATE TABLE IF NOT EXISTS roles (
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
CREATE TABLE IF NOT EXISTS role_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission VARCHAR(100) NOT NULL,
    granted BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(role_id, permission)
);

-- Users table
CREATE TABLE IF NOT EXISTS users (
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
CREATE TABLE IF NOT EXISTS user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    fingerprint_hash VARCHAR(64),
    device_info TEXT,
    ip_address INET,
    last_active_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    is_revoked BOOLEAN DEFAULT false
);

-- User preferences table
CREATE TABLE IF NOT EXISTS user_preferences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    starred_files TEXT[] DEFAULT '{}',
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id)
);

-- Password reset tokens table
CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- FILE MANAGEMENT TABLES
-- ============================================================================

-- Files metadata table
CREATE TABLE IF NOT EXISTS files_metadata (
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
CREATE TABLE IF NOT EXISTS file_shares (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    file_id UUID NOT NULL REFERENCES files_metadata(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    token VARCHAR(32) UNIQUE NOT NULL,
    created_by UUID NOT NULL REFERENCES users(id),
    is_public BOOLEAN NOT NULL DEFAULT false,
    is_directory BOOLEAN NOT NULL DEFAULT false,
    share_policy VARCHAR(20) DEFAULT 'permissioned',
    expires_at TIMESTAMPTZ,
    download_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- File requests table
CREATE TABLE IF NOT EXISTS file_requests (
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
CREATE TABLE IF NOT EXISTS file_request_uploads (
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
CREATE TABLE IF NOT EXISTS audit_logs (
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
CREATE TABLE IF NOT EXISTS audit_settings (
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
CREATE TABLE IF NOT EXISTS user_consent (
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
CREATE TABLE IF NOT EXISTS deletion_requests (
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
CREATE TABLE IF NOT EXISTS file_exports (
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
-- SECURITY TABLES
-- ============================================================================

-- Security alerts table
CREATE TABLE IF NOT EXISTS security_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    alert_type VARCHAR(50) NOT NULL,
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('critical', 'high', 'medium', 'low')),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    metadata JSONB DEFAULT '{}',
    ip_address INET,
    resolved BOOLEAN DEFAULT FALSE,
    resolved_by UUID REFERENCES users(id) ON DELETE SET NULL,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- User login history (for new IP detection)
CREATE TABLE IF NOT EXISTS user_login_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    ip_address INET NOT NULL,
    user_agent TEXT,
    first_seen_at TIMESTAMPTZ DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ DEFAULT NOW(),
    login_count INTEGER DEFAULT 1,
    UNIQUE(user_id, ip_address)
);

-- Failed login attempts (for brute force detection)
CREATE TABLE IF NOT EXISTS failed_login_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL,
    ip_address INET,
    attempted_at TIMESTAMPTZ DEFAULT NOW(),
    reason VARCHAR(100)
);

-- ============================================================================
-- NOTIFICATIONS TABLES
-- ============================================================================

-- Notifications table
CREATE TABLE IF NOT EXISTS notifications (
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
CREATE TABLE IF NOT EXISTS notification_preferences (
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
CREATE TABLE IF NOT EXISTS tenant_notification_settings (
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
-- EMAIL TEMPLATES TABLES
-- ============================================================================

-- Global default email templates (managed by SuperAdmin)
CREATE TABLE IF NOT EXISTS email_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_key VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    subject VARCHAR(255) NOT NULL,
    body_html TEXT NOT NULL,
    body_text TEXT,
    variables JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Per-tenant email template overrides
CREATE TABLE IF NOT EXISTS tenant_email_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    template_key VARCHAR(50) NOT NULL,
    subject VARCHAR(255) NOT NULL,
    body_html TEXT NOT NULL,
    body_text TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, template_key)
);

-- ============================================================================
-- EXTENSIONS TABLES
-- ============================================================================

-- Extensions table
CREATE TABLE IF NOT EXISTS extensions (
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
CREATE TABLE IF NOT EXISTS extension_versions (
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
CREATE TABLE IF NOT EXISTS extension_installations (
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
CREATE TABLE IF NOT EXISTS extension_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    installation_id UUID NOT NULL REFERENCES extension_installations(id) ON DELETE CASCADE,
    permission VARCHAR(100) NOT NULL,
    granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(installation_id, permission)
);

-- Extension event triggers table
CREATE TABLE IF NOT EXISTS extension_event_triggers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    extension_id UUID NOT NULL REFERENCES extensions(id) ON DELETE CASCADE,
    event_type VARCHAR(100) NOT NULL,
    filter_config JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Automation jobs table
CREATE TABLE IF NOT EXISTS automation_jobs (
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
CREATE TABLE IF NOT EXISTS extension_webhook_logs (
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
-- API USAGE TRACKING TABLES
-- ============================================================================

-- Raw API usage metrics
CREATE TABLE IF NOT EXISTS api_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id) ON DELETE SET NULL,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    endpoint VARCHAR(255) NOT NULL,
    method VARCHAR(10) NOT NULL,
    status_code INT NOT NULL,
    response_time_ms INT NOT NULL,
    request_size_bytes BIGINT DEFAULT 0,
    response_size_bytes BIGINT DEFAULT 0,
    ip_address TEXT,
    user_agent TEXT,
    error_message TEXT,  -- Captured from error responses (status >= 400)
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add error_message column if it doesn't exist (for existing installations)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='api_usage' AND column_name='error_message') THEN
        ALTER TABLE api_usage ADD COLUMN error_message TEXT;
    END IF;
END $$;

-- Aggregated hourly stats for faster dashboard queries
CREATE TABLE IF NOT EXISTS api_usage_hourly (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id) ON DELETE SET NULL,
    hour_bucket TIMESTAMPTZ NOT NULL,
    endpoint VARCHAR(255) NOT NULL,
    method VARCHAR(10) NOT NULL,
    request_count BIGINT NOT NULL DEFAULT 0,
    error_count BIGINT NOT NULL DEFAULT 0,
    total_response_time_ms BIGINT NOT NULL DEFAULT 0,
    avg_response_time_ms INT NOT NULL DEFAULT 0,
    min_response_time_ms INT NOT NULL DEFAULT 0,
    max_response_time_ms INT NOT NULL DEFAULT 0,
    total_request_bytes BIGINT NOT NULL DEFAULT 0,
    total_response_bytes BIGINT NOT NULL DEFAULT 0,
    UNIQUE(tenant_id, hour_bucket, endpoint, method)
);

-- ============================================================================
-- GLOBAL SETTINGS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS global_settings (
    key VARCHAR(100) PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_by UUID REFERENCES users(id)
);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Users indexes
CREATE INDEX IF NOT EXISTS idx_users_tenant ON users(tenant_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
CREATE INDEX IF NOT EXISTS idx_users_suspension ON users(suspended_at, suspended_until) WHERE suspended_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_widget_config ON users USING GIN (widget_config);
CREATE INDEX IF NOT EXISTS idx_users_allowed_depts ON users USING GIN (allowed_department_ids);

-- User sessions indexes
CREATE INDEX IF NOT EXISTS idx_user_sessions_user ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_token ON user_sessions(token_hash);
CREATE INDEX IF NOT EXISTS idx_user_sessions_expires ON user_sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_user_sessions_active ON user_sessions(user_id) WHERE is_revoked = false;
CREATE INDEX IF NOT EXISTS idx_user_sessions_fingerprint ON user_sessions(fingerprint_hash) WHERE fingerprint_hash IS NOT NULL;

-- Password reset tokens indexes
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_user_id ON password_reset_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_expires_at ON password_reset_tokens(expires_at);

-- Files indexes
CREATE INDEX IF NOT EXISTS idx_files_metadata_tenant ON files_metadata(tenant_id);
CREATE INDEX IF NOT EXISTS idx_files_metadata_parent ON files_metadata(parent_path);
CREATE INDEX IF NOT EXISTS idx_files_metadata_deleted ON files_metadata(is_deleted);
CREATE INDEX IF NOT EXISTS idx_files_metadata_department ON files_metadata(department_id);
CREATE INDEX IF NOT EXISTS idx_files_metadata_visibility ON files_metadata(visibility);
CREATE INDEX IF NOT EXISTS idx_files_metadata_private_owner ON files_metadata(visibility, owner_id) WHERE visibility = 'private';
CREATE INDEX IF NOT EXISTS idx_files_metadata_locked ON files_metadata(is_locked) WHERE is_locked = true;
CREATE INDEX IF NOT EXISTS idx_files_metadata_version_parent ON files_metadata(version_parent_id);
CREATE INDEX IF NOT EXISTS idx_files_parent_size ON files_metadata(parent_path, size_bytes) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_files_content_dedup ON files_metadata(tenant_id, department_id, content_hash) WHERE is_deleted = false AND is_directory = false AND content_hash IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_files_ulid ON files_metadata(ulid) WHERE ulid IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_files_storage_path_refs ON files_metadata(storage_path) WHERE is_deleted = false AND is_directory = false;

-- File shares indexes
CREATE INDEX IF NOT EXISTS idx_file_shares_token ON file_shares(token);
CREATE INDEX IF NOT EXISTS idx_file_shares_file_id ON file_shares(file_id);
CREATE INDEX IF NOT EXISTS idx_file_shares_tenant_id ON file_shares(tenant_id);
CREATE INDEX IF NOT EXISTS idx_file_shares_share_policy ON file_shares(share_policy);

-- File requests indexes
CREATE INDEX IF NOT EXISTS idx_file_requests_tenant ON file_requests(tenant_id);
CREATE INDEX IF NOT EXISTS idx_file_requests_token ON file_requests(token);
CREATE INDEX IF NOT EXISTS idx_file_requests_status ON file_requests(status);
CREATE INDEX IF NOT EXISTS idx_file_requests_expires ON file_requests(expires_at);
CREATE INDEX IF NOT EXISTS idx_file_requests_department ON file_requests(department_id);
CREATE INDEX IF NOT EXISTS idx_file_requests_visibility ON file_requests(visibility);
CREATE INDEX IF NOT EXISTS idx_file_requests_private_creator ON file_requests(visibility, created_by) WHERE visibility = 'private';
CREATE INDEX IF NOT EXISTS idx_file_request_uploads_file ON file_request_uploads(file_metadata_id);

-- Audit indexes
CREATE INDEX IF NOT EXISTS idx_audit_logs_tenant ON audit_logs(tenant_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_settings_tenant ON audit_settings(tenant_id);

-- Compliance indexes
CREATE INDEX IF NOT EXISTS idx_user_consent_user ON user_consent(user_id);
CREATE INDEX IF NOT EXISTS idx_user_consent_tenant ON user_consent(tenant_id);
CREATE INDEX IF NOT EXISTS idx_user_consent_type ON user_consent(consent_type);
CREATE INDEX IF NOT EXISTS idx_deletion_requests_tenant ON deletion_requests(tenant_id);
CREATE INDEX IF NOT EXISTS idx_deletion_requests_status ON deletion_requests(status);
CREATE INDEX IF NOT EXISTS idx_deletion_requests_user ON deletion_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_file_exports_tenant ON file_exports(tenant_id);
CREATE INDEX IF NOT EXISTS idx_file_exports_user ON file_exports(user_id);

-- Security indexes
CREATE INDEX IF NOT EXISTS idx_security_alerts_tenant_id ON security_alerts(tenant_id);
CREATE INDEX IF NOT EXISTS idx_security_alerts_user_id ON security_alerts(user_id);
CREATE INDEX IF NOT EXISTS idx_security_alerts_type ON security_alerts(alert_type);
CREATE INDEX IF NOT EXISTS idx_security_alerts_severity ON security_alerts(severity);
CREATE INDEX IF NOT EXISTS idx_security_alerts_resolved ON security_alerts(resolved);
CREATE INDEX IF NOT EXISTS idx_security_alerts_created_at ON security_alerts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_login_history_user_id ON user_login_history(user_id);
CREATE INDEX IF NOT EXISTS idx_failed_login_attempts_email ON failed_login_attempts(email);
CREATE INDEX IF NOT EXISTS idx_failed_login_attempts_ip ON failed_login_attempts(ip_address);
CREATE INDEX IF NOT EXISTS idx_failed_login_attempts_time ON failed_login_attempts(attempted_at DESC);

-- Notifications indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_tenant_id ON notifications(tenant_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications(user_id, is_read) WHERE is_read = false;
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(notification_type);
CREATE INDEX IF NOT EXISTS idx_notification_preferences_user_id ON notification_preferences(user_id);
CREATE INDEX IF NOT EXISTS idx_tenant_notification_settings_tenant ON tenant_notification_settings(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tenant_notification_settings_role ON tenant_notification_settings(tenant_id, role);

-- Email templates indexes
CREATE INDEX IF NOT EXISTS idx_tenant_email_templates_tenant_id ON tenant_email_templates(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tenant_email_templates_key ON tenant_email_templates(template_key);

-- Roles indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_roles_tenant_name ON roles(COALESCE(tenant_id, '00000000-0000-0000-0000-000000000000'::uuid), name);
CREATE INDEX IF NOT EXISTS idx_roles_tenant ON roles(tenant_id);
CREATE INDEX IF NOT EXISTS idx_roles_base_role ON roles(base_role);
CREATE INDEX IF NOT EXISTS idx_role_permissions_role ON role_permissions(role_id);

-- Extensions indexes
CREATE INDEX IF NOT EXISTS idx_extensions_tenant ON extensions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_extensions_type ON extensions(extension_type);
CREATE INDEX IF NOT EXISTS idx_extensions_status ON extensions(status);
CREATE INDEX IF NOT EXISTS idx_extensions_allowed_tenants ON extensions USING GIN (allowed_tenant_ids);
CREATE INDEX IF NOT EXISTS idx_extension_versions_extension ON extension_versions(extension_id);
CREATE INDEX IF NOT EXISTS idx_extension_versions_current ON extension_versions(extension_id) WHERE is_current = true;
CREATE INDEX IF NOT EXISTS idx_ext_installations_tenant ON extension_installations(tenant_id);
CREATE INDEX IF NOT EXISTS idx_ext_installations_extension ON extension_installations(extension_id);
CREATE INDEX IF NOT EXISTS idx_ext_installations_enabled ON extension_installations(tenant_id) WHERE enabled = true;
CREATE INDEX IF NOT EXISTS idx_ext_permissions_installation ON extension_permissions(installation_id);
CREATE INDEX IF NOT EXISTS idx_ext_event_triggers_extension ON extension_event_triggers(extension_id);
CREATE INDEX IF NOT EXISTS idx_ext_event_triggers_type ON extension_event_triggers(event_type);
CREATE INDEX IF NOT EXISTS idx_automation_jobs_next_run ON automation_jobs(next_run_at) WHERE enabled = true;
CREATE INDEX IF NOT EXISTS idx_automation_jobs_tenant ON automation_jobs(tenant_id);
CREATE INDEX IF NOT EXISTS idx_automation_jobs_extension ON automation_jobs(extension_id);
CREATE INDEX IF NOT EXISTS idx_webhook_logs_extension ON extension_webhook_logs(extension_id);
CREATE INDEX IF NOT EXISTS idx_webhook_logs_tenant ON extension_webhook_logs(tenant_id);
CREATE INDEX IF NOT EXISTS idx_webhook_logs_created ON extension_webhook_logs(created_at);

-- API usage indexes
CREATE INDEX IF NOT EXISTS idx_api_usage_tenant_created ON api_usage(tenant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_api_usage_user_created ON api_usage(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_api_usage_endpoint_created ON api_usage(endpoint, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_api_usage_created_at ON api_usage(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_api_usage_status_code ON api_usage(status_code) WHERE status_code >= 400;
CREATE INDEX IF NOT EXISTS idx_api_usage_hourly_tenant_hour ON api_usage_hourly(tenant_id, hour_bucket DESC);
CREATE INDEX IF NOT EXISTS idx_api_usage_hourly_hour ON api_usage_hourly(hour_bucket DESC);
CREATE INDEX IF NOT EXISTS idx_api_usage_hourly_endpoint ON api_usage_hourly(endpoint, hour_bucket DESC);

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

-- Aggregate hourly API usage stats
CREATE OR REPLACE FUNCTION aggregate_api_usage_hourly()
RETURNS void AS $$
DECLARE
    last_hour TIMESTAMPTZ;
BEGIN
    last_hour := date_trunc('hour', NOW() - INTERVAL '1 hour');
    
    INSERT INTO api_usage_hourly (
        tenant_id, hour_bucket, endpoint, method,
        request_count, error_count, total_response_time_ms,
        avg_response_time_ms, min_response_time_ms, max_response_time_ms,
        total_request_bytes, total_response_bytes
    )
    SELECT 
        tenant_id,
        date_trunc('hour', created_at) as hour_bucket,
        endpoint,
        method,
        COUNT(*) as request_count,
        COUNT(*) FILTER (WHERE status_code >= 400) as error_count,
        SUM(response_time_ms) as total_response_time_ms,
        AVG(response_time_ms)::INT as avg_response_time_ms,
        MIN(response_time_ms) as min_response_time_ms,
        MAX(response_time_ms) as max_response_time_ms,
        COALESCE(SUM(request_size_bytes), 0) as total_request_bytes,
        COALESCE(SUM(response_size_bytes), 0) as total_response_bytes
    FROM api_usage
    WHERE created_at >= last_hour 
      AND created_at < last_hour + INTERVAL '1 hour'
    GROUP BY tenant_id, date_trunc('hour', created_at), endpoint, method
    ON CONFLICT (tenant_id, hour_bucket, endpoint, method)
    DO UPDATE SET
        request_count = api_usage_hourly.request_count + EXCLUDED.request_count,
        error_count = api_usage_hourly.error_count + EXCLUDED.error_count,
        total_response_time_ms = api_usage_hourly.total_response_time_ms + EXCLUDED.total_response_time_ms,
        avg_response_time_ms = ((api_usage_hourly.total_response_time_ms + EXCLUDED.total_response_time_ms) / 
                                (api_usage_hourly.request_count + EXCLUDED.request_count))::INT,
        min_response_time_ms = LEAST(api_usage_hourly.min_response_time_ms, EXCLUDED.min_response_time_ms),
        max_response_time_ms = GREATEST(api_usage_hourly.max_response_time_ms, EXCLUDED.max_response_time_ms),
        total_request_bytes = api_usage_hourly.total_request_bytes + EXCLUDED.total_request_bytes,
        total_response_bytes = api_usage_hourly.total_response_bytes + EXCLUDED.total_response_bytes;
END;
$$ LANGUAGE plpgsql;

-- Cleanup old API usage data (keep 7 days of detailed logs)
CREATE OR REPLACE FUNCTION cleanup_old_api_usage()
RETURNS void AS $$
BEGIN
    DELETE FROM api_usage WHERE created_at < NOW() - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql;

-- Cleanup old failed login attempts (keep 24 hours)
CREATE OR REPLACE FUNCTION cleanup_failed_login_attempts()
RETURNS void AS $$
BEGIN
    DELETE FROM failed_login_attempts WHERE attempted_at < NOW() - INTERVAL '24 hours';
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at (using DROP IF EXISTS + CREATE for idempotency)
DROP TRIGGER IF EXISTS update_tenants_updated_at ON tenants;
CREATE TRIGGER update_tenants_updated_at BEFORE UPDATE ON tenants
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_file_requests_updated_at ON file_requests;
CREATE TRIGGER update_file_requests_updated_at BEFORE UPDATE ON file_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_files_metadata_updated_at ON files_metadata;
CREATE TRIGGER update_files_metadata_updated_at BEFORE UPDATE ON files_metadata
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_user_preferences_updated_at ON user_preferences;
CREATE TRIGGER update_user_preferences_updated_at BEFORE UPDATE ON user_preferences
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_roles_updated_at ON roles;
CREATE TRIGGER update_roles_updated_at BEFORE UPDATE ON roles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_audit_settings_updated_at ON audit_settings;
CREATE TRIGGER update_audit_settings_updated_at BEFORE UPDATE ON audit_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_user_consent_updated_at ON user_consent;
CREATE TRIGGER update_user_consent_updated_at BEFORE UPDATE ON user_consent
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_deletion_requests_updated_at ON deletion_requests;
CREATE TRIGGER update_deletion_requests_updated_at BEFORE UPDATE ON deletion_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_extensions_updated_at ON extensions;
CREATE TRIGGER update_extensions_updated_at BEFORE UPDATE ON extensions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_automation_jobs_updated_at ON automation_jobs;
CREATE TRIGGER update_automation_jobs_updated_at BEFORE UPDATE ON automation_jobs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS ensure_single_current_version_trigger ON extension_versions;
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
-- COMMENTS (Documentation)
-- ============================================================================

COMMENT ON TABLE tenants IS 'Companies/organizations using the platform';
COMMENT ON TABLE users IS 'User accounts with tenant association and RBAC';
COMMENT ON TABLE files_metadata IS 'File and folder metadata with versioning support';
COMMENT ON TABLE file_shares IS 'Share tokens for secure file sharing without exposing UUIDs';
COMMENT ON TABLE audit_logs IS 'Compliance and security audit trail';
COMMENT ON TABLE notifications IS 'In-app and email notifications';
COMMENT ON TABLE extensions IS 'Registered extensions (UI, file processors, automation)';
COMMENT ON TABLE global_settings IS 'App-wide settings managed by SuperAdmin';
COMMENT ON TABLE security_alerts IS 'Centralized security alerts for unusual activity monitoring';
COMMENT ON TABLE api_usage IS 'Stores raw API request metrics for analysis';
COMMENT ON TABLE api_usage_hourly IS 'Hourly aggregated API metrics for dashboard';
COMMENT ON TABLE password_reset_tokens IS 'Stores password reset tokens for email-based password resets';
COMMENT ON TABLE failed_login_attempts IS 'Tracks failed login attempts for brute force detection';

COMMENT ON COLUMN files_metadata.content_hash IS 'Blake3 hash of file content for per-department deduplication';
COMMENT ON COLUMN files_metadata.ulid IS 'ULID identifier - time-ordered, sortable alternative to UUID';
COMMENT ON COLUMN files_metadata.visibility IS 'department = shared with department, private = owner-only';
COMMENT ON COLUMN file_shares.is_public IS 'If true, anyone with link can download; if false, must be logged in';
COMMENT ON COLUMN file_shares.share_policy IS 'Share access policy: "permissioned" (default) requires user to pass can_access_file check, "tenant_wide" allows any user in the tenant';
COMMENT ON COLUMN users.allowed_department_ids IS 'Additional departments user can access beyond primary';
COMMENT ON COLUMN users.allowed_tenant_ids IS 'Additional tenants user can access (for SuperAdmin)';
COMMENT ON COLUMN tenants.data_export_enabled IS 'When true, users can export their personal data from their profile page';
COMMENT ON COLUMN tenants.blocked_extensions IS 'Array of file extensions that are blocked from upload (without the dot, e.g., exe, bat, sh)';
COMMENT ON COLUMN tenants.password_policy IS 'JSON object with password requirements: min_length, require_uppercase, require_lowercase, require_number, require_special, max_age_days, prevent_reuse';
COMMENT ON COLUMN tenants.ip_allowlist IS 'Array of allowed IP addresses/CIDR ranges';
COMMENT ON COLUMN tenants.ip_blocklist IS 'Array of blocked IP addresses/CIDR ranges';
COMMENT ON COLUMN tenants.ip_restriction_mode IS 'IP restriction mode: disabled, allowlist_only, blocklist_only, or both';
COMMENT ON COLUMN security_alerts.alert_type IS 'Type of alert: failed_login_spike, new_ip_login, permission_escalation, suspended_access_attempt, bulk_download, blocked_extension_attempt, excessive_sharing, account_lockout';
COMMENT ON COLUMN security_alerts.severity IS 'Alert severity: critical, high, medium, low';


