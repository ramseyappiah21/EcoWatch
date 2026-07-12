const { pool } = require('../db/pool');
const { detectHotspots, fetchRecentReports } = require('../services/hotspotService');

/** Persist DBSCAN hotspots for dashboard analytics */
async function runHotspotJob() {
  const reports = await fetchRecentReports(pool);
  const hotspots = detectHotspots(reports);

  const windowEnd = new Date();
  const windowStart = new Date(windowEnd);
  windowStart.setDate(windowStart.getDate() - 7);

  await pool.query('DELETE FROM hotspots WHERE detected_at < NOW() - INTERVAL \'14 days\'');

  for (const h of hotspots) {
    await pool.query(
      `INSERT INTO hotspots (
        external_id, latitude, longitude, report_count, density_score,
        priority, dominant_category, radius_meters, window_start, window_end
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
      ON CONFLICT (external_id) DO UPDATE SET
        report_count = EXCLUDED.report_count,
        density_score = EXCLUDED.density_score,
        priority = EXCLUDED.priority,
        detected_at = NOW()`,
      [
        h.id,
        h.latitude,
        h.longitude,
        h.reportCount,
        h.densityScore,
        h.priority,
        h.dominantCategory,
        h.radiusMeters,
        windowStart,
        windowEnd,
      ],
    );
  }

  if (hotspots.length) {
    console.log(`Hotspot job: ${hotspots.length} cluster(s) detected`);
  }
}

module.exports = { runHotspotJob };
