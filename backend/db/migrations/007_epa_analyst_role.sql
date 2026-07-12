-- EPA national analyst: views all incidents for data analysis (read-only).
INSERT INTO roles (name, label, description, can_view, can_update, can_export, can_manage_users) VALUES
  ('epa_analyst', 'EPA Analyst', 'National incident data analysis (read-only)', TRUE, FALSE, TRUE, FALSE)
ON CONFLICT (name) DO NOTHING;
