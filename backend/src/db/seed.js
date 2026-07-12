const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const { pool } = require('./pool');
const {
  AGENCIES,
  PLATFORM_OWNER,
  passwordForRole,
  emailForRole,
} = require('../services/categoryService');

async function runMigrations() {
  const migrationsDir = path.join(__dirname, '../../db/migrations');
  if (!fs.existsSync(migrationsDir)) return;

  const files = fs.readdirSync(migrationsDir).filter((f) => f.endsWith('.sql')).sort();
  for (const file of files) {
    const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');
    await pool.query(sql);
    console.log(`Migration applied: ${file}`);
  }
}

async function upsertUser({ email, name, role, agency, category, password }) {
  const passwordHash = await bcrypt.hash(password, 10);
  const result = await pool.query(
    `INSERT INTO users (email, password_hash, display_name, role_id, assigned_agency, assigned_category, is_active)
     SELECT $1, $2, $3, id, $4, $5, TRUE FROM roles WHERE name = $6
     ON CONFLICT (email) DO UPDATE SET
       password_hash = EXCLUDED.password_hash,
       display_name = EXCLUDED.display_name,
       assigned_agency = EXCLUDED.assigned_agency,
       assigned_category = EXCLUDED.assigned_category,
       is_active = TRUE,
       role_id = EXCLUDED.role_id
     RETURNING email`,
    [email, passwordHash, name, agency, category, role],
  );
  if (!result.rowCount) {
    throw new Error(`Failed to seed ${email}: role "${role}" is missing.`);
  }
  console.log(`  ${email} → ${password} (${role})`);
}

async function seed() {
  await runMigrations();

  // Ensure emergency/police roles exist even if an older schema was applied first
  await pool.query(`
    INSERT INTO roles (name, label, description, can_view, can_update, can_export, can_manage_users) VALUES
      ('emergency_officer', 'Emergency Response Officer', 'Emergency incidents for Fire Service and NADMO', TRUE, TRUE, FALSE, FALSE),
      ('police_support', 'Police Support', 'Law enforcement support for criminal environmental offences', TRUE, TRUE, FALSE, FALSE)
    ON CONFLICT (name) DO NOTHING
  `);
  await pool.query('DROP INDEX IF EXISTS idx_users_one_admin_per_agency');

  console.log(`\nPlatform owner: ${PLATFORM_OWNER.name}\n`);
  console.log('Municipal roles:');

  await upsertUser({
    email: emailForRole('super_admin'),
    name: `${PLATFORM_OWNER.name} — ICT`,
    role: 'super_admin',
    agency: null,
    category: null,
    password: passwordForRole('super_admin'),
  });

  await upsertUser({
    email: emailForRole('municipal_admin'),
    name: `${PLATFORM_OWNER.name} — Environmental Health`,
    role: 'municipal_admin',
    agency: null,
    category: null,
    password: passwordForRole('municipal_admin'),
  });

  await upsertUser({
    email: emailForRole('researcher'),
    name: 'Research Portal',
    role: 'researcher',
    agency: null,
    category: null,
    password: passwordForRole('researcher'),
  });

  await pool.query(
    `UPDATE users SET assigned_agency = NULL, assigned_category = NULL, is_active = FALSE
     WHERE role_id = (SELECT id FROM roles WHERE name = 'epa_analyst')`,
  );

  console.log('\nAgency staff:');
  for (const agency of AGENCIES) {
    const primaryCategory = agency.categories[0] || null;

    await upsertUser({
      email: agency.email,
      name: `${agency.name} Administrator`,
      role: agency.key === 'police' ? 'police_support' : 'agency_admin',
      agency: agency.key,
      category: primaryCategory,
      password: agency.password,
    });

    if (agency.key === 'police') continue;

    await upsertUser({
      email: emailForRole('environmental_officer', agency.key),
      name: `${agency.short} Field Officer`,
      role: 'environmental_officer',
      agency: agency.key,
      category: primaryCategory,
      password: passwordForRole('environmental_officer', agency.key),
    });

    if (agency.emergency) {
      await upsertUser({
        email: emailForRole('emergency_officer', agency.key),
        name: `${agency.short} Emergency Officer`,
        role: 'emergency_officer',
        agency: agency.key,
        category: primaryCategory,
        password: passwordForRole('emergency_officer', agency.key),
      });
      // Legacy alias (older docs used nadmo.emergency@…)
      await upsertUser({
        email: `${agency.key}.emergency@ecowatch.gov`,
        name: `${agency.short} Emergency Officer`,
        role: 'emergency_officer',
        agency: agency.key,
        category: primaryCategory,
        password: passwordForRole('emergency_officer', agency.key),
      });
    }
  }

  // Sample public announcement
  await pool.query(
    `INSERT INTO announcements (title, body, is_public, created_by)
     SELECT $1, $2, TRUE, u.id
     FROM users u
     JOIN roles r ON r.id = u.role_id
     WHERE r.name = 'municipal_admin'
     AND NOT EXISTS (SELECT 1 FROM announcements WHERE title = $3)
     LIMIT 1`,
    [
      'Welcome to EcoWatch Tarkwa',
      'This municipal platform is owned by Tarkwa-Nsuaem Municipal Assembly. Participating agencies manage incidents within their legal mandate.',
      'Welcome to EcoWatch Tarkwa',
    ],
  );

  console.log('\nPortal: http://localhost:3000/admin');
  console.log('Super Admin:     superadmin@ecowatch.gov / superadmin123');
  console.log('Municipal Admin: municipal@ecowatch.gov / municipal123');
  console.log('Researcher:      researcher@ecowatch.gov / researcher123');
  console.log('Agency admin:    {agency}@ecowatch.gov / {agency}123');
  console.log('Officer:         {agency}.officer@ecowatch.gov / {agency}off123');
  console.log('Emergency NADMO: nadmoemg@ecowatch.gov / nadmoemg123');
  console.log('Emergency Fire:  fireemg@ecowatch.gov / fireemg123');
  await pool.end();
}

seed().catch((err) => {
  console.error(err);
  process.exit(1);
});
