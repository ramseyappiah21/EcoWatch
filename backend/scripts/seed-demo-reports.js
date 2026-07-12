/**
 * Seeds clustered demo reports for analytics charts and map hotspots.
 * Run: npm run db:seed-reports
 */
const { pool } = require('../src/db/pool');

const DEMO_PREFIX = 'EW-DEMO-';

/** Small random offset in degrees (~±150 m at Tarkwa latitude). */
function jitter(base, spread = 0.0015) {
  return base + (Math.random() - 0.5) * spread;
}

function daysAgo(n) {
  return new Date(Date.now() - n * 24 * 60 * 60 * 1000);
}

const CLUSTERS = [
  {
    name: 'Tarkwa Central — illegal mining',
    category: 'landPollution',
    center: { lat: 5.3018, lng: -1.9931 },
    count: 7,
    community: 'Tarkwa Central',
    description: 'AI detected: Illegal mining (galamsey). Unauthorized mining pits near residential area.',
    severities: ['medium', 'high', 'high', 'critical', 'medium', 'high', 'critical'],
    statuses: ['submitted', 'underReview', 'underReview', 'inProgress', 'inProgress', 'resolved', 'submitted'],
    sources: ['app', 'app', 'ussd', 'app', 'app', 'app', 'ussd'],
    dayOffsets: [1, 2, 3, 5, 7, 10, 12],
  },
  {
    name: 'River Ankobra — water pollution',
    category: 'waterPollution',
    center: { lat: 5.3185, lng: -1.9750 },
    count: 6,
    community: 'Nsuta',
    description: 'Demo — oily sheen and discoloured water in river',
    severities: ['high', 'high', 'medium', 'critical', 'high', 'medium'],
    statuses: ['submitted', 'underReview', 'inProgress', 'inProgress', 'resolved', 'submitted'],
    sources: ['app', 'app', 'app', 'ussd', 'app', 'app'],
    dayOffsets: [0, 2, 4, 6, 9, 14],
  },
  {
    name: 'Mining road — waste dumping',
    category: 'landPollution',
    center: { lat: 5.2850, lng: -2.0120 },
    count: 5,
    community: 'Banso',
    description: 'AI detected: Illegal waste dumping. Demo refuse dump near water channel',
    severities: ['medium', 'medium', 'high', 'high', 'low'],
    statuses: ['submitted', 'submitted', 'underReview', 'inProgress', 'resolved'],
    sources: ['ussd', 'app', 'app', 'app', 'app'],
    dayOffsets: [1, 3, 5, 8, 11],
  },
  {
    name: 'Industrial zone — air pollution',
    category: 'airPollution',
    center: { lat: 5.3150, lng: -2.0050 },
    count: 4,
    community: 'Tarkwa Industrial',
    description: 'Demo — thick smoke from unlicensed processing site',
    severities: ['medium', 'high', 'high', 'medium'],
    statuses: ['submitted', 'underReview', 'inProgress', 'submitted'],
    sources: ['app', 'app', 'app', 'ussd'],
    dayOffsets: [2, 4, 7, 13],
  },
];

const SCATTERED = [
  {
    token: `${DEMO_PREFIX}SCAT01`,
    category: 'landPollution',
    lat: 5.312,
    lng: -1.985,
    community: 'Tarkwa',
    severity: 'low',
    status: 'submitted',
    source: 'app',
    daysAgo: 4,
    description: 'Demo — excessive blasting noise at night',
  },
  {
    token: `${DEMO_PREFIX}SCAT02`,
    category: 'landPollution',
    lat: 5.295,
    lng: -2.005,
    community: 'Prestea Road',
    severity: 'medium',
    status: 'underReview',
    source: 'app',
    daysAgo: 6,
    description: 'AI detected: Deforestation. Demo unauthorised tree clearing',
  },
  {
    token: `${DEMO_PREFIX}SCAT03`,
    category: 'landPollution',
    lat: 5.289,
    lng: -1.978,
    community: 'Huni Valley',
    severity: 'high',
    status: 'resolved',
    source: 'ussd',
    daysAgo: 20,
    description: 'Demo — severe erosion from illegal pits',
  },
];

function severityScore(level) {
  const map = { low: 0, medium: 2, high: 4, critical: 6 };
  return map[level] ?? 1;
}

async function clearDemoReports() {
  const { rows } = await pool.query(
    `SELECT id FROM reports WHERE tracking_token LIKE $1`,
    [`${DEMO_PREFIX}%`],
  );
  if (!rows.length) return 0;
  const ids = rows.map((r) => r.id);
  await pool.query('DELETE FROM reports WHERE id = ANY($1::uuid[])', [ids]);
  return rows.length;
}

async function insertReport(report) {
  const createdAt = report.createdAt || new Date();
  const result = await pool.query(
    `INSERT INTO reports (
      tracking_token, category, title, description,
      latitude, longitude, accuracy_meters, address, landmark, community_name,
      status, severity, severity_score, source, is_anonymous, water_body_nearby,
      created_at, updated_at
    ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$17)
    RETURNING id`,
    [
      report.trackingToken,
      report.category,
      report.title || null,
      report.description,
      report.latitude,
      report.longitude,
      report.accuracyMeters ?? 25,
      report.community,
      report.community,
      report.community,
      report.status,
      report.severity,
      severityScore(report.severity),
      report.source,
      true,
      report.waterBodyNearby ?? false,
      createdAt,
    ],
  );

  const reportId = result.rows[0].id;
  await pool.query(
    `INSERT INTO report_status_history (report_id, status, message, created_at)
     VALUES ($1, 'submitted', 'Demo report seeded', $2)`,
    [reportId, createdAt],
  );

  if (report.status !== 'submitted') {
    await pool.query(
      `INSERT INTO report_status_history (report_id, status, message, created_at)
       VALUES ($1, $2, 'Demo status update', $3)`,
      [reportId, report.status, new Date(createdAt.getTime() + 3600000)],
    );
  }

  return reportId;
}

async function seedClusters() {
  let seq = 1;
  let inserted = 0;

  for (const cluster of CLUSTERS) {
    for (let i = 0; i < cluster.count; i++) {
      const token = `${DEMO_PREFIX}${String(seq).padStart(4, '0')}`;
      seq += 1;
      await insertReport({
        trackingToken: token,
        category: cluster.category,
        description: cluster.description,
        latitude: jitter(cluster.center.lat),
        longitude: jitter(cluster.center.lng),
        community: cluster.community,
        severity: cluster.severities[i] || 'medium',
        status: cluster.statuses[i] || 'submitted',
        source: cluster.sources[i] || 'app',
        waterBodyNearby: cluster.category === 'waterPollution',
        createdAt: daysAgo(cluster.dayOffsets[i] ?? i),
      });
      inserted += 1;
    }
  }

  for (const s of SCATTERED) {
    await insertReport({
      trackingToken: s.token,
      category: s.category,
      description: s.description,
      latitude: s.lat,
      longitude: s.lng,
      community: s.community,
      severity: s.severity,
      status: s.status,
      source: s.source,
      createdAt: daysAgo(s.daysAgo),
    });
    inserted += 1;
  }

  return inserted;
}

async function main() {
  console.log('\nEcoWatch — seeding demo reports for analytics & hotspots\n');
  const removed = await clearDemoReports();
  if (removed) console.log(`Removed ${removed} previous demo report(s)`);

  const count = await seedClusters();
  console.log(`Inserted ${count} demo reports (tracking tokens start with ${DEMO_PREFIX})`);
  console.log('Clusters: land (7), water (6), land waste (5), air (4)');
  console.log('Refresh http://localhost:3000/admin → Map & Analytics\n');
  await pool.end();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
