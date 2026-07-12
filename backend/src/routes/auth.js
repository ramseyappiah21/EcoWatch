const express = require('express');
const bcrypt = require('bcryptjs');
const { pool } = require('../db/pool');
const { signToken } = require('../middleware/auth');
const {
  getAgencyByKey,
  getAgencyForCategory,
  PORTAL_ROLES,
} = require('../services/categoryService');

const router = express.Router();

router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password required' });
  }

  try {
    const { rows } = await pool.query(
      `SELECT u.*, r.name AS role_name
       FROM users u JOIN roles r ON r.id = u.role_id
       WHERE u.email = $1 AND u.is_active = TRUE`,
      [email.toLowerCase()],
    );

    if (!rows.length) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = rows[0];
    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    if (!PORTAL_ROLES.includes(user.role_name)) {
      return res.status(403).json({ error: 'Official admin credentials required' });
    }

    await pool.query('UPDATE users SET last_login_at = NOW() WHERE id = $1', [
      user.id,
    ]);

    const agency = user.assigned_agency
      ? getAgencyByKey(user.assigned_agency)
      : user.assigned_category
        ? getAgencyForCategory(user.assigned_category)
        : null;

    res.json({
      token: signToken(user),
      user: {
        id: String(user.id).toLowerCase(),
        email: user.email,
        displayName: user.display_name,
        role: user.role_name,
        assignedAgency: user.assigned_agency || agency?.key || null,
        assignedCategory: user.assigned_category || null,
        agencyName: agency?.name || null,
        agencyShort: agency?.short || null,
        categoryLabel: agency
          ? agency.categories.join(', ')
          : null,
      },
    });
  } catch (err) {
    console.error('Login failed:', err);
    if (err.code === 'ECONNREFUSED' || err.code === 'ENOTFOUND') {
      return res.status(503).json({
        error: 'Database unavailable. Start PostgreSQL (docker compose up -d postgres).',
      });
    }
    res.status(500).json({ error: 'Login failed' });
  }
});

router.post('/logout', (_req, res) => {
  res.json({ message: 'Logged out' });
});

module.exports = router;
