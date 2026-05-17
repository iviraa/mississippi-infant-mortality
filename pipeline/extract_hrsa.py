"""Pull HRSA HPSA designations for primary care, dental, mental health."""
from __future__ import annotations

from pipeline._http import download, log, write_manifest
from pipeline.config import (
    HRSA_HPSA_DENTAL_URL,
    HRSA_HPSA_MENTAL_URL,
    HRSA_HPSA_PRIMARY_URL,
    RAW_DIR,
)


def main() -> None:
    out = RAW_DIR / "hrsa"
    out.mkdir(parents=True, exist_ok=True)
    targets = [
        ("primary_care", HRSA_HPSA_PRIMARY_URL),
        ("dental", HRSA_HPSA_DENTAL_URL),
        ("mental_health", HRSA_HPSA_MENTAL_URL),
    ]
    files = []
    for name, url in targets:
        try:
            files.append(download(url, out / f"hpsa_{name}.csv"))
        except Exception as e:
            log.warning(f"  HRSA {name} failed: {e}")
    write_manifest("hrsa", files, notes="HRSA HPSA: Primary Care, Dental, Mental Health")


if __name__ == "__main__":
    main()
