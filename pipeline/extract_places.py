"""Pull CDC PLACES tract data for Mississippi (all release years)."""
from __future__ import annotations

import csv

from pipeline._http import get_json, log, write_manifest
from pipeline.config import (
    MS_STATE_ABBR,
    PLACES_API_BASE,
    PLACES_TRACT_DATASETS,
    RAW_DIR,
)

PAGE_SIZE = 50000  # Socrata max per call


def fetch_year(year: int, dataset_id: str) -> list[dict]:
    """Pull all MS rows for a single PLACES release; [] if dataset retired."""
    rows: list[dict] = []
    offset = 0
    while True:
        url = f"{PLACES_API_BASE}/{dataset_id}.json"
        params = {"stateabbr": MS_STATE_ABBR, "$limit": PAGE_SIZE, "$offset": offset}
        try:
            page = get_json(url, params=params)
        except Exception as e:
            log.warning(f"  PLACES {year} ({dataset_id}): unavailable ({e}); skipping")
            return []
        if not page:
            break
        rows.extend(page)
        log.info(f"  PLACES {year}: fetched {len(rows):,} rows so far")
        if len(page) < PAGE_SIZE:
            break
        offset += PAGE_SIZE
    return rows


def normalize(rows: list[dict], year: int) -> list[dict]:
    """Set year + flatten geolocation dict to WKT POINT."""
    for r in rows:
        r.setdefault("year", str(year))
        geo = r.get("geolocation")
        if isinstance(geo, dict) and "coordinates" in geo:
            lon, lat = geo["coordinates"]
            r["geolocation"] = f"POINT({lon} {lat})"
    return rows


def write_csv(rows: list[dict], path) -> None:
    if not rows:
        log.warning(f"  no rows for {path}")
        return
    keys = sorted({k for r in rows for k in r.keys()})
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=keys)
        w.writeheader()
        w.writerows(rows)
    log.info(f"  wrote {len(rows):,} rows -> {path}")


def main() -> None:
    out_dir = RAW_DIR / "places"
    out_dir.mkdir(parents=True, exist_ok=True)
    written = []
    for year, dataset_id in sorted(PLACES_TRACT_DATASETS.items()):
        log.info(f"PLACES release {year} (dataset {dataset_id})")
        rows = fetch_year(year, dataset_id)
        if not rows:
            continue
        rows = normalize(rows, year)
        path = out_dir / f"places_tract_{year}.csv"
        write_csv(rows, path)
        written.append(path)
    if not written:
        raise RuntimeError("No PLACES data fetched. Check internet + dataset IDs.")
    write_manifest("places", written, notes=f"Years: {list(PLACES_TRACT_DATASETS)}")


if __name__ == "__main__":
    main()
