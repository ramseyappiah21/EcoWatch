/**
 * Posts clustered demo incidents (all categories) with JPEG evidence via the API.
 * Run with API up: npm run db:seed-evidence
 *
 * Env: API_URL (default http://localhost:3000)
 */
const fs = require('fs');
const path = require('path');

const BASE = process.env.API_URL || 'http://localhost:3000';
const EVIDENCE_DIR = path.join(__dirname, 'demo-evidence');

/** Minimal valid 1×1 JPEG (colored via comment in filename only — real bytes below). */
function writeMinimalJpeg(filePath, r, g, b) {
  // Tiny valid JPEG; color channels are approximate via different files for demo.
  const jpeg = Buffer.from([
    0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01,
    0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xff, 0xdb, 0x00, 0x43,
    0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
    0x09, 0x08, 0x0a, 0x0c, 0x14, 0x0d, 0x0c, 0x0b, 0x0b, 0x0c, 0x19, 0x12,
    0x13, 0x0f, 0x14, 0x1d, 0x1a, 0x1f, 0x1e, 0x1d, 0x1a, 0x1c, 0x1c, 0x20,
    0x24, 0x2e, 0x27, 0x20, 0x22, 0x2c, 0x23, 0x1c, 0x1c, 0x28, 0x37, 0x29,
    0x2c, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1f, 0x27, 0x39, 0x3d, 0x38, 0x32,
    0x3c, 0x2e, 0x33, 0x34, 0x32, 0xff, 0xc0, 0x00, 0x0b, 0x08, 0x00, 0x01,
    0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xff, 0xc4, 0x00, 0x1f, 0x00, 0x00,
    0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
    0x09, 0x0a, 0x0b, 0xff, 0xc4, 0x00, 0xb5, 0x10, 0x00, 0x02, 0x01, 0x03,
    0x03, 0x02, 0x04, 0x03, 0x05, 0x05, 0x04, 0x04, 0x00, 0x00, 0x01, 0x7d,
    0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06,
    0x13, 0x51, 0x61, 0x07, 0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xa1, 0x08,
    0x23, 0x42, 0xb1, 0xc1, 0x15, 0x52, 0xd1, 0xf0, 0x24, 0x33, 0x62, 0x72,
    0x82, 0x09, 0x0a, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x25, 0x26, 0x27, 0x28,
    0x29, 0x2a, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x43, 0x44, 0x45,
    0x46, 0x47, 0x48, 0x49, 0x4a, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59,
    0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6a, 0x73, 0x74, 0x75,
    0x76, 0x77, 0x78, 0x79, 0x7a, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
    0x8a, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0xa2, 0xa3,
    0xa4, 0xa5, 0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6,
    0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3, 0xc4, 0xc5, 0xc6, 0xc7, 0xc8, 0xc9,
    0xca, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda, 0xe1, 0xe2,
    0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea, 0xf1, 0xf2, 0xf3, 0xf4,
    0xf5, 0xf6, 0xf7, 0xf8, 0xf9, 0xfa, 0xff, 0xda, 0x00, 0x08, 0x01, 0x01,
    0x00, 0x00, 0x3f, 0x00, (r ^ g ^ b) & 0xff, 0xd2, 0xcf, 0x20, 0xff, 0xd9,
  ]);
  fs.writeFileSync(filePath, jpeg);
}

function ensureEvidenceFiles() {
  fs.mkdirSync(EVIDENCE_DIR, { recursive: true });
  const files = {
    mining: path.join(EVIDENCE_DIR, 'illegal-mining.jpg'),
    water: path.join(EVIDENCE_DIR, 'water-pollution.jpg'),
    waste: path.join(EVIDENCE_DIR, 'waste-dumping.jpg'),
    air: path.join(EVIDENCE_DIR, 'air-pollution.jpg'),
    flood: path.join(EVIDENCE_DIR, 'flooding.jpg'),
    fire: path.join(EVIDENCE_DIR, 'bush-fire.jpg'),
    logging: path.join(EVIDENCE_DIR, 'illegal-logging.jpg'),
    chemical: path.join(EVIDENCE_DIR, 'chemical-spill.jpg'),
  };
  writeMinimalJpeg(files.mining, 120, 80, 40);
  writeMinimalJpeg(files.water, 40, 90, 160);
  writeMinimalJpeg(files.waste, 90, 90, 50);
  writeMinimalJpeg(files.air, 160, 160, 160);
  writeMinimalJpeg(files.flood, 50, 100, 180);
  writeMinimalJpeg(files.fire, 200, 80, 20);
  writeMinimalJpeg(files.logging, 40, 120, 40);
  writeMinimalJpeg(files.chemical, 180, 40, 180);
  return files;
}

function jitter(base, spread = 0.0012) {
  return base + (Math.random() - 0.5) * spread;
}

/**
 * Dense clusters so DBSCAN hotspots light up on the admin map.
 * Centers sit inside the Tarkwa study area (lat 5.25–5.38, lng -2.08–-1.90).
 */
const CLUSTERS = [
  {
    key: 'mining',
    category: 'illegalMining',
    label: 'Illegal mining (galamsey)',
    center: { lat: 5.3018, lng: -1.9931 },
    community: 'Tarkwa Central',
    count: 6,
    waterBodyNearby: false,
    description: 'Unauthorized mining pits and dredging near residential area. Evidence attached.',
  },
  {
    key: 'water',
    category: 'waterPollution',
    label: 'Water pollution',
    center: { lat: 5.3185, lng: -1.975 },
    community: 'Nsuta / Ankobra',
    count: 6,
    waterBodyNearby: true,
    description: 'Oily sheen and discoloured river water. Evidence attached.',
  },
  {
    key: 'waste',
    category: 'wasteDumping',
    label: 'Waste dumping',
    center: { lat: 5.285, lng: -2.012 },
    community: 'Banso',
    count: 5,
    waterBodyNearby: true,
    description: 'Open refuse dump beside drainage channel. Evidence attached.',
  },
  {
    key: 'air',
    category: 'airPollution',
    label: 'Air pollution',
    center: { lat: 5.315, lng: -2.005 },
    community: 'Tarkwa Industrial',
    count: 5,
    waterBodyNearby: false,
    description: 'Thick smoke from unlicensed processing site. Evidence attached.',
  },
  {
    key: 'flood',
    category: 'flooding',
    label: 'Flooding',
    center: { lat: 5.298, lng: -1.988 },
    community: 'Railways',
    count: 4,
    waterBodyNearby: true,
    description: 'Street flooding after heavy rain; blocked drains. Evidence attached.',
  },
  {
    key: 'fire',
    category: 'bushFire',
    label: 'Bush fire',
    center: { lat: 5.33, lng: -1.995 },
    community: 'Aboso fringe',
    count: 4,
    waterBodyNearby: false,
    description: 'Active bush fire along farm edge. Evidence attached.',
  },
  {
    key: 'logging',
    category: 'illegalLogging',
    label: 'Illegal logging',
    center: { lat: 5.275, lng: -1.97 },
    community: 'Huni Valley',
    count: 4,
    waterBodyNearby: false,
    description: 'Unauthorised tree felling in reserved fringe. Evidence attached.',
  },
  {
    key: 'chemical',
    category: 'chemicalSpill',
    label: 'Chemical spill',
    center: { lat: 5.308, lng: -2.0 },
    community: 'Cyanide plant road',
    count: 4,
    waterBodyNearby: true,
    description: 'Suspected chemical spill near plant access road. Evidence attached.',
  },
];

async function postReport(incident, evidencePath) {
  const form = new FormData();
  form.append('category', incident.category);
  form.append('title', incident.label);
  form.append('description', incident.description);
  form.append('latitude', String(incident.latitude));
  form.append('longitude', String(incident.longitude));
  form.append('accuracyMeters', '20');
  form.append('address', incident.community);
  form.append('landmark', incident.community);
  form.append('communityName', incident.community);
  form.append('source', 'app');
  form.append('isAnonymous', 'true');
  form.append('waterBodyNearby', incident.waterBodyNearby ? 'true' : 'false');

  const bytes = fs.readFileSync(evidencePath);
  const blob = new Blob([bytes], { type: 'image/jpeg' });
  form.append('media', blob, path.basename(evidencePath));

  const res = await fetch(`${BASE}/v1/reports`, { method: 'POST', body: form });
  const text = await res.text();
  let data;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = { raw: text };
  }
  if (!res.ok) {
    throw new Error(`${res.status} ${JSON.stringify(data)}`);
  }
  return data;
}

async function main() {
  console.log(`\nEcoWatch — seeding incidents with evidence → ${BASE}\n`);

  const health = await fetch(`${BASE}/health`).catch(() => null);
  if (!health || !health.ok) {
    console.error('API is not reachable. Start it with: npm start (in backend/)');
    process.exit(1);
  }

  const files = ensureEvidenceFiles();
  let ok = 0;
  let failed = 0;
  const summary = [];

  for (const cluster of CLUSTERS) {
    const evidencePath = files[cluster.key];
    console.log(`→ ${cluster.label} × ${cluster.count} @ ${cluster.community}`);
    for (let i = 0; i < cluster.count; i += 1) {
      try {
        const created = await postReport(
          {
            category: cluster.category,
            label: `${cluster.label} #${i + 1}`,
            description: `${cluster.description} (${i + 1}/${cluster.count})`,
            latitude: jitter(cluster.center.lat),
            longitude: jitter(cluster.center.lng),
            community: cluster.community,
            waterBodyNearby: cluster.waterBodyNearby,
          },
          evidencePath,
        );
        const mediaCount = created.media?.length ?? 0;
        ok += 1;
        if (i === 0) {
          summary.push({
            category: cluster.category,
            token: created.trackingToken,
            media: mediaCount,
            community: cluster.community,
          });
        }
        process.stdout.write(mediaCount > 0 ? '.' : '!');
      } catch (err) {
        failed += 1;
        process.stdout.write('x');
        console.error(`\n  failed: ${err.message}`);
      }
    }
    console.log('');
  }

  console.log(`\nCreated ${ok} reports (${failed} failed)`);
  console.log('Sample tokens (first of each category):');
  for (const row of summary) {
    console.log(`  ${row.category.padEnd(16)} ${row.token}  media=${row.media}  ${row.community}`);
  }
  console.log('\nOpen admin → Reports (Evidence column) and Map/Analytics (DBSCAN hotspots).');
  console.log('  http://localhost:3000/admin\n');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
