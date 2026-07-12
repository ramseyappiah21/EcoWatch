const express = require('express');
const { pool } = require('../db/pool');
const {
  INCIDENT_CATEGORIES,
  AGENCIES,
  PLATFORM_OWNER,
  officerPortalPath,
  emailForCategory,
} = require('../services/categoryService');

const router = express.Router();

router.get('/categories', (_req, res) => {
  res.json(
    INCIDENT_CATEGORIES.map((c) => ({
      slug: c.slug,
      key: c.key,
      label: c.label,
      agency: c.agency,
      agencyShort: c.agencyShort,
      agencyKey: c.agencyKey,
      multiAgency: c.multiAgency || [c.agencyKey],
      defaultEmail: emailForCategory(c.key),
      portalUrl: officerPortalPath(),
    })),
  );
});

router.get('/agencies', (_req, res) => {
  res.json({
    platformOwner: PLATFORM_OWNER,
    agencies: AGENCIES.map((a) => ({
      key: a.key,
      name: a.name,
      short: a.short,
      categories: a.categories,
      portalEmail: a.email,
    })),
  });
});

router.get('/emergency-contacts', async (_req, res) => {
  const { rows } = await pool.query(
    `SELECT name, agency, phone, description
     FROM emergency_contacts WHERE is_active = TRUE
     ORDER BY sort_order`,
  );
  res.json(rows);
});

router.get('/announcements', async (_req, res) => {
  const { rows } = await pool.query(
    `SELECT id, title, body, published_at AS "publishedAt"
     FROM announcements
     WHERE is_public = TRUE
       AND (expires_at IS NULL OR expires_at > NOW())
     ORDER BY published_at DESC
     LIMIT 20`,
  );
  res.json(rows);
});

module.exports = router;
