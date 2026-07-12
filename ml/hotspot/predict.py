"""Run inference using trained hotspot models and write predictions.json."""

from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import joblib
import numpy as np

from config import EXPORT_DIR, PREDICTION_THRESHOLD
from train import load_reports_from_csv, load_reports_from_db, predict_current

try:
    from tensorflow import keras
except ImportError:
    keras = None


def main() -> None:
    export_dir = Path(__file__).parent / EXPORT_DIR
    tabular_models = {}

    rf_path = export_dir / "random_forest.joblib"
    xgb_path = export_dir / "xgboost.joblib"
    lstm_path = export_dir / "lstm.keras"

    if rf_path.exists():
        tabular_models["random_forest"] = joblib.load(rf_path)
    if xgb_path.exists():
        tabular_models["xgboost"] = joblib.load(xgb_path)

    lstm_model = keras.models.load_model(lstm_path) if keras and lstm_path.exists() else None

    if "--stdin" in sys.argv:
        reports = json.load(sys.stdin)
    elif "--database" in sys.argv:
        reports = load_reports_from_db()
    else:
        csv = Path(__file__).resolve().parents[2] / "backend" / "export" / "reports.csv"
        reports = load_reports_from_csv(csv) if csv.exists() else load_reports_from_db()

    predictions = predict_current(reports, tabular_models, lstm_model)

    metrics_path = export_dir / "model_metrics.json"
    metrics = json.loads(metrics_path.read_text()) if metrics_path.exists() else {}

    output = {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "modelMetrics": metrics,
        "predictions": predictions,
        "algorithms": [k for k in ["random_forest", "xgboost", "lstm"] if k in metrics or k == "lstm"],
    }

    print(json.dumps(output))


if __name__ == "__main__":
    main()
