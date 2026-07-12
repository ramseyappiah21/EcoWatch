"""Train MobileNetV2 binary classifier and export TFLite for EcoWatch."""
from __future__ import annotations

import json
from pathlib import Path

import tensorflow as tf

ROOT = Path(__file__).resolve().parents[1]
DATASET = ROOT / "ml" / "dataset"
EXPORT_DIR = ROOT / "ml" / "export"
ASSET_DIR = ROOT / "assets" / "models"

IMG_SIZE = 224
BATCH_SIZE = 16
EPOCHS = 8
LEARNING_RATE = 1e-4


def build_model(num_classes: int = 2) -> tf.keras.Model:
    base = tf.keras.applications.MobileNetV2(
        input_shape=(IMG_SIZE, IMG_SIZE, 3),
        include_top=False,
        weights="imagenet",
    )
    base.trainable = False
    inputs = tf.keras.Input(shape=(IMG_SIZE, IMG_SIZE, 3))
    x = tf.keras.applications.mobilenet_v2.preprocess_input(inputs)
    x = base(x, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.3)(x)
    outputs = tf.keras.layers.Dense(num_classes, activation="softmax")(x)
    model = tf.keras.Model(inputs, outputs)
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=LEARNING_RATE),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    return model


def export_tflite(model: tf.keras.Model, class_names: list[str]) -> None:
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    ASSET_DIR.mkdir(parents=True, exist_ok=True)

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    tflite_path = EXPORT_DIR / "ecowatch_mining_classifier.tflite"
    asset_path = ASSET_DIR / "ecowatch_mining_classifier.tflite"
    tflite_path.write_bytes(tflite_model)
    asset_path.write_bytes(tflite_model)

    meta = {
        "model_version": "ecowatch-mining-v2",
        "image_size": IMG_SIZE,
        "classes": class_names,
        "positive_class": "illegal_mining",
        "preprocess": "mobilenet_v2_in_model",
        "input_range": "0-255",
    }
    meta_json = json.dumps(meta, indent=2)
    (ASSET_DIR / "mining_labels.json").write_text(meta_json, encoding="utf-8")
    (EXPORT_DIR / "mining_labels.json").write_text(meta_json, encoding="utf-8")
    print(f"TFLite model: {asset_path} ({len(tflite_model) / 1024 / 1024:.2f} MB)")


def main() -> None:
    if not DATASET.is_dir():
        raise SystemExit(f"Run prepare_dataset.py first. Missing {DATASET}")

    train_ds = tf.keras.utils.image_dataset_from_directory(
        DATASET / "train",
        image_size=(IMG_SIZE, IMG_SIZE),
        batch_size=BATCH_SIZE,
        label_mode="int",
    )
    val_ds = tf.keras.utils.image_dataset_from_directory(
        DATASET / "val",
        image_size=(IMG_SIZE, IMG_SIZE),
        batch_size=BATCH_SIZE,
        label_mode="int",
    )

    class_names = train_ds.class_names
    print("Classes:", class_names)

    train_ds = train_ds.cache().prefetch(tf.data.AUTOTUNE)
    val_ds = val_ds.cache().prefetch(tf.data.AUTOTUNE)

    model = build_model(num_classes=len(class_names))
    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor="val_accuracy", patience=2, restore_best_weights=True
        ),
    ]
    history = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=EPOCHS,
        callbacks=callbacks,
        verbose=1,
    )

    val_loss, val_acc = model.evaluate(val_ds, verbose=0)
    print(f"Final val accuracy: {val_acc:.3f}")

    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    model.save(EXPORT_DIR / "ecowatch_mining_classifier.keras")
    export_tflite(model, class_names)

    hist_path = EXPORT_DIR / "history.json"
    hist_path.write_text(
        json.dumps(
            {k: [float(v) for v in vals] for k, vals in history.history.items()}
        ),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
