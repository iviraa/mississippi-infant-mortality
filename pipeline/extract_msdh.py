"""Stage the curated MSDH infant mortality CSV into data/raw/."""
from __future__ import annotations

import shutil

from pipeline._http import log, write_manifest
from pipeline.config import PROJECT_ROOT, RAW_DIR


def main() -> None:
    source = PROJECT_ROOT / "data" / "seed" / "msdh_imr.csv"
    if not source.exists():
        raise FileNotFoundError(f"MSDH IMR seed CSV missing: {source}")
    out = RAW_DIR / "msdh"
    out.mkdir(parents=True, exist_ok=True)
    dest = out / "msdh_imr.csv"
    shutil.copy(source, dest)
    log.info(f"  staged MSDH IMR -> {dest}")
    write_manifest("msdh", [dest], notes="Curated from MSDH 2024 report + CDC WONDER")


if __name__ == "__main__":
    main()
