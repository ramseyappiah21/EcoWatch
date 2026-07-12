"""Grid-based feature engineering for predictive hotspot detection."""

from __future__ import annotations

from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import Any

import numpy as np

from config import (
    CATEGORIES,
    CELL_SIZE,
    HOTSPOT_LABEL_MIN_REPORTS,
    LABEL_HORIZON_DAYS,
    LAT_MAX,
    LAT_MIN,
    LNG_MAX,
    LNG_MIN,
    LSTM_SEQUENCE_DAYS,
    LOOKBACK_DAYS,
    SEVERITY_MAP,
)


def cell_id(lat: float, lng: float) -> str:
    row = int((lat - LAT_MIN) / CELL_SIZE)
    col = int((lng - LNG_MIN) / CELL_SIZE)
    return f"{row}_{col}"


def cell_center(cell: str) -> tuple[float, float]:
    row, col = map(int, cell.split("_"))
    lat = LAT_MIN + (row + 0.5) * CELL_SIZE
    lng = LNG_MIN + (col + 0.5) * CELL_SIZE
    return lat, lng


def in_bounds(lat: float, lng: float) -> bool:
    return LAT_MIN <= lat <= LAT_MAX and LNG_MIN <= lng <= LNG_MAX


def parse_ts(value: Any) -> datetime:
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    text = str(value).replace("Z", "+00:00")
    return datetime.fromisoformat(text)


def reports_by_cell(reports: list[dict]) -> dict[str, list[dict]]:
    grouped: dict[str, list[dict]] = defaultdict(list)
    for r in reports:
        lat, lng = float(r["latitude"]), float(r["longitude"])
        if not in_bounds(lat, lng):
            continue
        grouped[cell_id(lat, lng)].append(r)
    return grouped


def _reports_in_window(cell_reports: list[dict], start: datetime, end: datetime) -> list[dict]:
    return [r for r in cell_reports if start <= parse_ts(r["created_at"]) < end]


def tabular_features_for_cell(
    cell_reports: list[dict],
    as_of: datetime,
    lookback_days: int = LOOKBACK_DAYS,
) -> dict[str, float]:
    window_start = as_of - timedelta(days=lookback_days)
    recent = _reports_in_window(cell_reports, window_start, as_of)

    counts_7 = len(_reports_in_window(cell_reports, as_of - timedelta(days=7), as_of))
    counts_14 = len(_reports_in_window(cell_reports, as_of - timedelta(days=14), as_of))
    counts_30 = len(recent)

    severities = [SEVERITY_MAP.get(str(r.get("severity", "low")), 1) for r in recent]
    severity_mean = float(np.mean(severities)) if severities else 0.0
    critical_ratio = (
        sum(1 for s in severities if s >= 4) / len(severities) if severities else 0.0
    )

    cat_counts = {c: 0 for c in CATEGORIES}
    for r in recent:
        cat = str(r.get("category", "wasteDumping"))
        if cat in cat_counts:
            cat_counts[cat] += 1

    water_ratio = (
        sum(1 for r in recent if r.get("water_body_nearby")) / len(recent) if recent else 0.0
    )
    ussd_ratio = (
        sum(1 for r in recent if r.get("source") == "ussd") / len(recent) if recent else 0.0
    )

    unresolved = sum(1 for r in recent if r.get("status") != "resolved")
    unresolved_ratio = unresolved / len(recent) if recent else 0.0

    return {
        "counts_7d": float(counts_7),
        "counts_14d": float(counts_14),
        "counts_30d": float(counts_30),
        "severity_mean": severity_mean,
        "critical_ratio": critical_ratio,
        "water_ratio": water_ratio,
        "ussd_ratio": ussd_ratio,
        "unresolved_ratio": unresolved_ratio,
        **{f"cat_{c}": float(cat_counts[c]) for c in CATEGORIES},
    }


FEATURE_NAMES = [
    "counts_7d",
    "counts_14d",
    "counts_30d",
    "severity_mean",
    "critical_ratio",
    "water_ratio",
    "ussd_ratio",
    "unresolved_ratio",
    *[f"cat_{c}" for c in CATEGORIES],
]


def effective_windows(min_ts: datetime, max_ts: datetime) -> tuple[int, int, int]:
    """Shrink training windows when report history is short (demo/small datasets)."""
    span = max(1, (max_ts - min_ts).days)
    lookback = min(LOOKBACK_DAYS, max(3, span // 2))
    label_horizon = min(LABEL_HORIZON_DAYS, max(2, span // 4))
    lstm_seq = min(LSTM_SEQUENCE_DAYS, max(3, span // 3))
    return lookback, label_horizon, lstm_seq


def build_training_samples(reports: list[dict]) -> tuple[np.ndarray, np.ndarray, list[str]]:
    """Return X, y, cell_ids for tabular models."""
    if not reports:
        return np.empty((0, len(FEATURE_NAMES))), np.empty((0,)), []

    parsed = [dict(r, created_at=parse_ts(r["created_at"])) for r in reports]
    min_ts = min(r["created_at"] for r in parsed)
    max_ts = max(r["created_at"] for r in parsed)
    lookback, label_horizon, _ = effective_windows(min_ts, max_ts)

    grouped = reports_by_cell(parsed)
    xs: list[list[float]] = []
    ys: list[int] = []
    cells: list[str] = []

    cursor = min_ts + timedelta(days=lookback)
    end = max_ts - timedelta(days=label_horizon)

    if cursor > end:
        cursor = end

    while cursor <= end:
        label_end = cursor + timedelta(days=label_horizon)
        for cell, cell_reports in grouped.items():
            feats = tabular_features_for_cell(cell_reports, cursor, lookback_days=lookback)
            if feats["counts_30d"] < 1:
                continue
            future = _reports_in_window(cell_reports, cursor, label_end)
            label = 1 if len(future) >= max(2, HOTSPOT_LABEL_MIN_REPORTS - 1) else 0
            xs.append([feats[name] for name in FEATURE_NAMES])
            ys.append(label)
            cells.append(cell)
        cursor += timedelta(days=1)

    return np.array(xs, dtype=np.float32), np.array(ys, dtype=np.int32), cells


def build_lstm_sequences(reports: list[dict]) -> tuple[np.ndarray, np.ndarray]:
    """Daily sequences per cell: shape (n, seq_len, 3) -> [count, severity_mean, critical_ratio]."""
    if not reports:
        return np.empty((0, LSTM_SEQUENCE_DAYS, 3)), np.empty((0,))

    parsed = [dict(r, created_at=parse_ts(r["created_at"])) for r in reports]
    min_ts = min(r["created_at"] for r in parsed)
    max_ts = max(r["created_at"] for r in parsed)
    _, label_horizon, lstm_seq = effective_windows(min_ts, max_ts)
    grouped = reports_by_cell(parsed)

    xs: list[list[list[float]]] = []
    ys: list[int] = []

    cursor = min_ts + timedelta(days=lstm_seq)
    end = max_ts - timedelta(days=label_horizon)
    if cursor > end:
        cursor = end

    while cursor <= end:
        label_end = cursor + timedelta(days=label_horizon)
        for cell, cell_reports in grouped.items():
            seq: list[list[float]] = []
            for day_offset in range(lstm_seq, 0, -1):
                day_start = cursor - timedelta(days=day_offset)
                day_end = day_start + timedelta(days=1)
                day_reports = _reports_in_window(cell_reports, day_start, day_end)
                severities = [
                    SEVERITY_MAP.get(str(r.get("severity", "low")), 1) for r in day_reports
                ]
                seq.append([
                    float(len(day_reports)),
                    float(np.mean(severities)) if severities else 0.0,
                    float(sum(1 for s in severities if s >= 4) / len(severities))
                    if severities
                    else 0.0,
                ])
            if sum(row[0] for row in seq) < 1:
                continue
            future = _reports_in_window(cell_reports, cursor, label_end)
            xs.append(seq)
            ys.append(1 if len(future) >= max(2, HOTSPOT_LABEL_MIN_REPORTS - 1) else 0)
        cursor += timedelta(days=1)

    return np.array(xs, dtype=np.float32), np.array(ys, dtype=np.int32)
