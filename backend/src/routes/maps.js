const jwt = require('jsonwebtoken');
const express = require('express');
const { pool } = require('../db/pool');
const { detectHotspots, fetchRecentReports } = require('../services/hotspotService');
const { authMiddleware, requireRoles } = require('../middleware/auth');
const {
  buildCategoryScope,
  PORTAL_ROLES,
  isResearcher,
  anonymizeCoordinate,
} = require('../services/categoryService');
const config = require('../config');

const router = express.Router();

function optionalAuth(req, _res, next) {
  const header = req.headers.authorization;
  if (header?.startsWith('Bearer ')) {
    try {
      req.user = jwt.verify(header.slice(7), config.jwtSecret);
    } catch {
      req.user = null;
    }
  }
  next();
}

router.get('/hotspots', optionalAuth, async (req, res) => {
  const scope = req.user ? buildCategoryScope(req.user, 2) : null;
  const reports = await fetchRecentReports(pool, {
    days: 30,
    scope: scope ? { clause: scope.clause, params: scope.params } : null,
  });
  const hotspots = detectHotspots(reports);
  res.json(hotspots);
});
router.get('/reports', authMiddleware, requireRoles(...PORTAL_ROLES), async (req, res) => {
  const { north, south, east, west } = req.query;
  const scope = buildCategoryScope(req.user);
  let query = `SELECT id, category, latitude, longitude, severity, status, created_at FROM reports WHERE TRUE${scope.clause}`;
  const params = [...scope.params];

  if (north && south && east && west) {
    const i = params.length + 1;
    query += ` AND latitude <= $${i} AND latitude >= $${i + 1} AND longitude <= $${i + 2} AND longitude >= $${i + 3}`;
    params.push(Number(north), Number(south), Number(east), Number(west));
  }

  const { rows } = await pool.query(query, params);
  if (isResearcher(req.user)) {
    return res.json(rows.map((r) => ({
      ...r,
      latitude: anonymizeCoordinate(r.latitude),
      longitude: anonymizeCoordinate(r.longitude),
      anonymized: true,
    })));
  }
  res.json(rows);
});

module.exports = router;
