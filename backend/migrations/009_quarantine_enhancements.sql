-- Add file_size_bytes and owner_id columns to quarantined_files for better tracking
ALTER TABLE quarantined_files ADD COLUMN IF NOT EXISTS file_size_bytes BIGINT;
ALTER TABLE quarantined_files ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES users(id) ON DELETE SET NULL;

-- Backfill existing quarantined files with data from files_metadata where possible
UPDATE quarantined_files qf
SET 
    file_size_bytes = fm.size_bytes,
    owner_id = fm.owner_id
FROM files_metadata fm
WHERE qf.original_file_id = fm.id AND qf.file_size_bytes IS NULL;

