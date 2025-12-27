-- ============================================================================
-- ClovaLink Demo Data v1.0
-- Run this migration for development/demo environments
-- Skip for production (create your own admin user instead)
-- ============================================================================

-- ============================================================================
-- GLOBAL SETTINGS
-- ============================================================================

INSERT INTO global_settings (key, value) VALUES
    ('date_format', '"MM/DD/YYYY"'),
    ('time_format', '"12h"'),
    ('timezone', '"America/New_York"'),
    ('footer_attribution', '"An open source project by ClovaLink.org"'),
    ('footer_disclaimer', '"ClovaLink is provided \"as is\" without warranty of any kind. The authors and contributors are not liable for any damages arising from use of this software."'),
    ('app_name', '"ClovaLink"'),
    ('tos_content', '""'),
    ('privacy_content', '""'),
    ('help_content', '""'),
    ('maintenance_mode', '"false"'),
    ('maintenance_message', '"The system is currently undergoing maintenance. We will be back shortly!"')
ON CONFLICT (key) DO NOTHING;

-- ============================================================================
-- SYSTEM ROLES
-- ============================================================================

INSERT INTO roles (id, tenant_id, name, description, base_role, is_system) VALUES
    ('10000000-0000-0000-0000-000000000001', NULL, 'SuperAdmin', 'Full administrative control over all companies and settings', 'SuperAdmin', true),
    ('10000000-0000-0000-0000-000000000002', NULL, 'Admin', 'Company administrator with user and settings management', 'Admin', true),
    ('10000000-0000-0000-0000-000000000003', NULL, 'Manager', 'Team manager with file request and sharing capabilities', 'Manager', true),
    ('10000000-0000-0000-0000-000000000004', NULL, 'Employee', 'Standard user with basic file access', 'Employee', true)
ON CONFLICT DO NOTHING;

-- Employee permissions
INSERT INTO role_permissions (role_id, permission, granted) VALUES
    ('10000000-0000-0000-0000-000000000004', 'files.view', true),
    ('10000000-0000-0000-0000-000000000004', 'files.upload', true),
    ('10000000-0000-0000-0000-000000000004', 'files.download', true)
ON CONFLICT DO NOTHING;

-- Manager permissions
INSERT INTO role_permissions (role_id, permission, granted) VALUES
    ('10000000-0000-0000-0000-000000000003', 'files.view', true),
    ('10000000-0000-0000-0000-000000000003', 'files.upload', true),
    ('10000000-0000-0000-0000-000000000003', 'files.download', true),
    ('10000000-0000-0000-0000-000000000003', 'files.delete', true),
    ('10000000-0000-0000-0000-000000000003', 'files.share', true),
    ('10000000-0000-0000-0000-000000000003', 'requests.create', true),
    ('10000000-0000-0000-0000-000000000003', 'requests.view', true)
ON CONFLICT DO NOTHING;

-- Admin permissions
INSERT INTO role_permissions (role_id, permission, granted) VALUES
    ('10000000-0000-0000-0000-000000000002', 'files.view', true),
    ('10000000-0000-0000-0000-000000000002', 'files.upload', true),
    ('10000000-0000-0000-0000-000000000002', 'files.download', true),
    ('10000000-0000-0000-0000-000000000002', 'files.delete', true),
    ('10000000-0000-0000-0000-000000000002', 'files.share', true),
    ('10000000-0000-0000-0000-000000000002', 'requests.create', true),
    ('10000000-0000-0000-0000-000000000002', 'requests.view', true),
    ('10000000-0000-0000-0000-000000000002', 'users.view', true),
    ('10000000-0000-0000-0000-000000000002', 'users.invite', true),
    ('10000000-0000-0000-0000-000000000002', 'users.edit', true),
    ('10000000-0000-0000-0000-000000000002', 'roles.view', true),
    ('10000000-0000-0000-0000-000000000002', 'audit.view', true),
    ('10000000-0000-0000-0000-000000000002', 'settings.view', true)
ON CONFLICT DO NOTHING;

-- SuperAdmin permissions
INSERT INTO role_permissions (role_id, permission, granted) VALUES
    ('10000000-0000-0000-0000-000000000001', 'files.view', true),
    ('10000000-0000-0000-0000-000000000001', 'files.upload', true),
    ('10000000-0000-0000-0000-000000000001', 'files.download', true),
    ('10000000-0000-0000-0000-000000000001', 'files.delete', true),
    ('10000000-0000-0000-0000-000000000001', 'files.share', true),
    ('10000000-0000-0000-0000-000000000001', 'requests.create', true),
    ('10000000-0000-0000-0000-000000000001', 'requests.view', true),
    ('10000000-0000-0000-0000-000000000001', 'users.view', true),
    ('10000000-0000-0000-0000-000000000001', 'users.invite', true),
    ('10000000-0000-0000-0000-000000000001', 'users.edit', true),
    ('10000000-0000-0000-0000-000000000001', 'users.delete', true),
    ('10000000-0000-0000-0000-000000000001', 'roles.view', true),
    ('10000000-0000-0000-0000-000000000001', 'roles.manage', true),
    ('10000000-0000-0000-0000-000000000001', 'audit.view', true),
    ('10000000-0000-0000-0000-000000000001', 'audit.export', true),
    ('10000000-0000-0000-0000-000000000001', 'settings.view', true),
    ('10000000-0000-0000-0000-000000000001', 'settings.edit', true),
    ('10000000-0000-0000-0000-000000000001', 'tenants.manage', true)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- DEMO TENANTS
-- ============================================================================

INSERT INTO tenants (id, name, domain, plan, status, compliance_mode) VALUES
    ('11111111-1111-1111-1111-111111111111', 'Acme Corp', 'acme.com', 'Enterprise', 'active', 'HIPAA'),
    ('22222222-2222-2222-2222-222222222222', 'Globex Inc', 'globex.com', 'Business', 'active', 'SOX'),
    ('33333333-3333-3333-3333-333333333333', 'Soylent Corp', 'soylent.com', 'Starter', 'suspended', 'Standard')
ON CONFLICT DO NOTHING;

-- Apply compliance defaults
UPDATE tenants SET mfa_required = true, public_sharing_enabled = false, session_timeout_minutes = 15
WHERE id = '11111111-1111-1111-1111-111111111111';

UPDATE tenants SET mfa_required = true, public_sharing_enabled = false
WHERE id = '22222222-2222-2222-2222-222222222222';

-- ============================================================================
-- DEMO DEPARTMENTS
-- ============================================================================

-- Acme Corp departments
INSERT INTO departments (id, tenant_id, name, description) VALUES
    ('d1111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'Finance', 'Financial operations and accounting'),
    ('d2222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Legal', 'Legal affairs and compliance'),
    ('d3333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'Human Resources', 'Employee management and HR operations'),
    ('d4444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'Engineering', 'Software development and technical operations')
ON CONFLICT (tenant_id, name) DO NOTHING;

-- Globex Inc departments
INSERT INTO departments (id, tenant_id, name, description) VALUES
    ('d5555555-5555-5555-5555-555555555555', '22222222-2222-2222-2222-222222222222', 'Operations', 'Business operations'),
    ('d6666666-6666-6666-6666-666666666666', '22222222-2222-2222-2222-222222222222', 'Sales', 'Sales and marketing')
ON CONFLICT (tenant_id, name) DO NOTHING;

-- ============================================================================
-- DEMO USERS
-- Password for all users: "password123"
-- Hash: $argon2id$v=19$m=19456,t=2,p=1$ZZQeowa8qOIGQziIPCF9kg$yGQS+h+6nGq+E8Aol7Uq0mAeeWYCHlKk4yexS97wiHU
-- ============================================================================

-- SuperAdmin (password: password123)
INSERT INTO users (id, tenant_id, email, name, password_hash, role, status) VALUES
    ('00000000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111', 'superadmin@clovalink.com', 'Super Admin', '$argon2id$v=19$m=19456,t=2,p=1$ZZQeowa8qOIGQziIPCF9kg$yGQS+h+6nGq+E8Aol7Uq0mAeeWYCHlKk4yexS97wiHU', 'SuperAdmin', 'active')
ON CONFLICT DO NOTHING;

-- Acme Corp users
INSERT INTO users (id, tenant_id, email, name, password_hash, role, status) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'admin@acme.com', 'Admin User', '$argon2id$v=19$m=19456,t=2,p=1$ZZQeowa8qOIGQziIPCF9kg$yGQS+h+6nGq+E8Aol7Uq0mAeeWYCHlKk4yexS97wiHU', 'Admin', 'active'),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', 'manager@acme.com', 'Manager User', '$argon2id$v=19$m=19456,t=2,p=1$ZZQeowa8qOIGQziIPCF9kg$yGQS+h+6nGq+E8Aol7Uq0mAeeWYCHlKk4yexS97wiHU', 'Manager', 'active'),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', 'employee@acme.com', 'Employee User', '$argon2id$v=19$m=19456,t=2,p=1$ZZQeowa8qOIGQziIPCF9kg$yGQS+h+6nGq+E8Aol7Uq0mAeeWYCHlKk4yexS97wiHU', 'Employee', 'active')
ON CONFLICT DO NOTHING;

-- Globex Inc users
INSERT INTO users (id, tenant_id, email, name, password_hash, role, status) VALUES
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', '22222222-2222-2222-2222-222222222222', 'admin@globex.com', 'Globex Admin', '$argon2id$v=19$m=19456,t=2,p=1$ZZQeowa8qOIGQziIPCF9kg$yGQS+h+6nGq+E8Aol7Uq0mAeeWYCHlKk4yexS97wiHU', 'Admin', 'active')
ON CONFLICT DO NOTHING;

-- Soylent Corp users
INSERT INTO users (id, tenant_id, email, name, password_hash, role, status) VALUES
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '33333333-3333-3333-3333-333333333333', 'admin@soylent.com', 'Soylent Admin', '$argon2id$v=19$m=19456,t=2,p=1$ZZQeowa8qOIGQziIPCF9kg$yGQS+h+6nGq+E8Aol7Uq0mAeeWYCHlKk4yexS97wiHU', 'Admin', 'inactive')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- DEMO FILE REQUESTS
-- ============================================================================

INSERT INTO file_requests (tenant_id, name, destination_path, token, created_by, expires_at, status, upload_count) VALUES
    ('11111111-1111-1111-1111-111111111111', 'Q4 Financials', '/Finance/2024', 'demo-token-001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NOW() + INTERVAL '30 days', 'active', 3),
    ('11111111-1111-1111-1111-111111111111', 'Vendor Contracts', '/Legal/Contracts', 'demo-token-002', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NOW() + INTERVAL '15 days', 'active', 12),
    ('22222222-2222-2222-2222-222222222222', 'Marketing Assets', '/Marketing/2024', 'demo-token-003', 'dddddddd-dddd-dddd-dddd-dddddddddddd', NOW() - INTERVAL '5 days', 'expired', 25)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- DEMO FOLDERS
-- ============================================================================

-- Root folders for Acme Corp (visible as company folders)
INSERT INTO files_metadata (id, tenant_id, department_id, name, storage_path, size_bytes, is_directory, owner_id, parent_path, visibility, is_company_folder)
VALUES
    -- Projects folder (shared company folder)
    ('f0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', NULL, 
     'Projects', '11111111-1111-1111-1111-111111111111/Projects/', 0, true, 
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NULL, 'department', true)
ON CONFLICT (id) DO NOTHING;

-- Finance folders
INSERT INTO files_metadata (id, tenant_id, department_id, name, storage_path, size_bytes, is_directory, owner_id, parent_path, visibility)
VALUES
    ('f0000001-0001-0001-0001-000000000001', '11111111-1111-1111-1111-111111111111', 'd1111111-1111-1111-1111-111111111111', 
     'Finance', '11111111-1111-1111-1111-111111111111/Finance/', 0, true, 
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NULL, 'department'),
    ('f0000001-0001-0001-0001-000000000002', '11111111-1111-1111-1111-111111111111', 'd1111111-1111-1111-1111-111111111111', 
     '2024', '11111111-1111-1111-1111-111111111111/Finance/2024/', 0, true, 
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Finance', 'department'),
    ('f0000001-0001-0001-0001-000000000003', '11111111-1111-1111-1111-111111111111', 'd1111111-1111-1111-1111-111111111111', 
     'Invoices', '11111111-1111-1111-1111-111111111111/Finance/Invoices/', 0, true, 
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Finance', 'department')
ON CONFLICT (id) DO NOTHING;

-- Legal folders
INSERT INTO files_metadata (id, tenant_id, department_id, name, storage_path, size_bytes, is_directory, owner_id, parent_path, visibility)
VALUES
    ('f0000002-0002-0002-0002-000000000001', '11111111-1111-1111-1111-111111111111', 'd2222222-2222-2222-2222-222222222222', 
     'Legal', '11111111-1111-1111-1111-111111111111/Legal/', 0, true, 
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NULL, 'department'),
    ('f0000002-0002-0002-0002-000000000002', '11111111-1111-1111-1111-111111111111', 'd2222222-2222-2222-2222-222222222222', 
     'Contracts', '11111111-1111-1111-1111-111111111111/Legal/Contracts/', 0, true, 
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Legal', 'department'),
    ('f0000002-0002-0002-0002-000000000003', '11111111-1111-1111-1111-111111111111', 'd2222222-2222-2222-2222-222222222222', 
     'Policies', '11111111-1111-1111-1111-111111111111/Legal/Policies/', 0, true, 
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Legal', 'department')
ON CONFLICT (id) DO NOTHING;

-- Human Resources folders
INSERT INTO files_metadata (id, tenant_id, department_id, name, storage_path, size_bytes, is_directory, owner_id, parent_path, visibility)
VALUES
    ('f0000003-0003-0003-0003-000000000001', '11111111-1111-1111-1111-111111111111', 'd3333333-3333-3333-3333-333333333333', 
     'Human Resources', '11111111-1111-1111-1111-111111111111/Human Resources/', 0, true, 
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NULL, 'department'),
    ('f0000003-0003-0003-0003-000000000002', '11111111-1111-1111-1111-111111111111', 'd3333333-3333-3333-3333-333333333333', 
     'Onboarding', '11111111-1111-1111-1111-111111111111/Human Resources/Onboarding/', 0, true, 
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Human Resources', 'department')
ON CONFLICT (id) DO NOTHING;

-- Engineering folders
INSERT INTO files_metadata (id, tenant_id, department_id, name, storage_path, size_bytes, is_directory, owner_id, parent_path, visibility)
VALUES
    ('f0000004-0004-0004-0004-000000000001', '11111111-1111-1111-1111-111111111111', 'd4444444-4444-4444-4444-444444444444', 
     'Engineering', '11111111-1111-1111-1111-111111111111/Engineering/', 0, true, 
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NULL, 'department'),
    ('f0000004-0004-0004-0004-000000000002', '11111111-1111-1111-1111-111111111111', 'd4444444-4444-4444-4444-444444444444', 
     'Documentation', '11111111-1111-1111-1111-111111111111/Engineering/Documentation/', 0, true, 
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Engineering', 'department')
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- DEMO FILES
-- ============================================================================

-- Finance files
INSERT INTO files_metadata (id, tenant_id, department_id, name, storage_path, size_bytes, content_type, is_directory, owner_id, parent_path, visibility)
VALUES
    ('f1000001-1001-1001-1001-000000000001', '11111111-1111-1111-1111-111111111111', 'd1111111-1111-1111-1111-111111111111', 
     'Q1_Budget.xlsx', '11111111-1111-1111-1111-111111111111/Finance/2024/Q1_Budget.xlsx', 24576, 
     'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', false, 
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Finance/2024', 'department'),
    ('f1000001-1001-1001-1001-000000000002', '11111111-1111-1111-1111-111111111111', 'd1111111-1111-1111-1111-111111111111', 
     'Q2_Report.pdf', '11111111-1111-1111-1111-111111111111/Finance/2024/Q2_Report.pdf', 156789, 
     'application/pdf', false, 
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Finance/2024', 'department'),
    ('f1000001-1001-1001-1001-000000000003', '11111111-1111-1111-1111-111111111111', 'd1111111-1111-1111-1111-111111111111', 
     'Annual_Forecast.xlsx', '11111111-1111-1111-1111-111111111111/Finance/2024/Annual_Forecast.xlsx', 35840, 
     'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', false, 
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Finance/2024', 'department'),
    ('f1000001-1001-1001-1001-000000000004', '11111111-1111-1111-1111-111111111111', 'd1111111-1111-1111-1111-111111111111', 
     'Invoice_Template.pdf', '11111111-1111-1111-1111-111111111111/Finance/Invoices/Invoice_Template.pdf', 45678, 
     'application/pdf', false, 
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Finance/Invoices', 'department')
ON CONFLICT (id) DO NOTHING;

-- Legal files
INSERT INTO files_metadata (id, tenant_id, department_id, name, storage_path, size_bytes, content_type, is_directory, owner_id, parent_path, visibility)
VALUES
    ('f2000001-2001-2001-2001-000000000001', '11111111-1111-1111-1111-111111111111', 'd2222222-2222-2222-2222-222222222222', 
     'Vendor_Agreement.pdf', '11111111-1111-1111-1111-111111111111/Legal/Contracts/Vendor_Agreement.pdf', 234567, 
     'application/pdf', false, 
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Legal/Contracts', 'department'),
    ('f2000001-2001-2001-2001-000000000002', '11111111-1111-1111-1111-111111111111', 'd2222222-2222-2222-2222-222222222222', 
     'NDA_Template.docx', '11111111-1111-1111-1111-111111111111/Legal/Contracts/NDA_Template.docx', 28672, 
     'application/vnd.openxmlformats-officedocument.wordprocessingml.document', false, 
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Legal/Contracts', 'department'),
    ('f2000001-2001-2001-2001-000000000003', '11111111-1111-1111-1111-111111111111', 'd2222222-2222-2222-2222-222222222222', 
     'Employee_Handbook.pdf', '11111111-1111-1111-1111-111111111111/Legal/Policies/Employee_Handbook.pdf', 512000, 
     'application/pdf', false, 
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Legal/Policies', 'department')
ON CONFLICT (id) DO NOTHING;

-- Human Resources files
INSERT INTO files_metadata (id, tenant_id, department_id, name, storage_path, size_bytes, content_type, is_directory, owner_id, parent_path, visibility)
VALUES
    ('f3000001-3001-3001-3001-000000000001', '11111111-1111-1111-1111-111111111111', 'd3333333-3333-3333-3333-333333333333', 
     'Welcome_Guide.pdf', '11111111-1111-1111-1111-111111111111/Human Resources/Onboarding/Welcome_Guide.pdf', 89012, 
     'application/pdf', false, 
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Human Resources/Onboarding', 'department'),
    ('f3000001-3001-3001-3001-000000000002', '11111111-1111-1111-1111-111111111111', 'd3333333-3333-3333-3333-333333333333', 
     'Benefits_Overview.xlsx', '11111111-1111-1111-1111-111111111111/Human Resources/Onboarding/Benefits_Overview.xlsx', 18432, 
     'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', false, 
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Human Resources/Onboarding', 'department')
ON CONFLICT (id) DO NOTHING;

-- Engineering files
INSERT INTO files_metadata (id, tenant_id, department_id, name, storage_path, size_bytes, content_type, is_directory, owner_id, parent_path, visibility)
VALUES
    ('f4000001-4001-4001-4001-000000000001', '11111111-1111-1111-1111-111111111111', 'd4444444-4444-4444-4444-444444444444', 
     'API_Spec.pdf', '11111111-1111-1111-1111-111111111111/Engineering/Documentation/API_Spec.pdf', 145678, 
     'application/pdf', false, 
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Engineering/Documentation', 'department')
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- UPDATE TENANT STORAGE USED
-- ============================================================================

UPDATE tenants 
SET storage_used_bytes = (
    SELECT COALESCE(SUM(size_bytes), 0) 
    FROM files_metadata 
    WHERE tenant_id = '11111111-1111-1111-1111-111111111111' 
    AND is_directory = false 
    AND is_deleted = false
)
WHERE id = '11111111-1111-1111-1111-111111111111';

-- ============================================================================
-- DEFAULT NOTIFICATION PREFERENCES
-- ============================================================================

-- Insert default notification preferences for demo users
INSERT INTO notification_preferences (user_id, event_type, email_enabled, in_app_enabled)
SELECT u.id, event_type.type, true, true
FROM users u
CROSS JOIN (
    VALUES 
        ('file_upload'),
        ('request_expiring'),
        ('user_action'),
        ('compliance_alert'),
        ('storage_warning'),
        ('file_shared')
) AS event_type(type)
ON CONFLICT (user_id, event_type) DO NOTHING;

-- Insert tenant notification settings
INSERT INTO tenant_notification_settings (tenant_id, event_type, enabled, email_enforced, in_app_enforced, default_email, default_in_app)
SELECT t.id, event_type.type, true, false, false, true, true
FROM tenants t
CROSS JOIN (
    VALUES 
        ('file_upload'),
        ('request_expiring'),
        ('user_action'),
        ('compliance_alert'),
        ('storage_warning'),
        ('file_shared')
) AS event_type(type)
ON CONFLICT (tenant_id, event_type, role) DO NOTHING;
