const { pool } = require('../db/pool');
const {
  agenciesForCategory,
  EMERGENCY_CATEGORIES,
  severityMeetsThreshold,
  categoryVariants,
} = require('./categoryService');

async function notifyUser(userId, { title, body, reportId = null, isEmergency = false }) {
  if (!userId) return;
  await pool.query(
    `INSERT INTO notifications (user_id, title, body, report_id, is_emergency)
     VALUES ($1, $2, $3, $4, $5)`,
    [userId, title, body, reportId, isEmergency],
  );
}

async function usersForAgencyRoles(agencyKey, roles) {
  const { rows } = await pool.query(
    `SELECT u.id, u.email, r.name AS role
     FROM users u
     JOIN roles r ON r.id = u.role_id
     WHERE u.is_active = TRUE
       AND u.assigned_agency = $1
       AND r.name = ANY($2)`,
    [agencyKey, roles],
  );
  return rows;
}

async function municipalUsers() {
  const { rows } = await pool.query(
    `SELECT u.id, r.name AS role
     FROM users u
     JOIN roles r ON r.id = u.role_id
     WHERE u.is_active = TRUE
       AND r.name IN ('super_admin', 'municipal_admin')`,
  );
  return rows;
}

/**
 * Notify agency admins on new report; emergency officers on high severity.
 */
async function notifyOnNewReport(report) {
  const agencies = agenciesForCategory(report.category);
  const isEmergencyCategory = EMERGENCY_CATEGORIES.some((c) =>
    categoryVariants(c).includes(report.category) || c === report.category,
  );

  let threshold = 'high';
  try {
    const { rows } = await pool.query(
      `SELECT value FROM platform_settings WHERE key = 'emergency_severity_threshold'`,
    );
    if (rows[0]?.value) {
      threshold = String(rows[0].value).replace(/"/g, '');
    }
  } catch {
    /* defaults */
  }

  const isEmergencySeverity = severityMeetsThreshold(report.severity, threshold);

  for (const agency of agencies) {
    const admins = await usersForAgencyRoles(agency.key, [
      'agency_admin',
    ]);
    for (const u of admins) {
      await notifyUser(u.id, {
        title: `New incident — ${report.category}`,
        body: `Report ${report.tracking_token} routed to ${agency.name}. Severity: ${report.severity}.`,
        reportId: report.id,
        isEmergency: isEmergencyCategory && isEmergencySeverity,
      });
    }

    if (agency.emergency && isEmergencyCategory) {
      const officers = await usersForAgencyRoles(agency.key, ['emergency_officer']);
      for (const u of officers) {
        if (isEmergencySeverity) {
          await notifyUser(u.id, {
            title: 'EMERGENCY incident',
            body: `${report.tracking_token} — ${report.category} (${report.severity}). Immediate response required.`,
            reportId: report.id,
            isEmergency: true,
          });
        } else {
          await notifyUser(u.id, {
            title: `Emergency-category incident — ${report.category}`,
            body: `Report ${report.tracking_token} assigned to ${agency.short}.`,
            reportId: report.id,
            isEmergency: false,
          });
        }
      }
    }
  }

  if (report.needs_police) {
    const police = await usersForAgencyRoles('police', [
      'agency_admin',
      'police_support',
    ]);
    for (const u of police) {
      await notifyUser(u.id, {
        title: 'Police support requested',
        body: `Report ${report.tracking_token} may involve a criminal offence.`,
        reportId: report.id,
      });
    }
  }
}

async function notifyOfficerAssigned(officerId, report) {
  await notifyUser(officerId, {
    title: 'Case assigned to you',
    body: `You have been assigned report ${report.tracking_token} (${report.category}).`,
    reportId: report.id,
  });
}

async function notifyEscalation(report) {
  const users = await municipalUsers();
  for (const u of users) {
    await notifyUser(u.id, {
      title: 'Incident escalated',
      body: `Report ${report.tracking_token} was escalated for municipal attention.`,
      reportId: report.id,
    });
  }
}

async function listNotifications(userId, { unreadOnly = false, limit = 50 } = {}) {
  const { rows } = await pool.query(
    `SELECT id, title, body, report_id AS "reportId", is_read AS "isRead",
            is_emergency AS "isEmergency", created_at AS "createdAt"
     FROM notifications
     WHERE user_id = $1 ${unreadOnly ? 'AND is_read = FALSE' : ''}
     ORDER BY created_at DESC
     LIMIT $2`,
    [userId, limit],
  );
  return rows;
}

async function markNotificationRead(userId, notificationId) {
  await pool.query(
    `UPDATE notifications SET is_read = TRUE
     WHERE id = $1 AND user_id = $2`,
    [notificationId, userId],
  );
}

async function markAllNotificationsRead(userId) {
  await pool.query(
    `UPDATE notifications SET is_read = TRUE WHERE user_id = $1 AND is_read = FALSE`,
    [userId],
  );
}

module.exports = {
  notifyUser,
  notifyOnNewReport,
  notifyOfficerAssigned,
  notifyEscalation,
  listNotifications,
  markNotificationRead,
  markAllNotificationsRead,
};
