/**
 * Removes seeded demo incidents (API evidence seed + EW-DEMO-* DB seed).
 * Keeps real user-submitted reports.
 *
 * Local:  node scripts/cleanup-seeded-reports.js
 * Cloud:  $env:DATABASE_URL="<Render External DB URL>"; node scripts/cleanup-seeded-reports.js
 */
const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const { Pool } = require('pg');
const { deleteStoredFile } = require('../src/services/mediaService');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' || (process.env.DATABASE_URL || '').includes('render.com')
    ? { rejectUnauthorized: false }
    : undefined,
});

const MATCH_SQL = `
  SELECT r.id, r.tracking_token, r.description, rm.storage_url
  FROM reports r
  LEFT JOIN report_media rm ON rm.report_id = r.id
  WHERE r.description ILIKE '%Evidence attached.%'
     OR r.tracking_token LIKE 'EW-DEMO-%'
`;

async function main() {
  const preview = await pool.query(`
    SELECT count(DISTINCT r.id)::int AS n
    FROM reports r
    WHERE r.description ILIKE '%Evidence attached.%'
       OR r.tracking_token LIKE 'EW-DEMO-%'
  `);
  const total = await pool.query('SELECT count(*)::int AS n FROM reports');
  console.log(`Matched seeded reports: ${preview.rows[0].n} (of ${total.rows[0].n} total)`);

  if (!preview.rows[0].n) {
    console.log('Nothing to delete.');
    await pool.end();
    return;
  }

  const rows = await pool.query(MATCH_SQL);
  const ids = [...new Set(rows.rows.map((r) => r.id))];
  const urls = rows.rows.map((r) => r.storage_url).filter(Boolean);

  for (const url of urls) {
    try {
      await deleteStoredFile(url);
    } catch (_) {
      /* cloud files may not exist on this disk */
    }
  }

  const del = await pool.query(
    'DELETE FROM reports WHERE id = ANY($1::uuid[]) RETURNING tracking_token',
    [ids],
  );
  console.log(`Deleted ${del.rowCount} report(s).`);
  console.log('Sample tokens removed:', del.rows.slice(0, 8).map((r) => r.tracking_token).join(', '));

  const left = await pool.query('SELECT count(*)::int AS n FROM reports');
  console.log(`Remaining reports: ${left.rows[0].n}`);
  await pool.end();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
