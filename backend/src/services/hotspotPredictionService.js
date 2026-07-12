const fs = require('fs');
const path = require('path');
const { detectHotspots } = require('./hotspotService');

const LAT_MIN = 5.25;
const LAT_MAX = 5.38;
const LNG_MIN = -2.08;
const LNG_MAX = -1.9;
const CELL_SIZE = 0.009;
const PREDICTION_THRESHOLD = 0.45;

const CATEGORIES = [
  'airPollution',
  'waterPollution',
  'illegalMining',
  'wasteDumping',
  'flooding',
];

const SEVERITY_MAP = { low: 1, medium: 2, high: 3, critical: 4 };

const PREDICTIONS_PATH = path.join(
  __dirname,
  '../../../ml/hotspot/export/predictions.json',
);

function cellId(lat, lng) {
  const row = Math.floor((lat - LAT_MIN) / CELL_SIZE);
  const col = Math.floor((lng - LNG_MIN) / CELL_SIZE);
  return `${row}_${col}`;
}

function cellCenter(cell) {
  const [row, col] = cell.split('_').map(Number);
  return {
    latitude: LAT_MIN + (row + 0.5) * CELL_SIZE,
    longitude: LNG_MIN + (col + 0.5) * CELL_SIZE,
  };
}

function inBounds(lat, lng) {
  return lat >= LAT_MIN && lat <= LAT_MAX && lng >= LNG_MIN && lng <= LNG_MAX;
}

function parseTs(value) {
  return new Date(value);
}

function reportsInWindow(reports, start, end) {
  return reports.filter((r) => {
    const t = parseTs(r.created_at);
    return t >= start && t < end;
  });
}

function tabularFeatures(cellReports, asOf) {
  const lookback30 = new Date(asOf);
  lookback30.setDate(lookback30.getDate() - 30);
  const recent = reportsInWindow(cellReports, lookback30, asOf);

  const countInDays = (days) => {
    const start = new Date(asOf);
    start.setDate(start.getDate() - days);
    return reportsInWindow(cellReports, start, asOf).length;
  };

  const severities = recent.map(
    (r) => SEVERITY_MAP[r.severity] || SEVERITY_MAP.low,
  );
  const severityMean = severities.length
    ? severities.reduce((a, b) => a + b, 0) / severities.length
    : 0;
  const criticalRatio = severities.length
    ? severities.filter((s) => s >= 4).length / severities.length
    : 0;

  const catCounts = Object.fromEntries(CATEGORIES.map((c) => [c, 0]));
  for (const r of recent) {
    if (catCounts[r.category] !== undefined) catCounts[r.category] += 1;
  }

  const waterRatio = recent.length
    ? recent.filter((r) => r.water_body_nearby).length / recent.length
    : 0;
  const ussdRatio = recent.length
    ? recent.filter((r) => r.source === 'ussd').length / recent.length
    : 0;
  const unresolvedRatio = recent.length
    ? recent.filter((r) => r.status !== 'resolved').length / recent.length
    : 0;

  return {
    counts_7d: countInDays(7),
    counts_14d: countInDays(14),
    counts_30d: recent.length,
    severity_mean: severityMean,
    critical_ratio: criticalRatio,
    water_ratio: waterRatio,
    ussd_ratio: ussdRatio,
    unresolved_ratio: unresolvedRatio,
    catCounts,
  };
}

function priorityFromScore(score) {
  if (score >= 0.75) return 'critical';
  if (score >= 0.55) return 'high';
  if (score >= 0.45) return 'medium';
  return 'low';
}

/** Heuristic ensemble mimicking RF/XGBoost/LSTM when Python models are not trained. */
function heuristicScores(feats) {
  const growth = feats.counts_7d / Math.max(feats.counts_14d, 1);
  const density = Math.min(feats.counts_30d / 10, 1);
  const severity = feats.severity_mean / 4;
  const critical = feats.critical_ratio;
  const water = feats.water_ratio * 0.15;
  const unresolved = feats.unresolved_ratio * 0.1;

  const base = density * 0.35 + growth * 0.25 + severity * 0.2 + critical * 0.15 + water + unresolved;
  const rf = Math.min(base * 0.95 + feats.counts_7d * 0.02, 0.99);
  const xgb = Math.min(base * 1.05 + feats.critical_ratio * 0.1, 0.99);

  const lstmBase =
    feats.counts_7d > feats.counts_14d / 2
      ? base * 1.1
      : base * 0.85;
  const lstm = Math.min(lstmBase, 0.99);

  return {
    random_forest: Number(rf.toFixed(4)),
    xgboost: Number(xgb.toFixed(4)),
    lstm: Number(lstm.toFixed(4)),
  };
}

function groupByCell(reports) {
  const grouped = new Map();
  for (const r of reports) {
    const lat = Number(r.latitude);
    const lng = Number(r.longitude);
    if (!inBounds(lat, lng)) continue;
    const id = cellId(lat, lng);
    if (!grouped.has(id)) grouped.set(id, []);
    grouped.get(id).push(r);
  }
  return grouped;
}

function loadCachedPredictions() {
  try {
    if (!fs.existsSync(PREDICTIONS_PATH)) return null;
    const raw = fs.readFileSync(PREDICTIONS_PATH, 'utf8');
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function predictHotspots(reports, options = {}) {
  const cached = options.preferCache !== false ? loadCachedPredictions() : null;
  if (cached?.predictions?.length) {
    return {
      predictions: cached.predictions,
      modelMetrics: cached.modelMetrics || {},
      algorithms: cached.algorithms || ['random_forest', 'xgboost', 'lstm'],
      source: 'ml_models',
      generatedAt: cached.generatedAt,
    };
  }

  const now = new Date();
  const grouped = groupByCell(reports);
  const predictions = [];

  for (const [cell, cellReports] of grouped) {
    const feats = tabularFeatures(cellReports, now);
    if (feats.counts_30d < 1) continue;

    const scores = heuristicScores(feats);
    const values = Object.values(scores);
    const ensembleScore = values.reduce((a, b) => a + b, 0) / values.length;

    if (ensembleScore < PREDICTION_THRESHOLD) continue;

    const center = cellCenter(cell);
    predictions.push({
      cellId: cell,
      latitude: center.latitude,
      longitude: center.longitude,
      scores,
      ensembleScore: Number(ensembleScore.toFixed(4)),
      lstmScore: scores.lstm,
      priority: priorityFromScore(ensembleScore),
      reportCount30d: feats.counts_30d,
      radiusMeters: 1000,
      dominantCategory: dominantCategory(cellReports),
    });
  }

  predictions.sort((a, b) => b.ensembleScore - a.ensembleScore);

  return {
    predictions: predictions.slice(0, 25),
    modelMetrics: {
      random_forest: { mode: 'heuristic', note: 'Train ml/hotspot/train.py for full model' },
      xgboost: { mode: 'heuristic' },
      lstm: { mode: 'heuristic' },
    },
    algorithms: ['random_forest', 'xgboost', 'lstm'],
    source: 'heuristic',
    generatedAt: now.toISOString(),
  };
}

function dominantCategory(reports) {
  const counts = {};
  for (const r of reports) {
    counts[r.category] = (counts[r.category] || 0) + 1;
  }
  const sorted = Object.entries(counts).sort((a, b) => b[1] - a[1]);
  return sorted[0]?.[0] || 'wasteDumping';
}

function computeHotspotGrowth(reports, days = 30) {
  const points = [];
  const end = new Date();
  end.setHours(0, 0, 0, 0);

  for (let d = days; d >= 0; d--) {
    const dayEnd = new Date(end);
    dayEnd.setDate(dayEnd.getDate() - d);
    const dayStart = new Date(dayEnd);
    dayStart.setDate(dayStart.getDate() - 30);

    const window = reports.filter((r) => {
      const t = parseTs(r.created_at);
      return t >= dayStart && t < dayEnd;
    });

    const hotspots = detectHotspots(window);
    const totalInHotspots = hotspots.reduce((s, h) => s + h.reportCount, 0);

    points.push({
      date: dayEnd.toISOString().slice(0, 10),
      hotspotCount: hotspots.length,
      totalReportsInHotspots: totalInHotspots,
    });
  }

  return points;
}

function computePredictedTrend(reports, predictions) {
  const last7 = reports.filter((r) => {
    const t = parseTs(r.created_at);
    const start = new Date();
    start.setDate(start.getDate() - 7);
    return t >= start;
  }).length;

  const predictedCells = predictions.predictions?.length || 0;
  const avgScore =
    predictions.predictions?.length
      ? predictions.predictions.reduce((s, p) => s + p.ensembleScore, 0) /
        predictions.predictions.length
      : 0.5;

  const growthFactor = 1 + predictedCells * 0.08;
  const predictedReportsNextWeek = Math.round(last7 * growthFactor);

  const categoryCounts = {};
  for (const p of predictions.predictions || []) {
    const cat = p.dominantCategory || 'wasteDumping';
    categoryCounts[cat] = (categoryCounts[cat] || 0) + p.ensembleScore;
  }
  const risingCategories = Object.entries(categoryCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([k]) => k);

  return {
    predictedReportsNextWeek,
    confidence: Number(Math.min(0.95, 0.5 + avgScore * 0.4).toFixed(2)),
    risingCategories,
    generatedAt: new Date().toISOString(),
    algorithms: predictions.algorithms,
  };
}

module.exports = {
  predictHotspots,
  computeHotspotGrowth,
  computePredictedTrend,
  loadCachedPredictions,
  PREDICTIONS_PATH,
};
