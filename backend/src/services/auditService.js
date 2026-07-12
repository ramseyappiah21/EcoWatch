const { pool } = require('../db/pool');

async function writeAudit({
  actorId = null,
  actorEmail = null,
  actorRole = null,
  action,
  entityType = null,
  entityId = null,
  details = null,
}) {
  try {
    await pool.query(
      `INSERT INTO audit_logs (actor_id, actor_email, actor_role, action, entity_type, entity_id, details)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [
        actorId,
        actorEmail,
        actorRole,
        action,
        entityType,
        entityId != null ? String(entityId) : null,
        details ? JSON.stringify(details) : null,
      ],
    );
  } catch (err) {
    console.error('[audit]', err.message);
  }
}

function auditFromUser(user, action, entityType, entityId, details) {
  return writeAudit({
    actorId: user?.sub,
    actorEmail: user?.email,
    actorRole: user?.role,
    action,
    entityType,
    entityId,
    details,
  });
}

module.exports = { writeAudit, auditFromUser };
