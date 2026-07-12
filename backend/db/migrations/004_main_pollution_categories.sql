-- Consolidate legacy 8 categories into 3 main pollution pillars
UPDATE reports SET category = 'landPollution'
WHERE category IN (
  'illegalMining', 'illegal_mining',
  'wasteDumping', 'waste_dumping',
  'noisePollution', 'noise_pollution',
  'deforestation',
  'landDegradation', 'land_degradation',
  'other'
);

UPDATE reports SET category = 'airPollution'
WHERE category IN ('air_pollution');

UPDATE reports SET category = 'waterPollution'
WHERE category IN ('water_pollution');

-- Clear deprecated officer slots before re-provisioning the 3 main pillars
UPDATE users SET assigned_category = NULL, is_active = FALSE
WHERE assigned_category IN (
  'illegalMining', 'wasteDumping', 'noisePollution',
  'deforestation', 'landDegradation', 'other',
  'illegal_mining', 'waste_dumping', 'noise_pollution',
  'land_degradation'
)
AND role_id = (SELECT id FROM roles WHERE name = 'environmental_officer');
