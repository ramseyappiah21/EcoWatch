const NEARBY_RADIUS_METERS = 1000;
const RECENT_HOURS = 24;

function haversineMeters(lat1, lon1, lat2, lon2) {
  const R = 6371000;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.asin(Math.sqrt(a));
}

/**
 * PRD severity: image +2, nearby reports +3, recent +1 (max 6)
 */
function calculateSeverityScore({ hasMedia, hasNearby, isRecent }) {
  let score = 0;
  if (hasMedia) score += 2;
  if (hasNearby) score += 3;
  if (isRecent) score += 1;
  return Math.min(score, 6);
}

function scoreToLevel(score) {
  if (score >= 5) return 'critical';
  if (score >= 3) return 'high';
  if (score >= 1) return 'medium';
  return 'low';
}

async function computeSeverityForReport(pool, report) {
  const hasMedia = Boolean(report.has_media);

  const nearby = await pool.query(
    `SELECT id FROM reports
     WHERE id <> $1
       AND created_at > NOW() - INTERVAL '30 days'
       AND (
         6371000 * acos(
           cos(radians($2)) * cos(radians(latitude)) *
           cos(radians(longitude) - radians($3)) +
           sin(radians($2)) * sin(radians(latitude))
         )
       ) <= $4`,
    [report.id, report.latitude, report.longitude, NEARBY_RADIUS_METERS],
  );

  const isRecent = true; // new report is always within 24h window

  const score = calculateSeverityScore({
    hasMedia,
    hasNearby: nearby.rowCount > 0,
    isRecent,
  });

  return { score, level: scoreToLevel(score) };
}

module.exports = {
  calculateSeverityScore,
  scoreToLevel,
  computeSeverityForReport,
  haversineMeters,
};
