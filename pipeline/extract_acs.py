"""Pull ACS 5 year (2023) tables for Mississippi tracts via Census API.

Each table fetched with `group(<TABLE>)` then melted to long format:
(geoid, table_id, variable, label, estimate, moe).
"""
from __future__ import annotations

import csv

from pipeline._http import get_json, log, write_manifest
from pipeline.config import (
    ACS_BASE,
    ACS_DETAIL_TABLES,
    ACS_SUBJECT_BASE,
    ACS_SUBJECT_TABLES,
    CENSUS_API_KEY,
    MS_STATE_FIPS,
    RAW_DIR,
)


def _fetch_variable_labels(base: str, table_id: str) -> dict[str, str]:
    """Fetch variable definitions for a table to populate labels."""
    url = f"{base}/groups/{table_id}.json"
    try:
        meta = get_json(url)
    except Exception as e:
        log.warning(f"  no metadata for {table_id}: {e}")
        return {}
    return {var: info.get("label", "") for var, info in meta.get("variables", {}).items()}


def fetch_table(base: str, table_id: str) -> list[dict]:
    """Fetch one ACS table for all MS tracts; return long-format rows."""
    params = {"get": f"NAME,group({table_id})", "for": "tract:*", "in": f"state:{MS_STATE_FIPS}"}
    if CENSUS_API_KEY:
        params["key"] = CENSUS_API_KEY
    log.info(f"ACS table {table_id}")
    data = get_json(base, params=params)
    header, *body = data
    labels = _fetch_variable_labels(base, table_id)

    est_idx = {col[:-1]: i for i, col in enumerate(header) if col.endswith("E") and col != "NAME"}
    moe_idx = {col[:-1]: i for i, col in enumerate(header) if col.endswith("M")}
    state_i, county_i, tract_i, name_i = (header.index(c) for c in ("state", "county", "tract", "NAME"))

    rows: list[dict] = []
    for row in body:
        geoid = f"{row[state_i]}{row[county_i]}{row[tract_i]}"
        for var_root, ei in est_idx.items():
            full_var = f"{var_root}E"
            rows.append({
                "geoid": geoid,
                "state": row[state_i],
                "county": row[county_i],
                "tract": row[tract_i],
                "name": row[name_i],
                "table_id": table_id,
                "variable": full_var,
                "label": labels.get(full_var, ""),
                "estimate": row[ei],
                "moe": row[moe_idx[var_root]] if var_root in moe_idx else None,
            })
    log.info(f"  {table_id}: {len(rows):,} long rows")
    return rows


def write_csv(rows: list[dict], path) -> None:
    if not rows:
        log.warning(f"  no rows for {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    log.info(f"  wrote {len(rows):,} rows -> {path}")


def main() -> None:
    if not CENSUS_API_KEY:
        log.warning("CENSUS_API_KEY not set. Get one at https://api.census.gov/data/key_signup.html")
    out = RAW_DIR / "acs"
    out.mkdir(parents=True, exist_ok=True)
    all_rows: list[dict] = []
    for table_id in ACS_DETAIL_TABLES:
        all_rows.extend(fetch_table(ACS_BASE, table_id))
    for table_id in ACS_SUBJECT_TABLES:
        all_rows.extend(fetch_table(ACS_SUBJECT_BASE, table_id))
    path = out / "acs5_2023_ms_tract_long.csv"
    write_csv(all_rows, path)
    write_manifest("acs", [path], notes=f"Tables: {ACS_DETAIL_TABLES + ACS_SUBJECT_TABLES}")


if __name__ == "__main__":
    main()
