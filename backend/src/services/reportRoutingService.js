const {
  agenciesForCategory,
  POLICE_CATEGORIES,
  normalizeMainCategory,
} = require('./categoryService');
const { notifyOnNewReport } = require('./notificationService');

/**
 * Route each report to all agencies responsible for that mandate (multi-agency supported).
 */
async function routeReportToAdmins(client, report) {
  const category = normalizeMainCategory(report.category);
  const agencies = agenciesForCategory(category);
  const needsPolice = POLICE_CATEGORIES.includes(category);

  if (needsPolice) {
    await client.query(
      `UPDATE reports SET needs_police = TRUE WHERE id = $1`,
      [report.id],
    );
    report.needs_police = true;
  }

  if (!agencies.length) {
    console.log(
      `Report ${report.tracking_token} not routed — no agency for ${category}`,
    );
    return;
  }

  for (const agency of agencies) {
    const recipients = await client.query(
      `SELECT u.id, u.email, u.display_name, u.assigned_agency, r.name AS role_name
       FROM users u
       JOIN roles r ON r.id = u.role_id
       WHERE u.is_active = TRUE
         AND u.assigned_agency = $1
         AND r.name IN ('agency_admin', 'police_support')`,
      [agency.key],
    );

    if (!recipients.rows.length) {
      console.log(
        `Report ${report.tracking_token} — no recipients for ${agency.name}`,
      );
      continue;
    }

    for (const o of recipients.rows) {
      await client.query(
        `INSERT INTO report_routing (report_id, recipient_role, recipient_user_id, category)
         VALUES ($1, $2, $3, $4)`,
        [report.id, o.role_name, o.id, category],
      );
    }

    console.log(
      `Report ${report.tracking_token} routed → ${agency.name} (${category})`,
    );
  }

  // Notifications use the main pool connection after commit; fire-and-forget after routing.
  setImmediate(() => {
    notifyOnNewReport({
      id: report.id,
      tracking_token: report.tracking_token,
      category,
      severity: report.severity || 'low',
      needs_police: needsPolice,
    }).catch((err) => console.error('[notify]', err.message));
  });
}

module.exports = { routeReportToAdmins };
