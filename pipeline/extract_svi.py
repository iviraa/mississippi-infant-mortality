"""Pull CDC/ATSDR SVI 2022 (Mississippi tract + county)."""
from __future__ import annotations

from pipeline._http import download, write_manifest
from pipeline.config import RAW_DIR, SVI_COUNTY_URL, SVI_TRACT_URL


def main() -> None:
    out = RAW_DIR / "svi"
    out.mkdir(parents=True, exist_ok=True)
    files = [
        download(SVI_TRACT_URL, out / "svi_2022_ms_tract.csv"),
        download(SVI_COUNTY_URL, out / "svi_2022_ms_county.csv"),
    ]
    write_manifest("svi", files, notes="CDC/ATSDR SVI 2022 for MS tract and county")


if __name__ == "__main__":
    main()
