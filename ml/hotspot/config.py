"""Tarkwa-Nsuaem study area and grid settings for hotspot prediction."""

# Approximate bounding box (Tarkwa mining district, Ghana)
LAT_MIN = 5.25
LAT_MAX = 5.38
LNG_MIN = -2.08
LNG_MAX = -1.90

# ~1 km grid cells at this latitude
CELL_SIZE = 0.009

# Training windows (days)
LOOKBACK_DAYS = 30
LABEL_HORIZON_DAYS = 7
LSTM_SEQUENCE_DAYS = 14

# Hotspot label: reports in cell during label window >= this count
HOTSPOT_LABEL_MIN_REPORTS = 3

# Prediction threshold (probability)
PREDICTION_THRESHOLD = 0.45

EXPORT_DIR = "export"

CATEGORIES = [
    "airPollution",
    "waterPollution",
    "illegalMining",
    "wasteDumping",
    "flooding",
]

SEVERITY_MAP = {"low": 1, "medium": 2, "high": 3, "critical": 4}
