const express = require('express');
const bcrypt = require('bcryptjs');
const { pool } = require('../db/pool');
const { authMiddleware, requireRoles } = require('../middleware/auth');
const { auditFromUser } = require('../services/auditService');
const {
  listNotifications,
  markNotificationRead,
  markAllNotificationsRead,
} = require('../services/notificationService');
const {
  AGENCIES,
  PLATFORM_OWNER,
  PORTAL_ROLES,
  buildCategoryScope,
  canManageAnnouncements,
  canManageUsers,
  canManageSystemSettings,
  canViewAuditLogs,
  ANNOUNCEMENT_ROLES,
  MANAGE_USERS_ROLES,
  SYSTEM_SETTINGS_ROLES,
  AUDIT_ROLES,
  ASSIGN_ROLES,
} = require('../services/categoryService');

const router = express.Router();

/** GET /v1/admin/me/notifications */
router.get('/me/notifications', authMiddleware, requireRoles(...PORTAL_ROLES), async (req, res) => {
  const unreadOnly = req.query.unread === 'true';
  const items = await listNotifications(req.user.sub, { unreadOnly });
  res.json(items);
});

router.post('/me/notifications/read-all', authMiddleware, requireRoles(...PORTAL_ROLES), async (req, res) => {
  await markAllNotificationsRead(req.user.sub);
  res.json({ ok: true });
});

router.post('/me/notifications/:id/read', authMiddleware, requireRoles(...PORTAL_ROLES), async (req, res) => {
  await markNotificationRead(req.user.sub, req.params.id);
  res.json({ ok: true });
});

/** GET /v1/admin/officers — list officers assignable in scope */
router.get('/officers', authMiddleware, requireRoles(...ASSIGN_ROLES, 'environmental_officer', 'emergency_officer', 'police_support'), async (req, res) => {
  let agencyFilter = null;
  if (req.user.assignedAgency && !['super_admin', 'municipal_admin'].includes(req.user.role)) {
    agencyFilter = req.user.assignedAgency;
  } else if (req.query.agency) {
    agencyFilter = req.query.agency;
  }

  const params = [];
  let sql = `
    SELECT u.id::text AS id, u.email, u.display_name AS "displayName", u.assigned_agency AS "assignedAgency",
           r.name AS role, r.label AS "roleLabel"
    FROM users u
    JOIN roles r ON r.id = u.role_id
    WHERE u.is_active = TRUE
      AND r.name IN ('environmental_officer', 'emergency_officer', 'police_support')
      AND u.assigned_agency IS NOT NULL`;

  if (agencyFilter) {
    params.push(agencyFilter);
    sql += ` AND u.assigned_agency = $${params.length}`;
  }
  sql += ' ORDER BY u.display_name';

  const { rows } = await pool.query(sql, params);
  res.json(rows);
});

/** GET /v1/admin/users */
router.get('/users', authMiddleware, requireRoles(...MANAGE_USERS_ROLES, 'agency_admin'), async (req, res) => {
  const isMunicipal = ['super_admin', 'municipal_admin'].includes(req.user.role);
  const params = [];
  let sql = `
    SELECT u.id, u.email, u.display_name AS "displayName", u.assigned_agency AS "assignedAgency",
           u.assigned_category AS "assignedCategory", u.is_active AS "isActive",
           u.last_login_at AS "lastLoginAt", r.name AS role, r.label AS "roleLabel"
    FROM users u
    JOIN roles r ON r.id = u.role_id
    WHERE r.name = ANY($1)`;
  params.push(PORTAL_ROLES);

  if (!isMunicipal && req.user.assignedAgency) {
    params.push(req.user.assignedAgency);
    sql += ` AND u.assigned_agency = $${params.length}`;
  }
  sql += ' ORDER BY r.name, u.display_name';

  const { rows } = await pool.query(sql, params);
  res.json(rows);
});

/** POST /v1/admin/users — municipal registers agency users; agency admin can add officers in agency */
router.post('/users', authMiddleware, requireRoles(...MANAGE_USERS_ROLES, 'agency_admin'), async (req, res) => {
  const { email, password, displayName, role } = req.body;
  if (!email || !password || !displayName || !role) {
    return res.status(400).json({ error: 'email, password, displayName, and role are required' });
  }

  const isMunicipal = canManageUsers(req.user);
  const agencyOnlyRoles = ['environmental_officer', 'emergency_officer', 'police_support'];

  // Agency admins always register staff into their own department (ignore free-typed agency).
  let assignedAgency = req.body.assignedAgency || null;
  if (!isMunicipal) {
    if (!agencyOnlyRoles.includes(role)) {
      return res.status(403).json({ error: 'Agency admins may only create officers in their agency' });
    }
    if (!req.user.assignedAgency) {
      return res.status(403).json({ error: 'Your account has no department assigned' });
    }
    assignedAgency = req.user.assignedAgency;
  }

  if (!PORTAL_ROLES.includes(role)) {
    return res.status(400).json({ error: 'Invalid role' });
  }

  if (agencyOnlyRoles.includes(role) && !assignedAgency) {
    return res.status(400).json({
      error: 'Officers must belong to a department (agency key: epa, wrc, nadmo, fire, forestry, waste, police)',
    });
  }

  const passwordHash = await bcrypt.hash(password, 10);
  try {
    const { rows } = await pool.query(
      `INSERT INTO users (email, password_hash, display_name, role_id, assigned_agency, is_active)
       SELECT $1, $2, $3, id, $4, TRUE FROM roles WHERE name = $5
       RETURNING id, email, display_name AS "displayName", assigned_agency AS "assignedAgency"`,
      [email.toLowerCase(), passwordHash, displayName, assignedAgency, role],
    );
    if (!rows.length) {
      return res.status(400).json({ error: `Unknown role: ${role}` });
    }
    await auditFromUser(req.user, 'create_user', 'user', rows[0].id, { email, role, assignedAgency });
    res.status(201).json({ ...rows[0], role });
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ error: 'Email already exists' });
    console.error(err);
    res.status(500).json({ error: 'Failed to create user' });
  }
});

/** GET /v1/admin/agencies */
router.get('/agencies', authMiddleware, requireRoles(...PORTAL_ROLES), async (_req, res) => {
  const { rows } = await pool.query(
    `SELECT u.assigned_agency AS agency,
            COUNT(*) FILTER (WHERE r.name = 'agency_admin')::int AS admins,
            COUNT(*) FILTER (WHERE r.name = 'environmental_officer' OR r.name = 'police_support')::int AS officers,
            COUNT(*) FILTER (WHERE r.name = 'emergency_officer')::int AS emergencyOfficers
     FROM users u
     JOIN roles r ON r.id = u.role_id
     WHERE u.is_active = TRUE AND u.assigned_agency IS NOT NULL
     GROUP BY u.assigned_agency`,
  );
  const counts = Object.fromEntries(rows.map((r) => [r.agency, r]));

  res.json({
    platformOwner: PLATFORM_OWNER,
    agencies: AGENCIES.map((a) => ({
      key: a.key,
      name: a.name,
      short: a.short,
      categories: a.categories,
      supportOnly: Boolean(a.supportOnly),
      emergency: Boolean(a.emergency),
      portalEmail: a.email,
      staff: counts[a.key] || { admins: 0, officers: 0, emergencyOfficers: 0 },
    })),
  });
});

/** GET/POST announcements management */
router.get('/announcements', authMiddleware, requireRoles(...ANNOUNCEMENT_ROLES), async (_req, res) => {
  const { rows } = await pool.query(
    `SELECT id, title, body, is_public AS "isPublic", published_at AS "publishedAt",
            expires_at AS "expiresAt", created_at AS "createdAt"
     FROM announcements ORDER BY published_at DESC LIMIT 50`,
  );
  res.json(rows);
});

router.post('/announcements', authMiddleware, requireRoles(...ANNOUNCEMENT_ROLES), async (req, res) => {
  if (!canManageAnnouncements(req.user)) {
    return res.status(403).json({ error: 'Not authorized' });
  }
  const { title, body, isPublic = true, expiresAt = null } = req.body;
  if (!title || !body) return res.status(400).json({ error: 'title and body are required' });

  const { rows } = await pool.query(
    `INSERT INTO announcements (title, body, is_public, expires_at, created_by)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING id, title, body, is_public AS "isPublic", published_at AS "publishedAt",
               expires_at AS "expiresAt", created_at AS "createdAt"`,
    [title, body, Boolean(isPublic), expiresAt, req.user.sub],
  );
  await auditFromUser(req.user, 'create_announcement', 'announcement', rows[0].id, { title });
  res.status(201).json(rows[0]);
});

router.delete('/announcements/:id', authMiddleware, requireRoles(...ANNOUNCEMENT_ROLES), async (req, res) => {
  await pool.query('DELETE FROM announcements WHERE id = $1', [req.params.id]);
  await auditFromUser(req.user, 'delete_announcement', 'announcement', req.params.id);
  res.json({ ok: true });
});

/** Audit logs — super admin only; cannot delete */
router.get('/audit-logs', authMiddleware, requireRoles(...AUDIT_ROLES), async (req, res) => {
  if (!canViewAuditLogs(req.user)) {
    return res.status(403).json({ error: 'Not authorized' });
  }
  const { rows } = await pool.query(
    `SELECT id, actor_id AS "actorId", actor_email AS "actorEmail", actor_role AS "actorRole",
            action, entity_type AS "entityType", entity_id AS "entityId", details, created_at AS "createdAt"
     FROM audit_logs ORDER BY created_at DESC LIMIT 200`,
  );
  res.json(rows);
});

/** Platform settings — super admin only */
router.get('/settings', authMiddleware, requireRoles(...SYSTEM_SETTINGS_ROLES), async (req, res) => {
  if (!canManageSystemSettings(req.user)) {
    return res.status(403).json({ error: 'Not authorized' });
  }
  const { rows } = await pool.query(
    `SELECT key, value, updated_at AS "updatedAt" FROM platform_settings ORDER BY key`,
  );
  res.json(Object.fromEntries(rows.map((r) => [r.key, r.value])));
});

router.put('/settings', authMiddleware, requireRoles(...SYSTEM_SETTINGS_ROLES), async (req, res) => {
  if (!canManageSystemSettings(req.user)) {
    return res.status(403).json({ error: 'Not authorized' });
  }
  const entries = Object.entries(req.body || {});
  for (const [key, value] of entries) {
    await pool.query(
      `INSERT INTO platform_settings (key, value, updated_by, updated_at)
       VALUES ($1, $2::jsonb, $3, NOW())
       ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_by = EXCLUDED.updated_by, updated_at = NOW()`,
      [key, JSON.stringify(value), req.user.sub],
    );
  }
  await auditFromUser(req.user, 'update_settings', 'platform_settings', null, req.body);
  res.json({ ok: true });
});

/** Agency performance / response times — municipal + agency scoped */
router.get('/performance', authMiddleware, requireRoles(...PORTAL_ROLES), async (req, res) => {
  const scope = buildCategoryScope(req.user);
  const { rows } = await pool.query(
    `SELECT category,
            COUNT(*)::int AS total,
            COUNT(*) FILTER (WHERE status IN ('resolved', 'closed'))::int AS resolved,
            COUNT(*) FILTER (WHERE escalated)::int AS escalated,
            ROUND(AVG(EXTRACT(EPOCH FROM (COALESCE(closed_at, updated_at) - created_at)) / 3600)
              FILTER (WHERE status IN ('resolved', 'closed')))::numeric(10,1) AS avgResolutionHours,
            ROUND(AVG(EXTRACT(EPOCH FROM (updated_at - created_at)) / 3600))::numeric(10,1) AS avgResponseHours
     FROM reports
     WHERE TRUE${scope.clause}
     GROUP BY category
     ORDER BY total DESC`,
    scope.params,
  );

  const officers = await pool.query(
    `SELECT u.id, u.display_name AS "displayName", u.assigned_agency AS "assignedAgency",
            COUNT(r.id)::int AS assigned,
            COUNT(r.id) FILTER (WHERE r.status IN ('resolved', 'closed'))::int AS closed
     FROM users u
     JOIN roles role ON role.id = u.role_id
     LEFT JOIN reports r ON r.assigned_officer_id = u.id
     WHERE u.is_active = TRUE
       AND role.name IN ('environmental_officer', 'emergency_officer')
       ${req.user.assignedAgency && !['super_admin', 'municipal_admin', 'researcher'].includes(req.user.role)
    ? 'AND u.assigned_agency = $1'
    : ''}
     GROUP BY u.id, u.display_name, u.assigned_agency
     ORDER BY assigned DESC`,
    req.user.assignedAgency && !['super_admin', 'municipal_admin', 'researcher'].includes(req.user.role)
      ? [req.user.assignedAgency]
      : [],
  );

  res.json({
    byCategory: rows,
    officers: officers.rows,
  });
});

/**
 * POST /v1/admin/cleanup-seeded-reports
 * Removes demo seed incidents (Evidence attached / EW-DEMO-*), keeps real reports.
 */
router.post('/cleanup-seeded-reports', authMiddleware, requireRoles('super_admin', 'municipal_admin'), async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rows } = await client.query(`
      SELECT id, tracking_token
      FROM reports
      WHERE description ILIKE '%Evidence attached.%'
         OR tracking_token LIKE 'EW-DEMO-%'
    `);
    if (!rows.length) {
      await client.query('COMMIT');
      return res.json({ deleted: 0, remaining: (await client.query('SELECT count(*)::int AS n FROM reports')).rows[0].n });
    }
    const ids = rows.map((r) => r.id);
    await client.query('DELETE FROM reports WHERE id = ANY($1::uuid[])', [ids]);
    await auditFromUser(req.user, 'cleanup_seeded_reports', 'reports', null, { deleted: ids.length });
    await client.query('COMMIT');
    const remaining = await pool.query('SELECT count(*)::int AS n FROM reports');
    res.json({
      deleted: ids.length,
      tokens: rows.slice(0, 20).map((r) => r.tracking_token),
      remaining: remaining.rows[0].n,
    });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error(err);
    res.status(500).json({ error: 'Cleanup failed' });
  } finally {
    client.release();
  }
});

module.exports = router;
