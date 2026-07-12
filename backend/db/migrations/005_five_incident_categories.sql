-- Five incident types with agency admins (no land pollution pillar)

UPDATE reports SET category = 'illegalMining'
WHERE category IN (
  'landPollution', 'land_pollution', 'illegalMining', 'illegal_mining',
  'deforestation', 'miningRunoff', 'mining_runoff'
);

UPDATE reports SET category = 'wasteDumping'
WHERE category IN (
  'wasteDumping', 'waste_dumping', 'landDegradation', 'land_degradation',
  'noisePollution', 'noise_pollution', 'hazardousLandWaste', 'other'
);

UPDATE reports SET category = 'airPollution'
WHERE category IN ('airPollution', 'air_pollution');

UPDATE reports SET category = 'waterPollution'
WHERE category IN ('waterPollution', 'water_pollution');

UPDATE users SET assigned_category = NULL, is_active = FALSE
WHERE assigned_category IN ('landPollution', 'land_pollution')
  AND role_id = (SELECT id FROM roles WHERE name = 'environmental_officer');
