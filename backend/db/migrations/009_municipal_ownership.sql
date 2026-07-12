-- Municipal ownership model (Tarkwa-Nsuaem Municipal Assembly).
-- Platform is municipality-owned; agencies manage incidents in their mandate.

INSERT INTO roles (name, label, description, can_view, can_update, can_export, can_manage_users) VALUES
  ('super_admin', 'Super Administrator', 'Municipal Assembly ICT — full platform access', TRUE, TRUE, TRUE, TRUE),
  ('municipal_admin', 'Municipal Administrator', 'Municipality-wide monitoring, reports, and agency coordination', TRUE, TRUE, TRUE, TRUE),
  ('agency_admin', 'Agency Administrator', 'Manages incidents routed to their agency mandate', TRUE, TRUE, TRUE, FALSE)
ON CONFLICT (name) DO UPDATE SET
  label = EXCLUDED.label,
  description = EXCLUDED.description,
  can_view = EXCLUDED.can_view,
  can_update = EXCLUDED.can_update,
  can_export = EXCLUDED.can_export,
  can_manage_users = EXCLUDED.can_manage_users;

UPDATE roles SET
  label = 'Researcher',
  description = 'Anonymized analytics and research export only'
WHERE name = 'researcher';

ALTER TABLE users ADD COLUMN IF NOT EXISTS assigned_agency VARCHAR(50);

-- Migrate category officers → agency admins (agency key derived later in seed).
UPDATE users u
SET role_id = (SELECT id FROM roles WHERE name = 'agency_admin')
WHERE u.role_id = (SELECT id FROM roles WHERE name = 'environmental_officer');

-- EPA national analyst is no longer a platform-owner role; deactivate legacy accounts.
UPDATE users
SET is_active = FALSE,
    assigned_category = NULL,
    assigned_agency = NULL
WHERE role_id = (SELECT id FROM roles WHERE name = 'epa_analyst');

DROP INDEX IF EXISTS idx_users_one_officer_per_category;
DROP INDEX IF EXISTS idx_users_one_admin_per_agency;

CREATE INDEX IF NOT EXISTS idx_users_assigned_agency ON users(assigned_agency);
