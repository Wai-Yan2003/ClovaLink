-- Email Templates Migration
-- Supports global default templates and per-tenant overrides

-- Global default templates (managed by SuperAdmin)
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

-- Per-tenant template overrides
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

CREATE INDEX IF NOT EXISTS idx_tenant_email_templates_tenant_id ON tenant_email_templates(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tenant_email_templates_key ON tenant_email_templates(template_key);

-- Insert default email templates
INSERT INTO email_templates (template_key, name, subject, body_html, body_text, variables) VALUES
(
    'file_upload',
    'File Upload Notification',
    'New upload to "{{request_name}}"',
    '<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, ''Segoe UI'', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px 20px; border-radius: 8px 8px 0 0; text-align: center; }
        .header h1 { margin: 0; font-size: 24px; }
        .content { background: #ffffff; padding: 30px; border: 1px solid #e5e7eb; border-top: none; }
        .content p { margin: 0 0 15px 0; }
        .highlight { background: #f3f4f6; padding: 15px; border-radius: 6px; margin: 20px 0; }
        .button { display: inline-block; padding: 12px 24px; background: #667eea; color: white; text-decoration: none; border-radius: 6px; margin-top: 15px; }
        .footer { background: #f9fafb; padding: 20px; border: 1px solid #e5e7eb; border-top: none; border-radius: 0 0 8px 8px; text-align: center; color: #6b7280; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📁 New File Upload</h1>
        </div>
        <div class="content">
            <p>Hi {{user_name}},</p>
            <p>A new file has been uploaded to your file request.</p>
            <div class="highlight">
                <strong>Request:</strong> {{request_name}}<br>
                <strong>File:</strong> {{file_name}}<br>
                <strong>Uploaded by:</strong> {{uploader_name}}
            </div>
            <p>You can view and manage this file in your dashboard.</p>
            <a href="{{app_url}}" class="button">View in Dashboard</a>
        </div>
        <div class="footer">
            <p>This is an automated notification from {{company_name}}.</p>
            <p>Powered by ClovaLink</p>
        </div>
    </div>
</body>
</html>',
    'Hi {{user_name}},

A new file has been uploaded to your file request "{{request_name}}".

File: {{file_name}}
Uploaded by: {{uploader_name}}

View in dashboard: {{app_url}}

This is an automated notification from {{company_name}}.',
    '["user_name", "request_name", "file_name", "uploader_name", "company_name", "app_url"]'::jsonb
),
(
    'request_expiring',
    'Request Expiring Soon',
    'File request "{{request_name}}" expiring soon',
    '<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, ''Segoe UI'', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%); color: white; padding: 30px 20px; border-radius: 8px 8px 0 0; text-align: center; }
        .header h1 { margin: 0; font-size: 24px; }
        .content { background: #ffffff; padding: 30px; border: 1px solid #e5e7eb; border-top: none; }
        .content p { margin: 0 0 15px 0; }
        .warning { background: #fef3c7; border-left: 4px solid #f59e0b; padding: 15px; margin: 20px 0; }
        .button { display: inline-block; padding: 12px 24px; background: #f59e0b; color: white; text-decoration: none; border-radius: 6px; margin-top: 15px; }
        .footer { background: #f9fafb; padding: 20px; border: 1px solid #e5e7eb; border-top: none; border-radius: 0 0 8px 8px; text-align: center; color: #6b7280; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>⚠️ Request Expiring</h1>
        </div>
        <div class="content">
            <p>Hi {{user_name}},</p>
            <div class="warning">
                <strong>Your file request "{{request_name}}" will expire in {{days_until_expiry}} day(s).</strong>
            </div>
            <p>After expiration, no new files can be uploaded to this request. If you need to extend the deadline, please update the request settings.</p>
            <a href="{{app_url}}" class="button">Manage Request</a>
        </div>
        <div class="footer">
            <p>This is an automated notification from {{company_name}}.</p>
            <p>Powered by ClovaLink</p>
        </div>
    </div>
</body>
</html>',
    'Hi {{user_name}},

Your file request "{{request_name}}" will expire in {{days_until_expiry}} day(s).

After expiration, no new files can be uploaded to this request. If you need to extend the deadline, please update the request settings.

Manage request: {{app_url}}

This is an automated notification from {{company_name}}.',
    '["user_name", "request_name", "days_until_expiry", "company_name", "app_url"]'::jsonb
),
(
    'user_created',
    'New User Added',
    'New user added to {{company_name}}',
    '<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, ''Segoe UI'', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #10b981 0%, #059669 100%); color: white; padding: 30px 20px; border-radius: 8px 8px 0 0; text-align: center; }
        .header h1 { margin: 0; font-size: 24px; }
        .content { background: #ffffff; padding: 30px; border: 1px solid #e5e7eb; border-top: none; }
        .content p { margin: 0 0 15px 0; }
        .user-card { background: #f3f4f6; padding: 15px; border-radius: 6px; margin: 20px 0; }
        .button { display: inline-block; padding: 12px 24px; background: #10b981; color: white; text-decoration: none; border-radius: 6px; margin-top: 15px; }
        .footer { background: #f9fafb; padding: 20px; border: 1px solid #e5e7eb; border-top: none; border-radius: 0 0 8px 8px; text-align: center; color: #6b7280; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>👤 New User Added</h1>
        </div>
        <div class="content">
            <p>Hi {{user_name}},</p>
            <p>A new user has been added to your organization.</p>
            <div class="user-card">
                <strong>Name:</strong> {{new_user_name}}<br>
                <strong>Email:</strong> {{new_user_email}}<br>
                <strong>Role:</strong> {{new_user_role}}
            </div>
            <a href="{{app_url}}/users" class="button">View Users</a>
        </div>
        <div class="footer">
            <p>This is an automated notification from {{company_name}}.</p>
            <p>Powered by ClovaLink</p>
        </div>
    </div>
</body>
</html>',
    'Hi {{user_name}},

A new user has been added to your organization.

Name: {{new_user_name}}
Email: {{new_user_email}}
Role: {{new_user_role}}

View users: {{app_url}}/users

This is an automated notification from {{company_name}}.',
    '["user_name", "new_user_name", "new_user_email", "new_user_role", "company_name", "app_url"]'::jsonb
),
(
    'role_changed',
    'Role Updated',
    'Your role has been updated',
    '<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, ''Segoe UI'', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%); color: white; padding: 30px 20px; border-radius: 8px 8px 0 0; text-align: center; }
        .header h1 { margin: 0; font-size: 24px; }
        .content { background: #ffffff; padding: 30px; border: 1px solid #e5e7eb; border-top: none; }
        .content p { margin: 0 0 15px 0; }
        .role-change { background: #f3f4f6; padding: 15px; border-radius: 6px; margin: 20px 0; text-align: center; }
        .role { display: inline-block; padding: 8px 16px; background: #8b5cf6; color: white; border-radius: 20px; margin: 5px; }
        .arrow { color: #9ca3af; margin: 0 10px; }
        .button { display: inline-block; padding: 12px 24px; background: #8b5cf6; color: white; text-decoration: none; border-radius: 6px; margin-top: 15px; }
        .footer { background: #f9fafb; padding: 20px; border: 1px solid #e5e7eb; border-top: none; border-radius: 0 0 8px 8px; text-align: center; color: #6b7280; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔄 Role Updated</h1>
        </div>
        <div class="content">
            <p>Hi {{user_name}},</p>
            <p>Your role in {{company_name}} has been updated.</p>
            <div class="role-change">
                <span class="role">{{old_role}}</span>
                <span class="arrow">→</span>
                <span class="role">{{new_role}}</span>
            </div>
            <p>Your permissions have been adjusted accordingly. If you have any questions, please contact your administrator.</p>
            <a href="{{app_url}}" class="button">Go to Dashboard</a>
        </div>
        <div class="footer">
            <p>This is an automated notification from {{company_name}}.</p>
            <p>Powered by ClovaLink</p>
        </div>
    </div>
</body>
</html>',
    'Hi {{user_name}},

Your role in {{company_name}} has been updated.

Previous role: {{old_role}}
New role: {{new_role}}

Your permissions have been adjusted accordingly. If you have any questions, please contact your administrator.

Go to dashboard: {{app_url}}

This is an automated notification from {{company_name}}.',
    '["user_name", "old_role", "new_role", "company_name", "app_url"]'::jsonb
),
(
    'file_shared',
    'File Shared With You',
    '{{sharer_name}} shared a file with you',
    '<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, ''Segoe UI'', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%); color: white; padding: 30px 20px; border-radius: 8px 8px 0 0; text-align: center; }
        .header h1 { margin: 0; font-size: 24px; }
        .content { background: #ffffff; padding: 30px; border: 1px solid #e5e7eb; border-top: none; }
        .content p { margin: 0 0 15px 0; }
        .file-card { background: #eff6ff; border: 1px solid #bfdbfe; padding: 15px; border-radius: 6px; margin: 20px 0; display: flex; align-items: center; }
        .file-icon { font-size: 32px; margin-right: 15px; }
        .button { display: inline-block; padding: 12px 24px; background: #3b82f6; color: white; text-decoration: none; border-radius: 6px; margin-top: 15px; }
        .footer { background: #f9fafb; padding: 20px; border: 1px solid #e5e7eb; border-top: none; border-radius: 0 0 8px 8px; text-align: center; color: #6b7280; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📤 File Shared</h1>
        </div>
        <div class="content">
            <p>Hi {{user_name}},</p>
            <p><strong>{{sharer_name}}</strong> has shared a file with you.</p>
            <div class="file-card">
                <span class="file-icon">📄</span>
                <div>
                    <strong>{{file_name}}</strong>
                </div>
            </div>
            <a href="{{app_url}}" class="button">View File</a>
        </div>
        <div class="footer">
            <p>This is an automated notification from {{company_name}}.</p>
            <p>Powered by ClovaLink</p>
        </div>
    </div>
</body>
</html>',
    'Hi {{user_name}},

{{sharer_name}} has shared a file with you.

File: {{file_name}}

View file: {{app_url}}

This is an automated notification from {{company_name}}.',
    '["user_name", "sharer_name", "file_name", "company_name", "app_url"]'::jsonb
),
(
    'compliance_alert',
    'Compliance Alert',
    'Compliance Alert: {{alert_type}}',
    '<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, ''Segoe UI'', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%); color: white; padding: 30px 20px; border-radius: 8px 8px 0 0; text-align: center; }
        .header h1 { margin: 0; font-size: 24px; }
        .content { background: #ffffff; padding: 30px; border: 1px solid #e5e7eb; border-top: none; }
        .content p { margin: 0 0 15px 0; }
        .alert { background: #fef2f2; border-left: 4px solid #ef4444; padding: 15px; margin: 20px 0; }
        .button { display: inline-block; padding: 12px 24px; background: #ef4444; color: white; text-decoration: none; border-radius: 6px; margin-top: 15px; }
        .footer { background: #f9fafb; padding: 20px; border: 1px solid #e5e7eb; border-top: none; border-radius: 0 0 8px 8px; text-align: center; color: #6b7280; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚨 Compliance Alert</h1>
        </div>
        <div class="content">
            <p>Hi {{user_name}},</p>
            <div class="alert">
                <strong>{{alert_type}}</strong><br><br>
                {{message}}
            </div>
            <p>Please review this alert and take appropriate action to maintain compliance.</p>
            <a href="{{app_url}}/settings" class="button">View Settings</a>
        </div>
        <div class="footer">
            <p>This is an automated compliance notification from {{company_name}}.</p>
            <p>Powered by ClovaLink</p>
        </div>
    </div>
</body>
</html>',
    'Hi {{user_name}},

COMPLIANCE ALERT: {{alert_type}}

{{message}}

Please review this alert and take appropriate action to maintain compliance.

View settings: {{app_url}}/settings

This is an automated compliance notification from {{company_name}}.',
    '["user_name", "alert_type", "message", "company_name", "app_url"]'::jsonb
),
(
    'storage_warning',
    'Storage Warning',
    'Storage quota warning for {{company_name}}',
    '<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, ''Segoe UI'', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #f97316 0%, #ea580c 100%); color: white; padding: 30px 20px; border-radius: 8px 8px 0 0; text-align: center; }
        .header h1 { margin: 0; font-size: 24px; }
        .content { background: #ffffff; padding: 30px; border: 1px solid #e5e7eb; border-top: none; }
        .content p { margin: 0 0 15px 0; }
        .progress-bar { background: #e5e7eb; border-radius: 10px; height: 20px; margin: 20px 0; overflow: hidden; }
        .progress { background: linear-gradient(90deg, #f97316, #ea580c); height: 100%; border-radius: 10px; }
        .stats { background: #fff7ed; padding: 15px; border-radius: 6px; margin: 20px 0; text-align: center; }
        .button { display: inline-block; padding: 12px 24px; background: #f97316; color: white; text-decoration: none; border-radius: 6px; margin-top: 15px; }
        .footer { background: #f9fafb; padding: 20px; border: 1px solid #e5e7eb; border-top: none; border-radius: 0 0 8px 8px; text-align: center; color: #6b7280; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>💾 Storage Warning</h1>
        </div>
        <div class="content">
            <p>Hi {{user_name}},</p>
            <p>Your organization''s storage is running low.</p>
            <div class="progress-bar">
                <div class="progress" style="width: {{percentage_used}}%;"></div>
            </div>
            <div class="stats">
                <strong style="font-size: 24px;">{{percentage_used}}%</strong><br>
                of storage used
            </div>
            <p>Consider freeing up space by removing old files or upgrading your storage plan.</p>
            <a href="{{app_url}}/settings" class="button">Manage Storage</a>
        </div>
        <div class="footer">
            <p>This is an automated notification from {{company_name}}.</p>
            <p>Powered by ClovaLink</p>
        </div>
    </div>
</body>
</html>',
    'Hi {{user_name}},

Your organization''s storage is running low.

Storage used: {{percentage_used}}%

Consider freeing up space by removing old files or upgrading your storage plan.

Manage storage: {{app_url}}/settings

This is an automated notification from {{company_name}}.',
    '["user_name", "percentage_used", "company_name", "app_url"]'::jsonb
),
(
    'password_reset',
    'Password Reset Request',
    'Password reset request for {{company_name}}',
    '<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, ''Segoe UI'', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #6366f1 0%, #4f46e5 100%); color: white; padding: 30px 20px; border-radius: 8px 8px 0 0; text-align: center; }
        .header h1 { margin: 0; font-size: 24px; }
        .content { background: #ffffff; padding: 30px; border: 1px solid #e5e7eb; border-top: none; }
        .content p { margin: 0 0 15px 0; }
        .button { display: inline-block; padding: 14px 28px; background: #6366f1; color: white; text-decoration: none; border-radius: 6px; margin: 20px 0; font-weight: bold; }
        .warning { background: #fef3c7; border-left: 4px solid #f59e0b; padding: 15px; margin: 20px 0; font-size: 14px; }
        .footer { background: #f9fafb; padding: 20px; border: 1px solid #e5e7eb; border-top: none; border-radius: 0 0 8px 8px; text-align: center; color: #6b7280; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔐 Password Reset</h1>
        </div>
        <div class="content">
            <p>Hi {{user_name}},</p>
            <p>We received a request to reset your password. Click the button below to create a new password:</p>
            <p style="text-align: center;">
                <a href="{{reset_link}}" class="button">Reset Password</a>
            </p>
            <div class="warning">
                <strong>⚠️ This link will expire in 1 hour.</strong><br>
                If you didn''t request this password reset, you can safely ignore this email.
            </div>
        </div>
        <div class="footer">
            <p>This is an automated notification from {{company_name}}.</p>
            <p>Powered by ClovaLink</p>
        </div>
    </div>
</body>
</html>',
    'Hi {{user_name}},

We received a request to reset your password.

Click the link below to create a new password:
{{reset_link}}

This link will expire in 1 hour.

If you didn''t request this password reset, you can safely ignore this email.

This is an automated notification from {{company_name}}.',
    '["user_name", "reset_link", "company_name"]'::jsonb
),
(
    'welcome',
    'Welcome Email',
    'Welcome to {{company_name}}',
    '<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, ''Segoe UI'', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 40px 20px; border-radius: 8px 8px 0 0; text-align: center; }
        .header h1 { margin: 0; font-size: 28px; }
        .header p { margin: 10px 0 0 0; opacity: 0.9; }
        .content { background: #ffffff; padding: 30px; border: 1px solid #e5e7eb; border-top: none; }
        .content p { margin: 0 0 15px 0; }
        .credentials { background: #f3f4f6; padding: 20px; border-radius: 6px; margin: 20px 0; }
        .credentials p { margin: 5px 0; }
        .button { display: inline-block; padding: 14px 28px; background: #667eea; color: white; text-decoration: none; border-radius: 6px; margin: 20px 0; font-weight: bold; }
        .footer { background: #f9fafb; padding: 20px; border: 1px solid #e5e7eb; border-top: none; border-radius: 0 0 8px 8px; text-align: center; color: #6b7280; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>👋 Welcome!</h1>
            <p>You''ve been added to {{company_name}}</p>
        </div>
        <div class="content">
            <p>Hi {{user_name}},</p>
            <p>An account has been created for you at {{company_name}}. Here are your login credentials:</p>
            <div class="credentials">
                <p><strong>Email:</strong> {{user_email}}</p>
                <p><strong>Temporary Password:</strong> {{temp_password}}</p>
                <p><strong>Role:</strong> {{role}}</p>
            </div>
            <p><strong>⚠️ Important:</strong> Please change your password after your first login.</p>
            <p style="text-align: center;">
                <a href="{{app_url}}/login" class="button">Log In Now</a>
            </p>
        </div>
        <div class="footer">
            <p>This is an automated notification from {{company_name}}.</p>
            <p>Powered by ClovaLink</p>
        </div>
    </div>
</body>
</html>',
    'Hi {{user_name}},

Welcome to {{company_name}}! An account has been created for you.

Your login credentials:
Email: {{user_email}}
Temporary Password: {{temp_password}}
Role: {{role}}

IMPORTANT: Please change your password after your first login.

Log in at: {{app_url}}/login

This is an automated notification from {{company_name}}.',
    '["user_name", "user_email", "temp_password", "role", "company_name", "app_url"]'::jsonb
)
ON CONFLICT (template_key) DO NOTHING;

