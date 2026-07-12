"""Download ground-level / citizen illegal-mining photos for ML fine-tuning."""
from __future__ import annotations

import hashlib
import re
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data" / "illegal-mining" / "citizen-ground"
USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
)

# Seed URLs (news / NGO photos — ground-level galamsey scenes).
SEED_URLS = [
    "https://cdn.businessday.ng/wp-content/uploads/2025/02/illegal-mining.jpg",
    "https://cdn.businessday.ng/wp-content/uploads/2024/08/Illegal-mining.jpg",
    "https://www.ghanaweb.com/GhanaHomePage/NewsArchive/image/illegal-mining-2023.jpg",
]

YAHOO_SEARCH = (
    "https://uk.images.search.yahoo.com/search/images"
    "?p=illegal+mining+ghana+galamsey&fr=mcafee&type=E210GB1357G0"
)


def fetch(url: str, timeout: int = 30) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def extract_yahoo_image_urls(html: str) -> list[str]:
    urls: list[str] = []
    for match in re.finditer(r"imgurl=([^&\"'>]+)", html):
        decoded = urllib.parse.unquote(match.group(1))
        if decoded.startswith("http"):
            urls.append(decoded)
    # Also pick direct src from embedded JSON blobs.
    for match in re.finditer(r'"murl":"(https?://[^"]+)"', html):
        urls.append(match.group(1).encode().decode("unicode_escape"))
    seen: set[str] = set()
    unique: list[str] = []
    for u in urls:
        if u not in seen:
            seen.add(u)
            unique.append(u)
    return unique


def save_image(data: bytes, dest_dir: Path, prefix: str, source_url: str) -> Path | None:
    if len(data) < 8_000:
        return None
    digest = hashlib.sha1(data).hexdigest()[:10]
    ext = ".jpg"
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        ext = ".png"
    elif data[:2] == b"\xff\xd8":
        ext = ".jpg"
    elif data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        ext = ".webp"
    dest = dest_dir / f"{prefix}_{digest}{ext}"
    if dest.exists():
        return dest
    dest.write_bytes(data)
    print(f"  saved {dest.name} ({len(data) // 1024} KB) <- {source_url[:80]}")
    return dest


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    downloaded = 0

    print("Downloading seed citizen mining photos...")
    for idx, url in enumerate(SEED_URLS):
        try:
            data = fetch(url)
            if save_image(data, OUT, f"seed{idx:02d}", url):
                downloaded += 1
        except Exception as exc:  # noqa: BLE001
            print(f"  skip seed {url}: {exc}")
        time.sleep(0.4)

    print(f"\nScraping Yahoo image search: {YAHOO_SEARCH}")
    try:
        html = fetch(YAHOO_SEARCH).decode("utf-8", errors="ignore")
        urls = extract_yahoo_image_urls(html)
        print(f"  found {len(urls)} candidate image URLs")
    except Exception as exc:  # noqa: BLE001
        print(f"  Yahoo scrape failed: {exc}")
        urls = []

    for idx, url in enumerate(urls[:40]):
        try:
            data = fetch(url)
            if save_image(data, OUT, f"yahoo{idx:03d}", url):
                downloaded += 1
        except Exception as exc:  # noqa: BLE001
            print(f"  skip {url[:70]}: {exc}")
        time.sleep(0.35)

    total = len(list(OUT.glob("*")))
    print(f"\nCitizen ground images: {total} files in {OUT}")
    if total == 0:
        raise SystemExit("No images downloaded — check network or seed URLs.")


if __name__ == "__main__":
    main()
