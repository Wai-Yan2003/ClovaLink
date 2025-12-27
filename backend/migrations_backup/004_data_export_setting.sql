-- Add data_export_enabled setting to tenants table
-- This allows admins to enable/disable the user data export feature

ALTER TABLE tenants ADD COLUMN IF NOT EXISTS data_export_enabled BOOLEAN DEFAULT true;

COMMENT ON COLUMN tenants.data_export_enabled IS 
    'When true, users can export their personal data from their profile page';

