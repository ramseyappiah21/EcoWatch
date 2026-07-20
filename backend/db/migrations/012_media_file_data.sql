-- Persist evidence bytes in Postgres so photos survive ephemeral cloud disks (Render).
ALTER TABLE report_media ADD COLUMN IF NOT EXISTS file_data BYTEA;
