# Predictive Hotspot Detection

Forecasts where environmental incident clusters are likely to form in the next 7 days across the Tarkwa study area.

## Algorithms

| Model | Type | Input features |
|-------|------|----------------|
| **Random Forest** | Tabular ensemble | 7/14/30-day counts, severity, category mix, water/USSD ratios |
| **XGBoost** | Gradient boosted trees | Same tabular features |
| **LSTM** | Sequence model | 14-day daily sequences: report count, mean severity, critical ratio |

Grid cells are ~1 km². A cell is labeled a future hotspot if it receives ≥3 reports in the next 7 days.

## Setup

```powershell
cd ml\hotspot
python -m pip install -r requirements.txt
```

**Note:** LSTM requires TensorFlow, which currently supports Python 3.10–3.12 only. On Python 3.14, Random Forest and XGBoost still train; LSTM is skipped automatically.

## Train (from PostgreSQL)

```powershell
# Ensure backend Postgres is running and seeded
cd C:\Users\ramse\source\repos\EcoWatch\ml\hotspot
python train.py --database
```

Or from a CSV export:

```powershell
python train.py --csv ..\..\backend\export\reports.csv
```

Outputs:

- `export/random_forest.joblib`
- `export/xgboost.joblib`
- `export/lstm.keras`
- `export/predictions.json`
- `export/model_metrics.json`

## Predict only

```powershell
python predict.py --database
```

## API integration

The Node backend reads `ml/hotspot/export/predictions.json` and falls back to a built-in heuristic ensemble when models are not trained yet. Analytics endpoint:

`GET /v1/analytics/predictions`

Returns `predictedHotspots`, `hotspotGrowth`, `predictedTrend`, and `modelMetrics`.
