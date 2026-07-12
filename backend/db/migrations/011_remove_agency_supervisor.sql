-- Remove agency_supervisor role entirely; agency admins handle assignment and closure.

DELETE FROM report_routing
WHERE recipient_role = 'agency_supervisor'
   OR recipient_user_id IN (
     SELECT u.id FROM users u
     JOIN roles r ON r.id = u.role_id
     WHERE r.name = 'agency_supervisor'
   );

DELETE FROM notifications
WHERE user_id IN (
  SELECT u.id FROM users u
  JOIN roles r ON r.id = u.role_id
  WHERE r.name = 'agency_supervisor'
);

UPDATE announcements
SET created_by = (
  SELECT u.id FROM users u
  JOIN roles r ON r.id = u.role_id
  WHERE r.name = 'municipal_admin' AND u.is_active = TRUE
  ORDER BY u.created_at
  LIMIT 1
)
WHERE created_by IN (
  SELECT u.id FROM users u
  JOIN roles r ON r.id = u.role_id
  WHERE r.name = 'agency_supervisor'
);

UPDATE reports
SET assigned_officer_id = NULL
WHERE assigned_officer_id IN (
  SELECT u.id FROM users u
  JOIN roles r ON r.id = u.role_id
  WHERE r.name = 'agency_supervisor'
);

UPDATE reports
SET escalated_by = NULL
WHERE escalated_by IN (
  SELECT u.id FROM users u
  JOIN roles r ON r.id = u.role_id
  WHERE r.name = 'agency_supervisor'
);

UPDATE reports
SET closure_approved_by = NULL
WHERE closure_approved_by IN (
  SELECT u.id FROM users u
  JOIN roles r ON r.id = u.role_id
  WHERE r.name = 'agency_supervisor'
);

UPDATE report_media
SET uploaded_by = NULL
WHERE uploaded_by IN (
  SELECT u.id FROM users u
  JOIN roles r ON r.id = u.role_id
  WHERE r.name = 'agency_supervisor'
);

UPDATE report_status_history
SET updated_by = NULL
WHERE updated_by IN (
  SELECT u.id FROM users u
  JOIN roles r ON r.id = u.role_id
  WHERE r.name = 'agency_supervisor'
);

UPDATE audit_logs
SET actor_id = NULL
WHERE actor_id IN (
  SELECT u.id FROM users u
  JOIN roles r ON r.id = u.role_id
  WHERE r.name = 'agency_supervisor'
);

UPDATE platform_settings
SET updated_by = NULL
WHERE updated_by IN (
  SELECT u.id FROM users u
  JOIN roles r ON r.id = u.role_id
  WHERE r.name = 'agency_supervisor'
);

DELETE FROM users
WHERE role_id = (SELECT id FROM roles WHERE name = 'agency_supervisor');

DELETE FROM roles WHERE name = 'agency_supervisor';
