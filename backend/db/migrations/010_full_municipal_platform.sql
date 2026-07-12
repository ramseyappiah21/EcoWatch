-- Full municipal platform: officers, emergency, police,
-- assignment, investigation notes, audit logs, notifications, expanded statuses.

INSERT INTO roles (name, label, description, can_view, can_update, can_export, can_manage_users) VALUES
  ('emergency_officer', 'Emergency Response Officer', 'Emergency incidents for Fire Service and NADMO', TRUE, TRUE, FALSE, FALSE),
  ('police_support', 'Police Support', 'Law enforcement support for criminal environmental offences', TRUE, TRUE, FALSE, FALSE)
ON CONFLICT (name) DO UPDATE SET
  label = EXCLUDED.label,
  description = EXCLUDED.description,
  can_view = EXCLUDED.can_view,
  can_update = EXCLUDED.can_update,
  can_export = EXCLUDED.can_export;

UPDATE roles SET
  label = 'Environmental Officer',
  description = 'Field investigator for assigned incidents',
  can_view = TRUE,
  can_update = TRUE,
  can_export = FALSE,
  can_manage_users = FALSE
WHERE name = 'environmental_officer';

ALTER TABLE reports ADD COLUMN IF NOT EXISTS assigned_officer_id UUID REFERENCES users(id);
ALTER TABLE reports ADD COLUMN IF NOT EXISTS investigation_notes TEXT;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS escalated BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS escalated_at TIMESTAMPTZ;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS escalated_by UUID REFERENCES users(id);
ALTER TABLE reports ADD COLUMN IF NOT EXISTS needs_police BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS closed_at TIMESTAMPTZ;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS closure_approved_by UUID REFERENCES users(id);

CREATE INDEX IF NOT EXISTS idx_reports_assigned_officer ON reports(assigned_officer_id);
CREATE INDEX IF NOT EXISTS idx_reports_escalated ON reports(escalated) WHERE escalated = TRUE;

ALTER TABLE report_media ADD COLUMN IF NOT EXISTS uploaded_by UUID REFERENCES users(id);
ALTER TABLE report_media ADD COLUMN IF NOT EXISTS is_investigation BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE IF NOT EXISTS audit_logs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id    UUID REFERENCES users(id),
  actor_email VARCHAR(255),
  actor_role  VARCHAR(50),
  action      VARCHAR(80) NOT NULL,
  entity_type VARCHAR(50),
  entity_id   VARCHAR(80),
  details     JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON audit_logs(actor_id);

CREATE TABLE IF NOT EXISTS notifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title       VARCHAR(200) NOT NULL,
  body        TEXT NOT NULL,
  report_id   UUID REFERENCES reports(id) ON DELETE CASCADE,
  is_read     BOOLEAN NOT NULL DEFAULT FALSE,
  is_emergency BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, is_read, created_at DESC);

CREATE TABLE IF NOT EXISTS platform_settings (
  key         VARCHAR(80) PRIMARY KEY,
  value       JSONB NOT NULL,
  updated_by  UUID REFERENCES users(id),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO platform_settings (key, value) VALUES
  ('emergency_severity_threshold', '"high"'),
  ('routing_enabled', 'true'),
  ('backup_retention_days', '30')
ON CONFLICT (key) DO NOTHING;

-- Allow multiple agency admins/officers per agency (drop one-admin-only if present).
DROP INDEX IF EXISTS idx_users_one_admin_per_agency;
CREATE INDEX IF NOT EXISTS idx_users_assigned_agency ON users(assigned_agency);
