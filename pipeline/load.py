"""ETL pipeline: read CSVs from data/raw/, clean in pandas, load typed tables to Postgres.

This file replaces the old SQL staging layer. Each load_* function takes a
single source from raw CSV -> clean pandas dataframe -> typed Postgres table.
"""
from __future__ import annotations

import re
from pathlib import Path

import numpy as np
import pandas as pd
from sqlalchemy import inspect, text

from pipeline._http import log
from pipeline.config import (
    MS_DELTA_COUNTIES,
    MS_GULF_COUNTIES,
    MS_STATE_ABBR,
    MS_STATE_FIPS,
    RAW_DIR,
)
from pipeline.db import get_engine

# Regions used to tag every census tract
DELTA_COUNTIES = set(MS_DELTA_COUNTIES.keys())
GULF_COUNTIES = set(MS_GULF_COUNTIES.keys())
JACKSON_METRO = {"28049", "28089", "28121"}
PINE_BELT = {"28035", "28073", "28067", "28111", "28031"}


def _normalize_columns(df: pd.DataFrame) -> pd.DataFrame:
    """Lowercase snake_case column names with deduplication."""
    new_cols, seen = [], {}
    for c in df.columns:
        n = re.sub(r"[^\w]+", "_", str(c).strip().lower())
        n = re.sub(r"_+", "_", n).strip("_") or "col"
        if not n[0].isalpha() and n[0] != "_":
            n = "c_" + n
        if n in seen:
            seen[n] += 1
            n = f"{n}_{seen[n]}"
        else:
            seen[n] = 0
        new_cols.append(n)
    df.columns = new_cols
    return df


def _svi_to_numeric(s: pd.Series) -> pd.Series:
    """SVI -999 sentinel -> NaN, then numeric."""
    s = s.replace([-999, "-999", "-999.0", "-999.0000"], np.nan)
    return pd.to_numeric(s, errors="coerce")


def _safe_numeric(s: pd.Series) -> pd.Series:
    """Generic numeric cast that returns NaN on failure (handles 'Too Few to Report', etc.)."""
    return pd.to_numeric(s, errors="coerce")


def _acs_to_numeric(s: pd.Series) -> pd.Series:
    """ACS uses giant negative sentinels (-666666666 etc.) for missing data."""
    out = pd.to_numeric(s, errors="coerce")
    return out.where(out > -100000, np.nan)


def _region_for(county_fips: str) -> str:
    if county_fips in DELTA_COUNTIES:    return "Delta"
    if county_fips in GULF_COUNTIES:     return "Gulf Coast"
    if county_fips in JACKSON_METRO:     return "Jackson Metro"
    if county_fips in PINE_BELT:         return "Pine Belt"
    return "Other"


def _truncate(table: str) -> None:
    with get_engine().begin() as conn:
        conn.execute(text(f"TRUNCATE TABLE {table} CASCADE"))


def _reset_all() -> None:
    """Truncate every dim and fact (preserves dim_year seed)."""
    tables = [
        "fact_places", "fact_svi", "fact_svi_wide", "fact_acs", "fact_imr",
        "fact_hospital_quality", "fact_hpsa_county",
        "dim_facility", "dim_measure", "dim_geography",
    ]
    with get_engine().begin() as conn:
        for t in tables:
            conn.execute(text(f"TRUNCATE TABLE {t} RESTART IDENTITY CASCADE"))
    log.info("  reset all dim/fact tables")


# -------- TIGER (PostGIS) --------
def load_tiger() -> None:
    """Load tract + county shapefiles into PostGIS staging tables."""
    try:
        import geopandas as gpd
    except ImportError:
        log.error("geopandas not installed, skipping TIGER load")
        return

    engine = get_engine()
    base = RAW_DIR / "tiger"

    for layer, table in [("tract", "stg_tiger_tract"), ("county", "stg_tiger_county")]:
        shp = next((base / layer).glob("*.shp"), None) if (base / layer).exists() else None
        if not shp:
            log.warning(f"TIGER {layer} shapefile not found")
            continue
        gdf = gpd.read_file(shp)
        gdf.columns = [c.lower() for c in gdf.columns]
        if layer == "county" and "statefp" in gdf.columns:
            gdf = gdf[gdf["statefp"] == MS_STATE_FIPS]
        if gdf.crs and gdf.crs.to_epsg() != 4269:
            gdf = gdf.to_crs(epsg=4269)
        cols = ["statefp", "countyfp", "tractce", "geoid", "name", "namelsad",
                "aland", "awater", "intptlat", "intptlon", "geometry"]
        if layer == "county":
            cols = [c for c in cols if c != "tractce"]
        gdf = gdf[[c for c in cols if c in gdf.columns]]
        gdf = gdf.rename(columns={"geometry": "geom"}).set_geometry("geom")
        with engine.begin() as conn:
            conn.execute(text(f"TRUNCATE TABLE {table}"))
        gdf.to_postgis(table, engine, if_exists="append")
        log.info(f"  loaded {len(gdf):,} -> {table}")


# -------- dim_geography (needs PostGIS for centroids) --------
def load_dim_geography_and_svi() -> None:
    """Build dim_geography from TIGER tracts + load SVI both long and wide.

    Done together because we need SVI cleaned to attach pct_minority etc. to
    dim_geography rows, and we need dim_geography surrogate keys to load fact_svi.
    """
    engine = get_engine()

    svi_path = RAW_DIR / "svi" / "svi_2022_ms_tract.csv"
    if not svi_path.exists():
        raise FileNotFoundError(f"SVI tract CSV missing: {svi_path}")
    svi = pd.read_csv(svi_path, dtype=str, low_memory=False)
    svi = _normalize_columns(svi)
    svi = svi[svi["st_abbr"] == MS_STATE_ABBR].copy()

    svi_cols = {
        "tract_fips":           svi["fips"].astype(str),
        "county_fips":          svi["stcnty"].astype(str),
        "county_name":          svi["county"],
        "rpl_themes":           _svi_to_numeric(svi["rpl_themes"]),
        "rpl_theme1":           _svi_to_numeric(svi["rpl_theme1"]),
        "rpl_theme2":           _svi_to_numeric(svi["rpl_theme2"]),
        "rpl_theme3":           _svi_to_numeric(svi["rpl_theme3"]),
        "rpl_theme4":           _svi_to_numeric(svi["rpl_theme4"]),
        "f_total":              _svi_to_numeric(svi["f_total"]),
        "ep_pov150":            _svi_to_numeric(svi["ep_pov150"]),
        "ep_unemp":             _svi_to_numeric(svi["ep_unemp"]),
        "ep_uninsur":           _svi_to_numeric(svi["ep_uninsur"]),
        "ep_nohsdp":            _svi_to_numeric(svi["ep_nohsdp"]),
        "ep_minrty":            _svi_to_numeric(svi["ep_minrty"]),
        "ep_noveh":             _svi_to_numeric(svi["ep_noveh"]),
        "ep_noint":             _svi_to_numeric(svi.get("ep_noint", pd.Series([np.nan]*len(svi)))),
        "ep_disabl":            _svi_to_numeric(svi["ep_disabl"]),
        "ep_sngpnt":            _svi_to_numeric(svi["ep_sngpnt"]),
        "ep_mobile":            _svi_to_numeric(svi["ep_mobile"]),
        "total_population":     _svi_to_numeric(svi["e_totpop"]),
    }
    svi_clean = pd.DataFrame(svi_cols)
    log.info(f"  cleaned {len(svi_clean)} SVI tract rows")

    # Build dim_geography via SQL (needs PostGIS centroid)
    log.info("  building dim_geography from TIGER + SVI")
    with engine.begin() as conn:
        conn.execute(text("TRUNCATE TABLE dim_geography RESTART IDENTITY CASCADE"))
    # Stage SVI population separately so the SQL insert can join it
    svi_pop = svi_clean[["tract_fips", "total_population"]]
    svi_pop.to_sql("tmp_svi_pop", engine, if_exists="replace", index=False)

    with engine.begin() as conn:
        conn.execute(text("""
            INSERT INTO dim_geography (
                tract_fips, county_fips, county_name, state_fips, state_abbr,
                region, is_delta, is_gulf_coast,
                total_population, centroid_lat, centroid_lon, geom, centroid_geom
            )
            WITH counties AS (
                SELECT geoid AS county_fips, name AS county_name
                FROM stg_tiger_county WHERE statefp = '28'
            )
            SELECT
                t.geoid,
                t.statefp || t.countyfp,
                c.county_name,
                t.statefp,
                'MS',
                CASE
                    WHEN (t.statefp || t.countyfp) IN ('28011','28015','28027','28033','28051',
                                                       '28053','28055','28083','28107','28119',
                                                       '28125','28133','28135','28137','28143',
                                                       '28149','28151','28163') THEN 'Delta'
                    WHEN (t.statefp || t.countyfp) IN ('28045','28047','28059') THEN 'Gulf Coast'
                    WHEN (t.statefp || t.countyfp) IN ('28049','28089','28121') THEN 'Jackson Metro'
                    WHEN (t.statefp || t.countyfp) IN ('28035','28073','28067','28111','28031') THEN 'Pine Belt'
                    ELSE 'Other'
                END,
                (t.statefp || t.countyfp) IN ('28011','28015','28027','28033','28051',
                                              '28053','28055','28083','28107','28119',
                                              '28125','28133','28135','28137','28143',
                                              '28149','28151','28163'),
                (t.statefp || t.countyfp) IN ('28045','28047','28059'),
                sv.total_population::INT,
                NULLIF(t.intptlat, '')::NUMERIC,
                NULLIF(t.intptlon, '')::NUMERIC,
                t.geom,
                ST_Centroid(t.geom)
            FROM stg_tiger_tract t
            LEFT JOIN counties c ON c.county_fips = (t.statefp || t.countyfp)
            LEFT JOIN tmp_svi_pop sv ON sv.tract_fips = t.geoid
            WHERE t.statefp = '28';
        """))
        conn.execute(text("DROP TABLE IF EXISTS tmp_svi_pop"))
        conn.execute(text("ANALYZE dim_geography"))
    log.info("  dim_geography built")

    # Load dim_measure for SVI variables
    svi_measures = pd.DataFrame([
        ("SVI", "RPL_THEMES", "SVI Overall Vulnerability Percentile",  "Overall SVI",  "Theme Summary", "percentile", True),
        ("SVI", "RPL_THEME1", "SVI Theme 1: Socioeconomic",             "SES SVI",       "Theme 1",       "percentile", True),
        ("SVI", "RPL_THEME2", "SVI Theme 2: Household",                 "Household SVI", "Theme 2",       "percentile", True),
        ("SVI", "RPL_THEME3", "SVI Theme 3: Minority",                  "Minority SVI",  "Theme 3",       "percentile", True),
        ("SVI", "RPL_THEME4", "SVI Theme 4: Housing/Transport",         "Housing SVI",   "Theme 4",       "percentile", True),
        ("SVI", "EP_POV150",  "Below 150% poverty (%)",                 "Pov<150%",      "Theme 1",       "percent",    True),
        ("SVI", "EP_UNEMP",   "Unemployed (%)",                         "Unemployed",    "Theme 1",       "percent",    True),
        ("SVI", "EP_NOHSDP",  "No HS diploma 25+ (%)",                  "No HS diploma", "Theme 1",       "percent",    True),
        ("SVI", "EP_UNINSUR", "Uninsured (%)",                          "Uninsured",     "Theme 1",       "percent",    True),
        ("SVI", "EP_DISABL",  "Disabled (%)",                           "Disabled",      "Theme 2",       "percent",    True),
        ("SVI", "EP_SNGPNT",  "Single-parent households (%)",           "Single parent", "Theme 2",       "percent",    True),
        ("SVI", "EP_MINRTY",  "Racial/ethnic minority (%)",             "Minority",      "Theme 3",       "percent",    None),
        ("SVI", "EP_NOVEH",   "Households with no vehicle (%)",         "No vehicle",    "Theme 4",       "percent",    True),
        ("SVI", "EP_MOBILE",  "Mobile homes (%)",                       "Mobile home",   "Theme 4",       "percent",    True),
        ("SVI", "EP_NOINT",   "No internet subscription (%)",           "No internet",   "Theme 4",       "percent",    True),
    ], columns=["source", "measure_id", "measure_name", "short_name", "category", "unit", "higher_is_worse"])

    # Append SVI measures (PLACES + ACS get added by other loaders)
    svi_measures.to_sql("dim_measure", engine, if_exists="append", index=False, method="multi")

    # Build fact_svi_wide
    geo = pd.read_sql("SELECT geo_sk, tract_fips FROM dim_geography", engine)
    svi_wide = svi_clean.merge(geo, on="tract_fips", how="inner").drop(columns=["tract_fips", "county_fips", "county_name", "total_population"])
    svi_wide["year_sk"] = 2022
    _truncate("fact_svi_wide")
    svi_wide.to_sql("fact_svi_wide", engine, if_exists="append", index=False, method="multi", chunksize=200)
    log.info(f"  loaded {len(svi_wide):,} -> fact_svi_wide")

    # Build fact_svi (long): one row per (tract, svi_var)
    measure_lookup = pd.read_sql(
        "SELECT measure_sk, measure_id FROM dim_measure WHERE source = 'SVI'", engine)
    measure_map = dict(zip(measure_lookup["measure_id"], measure_lookup["measure_sk"]))

    long_rows = []
    for _, row in svi_clean.merge(geo, on="tract_fips", how="inner").iterrows():
        for col, mid in [
            ("rpl_themes","RPL_THEMES"),("rpl_theme1","RPL_THEME1"),("rpl_theme2","RPL_THEME2"),
            ("rpl_theme3","RPL_THEME3"),("rpl_theme4","RPL_THEME4"),
            ("ep_pov150","EP_POV150"),("ep_unemp","EP_UNEMP"),("ep_nohsdp","EP_NOHSDP"),
            ("ep_uninsur","EP_UNINSUR"),("ep_disabl","EP_DISABL"),("ep_sngpnt","EP_SNGPNT"),
            ("ep_minrty","EP_MINRTY"),("ep_noveh","EP_NOVEH"),("ep_mobile","EP_MOBILE"),
            ("ep_noint","EP_NOINT"),
        ]:
            val = row[col]
            if pd.notna(val) and mid in measure_map:
                long_rows.append((row["geo_sk"], measure_map[mid], 2022, float(val)))
    fact_svi = pd.DataFrame(long_rows, columns=["geo_sk", "measure_sk", "year_sk", "data_value"])
    _truncate("fact_svi")
    fact_svi.to_sql("fact_svi", engine, if_exists="append", index=False, method="multi", chunksize=1000)
    log.info(f"  loaded {len(fact_svi):,} -> fact_svi")


# -------- PLACES --------
def load_places() -> None:
    """Clean + load CDC PLACES for all years."""
    files = sorted(Path(RAW_DIR / "places").glob("places_tract_*.csv"))
    if not files:
        log.warning("No PLACES files")
        return

    engine = get_engine()
    frames = []
    for path in files:
        df = pd.read_csv(path, dtype=str, low_memory=False)
        df = _normalize_columns(df)
        df = df[df["stateabbr"] == MS_STATE_ABBR].copy()
        df = df[df["data_value"].notna() & (df["data_value"] != "")]
        frames.append(df)
    raw = pd.concat(frames, ignore_index=True, sort=False)
    log.info(f"  PLACES rows after MS filter: {len(raw):,}")

    clean = pd.DataFrame({
        "tract_fips":       raw["locationid"].astype(str),
        "year":             pd.to_numeric(raw["year"], errors="coerce").astype("Int64"),
        "measure_id":       raw["measureid"],
        "measure_name":     raw["measure"],
        "short_name":       raw["short_question_text"],
        "category":         raw["category"],
        "data_value":       _safe_numeric(raw["data_value"]),
        "low_ci":           _safe_numeric(raw["low_confidence_limit"]),
        "high_ci":          _safe_numeric(raw["high_confidence_limit"]),
        "total_population": _safe_numeric(raw["totalpopulation"]).astype("Int64"),
    })
    clean = clean.dropna(subset=["data_value", "tract_fips", "measure_id", "year"])

    # Load dim_measure for PLACES (dedup on measure_id)
    measures = (clean[["measure_id", "measure_name", "short_name", "category"]]
                .drop_duplicates(subset=["measure_id"]))
    measures["source"] = "PLACES"
    measures["unit"] = "percent"
    measures["higher_is_worse"] = measures["category"].apply(lambda c: False if c == "Prevention" else True)
    measures = measures[["source","measure_id","measure_name","short_name","category","unit","higher_is_worse"]]
    measures.to_sql("dim_measure", engine, if_exists="append", index=False, method="multi")
    log.info(f"  upserted {len(measures)} PLACES measures into dim_measure")

    # Build fact_places by joining to geo_sk + measure_sk
    geo = pd.read_sql("SELECT geo_sk, tract_fips FROM dim_geography", engine)
    msr = pd.read_sql("SELECT measure_sk, measure_id FROM dim_measure WHERE source='PLACES'", engine)

    fact = (clean
            .merge(geo, on="tract_fips", how="inner")
            .merge(msr, on="measure_id", how="inner"))
    fact = fact.rename(columns={"year": "year_sk"})
    # Dedupe on PK (occasional duplicate rows in PLACES feed)
    fact = fact.drop_duplicates(subset=["geo_sk", "measure_sk", "year_sk"])
    fact = fact[["geo_sk", "measure_sk", "year_sk", "data_value", "low_ci", "high_ci", "total_population"]]

    _truncate("fact_places")
    fact.to_sql("fact_places", engine, if_exists="append", index=False, method="multi", chunksize=1000)
    log.info(f"  loaded {len(fact):,} -> fact_places")


# -------- ACS --------
def load_acs() -> None:
    """Clean + load ACS long format."""
    path = RAW_DIR / "acs" / "acs5_2023_ms_tract_long.csv"
    if not path.exists():
        log.warning("No ACS file")
        return

    engine = get_engine()
    raw = pd.read_csv(path, dtype=str, low_memory=False)
    raw = _normalize_columns(raw)
    clean = pd.DataFrame({
        "tract_fips":  raw["geoid"].astype(str),
        "table_id":    raw["table_id"],
        "variable":    raw["variable"],
        "label":       raw["label"],
        "estimate":    _acs_to_numeric(raw["estimate"]),
        "moe":         _acs_to_numeric(raw["moe"]),
    })
    clean = clean.dropna(subset=["estimate"])
    log.info(f"  ACS rows after cleaning: {len(clean):,}")

    # Insert any ACS variables we use into dim_measure (idempotent on conflict)
    headline_acs = pd.DataFrame([
        ("ACS", "B19013_001E",    "Median Household Income",          "Median income", "Income",     "dollars", False),
        ("ACS", "S2701_C04_001E", "Uninsured rate (%)",               "Uninsured",     "Insurance",  "percent", True),
        ("ACS", "S1701_C03_001E", "Below poverty (%)",                "Below poverty", "Poverty",    "percent", True),
        ("ACS", "B02001_002E",    "White alone population",           "White pop",     "Race",       "count",   None),
        ("ACS", "B02001_003E",    "Black/African American population","Black pop",     "Race",       "count",   None),
        ("ACS", "B03002_012E",    "Hispanic/Latino population",       "Hispanic pop",  "Ethnicity",  "count",   None),
        ("ACS", "B15003_022E",    "Bachelors degree (25+)",           "Bachelors",     "Education",  "count",   False),
        ("ACS", "B28002_013E",    "No internet subscription (count)", "No internet",   "Connectivity","count",  True),
    ], columns=["source","measure_id","measure_name","short_name","category","unit","higher_is_worse"])
    headline_acs.to_sql("dim_measure", engine, if_exists="append", index=False, method="multi")

    geo = pd.read_sql("SELECT geo_sk, tract_fips FROM dim_geography", engine)
    msr = pd.read_sql("SELECT measure_sk, measure_id FROM dim_measure WHERE source='ACS'", engine)

    fact = (clean.merge(geo, on="tract_fips", how="inner")
                  .merge(msr, left_on="variable", right_on="measure_id", how="inner"))
    fact["year_sk"] = 2023
    fact = fact[["geo_sk", "measure_sk", "year_sk", "estimate", "moe"]]
    fact = fact.drop_duplicates(subset=["geo_sk", "measure_sk", "year_sk"])

    _truncate("fact_acs")
    fact.to_sql("fact_acs", engine, if_exists="append", index=False, method="multi", chunksize=1000)
    log.info(f"  loaded {len(fact):,} -> fact_acs")

    # Persist the full long table for the headline pivot view in marts/notebooks
    full = clean.copy()
    full["county_fips"] = full["tract_fips"].str.slice(0, 5)
    full.to_sql("stg_acs_long", engine, if_exists="replace", index=False, method="multi", chunksize=2000)
    log.info(f"  staged {len(full):,} ACS long rows -> stg_acs_long")


# -------- ACS headline pivot (for fast joins to women_reproductive_age etc.) --------
def build_acs_headline() -> None:
    """Pivot ACS long into a one-row-per-tract headline view via SQL."""
    engine = get_engine()
    with engine.begin() as conn:
        conn.execute(text("DROP TABLE IF EXISTS acs_headline CASCADE"))
        conn.execute(text("""
            CREATE TABLE acs_headline AS
            SELECT
                tract_fips,
                county_fips,
                MAX(estimate) FILTER (WHERE variable = 'B01001_001E')    AS total_population,
                MAX(estimate) FILTER (WHERE variable = 'S2701_C04_001E') AS pct_uninsured,
                MAX(estimate) FILTER (WHERE variable = 'S1701_C03_001E') AS pct_below_poverty,
                MAX(estimate) FILTER (WHERE variable = 'B19013_001E')    AS median_household_income,
                MAX(estimate) FILTER (WHERE variable = 'B02001_002E')    AS pop_white_alone,
                MAX(estimate) FILTER (WHERE variable = 'B02001_003E')    AS pop_black_alone,
                MAX(estimate) FILTER (WHERE variable = 'B03002_012E')    AS pop_hispanic,
                COALESCE(MAX(estimate) FILTER (WHERE variable = 'B01001_030E'), 0) +
                COALESCE(MAX(estimate) FILTER (WHERE variable = 'B01001_031E'), 0) +
                COALESCE(MAX(estimate) FILTER (WHERE variable = 'B01001_032E'), 0) +
                COALESCE(MAX(estimate) FILTER (WHERE variable = 'B01001_033E'), 0) +
                COALESCE(MAX(estimate) FILTER (WHERE variable = 'B01001_034E'), 0) +
                COALESCE(MAX(estimate) FILTER (WHERE variable = 'B01001_035E'), 0) AS women_reproductive_age
            FROM stg_acs_long
            GROUP BY tract_fips, county_fips
        """))
        conn.execute(text("CREATE UNIQUE INDEX uidx_acs_headline ON acs_headline (tract_fips)"))
        conn.execute(text("ANALYZE acs_headline"))
    log.info("  built acs_headline pivot")


# -------- CMS hospitals --------
def load_cms() -> None:
    """Clean + load CMS hospital files into dim_facility + fact_hospital_quality."""
    engine = get_engine()
    cms = RAW_DIR / "cms"

    # ---- dim_facility from hospital_general ----
    hg = pd.read_csv(cms / "hospital_general.csv", dtype=str, low_memory=False)
    hg = _normalize_columns(hg)
    hg = hg[hg["state"] == MS_STATE_ABBR].copy()

    # Geocode to county centroid via TIGER (county polygons in PostGIS)
    counties = pd.read_sql("""
        SELECT UPPER(name) AS county_name_uc,
               statefp || countyfp AS county_fips,
               ST_Y(ST_Centroid(geom)) AS lat,
               ST_X(ST_Centroid(geom)) AS lon
        FROM stg_tiger_county WHERE statefp = '28'
    """, engine)

    hg["county_name_uc"] = hg["county_parish"].str.upper()
    hg = hg.merge(counties, on="county_name_uc", how="left")

    facility = pd.DataFrame({
        "ccn":                  hg["facility_id"].astype(str),
        "facility_name":        hg["facility_name"],
        "address":              hg["address"],
        "city":                 hg["city_town"],
        "state_abbr":           hg["state"],
        "zip_code":             hg["zip_code"].str.zfill(5),
        "county_name":          hg["county_parish"],
        "county_fips":          hg["county_fips"],
        "hospital_type":        hg["hospital_type"],
        "hospital_ownership":   hg["hospital_ownership"],
        "emergency_services":   hg["emergency_services"].str.lower() == "yes",
        "is_birthing_friendly": hg["meets_criteria_for_birthing_friendly_designation"].str.lower() == "y",
        "overall_rating":       pd.to_numeric(hg["hospital_overall_rating"].replace("Not Available", np.nan), errors="coerce").astype("Int64"),
        "lat":                  hg["lat"],
        "lon":                  hg["lon"],
    })
    _truncate("dim_facility")
    facility.to_sql("dim_facility", engine, if_exists="append", index=False, method="multi", chunksize=200)
    # Set the point geometry from lat/lon via SQL
    with engine.begin() as conn:
        conn.execute(text("""
            UPDATE dim_facility
               SET geom = ST_SetSRID(ST_MakePoint(lon, lat), 4269)
             WHERE lat IS NOT NULL AND lon IS NOT NULL
        """))
        conn.execute(text("ANALYZE dim_facility"))
    log.info(f"  loaded {len(facility):,} -> dim_facility")

    # ---- fact_hospital_quality from HRRP + Timely Care ----
    _truncate("fact_hospital_quality")
    fac_lookup = pd.read_sql("SELECT facility_sk, ccn FROM dim_facility", engine)

    # HRRP
    hrrp_path = cms / "hrrp_fy2026.csv"
    if hrrp_path.exists():
        hrrp = pd.read_csv(hrrp_path, dtype=str, low_memory=False)
        hrrp = _normalize_columns(hrrp)
        hrrp = hrrp[hrrp["state"] == MS_STATE_ABBR].copy()
        hrrp_clean = pd.DataFrame({
            "ccn":          hrrp["facility_id"].astype(str),
            "measure_id":   hrrp["measure_name"],
            "measure_name": hrrp["measure_name"],
            "measure_type": "HRRP",
            "score":        _safe_numeric(hrrp["excess_readmission_ratio"]),
            "discharges":   _safe_numeric(hrrp["number_of_discharges"]).astype("Int64"),
            "period_start": pd.to_datetime(hrrp["start_date"], errors="coerce").dt.date,
            "period_end":   pd.to_datetime(hrrp["end_date"], errors="coerce").dt.date,
        }).dropna(subset=["score"])
        hrrp_fact = hrrp_clean.merge(fac_lookup, on="ccn", how="inner").drop(columns=["ccn"])
        hrrp_fact = hrrp_fact.drop_duplicates(subset=["facility_sk", "measure_id", "measure_type"])
        hrrp_fact.to_sql("fact_hospital_quality", engine, if_exists="append", index=False, method="multi", chunksize=500)
        log.info(f"  loaded {len(hrrp_fact):,} HRRP -> fact_hospital_quality")

    # Timely Care (maternity-relevant subset)
    tc_path = cms / "timely_care.csv"
    if tc_path.exists():
        tc = pd.read_csv(tc_path, dtype=str, low_memory=False)
        tc = _normalize_columns(tc)
        tc = tc[tc["state"] == MS_STATE_ABBR].copy()
        tc_clean = pd.DataFrame({
            "ccn":          tc["facility_id"].astype(str),
            "measure_id":   tc["measure_id"],
            "measure_name": tc["measure_name"],
            "measure_type": "Timely Care",
            "score":        _safe_numeric(tc["score"]),
            "discharges":   _safe_numeric(tc.get("sample", pd.Series([np.nan]*len(tc)))).astype("Int64"),
            "period_start": pd.to_datetime(tc["start_date"], errors="coerce").dt.date,
            "period_end":   pd.to_datetime(tc["end_date"], errors="coerce").dt.date,
        }).dropna(subset=["score"])
        tc_fact = tc_clean.merge(fac_lookup, on="ccn", how="inner").drop(columns=["ccn"])
        tc_fact = tc_fact.drop_duplicates(subset=["facility_sk", "measure_id", "measure_type"])
        tc_fact.to_sql("fact_hospital_quality", engine, if_exists="append", index=False, method="multi", chunksize=500)
        log.info(f"  loaded {len(tc_fact):,} Timely Care -> fact_hospital_quality")


# -------- HRSA HPSA --------
def load_hrsa() -> None:
    """Clean + aggregate HPSA designations to county-level fact_hpsa_county."""
    engine = get_engine()
    base = RAW_DIR / "hrsa"
    files = [base / f for f in ["hpsa_primary_care.csv", "hpsa_dental.csv", "hpsa_mental_health.csv"] if (base / f).exists()]
    if not files:
        log.warning("No HRSA files")
        return

    frames = []
    for path in files:
        df = pd.read_csv(path, dtype=str, low_memory=False)
        df = _normalize_columns(df)
        state_col = next((c for c in ["primary_state_abbreviation", "state_abbreviation", "state"] if c in df.columns), None)
        if state_col:
            df = df[df[state_col].str.upper() == MS_STATE_ABBR]
        frames.append(df)
    raw = pd.concat(frames, ignore_index=True, sort=False)
    raw = raw[raw["hpsa_status"].isin(["Designated", "Proposed for Withdrawal"])]

    raw["county_fips"] = raw.get("common_state_county_fips_code", pd.Series(["" ]*len(raw))).fillna("").astype(str).str.zfill(5)
    raw["hpsa_score"] = _safe_numeric(raw["hpsa_score"])
    raw["discipline_class"] = raw.get("hpsa_discipline_class", raw.get("discipline_class"))
    raw = raw[raw["county_fips"].str.len() == 5]

    agg = raw.groupby(["county_fips", "discipline_class"], dropna=False).agg(
        avg_hpsa_score=("hpsa_score", "mean"),
        max_hpsa_score=("hpsa_score", "max"),
        n_hpsa_designations=("hpsa_score", "count"),
    ).reset_index().rename(columns={"discipline_class": "discipline"})
    agg["underserved_population"] = pd.Series([pd.NA] * len(agg), dtype="Int64")
    agg = agg.dropna(subset=["county_fips", "discipline"])

    _truncate("fact_hpsa_county")
    agg.to_sql("fact_hpsa_county", engine, if_exists="append", index=False, method="multi")
    log.info(f"  loaded {len(agg):,} -> fact_hpsa_county")

    # Also keep a county-level svi table for HRRP regressivity + top20 mart
    svi_county_path = RAW_DIR / "svi" / "svi_2022_ms_county.csv"
    if svi_county_path.exists():
        svc = pd.read_csv(svi_county_path, dtype=str, low_memory=False)
        svc = _normalize_columns(svc)
        svc = svc[svc["st_abbr"] == MS_STATE_ABBR]
        svi_county = pd.DataFrame({
            "county_fips": svc["fips"].astype(str),
            "county_name": svc["county"],
            "rpl_themes":  _svi_to_numeric(svc["rpl_themes"]),
            "pct_uninsured": _svi_to_numeric(svc["ep_uninsur"]),
        })
        svi_county.to_sql("svi_county", engine, if_exists="replace", index=False, method="multi")
        with engine.begin() as conn:
            conn.execute(text("CREATE INDEX IF NOT EXISTS idx_svi_county_fips ON svi_county (county_fips)"))
        log.info(f"  loaded {len(svi_county):,} -> svi_county")


# -------- MSDH IMR --------
def load_msdh_imr() -> None:
    """Load Mississippi infant mortality into fact_imr (county-year) and
    ship the race-specific rows separately as stg_msdh_imr_race for the
    Black:white disparity ratio query."""
    path = RAW_DIR / "msdh" / "msdh_imr.csv"
    if not path.exists():
        log.warning("No MSDH IMR file")
        return

    engine = get_engine()
    df = pd.read_csv(path, dtype=str, low_memory=False)
    df = _normalize_columns(df)

    race_mask = df["county_name"].str.contains(
        r"\bBlack\b|\bWhite\b|\bHispanic\b", case=False, regex=True, na=False
    )

    # Race-specific rows for Q15 disparity ratio
    race_df = df[race_mask].copy()
    if not race_df.empty:
        race_df["county_fips"] = race_df["county_fips"].astype(str).str.zfill(5)
        race_df["year"] = pd.to_numeric(race_df["year"], errors="coerce").astype("Int64")
        race_df["live_births"] = _safe_numeric(race_df["live_births"]).astype("Int64")
        race_df["infant_deaths"] = _safe_numeric(race_df["infant_deaths"]).astype("Int64")
        race_df["imr_per_1000"] = _safe_numeric(race_df["imr_per_1000"])
        race_out = race_df[["county_name", "county_fips", "year", "live_births",
                            "infant_deaths", "imr_per_1000", "notes"]]
        race_out.to_sql("stg_msdh_imr_race", engine, if_exists="replace",
                        index=False, method="multi")
        log.info(f"  loaded {len(race_out):,} -> stg_msdh_imr_race")

    # County rows for fact_imr (deduped on natural key)
    main = df[~race_mask].copy()
    main["county_fips"] = main["county_fips"].astype(str).str.zfill(5)
    main["year_sk"] = pd.to_numeric(main["year"], errors="coerce").astype("Int64")
    main["live_births"] = _safe_numeric(main["live_births"]).astype("Int64")
    main["infant_deaths"] = _safe_numeric(main["infant_deaths"]).astype("Int64")
    main["imr_per_1000"] = _safe_numeric(main["imr_per_1000"])
    main["neonatal_deaths"] = _safe_numeric(main["neonatal_deaths"]).astype("Int64")
    main["postneonatal_deaths"] = _safe_numeric(main["postneonatal_deaths"]).astype("Int64")
    main = main.dropna(subset=["year_sk"])

    main = (main.sort_values("live_births", ascending=False, na_position="last")
                .drop_duplicates(subset=["county_fips", "year_sk"], keep="first"))

    out = main[["county_fips", "year_sk", "live_births", "infant_deaths",
                "imr_per_1000", "neonatal_deaths", "postneonatal_deaths"]]

    _truncate("fact_imr")
    out.to_sql("fact_imr", engine, if_exists="append", index=False, method="multi", chunksize=500)
    log.info(f"  loaded {len(out):,} -> fact_imr")


def main() -> None:
    log.info("=== ETL pipeline: cleaning in pandas, loading to public schema ===")
    _reset_all()
    load_tiger()
    load_dim_geography_and_svi()
    load_places()
    load_acs()
    build_acs_headline()
    load_cms()
    load_hrsa()
    load_msdh_imr()
    log.info("=== ETL complete ===")


if __name__ == "__main__":
    main()
