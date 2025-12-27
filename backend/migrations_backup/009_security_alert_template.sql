-- Migration: Add Security Alert Email Template
-- Sends notifications for Critical and High severity security alerts

INSERT INTO email_templates (template_key, name, subject, body_html, body_text, variables) VALUES
(
    'security_alert',
    'Security Alert',
    '🚨 Security Alert: {{alert_title}}',
    '<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, ''Segoe UI'', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #dc2626 0%, #991b1b 100%); color: white; padding: 30px 20px; border-radius: 8px 8px 0 0; text-align: center; }
        .header h1 { margin: 0; font-size: 24px; }
        .content { background: #ffffff; padding: 30px; border: 1px solid #e5e7eb; border-top: none; }
        .content p { margin: 0 0 15px 0; }
        .severity-critical { background: #fef2f2; border-left: 4px solid #dc2626; padding: 15px; margin: 20px 0; }
        .severity-high { background: #fff7ed; border-left: 4px solid #ea580c; padding: 15px; margin: 20px 0; }
        .severity-badge { display: inline-block; padding: 4px 12px; border-radius: 20px; font-size: 12px; font-weight: bold; text-transform: uppercase; }
        .severity-critical .severity-badge { background: #dc2626; color: white; }
        .severity-high .severity-badge { background: #ea580c; color: white; }
        .details { background: #f9fafb; padding: 15px; border-radius: 6px; margin: 20px 0; }
        .details p { margin: 5px 0; font-size: 14px; }
        .details strong { color: #374151; }
        .button { display: inline-block; padding: 12px 24px; background: #dc2626; color: white; text-decoration: none; border-radius: 6px; margin-top: 15px; }
        .footer { background: #f9fafb; padding: 20px; border: 1px solid #e5e7eb; border-top: none; border-radius: 0 0 8px 8px; text-align: center; color: #6b7280; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🛡️ Security Alert</h1>
        </div>
        <div class="content">
            <p>Hi {{user_name}},</p>
            <p>A security alert has been triggered that requires your attention.</p>
            <div class="severity-{{severity_lower}}">
                <span class="severity-badge">{{severity}}</span>
                <h3 style="margin: 10px 0 5px 0;">{{alert_title}}</h3>
                <p style="margin: 0; color: #6b7280;">{{description}}</p>
            </div>
            <div class="details">
                <p><strong>Alert Type:</strong> {{alert_type_display}}</p>
                <p><strong>Time:</strong> {{timestamp}}</p>
                {{#if affected_user}}<p><strong>Affected User:</strong> {{affected_user}}</p>{{/if}}
                {{#if ip_address}}<p><strong>IP Address:</strong> {{ip_address}}</p>{{/if}}
                <p><strong>Company:</strong> {{tenant_name}}</p>
            </div>
            <p>Please review this alert and take appropriate action.</p>
            <a href="{{app_url}}/security" class="button">View Security Dashboard</a>
        </div>
        <div class="footer">
            <p>This is an automated security notification from {{tenant_name}}.</p>
            <p>Powered by ClovaLink</p>
        </div>
    </div>
</body>
</html>',
    'Hi {{user_name}},

A security alert has been triggered that requires your attention.

SEVERITY: {{severity}}
ALERT: {{alert_title}}

{{description}}

Details:
- Alert Type: {{alert_type_display}}
- Time: {{timestamp}}
- Affected User: {{affected_user}}
- IP Address: {{ip_address}}
- Company: {{tenant_name}}

Please review this alert and take appropriate action.

View Security Dashboard: {{app_url}}/security

This is an automated security notification from {{tenant_name}}.',
    '["user_name", "severity", "severity_lower", "alert_title", "description", "alert_type", "alert_type_display", "timestamp", "affected_user", "ip_address", "tenant_name", "app_url"]'::jsonb
)
ON CONFLICT (template_key) DO NOTHING;

