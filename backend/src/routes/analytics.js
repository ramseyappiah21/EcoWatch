const express = require('express');
const { pool } = require('../db/pool');
const { detectHotspots } = require('../services/hotspotService');
const {
  predictHotspots,
  computeHotspotGrowth,
  computePredictedTrend,
} = require('../services/hotspotPredictionService');
const { authMiddleware, requireRoles } = require('../middleware/auth');
const {
  buildCategoryScope,
  PORTAL_ROLES,
  EXPORT_ROLES,
  isResearcher,
  anonymizeCoordinate,
} = require('../services/categoryService');

const router = express.Router();

async function fetchScopedReports(user, days = 30) {
  const scope = buildCategoryScope(user, 2);
  const { rows } = await pool.query(
    `SELECT id, category, latitude, longitude, severity, severity_score,
            source, status, water_body_nearby, created_at
     FROM reports
     WHERE created_at > NOW() - make_interval(days => $1)${scope.clause}
     ORDER BY created_at`,
    [days, ...scope.params],
  );
  return rows;
}

router.get('/', authMiddleware, requireRoles(...PORTAL_ROLES), async (req, res) => {
  const period = req.query.period || 'weekly';
  const days = period === 'monthly' ? 30 : period === 'daily' ? 1 : 7;
  const scope = buildCategoryScope(req.user, 2);
  const timeFilter = 'created_at > NOW() - make_interval(days => $1)';
  const whereSql = `${timeFilter}${scope.clause}`;
  const params = [days, ...scope.params];
  const recentRows = await fetchScopedReports(req.user, 30);

  const totals = await pool.query(
    `SELECT COUNT(*)::int AS total,
            COUNT(*) FILTER (WHERE status IN ('resolved', 'closed'))::int AS resolved
     FROM reports WHERE ${whereSql}`,
    params,
  );

  const byCategory = await pool.query(
    `SELECT category, COUNT(*)::int AS count
     FROM reports WHERE ${whereSql}
     GROUP BY category`,
    params,
  );

  const bySource = await pool.query(
    `SELECT source, COUNT(*)::int AS count
     FROM reports WHERE ${whereSql}
     GROUP BY source`,
    params,
  );

  const bySeverity = await pool.query(
    `SELECT severity, COUNT(*)::int AS count
     FROM reports WHERE ${whereSql}
     GROUP BY severity`,
    params,
  );

  const trend = await pool.query(
    `SELECT DATE(created_at) AS date, COUNT(*)::int AS count
     FROM reports WHERE ${whereSql}
     GROUP BY DATE(created_at) ORDER BY date`,
    params,
  );

  const hotspots = detectHotspots(recentRows);
  const hotspotGrowth = computeHotspotGrowth(recentRows);
  const mlPredictions = predictHotspots(recentRows);
  const predictedTrend = computePredictedTrend(recentRows, mlPredictions);

  res.json({
    period,
    totalReports: totals.rows[0].total,
    resolvedReports: totals.rows[0].resolved,
    categoryBreakdown: Object.fromEntries(
      byCategory.rows.map((r) => [r.category, r.count]),
    ),
    sourceBreakdown: Object.fromEntries(
      bySource.rows.map((r) => [r.source, r.count]),
    ),
    severityBreakdown: Object.fromEntries(
      bySeverity.rows.map((r) => [r.severity, r.count]),
    ),
    dailyTrend: trend.rows,
    hotspots,
    hotspotGrowth,
    predictedHotspots: mlPredictions.predictions,
    predictedTrend,
    modelMetrics: mlPredictions.modelMetrics,
    predictionSource: mlPredictions.source,
    algorithms: mlPredictions.algorithms,
  });
});

/** GET /v1/analytics/predictions — ML hotspot forecast detail */
router.get('/predictions', authMiddleware, requireRoles(...PORTAL_ROLES), async (req, res) => {
  const recentRows = await fetchScopedReports(req.user, 60);
  const hotspots = detectHotspots(recentRows);
  const mlPredictions = predictHotspots(recentRows);

  res.json({
    currentHotspots: hotspots,
    predictedHotspots: mlPredictions.predictions,
    hotspotGrowth: computeHotspotGrowth(recentRows),
    predictedTrend: computePredictedTrend(recentRows, mlPredictions),
    modelMetrics: mlPredictions.modelMetrics,
    algorithms: mlPredictions.algorithms,
    predictionSource: mlPredictions.source,
    generatedAt: mlPredictions.generatedAt,
  });
});

/** GET /v1/analytics/export — CSV export (agency-scoped; researcher anonymized) */
router.get('/export', authMiddleware, requireRoles(...EXPORT_ROLES), async (req, res) => {
  const scope = buildCategoryScope(req.user);
  const researcher = isResearcher(req.user);
  const { rows } = await pool.query(
    researcher
      ? `SELECT category, status, severity, severity_score, source,
                community_name, created_at, updated_at, latitude, longitude
         FROM reports WHERE TRUE${scope.clause} ORDER BY created_at DESC`
      : `SELECT tracking_token, category, status, severity, severity_score, source,
                latitude, longitude, community_name, created_at
         FROM reports WHERE TRUE${scope.clause} ORDER BY created_at DESC`,
    scope.params,
  );

  const exportRows = researcher
    ? rows.map((r) => ({
      category: r.category,
      status: r.status,
      severity: r.severity,
      severity_score: r.severity_score,
      source: r.source,
      community_name: r.community_name,
      created_at: r.created_at,
      updated_at: r.updated_at,
      approx_latitude: anonymizeCoordinate(r.latitude),
      approx_longitude: anonymizeCoordinate(r.longitude),
    }))
    : rows;

  const header = Object.keys(exportRows[0] || {
    category: '',
    status: '',
    severity: '',
  }).join(',');
  const lines = exportRows.map((r) => Object.values(r).join(','));
  res.setHeader('Content-Type', 'text/csv');
  res.setHeader(
    'Content-Disposition',
    `attachment; filename=${researcher ? 'ecowatch_research_anonymized.csv' : 'ecowatch_reports.csv'}`,
  );
  res.send([header, ...lines].join('\n'));
});

module.exports = router;
