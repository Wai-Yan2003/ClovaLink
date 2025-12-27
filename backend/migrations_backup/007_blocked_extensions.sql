-- Migration: Add blocked file extensions per tenant
-- This allows tenants to block certain file types (e.g., .exe, .bat, .sh) from being uploaded

-- Add blocked_extensions column to tenants table
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS blocked_extensions TEXT[] DEFAULT ARRAY[]::TEXT[];

-- Add some comments for documentation
COMMENT ON COLUMN tenants.blocked_extensions IS 'Array of file extensions that are blocked from upload (without the dot, e.g., exe, bat, sh)';

