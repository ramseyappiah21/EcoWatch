# EcoWatch ML — Illegal Mining Classifier

Trains a lightweight **illegal mining vs not mining** image classifier from the datasets in `data/illegal-mining/`, then exports a TFLite model for the Flutter app.

## Prerequisites

- Python **3.13** (TensorFlow does not support 3.14 yet)
- Downloaded datasets (see `data/illegal-mining/README.md`)

## Quick start

```powershell
cd C:\Users\ramse\source\repos\EcoWatch

py -3.13 -m pip install -r ml/requirements.txt
py -3.13 ml/prepare_dataset.py
py -3.13 ml/train.py
```

Outputs:

| File | Purpose |
|------|---------|
| `assets/models/ecowatch_mining_classifier.tflite` | On-device model in the Flutter app |
| `assets/models/mining_labels.json` | Class names and preprocessing metadata |
| `ml/export/` | Keras checkpoint + training history |

## How it maps to the app

When a citizen selects **Illegal Mining** and attaches a photo, `HybridAiPredictionService` runs the TFLite model. Other categories still use the mock AI until more datasets are trained.

**Windows desktop:** Uses `flutter_litert` (bundles the TFLite DLL automatically). If loading still fails, the app falls back to mock AI.

**Note:** Training images are mostly satellite/aerial. Accuracy on ground-level phone photos will improve as you add local Tarkwa images to `ml/dataset/train/illegal_mining/`.
