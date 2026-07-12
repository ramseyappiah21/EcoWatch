const { Pool } = require('pg');
const config = require('../config');

/** Render / managed Postgres requires TLS */
function sslOption() {
  const url = config.databaseUrl || '';
  const force =
    process.env.DATABASE_SSL === 'true' ||
    process.env.NODE_ENV === 'production' ||
    /render\.com|amazonaws\.com|neon\.tech|supabase\.co/i.test(url);
  if (!force || process.env.DATABASE_SSL === 'false') return undefined;
  return { rejectUnauthorized: false };
}

const pool = new Pool({
  connectionString: config.databaseUrl,
  ssl: sslOption(),
});

pool.on('error', (err) => {
  console.error('Unexpected PostgreSQL error', err);
});

module.exports = { pool };
