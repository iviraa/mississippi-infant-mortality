"""Centralized config: paths, DB connection, source URLs."""
from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

# Paths
PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "data"
RAW_DIR = DATA_DIR / "raw"
PROCESSED_DIR = DATA_DIR / "processed"
FIGURES_DIR = PROJECT_ROOT / "figures"

for d in (RAW_DIR, PROCESSED_DIR, FIGURES_DIR / "static", FIGURES_DIR / "interactive"):
    d.mkdir(parents=True, exist_ok=True)

# Mississippi constants
MS_STATE_FIPS = "28"
MS_STATE_ABBR = "MS"

# 18 counties of the Mississippi Delta National Heritage Area
MS_DELTA_COUNTIES = {
    "28011": "Bolivar", "28015": "Carroll", "28027": "Coahoma",
    "28033": "DeSoto", "28051": "Holmes", "28053": "Humphreys",
    "28055": "Issaquena", "28083": "Leflore", "28107": "Panola",
    "28119": "Quitman", "28125": "Sharkey", "28133": "Sunflower",
    "28135": "Tallahatchie", "28137": "Tate", "28143": "Tunica",
    "28149": "Warren", "28151": "Washington", "28163": "Yazoo",
}
MS_GULF_COUNTIES = {"28045": "Hancock", "28047": "Harrison", "28059": "Jackson"}

# Database
PGHOST = os.getenv("PGHOST", "localhost")
PGPORT = int(os.getenv("PGPORT", "5432"))
PGDATABASE = os.getenv("PGDATABASE", "ms_health")
PGUSER = os.getenv("PGUSER", "postgres")
PGPASSWORD = os.getenv("PGPASSWORD", "postgres")
DB_URL = f"postgresql+psycopg://{PGUSER}:{PGPASSWORD}@{PGHOST}:{PGPORT}/{PGDATABASE}"

# Census API
CENSUS_API_KEY = os.getenv("CENSUS_API_KEY", "")

# CDC PLACES Socrata SODA API. Tract-grain releases by year; older years
# may have been retired by CDC, in which case the extractor skips on 404.
PLACES_TRACT_DATASETS = {
    2025: "cwsq-ngmh",
    2024: "4ai3-zynv",
    2023: "nw2y-v4gm",
    2022: "em5e-5hvn",
    2021: "jpdw-4rwm",
}
PLACES_API_BASE = "https://data.cdc.gov/resource"

# CDC SVI 2022 direct CSV download.
SVI_TRACT_URL = "https://svi.cdc.gov/Documents/Data/2022/csv/states/Mississippi.csv"
SVI_COUNTY_URL = "https://svi.cdc.gov/Documents/Data/2022/csv/states_counties/Mississippi_COUNTY.csv"

# Census ACS API
ACS_BASE = "https://api.census.gov/data/2023/acs/acs5"
ACS_SUBJECT_BASE = "https://api.census.gov/data/2023/acs/acs5/subject"

ACS_DETAIL_TABLES = [
    "B27001",  # Health insurance by sex by age
    "B17001",  # Poverty by sex by age
    "B19013",  # Median household income
    "B02001",  # Race
    "B03002",  # Hispanic origin by race
    "B15003",  # Educational attainment 25+
    "B25070",  # Gross rent as % of income
    "B28002",  # Internet subscriptions
    "B01001",  # Sex by age (for women of reproductive age)
]
ACS_SUBJECT_TABLES = [
    "S2701",  # Health insurance coverage characteristics
    "S1701",  # Poverty status
]

# CMS Provider Data Catalog. Resource hashes change quarterly; if a static URL
# 404s the extractor falls back to the metastore API.
CMS_HOSPITAL_GENERAL_URL = (
    "https://data.cms.gov/provider-data/sites/default/files/resources/"
    "893c372430d9d71a1c52737d01239d47_1777413958/Hospital_General_Information.csv"
)
CMS_HCAHPS_URL = (
    "https://data.cms.gov/provider-data/sites/default/files/resources/"
    "78a50346fbe828ea0ce2837847af6a7c_1777413952/HCAHPS-Hospital.csv"
)
CMS_HRRP_URL = (
    "https://data.cms.gov/provider-data/sites/default/files/resources/"
    "a171bc36c488d3e0dc33ec63abb469a6_1770163617/"
    "FY_2026_Hospital_Readmissions_Reduction_Program_Hospital.csv"
)
CMS_COMPLICATIONS_URL = (
    "https://data.cms.gov/provider-data/sites/default/files/resources/"
    "6af7c44d77436e5a1caac3ce39a83fe9_1777413950/Complications_and_Deaths-Hospital.csv"
)
CMS_TIMELY_CARE_URL = (
    "https://data.cms.gov/provider-data/sites/default/files/resources/"
    "0437b5494ac61507ad90f2af6b8085a7_1777413965/Timely_and_Effective_Care-Hospital.csv"
)
CMS_DATASETS = {
    "hospital_general": "xubh-q36u",
    "hcahps": "dgck-syfz",
    "hrrp": "9n3s-kdb3",
    "complications": "ynj2-r877",
    "timely_care": "yv7e-xc69",
}

# HRSA HPSA datasets: primary care, dental, mental health.
HRSA_HPSA_PRIMARY_URL = "https://data.hrsa.gov/DataDownload/DD_Files/BCD_HPSA_FCT_DET_PC.csv"
HRSA_HPSA_DENTAL_URL = "https://data.hrsa.gov/DataDownload/DD_Files/BCD_HPSA_FCT_DET_DH.csv"
HRSA_HPSA_MENTAL_URL = "https://data.hrsa.gov/DataDownload/DD_Files/BCD_HPSA_FCT_DET_MH.csv"

# TIGER/Line shapefiles (2023)
TIGER_BASE = "https://www2.census.gov/geo/tiger/TIGER2023"
TIGER_FILES = {
    "tract": f"{TIGER_BASE}/TRACT/tl_2023_28_tract.zip",
    "county": f"{TIGER_BASE}/COUNTY/tl_2023_us_county.zip",
    "place": f"{TIGER_BASE}/PLACE/tl_2023_28_place.zip",
}
