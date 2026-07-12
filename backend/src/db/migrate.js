const fs = require('fs');
const path = require('path');
const { pool } = require('./pool');

async function migrate() {
  const schemaPath = path.join(__dirname, '../../db/schema.sql');
  const sql = fs.readFileSync(schemaPath, 'utf8');
  try {
    await pool.query(sql);
    console.log('Database schema applied.');
  } catch (err) {
    if (err.code === '42P07') {
      console.log('Schema objects already exist — applying migrations only.');
    } else {
      throw err;
    }
  }

  const migrationsDir = path.join(__dirname, '../../db/migrations');
  if (fs.existsSync(migrationsDir)) {
    const files = fs.readdirSync(migrationsDir).filter((f) => f.endsWith('.sql')).sort();
    for (const file of files) {
      await pool.query(fs.readFileSync(path.join(migrationsDir, file), 'utf8'));
      console.log(`Migration applied: ${file}`);
    }
  }

  await pool.end();
}

migrate().catch((err) => {
  console.error(err);
  process.exit(1);
});
