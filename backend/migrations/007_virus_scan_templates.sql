-- Add email templates for virus/malware detection notifications

-- Template for admin notification
INSERT INTO email_templates (template_key, name, subject, body_html, body_text, variables)
VALUES (
    'malware_detected',
    'Malware Detection Alert',
    '🛡️ Security Alert: Malware Detected in {{file_name}}',
    '<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #dc2626 0%, #991b1b 100%); color: white; padding: 30px; border-radius: 8px 8px 0 0; text-align: center; }
        .header h1 { margin: 0; font-size: 24px; }
        .content { background: #ffffff; padding: 30px; border: 1px solid #e5e7eb; border-top: none; }
        .alert-box { background: #fef2f2; border: 1px solid #fecaca; border-radius: 8px; padding: 20px; margin: 20px 0; }
        .alert-box h3 { color: #991b1b; margin-top: 0; }
        .detail-row { display: flex; padding: 10px 0; border-bottom: 1px solid #e5e7eb; }
        .detail-label { font-weight: 600; width: 140px; color: #6b7280; }
        .detail-value { color: #111827; }
        .action-badge { display: inline-block; padding: 4px 12px; border-radius: 9999px; font-size: 14px; font-weight: 600; }
        .action-quarantine { background: #fef3c7; color: #92400e; }
        .action-delete { background: #fee2e2; color: #991b1b; }
        .action-flag { background: #dbeafe; color: #1e40af; }
        .button { display: inline-block; background: #dc2626; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: 600; margin-top: 20px; }
        .footer { background: #f9fafb; padding: 20px; border: 1px solid #e5e7eb; border-top: none; border-radius: 0 0 8px 8px; text-align: center; font-size: 14px; color: #6b7280; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🛡️ Malware Detected</h1>
        </div>
        <div class="content">
            <p>A file uploaded to <strong>{{company_name}}</strong> has been detected as malicious.</p>
            
            <div class="alert-box">
                <h3>Threat Details</h3>
                <div class="detail-row">
                    <span class="detail-label">File Name:</span>
                    <span class="detail-value">{{file_name}}</span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">Threat:</span>
                    <span class="detail-value"><strong>{{threat_name}}</strong></span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">Uploaded By:</span>
                    <span class="detail-value">{{uploader_email}}</span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">Scanned At:</span>
                    <span class="detail-value">{{scanned_at}}</span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">Action Taken:</span>
                    <span class="detail-value">
                        <span class="action-badge action-{{action_class}}">{{action_taken}}</span>
                    </span>
                </div>
            </div>
            
            <p>Please review this incident in your security dashboard.</p>
            
            <a href="{{app_url}}/security" class="button">View Security Dashboard</a>
        </div>
        <div class="footer">
            <p>This is an automated security alert from {{company_name}}.</p>
            <p>If you have questions, please contact your system administrator.</p>
        </div>
    </div>
</body>
</html>',
    'SECURITY ALERT: Malware Detected

A file uploaded to {{company_name}} has been detected as malicious.

THREAT DETAILS:
- File Name: {{file_name}}
- Threat: {{threat_name}}
- Uploaded By: {{uploader_email}}
- Scanned At: {{scanned_at}}
- Action Taken: {{action_taken}}

Please review this incident in your security dashboard:
{{app_url}}/security

This is an automated security alert from {{company_name}}.
If you have questions, please contact your system administrator.',
    '{"file_name": "Name of the infected file", "threat_name": "Name of the detected threat", "uploader_email": "Email of the user who uploaded the file", "scanned_at": "Timestamp of the scan", "action_taken": "Action taken (Quarantined, Deleted, Flagged)", "action_class": "CSS class for action badge", "company_name": "Organization name", "app_url": "Application URL"}'::jsonb
)
ON CONFLICT (template_key) DO UPDATE SET
    name = EXCLUDED.name,
    subject = EXCLUDED.subject,
    body_html = EXCLUDED.body_html,
    body_text = EXCLUDED.body_text,
    variables = EXCLUDED.variables,
    updated_at = NOW();

-- Template for uploader notification (gentler wording)
INSERT INTO email_templates (template_key, name, subject, body_html, body_text, variables)
VALUES (
    'malware_detected_uploader',
    'File Security Alert (Uploader)',
    'Security Notice: Your uploaded file was flagged',
    '<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%); color: white; padding: 30px; border-radius: 8px 8px 0 0; text-align: center; }
        .header h1 { margin: 0; font-size: 24px; }
        .content { background: #ffffff; padding: 30px; border: 1px solid #e5e7eb; border-top: none; }
        .notice-box { background: #fffbeb; border: 1px solid #fde68a; border-radius: 8px; padding: 20px; margin: 20px 0; }
        .detail-row { display: flex; padding: 8px 0; }
        .detail-label { font-weight: 600; width: 120px; color: #6b7280; }
        .detail-value { color: #111827; }
        .footer { background: #f9fafb; padding: 20px; border: 1px solid #e5e7eb; border-top: none; border-radius: 0 0 8px 8px; text-align: center; font-size: 14px; color: #6b7280; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>⚠️ Security Notice</h1>
        </div>
        <div class="content">
            <p>Hi,</p>
            
            <p>A file you recently uploaded has been flagged by our security scanner and has been <strong>{{action_taken}}</strong> as a precaution.</p>
            
            <div class="notice-box">
                <div class="detail-row">
                    <span class="detail-label">File:</span>
                    <span class="detail-value">{{file_name}}</span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">Reason:</span>
                    <span class="detail-value">{{threat_name}}</span>
                </div>
            </div>
            
            <p><strong>What does this mean?</strong></p>
            <p>Our automated security scanner detected something potentially harmful in your file. This can sometimes happen with:</p>
            <ul>
                <li>Files containing macros or scripts</li>
                <li>Password-protected archives</li>
                <li>Legitimate software that triggers false positives</li>
            </ul>
            
            <p><strong>What should I do?</strong></p>
            <p>If you believe this was a mistake, please contact your administrator. They can review the detection and restore the file if appropriate.</p>
        </div>
        <div class="footer">
            <p>This is an automated message from {{company_name}}.</p>
        </div>
    </div>
</body>
</html>',
    'SECURITY NOTICE

Hi,

A file you recently uploaded has been flagged by our security scanner and has been {{action_taken}} as a precaution.

FILE DETAILS:
- File: {{file_name}}
- Reason: {{threat_name}}

WHAT DOES THIS MEAN?
Our automated security scanner detected something potentially harmful in your file. This can sometimes happen with files containing macros, password-protected archives, or legitimate software that triggers false positives.

WHAT SHOULD I DO?
If you believe this was a mistake, please contact your administrator. They can review the detection and restore the file if appropriate.

This is an automated message from {{company_name}}.',
    '{"file_name": "Name of the flagged file", "threat_name": "Reason for flagging", "action_taken": "Action taken (quarantined, removed, flagged)", "company_name": "Organization name"}'::jsonb
)
ON CONFLICT (template_key) DO UPDATE SET
    name = EXCLUDED.name,
    subject = EXCLUDED.subject,
    body_html = EXCLUDED.body_html,
    body_text = EXCLUDED.body_text,
    variables = EXCLUDED.variables,
    updated_at = NOW();

