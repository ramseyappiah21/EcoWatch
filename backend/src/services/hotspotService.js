const { haversineMeters } = require('./severityService');

const EPS_METERS = 1000;
const MIN_PTS = 5;
const WINDOW_DAYS = 30;

function effectiveMinPts(reportCount, minPts = MIN_PTS) {
  if (reportCount < 3) return reportCount + 1;
  if (reportCount < minPts) return 3;
  return minPts;
}

function priorityFromDensity(densityScore, reportCount = 0) {
  // Use absolute cluster size as well as share of all reports — avoids all-green
  // hotspots when total report volume is high but clusters are still significant.
  if (reportCount >= 12 || densityScore >= 0.4) return 'critical';
  if (reportCount >= 8 || densityScore >= 0.2) return 'high';
  if (reportCount >= 5 || densityScore >= 0.1) return 'medium';
  return 'low';
}

function regionQuery(reports, index) {
  const result = [];
  for (let i = 0; i < reports.length; i++) {
    if (
      haversineMeters(
        reports[index].latitude,
        reports[index].longitude,
        reports[i].latitude,
        reports[i].longitude,
      ) <= EPS_METERS
    ) {
      result.push(i);
    }
  }
  return result;
}

/** DBSCAN clustering — PRD eps=1km, minPts=5 (adaptive down to 3 for smaller datasets) */
function detectHotspots(reports, options = {}) {
  const minPts = effectiveMinPts(reports.length, options.minPts ?? MIN_PTS);
  if (reports.length < minPts) return [];

  const visited = new Set();
  const clusters = [];

  for (let i = 0; i < reports.length; i++) {
    if (visited.has(i)) continue;
    visited.add(i);

    const neighbors = regionQuery(reports, i);
    if (neighbors.length < minPts) continue;

    const cluster = [reports[i]];
    const queue = neighbors.filter((n) => n !== i);

    while (queue.length) {
      const j = queue.shift();
      if (!visited.has(j)) {
        visited.add(j);
        const jNeighbors = regionQuery(reports, j);
        if (jNeighbors.length >= minPts) {
          for (const n of jNeighbors) {
            if (!queue.includes(n)) queue.push(n);
          }
        }
      }
      if (!cluster.find((r) => r.id === reports[j].id)) {
        cluster.push(reports[j]);
      }
    }

    if (cluster.length >= minPts) clusters.push(cluster);
  }

  return clusters.map((group, idx) => {
    const avgLat = group.reduce((s, r) => s + r.latitude, 0) / group.length;
    const avgLng = group.reduce((s, r) => s + r.longitude, 0) / group.length;
    const densityScore = Math.min(group.length / reports.length, 1);

    const categoryCounts = {};
    for (const r of group) {
      categoryCounts[r.category] = (categoryCounts[r.category] || 0) + 1;
    }
    const dominantCategory = Object.entries(categoryCounts).sort(
      (a, b) => b[1] - a[1],
    )[0][0];

    return {
      id: `hotspot_${idx + 1}`,
      latitude: avgLat,
      longitude: avgLng,
      reportCount: group.length,
      densityScore,
      priority: priorityFromDensity(densityScore, group.length),
      dominantCategory,
      radiusMeters: EPS_METERS,
      reports: group.map((r) => r.id),
    };
  });
}

async function fetchRecentReports(pool, { days = WINDOW_DAYS, scope = null } = {}) {
  const scopeClause = scope?.clause ?? '';
  const params = scope?.params ?? [];
  const { rows } = await pool.query(
    `SELECT id, category, latitude, longitude, created_at
     FROM reports
     WHERE created_at > NOW() - make_interval(days => $1)${scopeClause}`,
    [days, ...params],
  );
  return rows;
}

module.exports = {
  detectHotspots,
  fetchRecentReports,
  effectiveMinPts,
  EPS_METERS,
  MIN_PTS,
  WINDOW_DAYS,
};
