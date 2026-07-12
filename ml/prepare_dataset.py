"""Build train/val folders for illegal-mining binary classifier."""
from __future__ import annotations

import json
import random
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data" / "illegal-mining"
OUT = ROOT / "ml" / "dataset"
SEED = 42
ELDOR_POSITIVE_CAP = 1500

MINING_ACTIONS = {"downlink", "flag", "request_hires"}


def galamsey_samples() -> tuple[list[Path], list[Path]]:
    base = DATA / "galamsey-unified-decisions"
    labels_file = base / "labels.jsonl"
    positives: list[Path] = []
    negatives: list[Path] = []

    if not labels_file.is_file():
        return positives, negatives

    for line in labels_file.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        row = json.loads(line)
        coord = row["coord_id"]
        rgb = base / "images" / coord / "rgb.png"
        if not rgb.is_file():
            continue
        action = row.get("label", {}).get("action", "discard")
        if action == "discard":
            negatives.append(rgb)
        elif action in MINING_ACTIONS or row.get("stratum") == "mining":
            positives.append(rgb)

    return positives, negatives


def eldor_samples() -> list[Path]:
    images_dir = DATA / "ELDOR-sample" / "patches" / "images"
    if not images_dir.is_dir():
        return []
    paths = sorted(images_dir.glob("*.jpg"))
    random.Random(SEED).shuffle(paths)
    return paths[:ELDOR_POSITIVE_CAP]


def citizen_ground_samples() -> list[Path]:
    """Ground-level news/citizen photos (Yahoo, press, etc.)."""
    base = DATA / "citizen-ground"
    if not base.is_dir():
        return []
    exts = {".jpg", ".jpeg", ".png", ".webp"}
    return sorted(p for p in base.iterdir() if p.suffix.lower() in exts)


def copy_split(
    paths: list[Path],
    class_name: str,
    train_ratio: float = 0.8,
) -> tuple[int, int]:
    rng = random.Random(SEED)
    shuffled = paths.copy()
    rng.shuffle(shuffled)
    split = int(len(shuffled) * train_ratio)
    train_files = shuffled[:split]
    val_files = shuffled[split:]

    for split_name, files in (("train", train_files), ("val", val_files)):
        dest_dir = OUT / split_name / class_name
        dest_dir.mkdir(parents=True, exist_ok=True)
        for idx, src in enumerate(files):
            ext = src.suffix.lower() or ".jpg"
            dest = dest_dir / f"{class_name}_{split_name}_{idx:05d}{ext}"
            if not dest.exists():
                shutil.copy2(src, dest)

    return len(train_files), len(val_files)


def main() -> None:
    random.seed(SEED)
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)

    pos_g, neg_g = galamsey_samples()
    pos_e = eldor_samples()
    pos_c = citizen_ground_samples()
    # Duplicate citizen photos so the model learns ground-level galamsey scenes.
    positives = pos_g + pos_e + (pos_c * 4)
    negatives = neg_g

    print(f"Galamsey: {len(pos_g)} mining, {len(neg_g)} not-mining")
    print(f"ELDOR: {len(pos_e)} mining patches (capped)")
    print(f"Citizen ground: {len(pos_c)} photos (x4 weight -> {len(pos_c) * 4})")
    print(f"Total: {len(positives)} illegal_mining, {len(negatives)} not_mining")

    if not positives or not negatives:
        raise SystemExit(
            "Need both positive and negative samples. "
            "Ensure galamsey-unified-decisions is downloaded."
        )

    pt, pv = copy_split(positives, "illegal_mining")
    nt, nv = copy_split(negatives, "not_mining")
    print(f"Train: {pt} mining + {nt} not-mining")
    print(f"Val:   {pv} mining + {nv} not-mining")
    print(f"Dataset ready at {OUT}")


if __name__ == "__main__":
    main()
