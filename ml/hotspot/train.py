"""
Train Random Forest, XGBoost, and LSTM models for predictive hotspot detection.

Usage:
  cd ml/hotspot
  pip install -r requirements.txt
  python train.py --csv ../../backend/export/reports.csv
  python train.py --database   # uses DATABASE_URL from backend/.env
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

import joblib
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, f1_score, roc_auc_score
from sklearn.model_selection import train_test_split

from config import EXPORT_DIR, PREDICTION_THRESHOLD
from features import FEATURE_NAMES
from features import (
    FEATURE_NAMES as FN,
    build_lstm_sequences,
    build_training_samples,
    cell_center,
    reports_by_cell,
    tabular_features_for_cell,
)

try:
    from xgboost import XGBClassifier
except ImportError:
    XGBClassifier = None  # type: ignore

try:
    import tensorflow as tf
    from tensorflow import keras
    from tensorflow.keras import layers
except ImportError:
    tf = None
    keras = None
    layers = None


def load_reports_from_csv(path: Path) -> list[dict]:
    import csv

    rows = []
    with path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append({
                "id": row.get("id") or row.get("tracking_token"),
                "category": row.get("category"),
                "latitude": float(row["latitude"]),
                "longitude": float(row["longitude"]),
                "severity": row.get("severity", "low"),
                "severity_score": int(row.get("severity_score") or 0),
                "source": row.get("source", "app"),
                "status": row.get("status", "underReview"),
                "water_body_nearby": str(row.get("water_body_nearby", "")).lower()
                in ("true", "t", "1"),
                "created_at": row["created_at"],
            })
    return rows


def load_reports_from_db() -> list[dict]:
    import psycopg2
    from dotenv import load_dotenv

    load_dotenv(Path(__file__).resolve().parents[2] / "backend" / ".env")
    url = os.environ.get("DATABASE_URL", "postgresql://ecowatch:ecowatch@localhost:5432/ecowatch")
    conn = psycopg2.connect(url)
    cur = conn.cursor()
    cur.execute(
        """SELECT id, category, latitude, longitude, severity, severity_score,
                  source, status, water_body_nearby, created_at
           FROM reports ORDER BY created_at"""
    )
    cols = [d[0] for d in cur.description]
    rows = []
    for record in cur.fetchall():
        row = dict(zip(cols, record))
        row["water_body_nearby"] = bool(row.get("water_body_nearby"))
        row["created_at"] = row["created_at"].isoformat()
        rows.append(row)
    conn.close()
    return rows


def train_tabular_models(X: np.ndarray, y: np.ndarray) -> dict:
    if len(X) < 4:
        return {"skipped": True, "reason": f"insufficient labeled samples ({len(X)})"}

    stratify = y if len(np.unique(y)) > 1 and min(np.bincount(y)) >= 2 else None
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=min(0.25, max(1, len(X) // 4) / len(X)), random_state=42, stratify=stratify
    )

    rf = RandomForestClassifier(
        n_estimators=120,
        max_depth=8,
        min_samples_leaf=2,
        class_weight="balanced",
        random_state=42,
    )
    rf.fit(X_train, y_train)
    rf_proba = rf.predict_proba(X_test)[:, 1]
    rf_pred = (rf_proba >= PREDICTION_THRESHOLD).astype(int)

    metrics = {
        "random_forest": {
            "accuracy": round(float(accuracy_score(y_test, rf_pred)), 4),
            "f1": round(float(f1_score(y_test, rf_pred, zero_division=0)), 4),
            "auc": round(float(roc_auc_score(y_test, rf_proba)), 4)
            if len(np.unique(y_test)) > 1
            else None,
            "feature_importance": dict(
                zip(FEATURE_NAMES, [round(float(v), 4) for v in rf.feature_importances_])
            ),
        }
    }

    models = {"random_forest": rf}

    if XGBClassifier is not None:
        xgb = XGBClassifier(
            n_estimators=100,
            max_depth=5,
            learning_rate=0.08,
            subsample=0.9,
            colsample_bytree=0.9,
            eval_metric="logloss",
            random_state=42,
        )
        xgb.fit(X_train, y_train)
        xgb_proba = xgb.predict_proba(X_test)[:, 1]
        xgb_pred = (xgb_proba >= PREDICTION_THRESHOLD).astype(int)
        metrics["xgboost"] = {
            "accuracy": round(float(accuracy_score(y_test, xgb_pred)), 4),
            "f1": round(float(f1_score(y_test, xgb_pred, zero_division=0)), 4),
            "auc": round(float(roc_auc_score(y_test, xgb_proba)), 4)
            if len(np.unique(y_test)) > 1
            else None,
        }
        models["xgboost"] = xgb
    else:
        metrics["xgboost"] = {"skipped": True, "reason": "xgboost not installed"}

    return {"models": models, "metrics": metrics}


def train_lstm(X: np.ndarray, y: np.ndarray) -> dict:
    if tf is None or keras is None:
        return {"skipped": True, "reason": "tensorflow not installed"}

    if len(X) < 16 or len(np.unique(y)) < 2:
        return {"skipped": True, "reason": "insufficient sequence samples"}

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.25, random_state=42, stratify=y
    )

    model = keras.Sequential([
        layers.Input(shape=(X.shape[1], X.shape[2])),
        layers.LSTM(32, return_sequences=False),
        layers.Dropout(0.2),
        layers.Dense(16, activation="relu"),
        layers.Dense(1, activation="sigmoid"),
    ])
    model.compile(optimizer="adam", loss="binary_crossentropy", metrics=["accuracy"])
    model.fit(
        X_train,
        y_train,
        epochs=25,
        batch_size=min(16, len(X_train)),
        validation_split=0.15,
        verbose=0,
    )

    proba = model.predict(X_test, verbose=0).flatten()
    pred = (proba >= PREDICTION_THRESHOLD).astype(int)

    return {
        "model": model,
        "metrics": {
            "lstm": {
                "accuracy": round(float(accuracy_score(y_test, pred)), 4),
                "f1": round(float(f1_score(y_test, pred, zero_division=0)), 4),
                "auc": round(float(roc_auc_score(y_test, proba)), 4)
                if len(np.unique(y_test)) > 1
                else None,
            }
        },
    }


def predict_current(
    reports: list[dict],
    tabular_models: dict,
    lstm_model,
) -> list[dict]:
    from features import parse_ts

    now = datetime.now(timezone.utc)
    grouped = reports_by_cell(reports)
    predictions = []

    lstm_cells: list[str] = []
    lstm_seqs: list[np.ndarray] = []

    for cell, cell_reports in grouped.items():
        feats = tabular_features_for_cell(cell_reports, now)
        if feats["counts_30d"] < 1:
            continue

        x = np.array([[feats[name] for name in FN]], dtype=np.float32)
        scores = {}

        if "random_forest" in tabular_models:
            scores["random_forest"] = float(tabular_models["random_forest"].predict_proba(x)[0, 1])
        if "xgboost" in tabular_models:
            scores["xgboost"] = float(tabular_models["xgboost"].predict_proba(x)[0, 1])

        # Build LSTM sequence for this cell
        from datetime import timedelta

        seq = []
        for day_offset in range(14, 0, -1):
            day_start = now - timedelta(days=day_offset)
            day_end = day_start + timedelta(days=1)
            day_reports = [
                r
                for r in cell_reports
                if day_start <= parse_ts(r["created_at"]) < day_end
            ]
            severities = [
                {"low": 1, "medium": 2, "high": 3, "critical": 4}.get(
                    str(r.get("severity", "low")), 1
                )
                for r in day_reports
            ]
            seq.append([
                float(len(day_reports)),
                float(np.mean(severities)) if severities else 0.0,
                float(sum(1 for s in severities if s >= 4) / len(severities))
                if severities
                else 0.0,
            ])
        lstm_cells.append(cell)
        lstm_seqs.append(seq)

        model_scores = [v for v in scores.values()]
        ensemble = float(np.mean(model_scores)) if model_scores else 0.0

        lat, lng = cell_center(cell)
        predictions.append({
            "cellId": cell,
            "latitude": lat,
            "longitude": lng,
            "scores": scores,
            "ensembleScore": ensemble,
            "lstmScore": None,
            "priority": _priority(ensemble),
            "reportCount30d": int(feats["counts_30d"]),
        })

    if lstm_model is not None and lstm_seqs:
        X_lstm = np.array(lstm_seqs, dtype=np.float32)
        lstm_probs = lstm_model.predict(X_lstm, verbose=0).flatten()
        for i, cell in enumerate(lstm_cells):
            for p in predictions:
                if p["cellId"] == cell:
                    p["lstmScore"] = float(lstm_probs[i])
                    p["scores"]["lstm"] = float(lstm_probs[i])
                    all_scores = list(p["scores"].values())
                    p["ensembleScore"] = float(np.mean(all_scores))
                    p["priority"] = _priority(p["ensembleScore"])
                    break

    predictions.sort(key=lambda p: p["ensembleScore"], reverse=True)
    return [p for p in predictions if p["ensembleScore"] >= PREDICTION_THRESHOLD][:25]


def _priority(score: float) -> str:
    if score >= 0.75:
        return "critical"
    if score >= 0.55:
        return "high"
    if score >= 0.45:
        return "medium"
    return "low"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=str, help="Path to reports CSV export")
    parser.add_argument("--database", action="store_true", help="Load from PostgreSQL")
    args = parser.parse_args()

    export_dir = Path(__file__).parent / EXPORT_DIR
    export_dir.mkdir(exist_ok=True)

    if args.database:
        reports = load_reports_from_db()
    elif args.csv:
        reports = load_reports_from_csv(Path(args.csv))
    else:
        default_csv = Path(__file__).resolve().parents[2] / "backend" / "export" / "reports.csv"
        if default_csv.exists():
            reports = load_reports_from_csv(default_csv)
        else:
            print("No data source. Use --database or --csv path", file=sys.stderr)
            sys.exit(1)

    print(f"Loaded {len(reports)} reports")

    X_tab, y_tab, _ = build_training_samples(reports)
    X_lstm, y_lstm = build_lstm_sequences(reports)
    print(f"Tabular training samples: {len(X_tab)} (positive: {int(y_tab.sum()) if len(y_tab) else 0})")
    print(f"LSTM training samples: {len(X_lstm)}")

    tabular_result = train_tabular_models(X_tab, y_tab)
    lstm_result = train_lstm(X_lstm, y_lstm)

    all_metrics = {}
    tabular_models = {}

    if not tabular_result.get("skipped"):
        tabular_models = tabular_result["models"]
        all_metrics.update(tabular_result["metrics"])
        joblib.dump(tabular_models["random_forest"], export_dir / "random_forest.joblib")
        if "xgboost" in tabular_models:
            joblib.dump(tabular_models["xgboost"], export_dir / "xgboost.joblib")

    lstm_model = None
    if not lstm_result.get("skipped") and "model" in lstm_result:
        lstm_model = lstm_result["model"]
        lstm_model.save(export_dir / "lstm.keras")
        all_metrics.update(lstm_result["metrics"])

    predictions = predict_current(reports, tabular_models, lstm_model)

    output = {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "modelMetrics": all_metrics,
        "featureNames": FEATURE_NAMES,
        "predictions": predictions,
        "algorithms": ["random_forest", "xgboost", "lstm"],
    }

    (export_dir / "predictions.json").write_text(json.dumps(output, indent=2))
    (export_dir / "model_metrics.json").write_text(json.dumps(all_metrics, indent=2))

    print(json.dumps(all_metrics, indent=2))
    print(f"Wrote {len(predictions)} predicted hotspot cells to {export_dir / 'predictions.json'}")


if __name__ == "__main__":
    main()
