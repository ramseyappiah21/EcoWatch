-- Category officer assignments (run on existing databases)
ALTER TABLE users ADD COLUMN IF NOT EXISTS assigned_category VARCHAR(50);

DROP INDEX IF EXISTS idx_users_one_officer_per_category;
CREATE INDEX IF NOT EXISTS idx_users_assigned_category ON users(assigned_category);