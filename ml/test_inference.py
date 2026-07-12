"""Quick TFLite inference test for a single image (matches Flutter preprocessing)."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
import tensorflow as tf

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "assets" / "models" / "ecowatch_mining_classifier.tflite"
LABELS = ROOT / "assets" / "models" / "mining_labels.json"
IMG_SIZE = 224


def preprocess(path: Path) -> np.ndarray:
    img = Image.open(path).convert("RGB").resize((IMG_SIZE, IMG_SIZE))
    arr = np.array(img, dtype=np.float32)  # 0-255, model has preprocess inside
    return np.expand_dims(arr, axis=0)


def main() -> None:
    if len(sys.argv) < 2:
        print(f"Usage: py -3.13 {Path(__file__).name} <image> [image2 ...]")
        sys.exit(1)

    meta = json.loads(LABELS.read_text(encoding="utf-8"))
    classes = meta["classes"]
    positive = meta.get("positive_class", "illegal_mining")
    pos_idx = classes.index(positive)

    interpreter = tf.lite.Interpreter(model_path=str(MODEL))
    interpreter.allocate_tensors()
    in_details = interpreter.get_input_details()[0]
    out_details = interpreter.get_output_details()[0]

    for arg in sys.argv[1:]:
        path = Path(arg)
        if not path.is_file():
            print(f"MISSING {path}")
            continue
        batch = preprocess(path)
        interpreter.set_tensor(in_details["index"], batch)
        interpreter.invoke()
        scores = interpreter.get_tensor(out_details["index"])[0]
        mining = float(scores[pos_idx])
        label = positive if mining >= 0.5 else classes[1 - pos_idx]
        print(
            f"{path.name}: {label} {mining * 100:.1f}% mining "
            f"(scores={scores.tolist()})"
        )


if __name__ == "__main__":
    main()
