"""HTTP helpers: retry, streaming download, manifest logging."""
from __future__ import annotations

import json
import logging
from datetime import datetime
from pathlib import Path
from typing import Optional

import httpx
from tenacity import retry, stop_after_attempt, wait_exponential

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(name)s] %(message)s")
log = logging.getLogger("pipeline")


@retry(stop=stop_after_attempt(4), wait=wait_exponential(multiplier=2, min=2, max=30))
def get_json(url: str, params: Optional[dict] = None, timeout: float = 60.0) -> list | dict:
    log.info(f"GET {url} params={params}")
    r = httpx.get(url, params=params, timeout=timeout, follow_redirects=True)
    r.raise_for_status()
    return r.json()


@retry(stop=stop_after_attempt(4), wait=wait_exponential(multiplier=2, min=2, max=30))
def download(url: str, dest: Path, timeout: float = 300.0) -> Path:
    """Stream a URL to disk."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    log.info(f"Downloading {url} -> {dest}")
    with httpx.stream("GET", url, timeout=timeout, follow_redirects=True) as r:
        r.raise_for_status()
        with open(dest, "wb") as fh:
            for chunk in r.iter_bytes(chunk_size=64 * 1024):
                fh.write(chunk)
    log.info(f"  wrote {dest.stat().st_size:,} bytes")
    return dest


def write_manifest(source: str, files: list[Path], notes: str = "") -> None:
    """Append a JSONL entry to data/raw/_manifest.jsonl."""
    from pipeline.config import RAW_DIR
    manifest = RAW_DIR / "_manifest.jsonl"
    entry = {
        "ts": datetime.utcnow().isoformat() + "Z",
        "source": source,
        "files": [str(p.relative_to(RAW_DIR)) for p in files],
        "notes": notes,
    }
    with open(manifest, "a") as fh:
        fh.write(json.dumps(entry) + "\n")
