"""Download public illegal-mining / galamsey datasets for EcoWatch ML training."""
from __future__ import annotations

import sys
from pathlib import Path

from huggingface_hub import hf_hub_download, snapshot_download

BASE = Path(__file__).resolve().parents[1] / "data" / "illegal-mining"

DATASETS = [
    {
        "name": "galamsey-unified-decisions",
        "repo_id": "samwell/galamsey-unified-decisions",
        "kind": "snapshot",
        "min_images": 490,
        "note": "250 Sentinel-2 tiles over Ghana (RGB + SWIR + labels)",
    },
    {
        "name": "ELDOR-sample",
        "repo_id": "IRSC/ELDOR-sample",
        "kind": "snapshot",
        "min_images": 9000,
        "note": "Illegal gold mining detection sample patches (ELDOR benchmark)",
    },
    {
        "name": "SmallMinesDS",
        "repo_id": "ellaampy/SmallMinesDS",
        "kind": "zip",
        "filename": "SmallMinesDS.zip",
        "min_bytes": 1_500_000_000,
        "note": "Southwestern Ghana ASGM patches (~3.1 GB zip)",
    },
]


def count_images(root: Path) -> int:
    exts = {".jpg", ".jpeg", ".png", ".tif", ".tiff"}
    return sum(1 for p in root.rglob("*") if p.suffix.lower() in exts)


def is_complete(item: dict, dest: Path) -> bool:
    if not dest.exists():
        return False
    if item["kind"] == "zip":
        zip_path = dest / item["filename"]
        return zip_path.is_file() and zip_path.stat().st_size >= item["min_bytes"]
    return count_images(dest) >= item["min_images"]


def download_snapshot(repo_id: str, dest: Path) -> Path:
    print(f"  snapshot_download -> {dest}")
    return Path(
        snapshot_download(
            repo_id=repo_id,
            repo_type="dataset",
            local_dir=str(dest),
        )
    )


def download_zip(repo_id: str, filename: str, dest: Path) -> Path:
    dest.mkdir(parents=True, exist_ok=True)
    print(f"  hf_hub_download {filename} -> {dest}")
    return Path(
        hf_hub_download(
            repo_id=repo_id,
            repo_type="dataset",
            filename=filename,
            local_dir=str(dest),
        )
    )


def main() -> int:
    BASE.mkdir(parents=True, exist_ok=True)
    print(f"Target folder: {BASE}\n")

    for item in DATASETS:
        name = item["name"]
        dest = BASE / name
        print(f"[{name}] {item['note']}")

        if is_complete(item, dest):
            print(f"  SKIP: already complete at {dest}\n")
            continue

        try:
            if item["kind"] == "snapshot":
                path = download_snapshot(item["repo_id"], dest)
            else:
                path = download_zip(item["repo_id"], item["filename"], dest)
            images = count_images(path if path.is_dir() else path.parent)
            print(f"  OK: {path}")
            print(f"  Images found: {images}\n")
        except Exception as exc:
            print(f"  FAILED: {exc}\n", file=sys.stderr)
            return 1

    print("All downloads finished.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
