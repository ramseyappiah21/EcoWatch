-- Use agency names as admin display names (not generic officer titles)
UPDATE users u SET display_name = v.display_name
FROM (VALUES
  ('airPollution', 'EPA Ghana'),
  ('waterPollution', 'Water Resources Commission'),
  ('illegalMining', 'Minerals Commission'),
  ('wasteDumping', 'Tarkwa-Nsuaem Municipal Assembly'),
  ('flooding', 'NADMO')
) AS v(category, display_name)
WHERE u.assigned_category = v.category
  AND u.role_id = (SELECT id FROM roles WHERE name = 'environmental_officer');

UPDATE users SET display_name = 'EcoWatch Platform Admin'
WHERE email = 'superadmin@ecowatch.gov';
