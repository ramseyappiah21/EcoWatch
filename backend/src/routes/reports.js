const express = require('express');
const multer = require('multer');
const { pool } = require('../db/pool');
const { generateTrackingToken } = require('../services/tokenService');
const { computeSeverityForReport } = require('../services/severityService');
const { storeMediaFile, mediaTypeFromFile } = require('../services/mediaService');
const { routeReportToAdmins } = require('../services/reportRoutingService');
const { sendSmsSafe, statusUpdateMessage } = require('../services/smsService');
const {
  ADMIN_STATUSES,
  toCitizenStatus,
  nextAdminStatus,
  normalizeStatus,
  canCloseReport,
  canAdvanceInvestigation,
  statusLabel,
} = require('../services/statusService');
const { authMiddleware, requireRoles } = require('../middleware/auth');
const { auditFromUser } = require('../services/auditService');
const { notifyOfficerAssigned, notifyEscalation } = require('../services/notificationService');
const {
  buildCategoryScope,
  normalizeMainCategory,
  canAssignOfficers,
  canInvestigate,
  isResearcher,
  anonymizeCoordinate,
  agenciesForCategory,
  PORTAL_ROLES,
  STATUS_UPDATE_ROLES,
  INVESTIGATION_ROLES,
  CLOSE_ROLES,
  ASSIGN_ROLES,
} = require('../services/categoryService');

const router = express.Router();
const upload = multer({ dest: 'uploads/tmp' });

function resolveMediaUrl(storageUrl, req) {
  if (!storageUrl) return storageUrl;
  if (storageUrl.includes('ecowatch-media/')) {
    const filename = storageUrl.split('/').pop();
    storageUrl = `/uploads/${filename}`;
  }
  if (storageUrl.startsWith('http')) return storageUrl;
  const host = req?.get?.('host') ? `${req.protocol}://${req.get('host')}` : '';
  return host ? `${host}${storageUrl.startsWith('/') ? storageUrl : `/${storageUrl}`}` : storageUrl;
}

function isVisualMediaRow(row) {
  return row.media_type !== 'audio' && !(row.mime_type || '').startsWith('audio');
}

function mapMedia(row, req) {
  const url = resolveMediaUrl(row.storage_url, req);
  return {
    id: row.id,
    type: row.media_type === 'video'
      ? 'video'
      : row.media_type === 'audio'
        ? 'audio'
        : 'photo',
    localPath: '',
    remoteUrl: url,
    storageUrl: url,
    mimeType: row.mime_type,
    fileSizeBytes: row.file_size_bytes ? Number(row.file_size_bytes) : null,
    capturedAt: row.captured_at || row.created_at,
    isInvestigation: Boolean(row.is_investigation),
    uploadedBy: row.uploaded_by || null,
  };
}

function mapStatusHistory(row, citizen = false) {
  return {
    status: citizen ? toCitizenStatus(row.status) : row.status,
    statusLabel: citizen ? undefined : statusLabel(row.status),
    timestamp: row.timestamp || row.created_at,
    message: row.message,
    updatedBy: row.updated_by || null,
  };
}

function mapReport(row, media = [], history = [], req = null, options = {}) {
  const citizen = options.audience === 'citizen';
  const researcher = options.audience === 'researcher' || options.anonymize === true;

  if (researcher) {
    const created = new Date(row.created_at);
    const updated = new Date(row.updated_at || row.created_at);
    const resolutionHours = ['resolved', 'closed'].includes(normalizeStatus(row.status))
      ? Math.round((updated - created) / 36e5)
      : null;
    return {
      id: row.id,
      trackingToken: null,
      category: row.category,
      title: null,
      description: null,
      hasDescription: Boolean(row.description && String(row.description).trim()),
      location: {
        latitude: anonymizeCoordinate(row.latitude),
        longitude: anonymizeCoordinate(row.longitude),
        accuracyMeters: null,
        address: null,
        landmark: null,
      },
      status: normalizeStatus(row.status),
      severity: row.severity,
      severityScore: row.severity_score,
      source: row.source,
      isAnonymous: true,
      waterBodyNearby: row.water_body_nearby,
      communityName: row.community_name,
      syncStatus: row.sync_status || 'synced',
      media: [],
      statusHistory: history.map((h) => ({
        status: normalizeStatus(h.status),
        timestamp: h.timestamp || h.created_at,
        message: null,
        updatedBy: null,
      })),
      resolutionHours,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      anonymized: true,
    };
  }

  return {
    id: row.id,
    trackingToken: row.tracking_token,
    category: row.category,
    title: row.title,
    description: row.description,
    hasDescription: Boolean(row.description && String(row.description).trim()),
    location: {
      latitude: row.latitude,
      longitude: row.longitude,
      accuracyMeters: row.accuracy_meters,
      address: row.address,
      landmark: row.landmark,
    },
    status: citizen ? toCitizenStatus(row.status) : normalizeStatus(row.status),
    statusLabel: citizen ? undefined : statusLabel(normalizeStatus(row.status)),
    severity: row.severity,
    severityScore: row.severity_score,
    source: row.source,
    isAnonymous: row.is_anonymous,
    waterBodyNearby: row.water_body_nearby,
    communityName: row.community_name,
    syncStatus: row.sync_status || 'synced',
    assignedOfficerId: row.assigned_officer_id || null,
    assignedOfficerName: row.assigned_officer_name || null,
    investigationNotes: citizen ? null : (row.investigation_notes || null),
    escalated: Boolean(row.escalated),
    needsPolice: Boolean(row.needs_police),
    reporterPhone: citizen || researcher ? null : (row.reporter_phone || null),
    media: media.filter(isVisualMediaRow).map((m) => mapMedia(m, req)),
    statusHistory: history.map((h) => mapStatusHistory(h, citizen)),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

async function mediaByReportIds(reportIds) {
  if (!reportIds.length) return {};
  const { rows } = await pool.query(
    'SELECT * FROM report_media WHERE report_id = ANY($1::uuid[]) ORDER BY created_at',
    [reportIds],
  );
  const map = {};
  for (const row of rows) {
    if (!map[row.report_id]) map[row.report_id] = [];
    map[row.report_id].push(row);
  }
  return map;
}

function sameUserId(a, b) {
  if (a == null || b == null) return false;
  return String(a).toLowerCase() === String(b).toLowerCase();
}

async function loadScopedReport(req, res) {
  const scope = buildCategoryScope(req.user, 2);
  const { rows } = await pool.query(
    `SELECT r.*, u.display_name AS assigned_officer_name
     FROM reports r
     LEFT JOIN users u ON u.id = r.assigned_officer_id
     WHERE r.id = $1${scope.clause}`,
    [req.params.id, ...scope.params],
  );
  if (!rows.length) {
    res.status(403).json({
      error: INVESTIGATION_ROLES.includes(req.user.role)
        ? 'Not authorized — this case is not assigned to you'
        : 'Not authorized for this report',
    });
    return null;
  }
  return rows[0];
}

/** POST /v1/reports — anonymous mobile submit */
router.post('/', upload.array('media', 5), async (req, res) => {
  const client = await pool.connect();
  try {
    const body = req.body;
    const trackingToken = generateTrackingToken();
    const mainCategory = normalizeMainCategory(body.category);

    await client.query('BEGIN');

    const insert = await client.query(
      `INSERT INTO reports (
        tracking_token, category, title, description,
        latitude, longitude, accuracy_meters, address, landmark, community_name,
        source, is_anonymous, water_body_nearby, ai_suggested_category, ai_confidence,
        status
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,'received')
      RETURNING *`,
      [
        trackingToken,
        mainCategory,
        body.title || null,
        body.description?.trim() || '',
        Number(body.latitude),
        Number(body.longitude),
        body.accuracyMeters ? Number(body.accuracyMeters) : null,
        body.address || body.communityName || null,
        body.landmark || body.communityName || null,
        body.communityName || null,
        body.source || 'app',
        body.isAnonymous !== 'false',
        body.waterBodyNearby === 'true',
        body.aiSuggestedCategory || null,
        body.aiConfidence ? Number(body.aiConfidence) : null,
      ],
    );

    const report = insert.rows[0];
    const mediaRows = [];

    if (req.files?.length) {
      for (const file of req.files) {
        let stored;
        let mediaType;
        try {
          stored = await storeMediaFile(file);
          mediaType = mediaTypeFromFile(file);
        } catch (err) {
          await client.query('ROLLBACK');
          return res.status(400).json({ error: err.message || 'Invalid media file' });
        }
        const mediaInsert = await client.query(
          `INSERT INTO report_media (report_id, media_type, storage_url, mime_type, file_size_bytes)
           VALUES ($1, $2, $3, $4, $5) RETURNING *`,
          [
            report.id,
            mediaType,
            stored.storageUrl,
            stored.mimeType,
            stored.fileSizeBytes,
          ],
        );
        mediaRows.push(mediaInsert.rows[0]);
      }
    }

    const severity = await computeSeverityForReport(client, {
      id: report.id,
      latitude: report.latitude,
      longitude: report.longitude,
      has_media: mediaRows.length > 0,
    });

    await client.query(
      `UPDATE reports SET severity_score = $1, severity = $2, updated_at = NOW() WHERE id = $3`,
      [severity.score, severity.level, report.id],
    );
    report.severity = severity.level;
    report.severity_score = severity.score;

    await client.query(
      `INSERT INTO report_status_history (report_id, status, message)
       VALUES ($1, 'received', 'Report received — under review')`,
      [report.id],
    );

    await routeReportToAdmins(client, report);
    await client.query('COMMIT');

    const updated = await pool.query('SELECT * FROM reports WHERE id = $1', [report.id]);

    res.status(201).json(
      mapReport(
        updated.rows[0],
        mediaRows,
        [{ status: 'received', message: 'Report received — under review', created_at: updated.rows[0].created_at }],
        req,
        { audience: 'citizen' },
      ),
    );
  } catch (err) {
    await client.query('ROLLBACK');
    console.error(err);
    res.status(500).json({ error: 'Failed to create report' });
  } finally {
    client.release();
  }
});

/** GET /v1/reports/track/:token — public status tracking */
router.get('/track/:token', async (req, res) => {
  const { rows } = await pool.query(
    'SELECT * FROM reports WHERE tracking_token = $1',
    [req.params.token.toUpperCase()],
  );
  if (!rows.length) {
    return res.status(404).json({ error: 'Invalid tracking token' });
  }

  const report = rows[0];
  const [history, media] = await Promise.all([
    pool.query(
      `SELECT status, message, created_at AS timestamp
       FROM report_status_history WHERE report_id = $1 ORDER BY created_at`,
      [report.id],
    ),
    pool.query('SELECT * FROM report_media WHERE report_id = $1 AND COALESCE(is_investigation, FALSE) = FALSE', [report.id]),
  ]);

  res.json(mapReport(report, media.rows, history.rows, req, { audience: 'citizen' }));
});

/** GET /v1/reports — dashboard list */
router.get('/', authMiddleware, requireRoles(...PORTAL_ROLES), async (req, res) => {
  const scope = buildCategoryScope(req.user);
  const { rows } = await pool.query(
    `SELECT r.*, u.display_name AS assigned_officer_name
     FROM reports r
     LEFT JOIN users u ON u.id = r.assigned_officer_id
     WHERE TRUE${scope.clause}
     ORDER BY r.escalated DESC, r.created_at DESC
     LIMIT 300`,
    scope.params,
  );
  const researcher = isResearcher(req.user);
  const mediaMap = researcher ? {} : await mediaByReportIds(rows.map((r) => r.id));
  res.json(rows.map((r) => mapReport(r, mediaMap[r.id] || [], [], req, {
    audience: researcher ? 'researcher' : 'admin',
  })));
});

/** PATCH /v1/reports/:id/status — officers advance investigation; agency leadership closes */
router.patch('/:id/status', authMiddleware, requireRoles(...STATUS_UPDATE_ROLES, ...CLOSE_ROLES), async (req, res) => {
  const { status, message } = req.body;
  if (!status) return res.status(400).json({ error: 'status is required' });

  const target = normalizeStatus(status);
  if (!ADMIN_STATUSES.includes(target) && !ADMIN_STATUSES.includes(status)) {
    return res.status(400).json({
      error: `Invalid status. Allowed: received, underInvestigation, siteVisited, awaitingAction, resolved, closed`,
    });
  }

  if (target === 'closed') {
    if (!canCloseReport(req.user)) {
      return res.status(403).json({ error: 'Only agency leadership or municipal admins may close reports' });
    }
  } else if (!canAdvanceInvestigation(req.user)) {
    return res.status(403).json({
      error: 'Investigation actions are updated by assigned officers, not agency administrators',
    });
  }

  const existing = await loadScopedReport(req, res);
  if (!existing) return;

  // Field officers may only update cases assigned to them
  if (INVESTIGATION_ROLES.includes(req.user.role)) {
    if (!existing.assigned_officer_id || !sameUserId(existing.assigned_officer_id, req.user.sub)) {
      return res.status(403).json({ error: 'You may only update cases assigned to you' });
    }
  }

  const current = normalizeStatus(existing.status);
  const allowedNext = nextAdminStatus(current);

  if (!allowedNext) {
    return res.status(400).json({ error: 'Closed reports cannot be changed' });
  }
  if (target === current) {
    return res.status(400).json({ error: 'Report is already at this status' });
  }
  if (target !== allowedNext) {
    return res.status(400).json({
      error: `From ${statusLabel(current)} you may only move to ${statusLabel(allowedNext)}`,
    });
  }

  const updates = ['status = $1', 'updated_at = NOW()'];
  const params = [target];
  let idx = 2;
  if (target === 'closed') {
    updates.push(`closed_at = NOW()`, `closure_approved_by = $${idx++}`);
    params.push(req.user.sub);
  }
  params.push(req.params.id);

  const updated = await pool.query(
    `UPDATE reports SET ${updates.join(', ')} WHERE id = $${idx} RETURNING *`,
    params,
  );

  await pool.query(
    `INSERT INTO report_status_history (report_id, status, message, updated_by)
     VALUES ($1, $2, $3, $4)`,
    [req.params.id, target, message || null, req.user.sub],
  );

  await auditFromUser(req.user, 'status_update', 'report', req.params.id, {
    from: current,
    to: target,
    message,
  });

  const reportRow = updated.rows[0];
  if (reportRow.reporter_phone && (target === 'underInvestigation' || target === 'resolved' || target === 'closed')) {
    sendSmsSafe(
      reportRow.reporter_phone,
      statusUpdateMessage(reportRow.tracking_token, target === 'underInvestigation' ? 'inProgress' : target === 'closed' ? 'resolved' : target),
    );
  }

  const media = await pool.query('SELECT * FROM report_media WHERE report_id = $1', [req.params.id]);
  const history = await pool.query(
    `SELECT status, message, created_at AS timestamp, updated_by
     FROM report_status_history WHERE report_id = $1 ORDER BY created_at`,
    [req.params.id],
  );

  res.json(mapReport({ ...reportRow, assigned_officer_name: existing.assigned_officer_name }, media.rows, history.rows, req));
});

/** PATCH /v1/reports/:id/assign — assign / reassign officer */
router.patch('/:id/assign', authMiddleware, requireRoles(...ASSIGN_ROLES), async (req, res) => {
  if (!canAssignOfficers(req.user)) {
    return res.status(403).json({ error: 'Not authorized to assign officers' });
  }

  const { officerId } = req.body;
  if (!officerId) return res.status(400).json({ error: 'officerId is required' });

  const existing = await loadScopedReport(req, res);
  if (!existing) return;

  const currentStatus = normalizeStatus(existing.status);
  if (currentStatus !== 'received') {
    return res.status(400).json({
      error: 'Officers can only be assigned while the incident is Received. After assignment, the officer updates the status.',
    });
  }

  const officer = await pool.query(
    `SELECT u.id::text AS id, u.display_name, u.assigned_agency, r.name AS role_name
     FROM users u JOIN roles r ON r.id = u.role_id
     WHERE u.id::text = LOWER($1::text) AND u.is_active = TRUE
       AND r.name IN ('environmental_officer', 'emergency_officer', 'police_support')`,
    [String(officerId).toLowerCase()],
  );
  if (!officer.rowCount) {
    return res.status(400).json({ error: 'Invalid officer — register them as Environmental Officer in your department' });
  }

  const officerRow = officer.rows[0];
  const officerAgency = officerRow.assigned_agency;
  if (!officerAgency) {
    return res.status(400).json({
      error: 'Officer has no department. Re-register them under your agency.',
    });
  }

  const reportAgencies = agenciesForCategory(existing.category).map((a) => a.key);
  if (existing.needs_police && !reportAgencies.includes('police')) {
    reportAgencies.push('police');
  }

  // Officer must belong to a department responsible for this incident type
  if (!reportAgencies.includes(officerAgency)) {
    return res.status(403).json({
      error: 'Officer is not in a department responsible for this incident type',
    });
  }

  // Agency-scoped assigners may only assign within their own department
  if (req.user.assignedAgency && officerAgency !== req.user.assignedAgency
    && !['super_admin', 'municipal_admin'].includes(req.user.role)) {
    return res.status(403).json({ error: 'Officer is not in your department' });
  }

  const updated = await pool.query(
    `UPDATE reports SET assigned_officer_id = $1::uuid, updated_at = NOW() WHERE id = $2 RETURNING *`,
    [officerRow.id, req.params.id],
  );

  await pool.query(
    `INSERT INTO report_status_history (report_id, status, message, updated_by)
     VALUES ($1, 'received', $2, $3)`,
    [
      req.params.id,
      `Assigned to ${officerRow.display_name} — officer will update investigation status`,
      req.user.sub,
    ],
  );

  await notifyOfficerAssigned(officerRow.id, updated.rows[0]);
  await auditFromUser(req.user, 'assign_officer', 'report', req.params.id, {
    officerId: officerRow.id,
    officerName: officerRow.display_name,
  });

  res.json(mapReport({
    ...updated.rows[0],
    assigned_officer_name: officerRow.display_name,
  }, [], [], req));
});

/** PATCH /v1/reports/:id/notes — investigation notes (officers only) */
router.patch('/:id/notes', authMiddleware, requireRoles(...INVESTIGATION_ROLES), async (req, res) => {
  if (!canInvestigate(req.user)) {
    return res.status(403).json({ error: 'Only assigned officers may add investigation notes' });
  }

  const existing = await loadScopedReport(req, res);
  if (!existing) return;

  if (INVESTIGATION_ROLES.includes(req.user.role) && !sameUserId(existing.assigned_officer_id, req.user.sub)) {
    return res.status(403).json({ error: 'You may only update cases assigned to you' });
  }

  const notes = req.body.notes ?? req.body.investigationNotes ?? '';
  const updated = await pool.query(
    `UPDATE reports SET investigation_notes = $1, updated_at = NOW() WHERE id = $2 RETURNING *`,
    [notes, req.params.id],
  );

  await auditFromUser(req.user, 'investigation_notes', 'report', req.params.id, {
    length: String(notes).length,
  });

  res.json(mapReport({
    ...updated.rows[0],
    assigned_officer_name: existing.assigned_officer_name,
  }, [], [], req));
});

/** POST /v1/reports/:id/investigation-media — field photos (officers only) */
router.post(
  '/:id/investigation-media',
  authMiddleware,
  requireRoles(...INVESTIGATION_ROLES),
  upload.array('media', 5),
  async (req, res) => {
    if (!canInvestigate(req.user)) {
      return res.status(403).json({ error: 'Only assigned officers may upload investigation media' });
    }

    const existing = await loadScopedReport(req, res);
    if (!existing) return;

    if (INVESTIGATION_ROLES.includes(req.user.role) && !sameUserId(existing.assigned_officer_id, req.user.sub)) {
      return res.status(403).json({ error: 'You may only update cases assigned to you' });
    }

    if (!req.files?.length) {
      return res.status(400).json({ error: 'No media uploaded' });
    }

    const mediaRows = [];
    for (const file of req.files) {
      let stored;
      let mediaType;
      try {
        stored = await storeMediaFile(file);
        mediaType = mediaTypeFromFile(file);
      } catch (err) {
        return res.status(400).json({ error: err.message || 'Invalid media file' });
      }
      const mediaInsert = await pool.query(
        `INSERT INTO report_media (report_id, media_type, storage_url, mime_type, file_size_bytes, uploaded_by, is_investigation)
         VALUES ($1, $2, $3, $4, $5, $6, TRUE) RETURNING *`,
        [
          req.params.id,
          mediaType,
          stored.storageUrl,
          stored.mimeType,
          stored.fileSizeBytes,
          req.user.sub,
        ],
      );
      mediaRows.push(mediaInsert.rows[0]);
    }

    await auditFromUser(req.user, 'investigation_media', 'report', req.params.id, {
      count: mediaRows.length,
    });

    res.status(201).json(mediaRows.map((m) => mapMedia(m, req)));
  },
);

/** POST /v1/reports/:id/escalate */
router.post('/:id/escalate', authMiddleware, requireRoles('super_admin', 'municipal_admin', 'agency_admin'), async (req, res) => {
  const existing = await loadScopedReport(req, res);
  if (!existing) return;

  const updated = await pool.query(
    `UPDATE reports
     SET escalated = TRUE, escalated_at = NOW(), escalated_by = $1, updated_at = NOW()
     WHERE id = $2 RETURNING *`,
    [req.user.sub, req.params.id],
  );

  await pool.query(
    `INSERT INTO report_status_history (report_id, status, message, updated_by)
     VALUES ($1, $2, $3, $4)`,
    [
      req.params.id,
      normalizeStatus(existing.status),
      req.body.message || 'Escalated to municipal administration',
      req.user.sub,
    ],
  );

  await notifyEscalation(updated.rows[0]);
  await auditFromUser(req.user, 'escalate', 'report', req.params.id, {
    message: req.body.message || null,
  });

  res.json(mapReport({
    ...updated.rows[0],
    assigned_officer_name: existing.assigned_officer_name,
  }, [], [], req));
});

/** PATCH /v1/reports/:id — limited field updates */
router.patch('/:id', authMiddleware, requireRoles(...STATUS_UPDATE_ROLES, ...CLOSE_ROLES, ...ASSIGN_ROLES), async (req, res) => {
  const existing = await loadScopedReport(req, res);
  if (!existing) return;

  if (req.body.description !== undefined || req.body.category !== undefined) {
    return res.status(403).json({ error: 'Category and description cannot be changed after submission' });
  }

  if (req.body.status !== undefined) {
    return res.status(400).json({ error: 'Use PATCH /reports/:id/status to update status' });
  }

  const updates = [];
  const params = [];
  let idx = 1;

  if (req.body.communityName !== undefined) {
    updates.push(`community_name = $${idx++}`);
    params.push(req.body.communityName || null);
  }
  if (req.body.needsPolice !== undefined && ['super_admin', 'municipal_admin', 'agency_admin'].includes(req.user.role)) {
    updates.push(`needs_police = $${idx++}`);
    params.push(Boolean(req.body.needsPolice));
  }

  if (!updates.length) {
    return res.status(400).json({ error: 'No valid fields to update' });
  }

  updates.push('updated_at = NOW()');
  params.push(req.params.id);

  const updated = await pool.query(
    `UPDATE reports SET ${updates.join(', ')} WHERE id = $${idx} RETURNING *`,
    params,
  );

  res.json(mapReport({
    ...updated.rows[0],
    assigned_officer_name: existing.assigned_officer_name,
  }, [], [], req));
});

module.exports = router;
