"""Pull CMS Provider Data Catalog files (hospital general, HCAHPS, HRRP,
complications, timely care). Falls back to the metastore API if a static
download URL 404s (CMS rotates resource hashes quarterly)."""
from __future__ import annotations

from pipeline._http import download, get_json, log, write_manifest
from pipeline.config import (
    CMS_COMPLICATIONS_URL,
    CMS_DATASETS,
    CMS_HCAHPS_URL,
    CMS_HOSPITAL_GENERAL_URL,
    CMS_HRRP_URL,
    CMS_TIMELY_CARE_URL,
    RAW_DIR,
)

METASTORE = "https://data.cms.gov/provider-data/api/1/metastore/schemas/dataset/items/{id}"


def resolve_current_url(dataset_id: str) -> str:
    """Look up the current downloadable CSV URL for a CMS dataset."""
    meta = get_json(METASTORE.format(id=dataset_id))
    dist = meta.get("distribution", [])
    if not dist:
        raise RuntimeError(f"No distribution for {dataset_id}")
    url = dist[0].get("downloadURL") or dist[0].get("data", {}).get("downloadURL")
    if not url:
        raise RuntimeError(f"No downloadURL in distribution for {dataset_id}")
    log.info(f"  resolved {dataset_id} -> {url}")
    return url


def safe_download(static_url: str, dataset_id: str, dest):
    try:
        return download(static_url, dest)
    except Exception as e:
        log.warning(f"static URL failed ({e}); resolving via metastore")
        return download(resolve_current_url(dataset_id), dest)


def main() -> None:
    out = RAW_DIR / "cms"
    out.mkdir(parents=True, exist_ok=True)
    files = [
        safe_download(CMS_HOSPITAL_GENERAL_URL, CMS_DATASETS["hospital_general"], out / "hospital_general.csv"),
        safe_download(CMS_HCAHPS_URL,           CMS_DATASETS["hcahps"],           out / "hcahps.csv"),
        safe_download(CMS_HRRP_URL,             CMS_DATASETS["hrrp"],             out / "hrrp_fy2026.csv"),
        safe_download(CMS_COMPLICATIONS_URL,    CMS_DATASETS["complications"],    out / "complications_deaths.csv"),
        safe_download(CMS_TIMELY_CARE_URL,      CMS_DATASETS["timely_care"],      out / "timely_care.csv"),
    ]
    write_manifest("cms", files, notes="CMS Provider Data Catalog, quarterly refresh")


if __name__ == "__main__":
    main()
