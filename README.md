# Mississippi Maternal and Infant Mortality Analysis

A reproducible data engineering pipeline that ingests seven public health datasets, models them in a PostgreSQL star schema with PostGIS, and quantifies the structural drivers of Mississippi's August 2025 Public Health Emergency on infant mortality at census tract granularity.

## Why this matters

On August 21, 2025, the Mississippi State Department of Health declared a Public Health Emergency on infant mortality. The state's infant mortality rate reached 9.7 deaths per 1,000 live births in 2024, the highest in the United States, up from 8.9 the year prior. Within that state level rate, the disparity is severe: the infant mortality rate in Mississippi's Black population is 15.2 per 1,000 live births, 2.6 times the rate of 5.8 in the White population.

The analysis was built around three questions. First, where in Mississippi are mothers and infants most at risk, at census tract granularity? Second, how much of the racial disparity can be explained by structural factors such as social vulnerability, insurance coverage, and distance to obstetric care? Third, which counties should the state health department prioritize for intervention, and with what kind of intervention?

## Datasets

Seven datasets are ingested and joined on standard Federal Information Processing Standards (FIPS) and GEOID identifiers.

| Source | Granularity | What we use it for |
|---|---|---|
| CDC PLACES, 2022 through 2025 release years | Census tract | About 40 modeled health measures, including diabetes, hypertension, obesity, smoking, depression, and uninsured rate |
| CDC and ATSDR Social Vulnerability Index 2022 | Census tract and county | 16 vulnerability variables organized into 4 themes plus an overall percentile rank |
| US Census American Community Survey 5 year, 2023 vintage | Census tract | Insurance, poverty, race, education, housing, and internet access |
| CMS Provider Data Catalog | Hospital | General information, HCAHPS satisfaction scores, HRRP readmission penalties, and Timely Care measures |
| HRSA Health Professional Shortage Areas | County | Primary care, dental, and mental health shortage area scores |
| TIGER/Line shapefiles, 2023 vintage | Census tract and county | Polygons and centroids for spatial joins and drive distance computations |
| Mississippi State Department of Health 2025 Infant Mortality Report | County and race | State by year and race specific infant mortality rates, plus county level 5 year aggregate rates |

## Architecture

```
Sources  ->  Extract (Python httpx)  ->  CSV files in data/raw/
                                                |
                                                v
                       pandas ETL (clean and type)  ->  public.dim_* and public.fact_*
                                                                |
                                                                v
                                                       SQL marts (PostGIS, CTEs, window functions)
                                                                |
                                                                v
                                              Jupyter notebooks, Folium maps, matplotlib charts
```

The entire database lives in a single Postgres schema called `public` and follows a Kimball star schema. Four dimension tables hold the descriptive context: `dim_geography` carries one row per Mississippi census tract along with its county, region, total population, and PostGIS polygon; `dim_measure` is the dictionary of every health, vulnerability, and demographic measure across all sources; `dim_facility` holds one row per CMS certified hospital with its birthing friendly designation and point geometry; and `dim_year` is a small lookup that makes time joins clean.

Seven fact tables hold the measurements themselves. `fact_places` records one health value per tract per year from the CDC PLACES feed. `fact_svi` and its wide companion `fact_svi_wide` store the Social Vulnerability Index in long and wide form respectively. `fact_acs` holds Census American Community Survey values. `fact_imr` holds Mississippi infant mortality by county and year. `fact_hospital_quality` holds CMS Hospital Readmissions Reduction Program scores and Timely Care measures. `fact_hpsa_county` holds aggregated Health Professional Shortage Area scores per county.

Five analytical marts sit on top of the star schema and pre compute the headline answers: `mart_maternal_risk_index` (tract level composite score), `mart_drive_time` (PostGIS nearest birthing hospital), `mart_double_burden` (tracts flagged on multiple axes), `mart_top20_priority` (county level priority ranking), and `mart_hrrp_regressivity` (HRRP penalty by SVI quintile).

## Quickstart

Prerequisites are Python 3.10 or newer, PostgreSQL 14 or newer with PostGIS 3.x, and a free [Census Bureau API key](https://api.census.gov/data/key_signup.html).

```bash
cp .env.example .env       # edit with your Postgres credentials and Census key
make install               # creates .venv and installs requirements.txt
make db                    # creates ms_health database and enables PostGIS
make schema                # runs DDL scripts
make extract               # downloads source data into data/raw/
make load                  # pandas ETL: cleans CSVs and loads typed tables
make marts                 # builds analytical marts in SQL
make figures               # renders interactive and static visualizations
```

Or simply `make all`.

## Repository layout

```
.
├── README.md                    This file
├── requirements.txt             Python dependencies
├── Makefile                     Pipeline orchestration
├── .env.example                 Configuration template
│
├── pipeline/                    Python ETL (extract, clean, load in pandas)
├── sql/
│   ├── ddl/                     dim and fact table definitions plus PostGIS
│   ├── marts/                   Analytical marts (CTEs, window functions, PostGIS)
│   └── analysis/                Standalone SQL showcase (Q01 through Q17)
├── notebooks/                   Seven notebooks with inline SQL, each readable top to bottom
├── figures/                     Rendered Folium maps and matplotlib charts
├── data/seed/                   Curated reference data (MSDH IMR)
├── data/processed/              Final mart CSVs (raw downloads are gitignored)
└── docs/                        Schema diagram, data dictionary, methodology, findings
```

## Executive summary

Across the Mississippi Delta, 51.2 percent of women aged 15 to 44 live more than 30 minutes from a birthing friendly hospital, an order of magnitude worse than any other Mississippi region. Fifty four of the state's 82 counties have zero CMS designated birthing friendly hospitals, and roughly 111,500 women of reproductive age live in those counties. Infant mortality in Mississippi's Black communities runs 2.6 times the rate in the White population, with a 95 percent confidence interval of 2.06 to 3.33 computed in pure SQL via the Katz log rate ratio formula. Eleven of the top twenty highest priority counties for state intervention are in the Mississippi Delta.

## Key findings

**Maternity care deserts cluster in the Delta.** In the Mississippi Delta, 51.2 percent of women aged 15 to 44 live more than 30 minutes from a birthing friendly hospital. The figure drops to 9.2 percent in other rural counties, 0.5 percent in Jackson Metro, and 0 on the Gulf Coast. The Delta is, by an order of magnitude, the part of the state where geographic access to obstetric care has broken down.

**The chronic disease burden tracks the same geography.** Population weighted diabetes prevalence in the Delta is 17.22 percent, compared with 15.45 percent in the rest of Mississippi and a national average of roughly 11 percent. The Delta versus rest of state gap is statistically significant by Mann Whitney U test at p < 0.001, and every Delta county lies inside the CDC Diabetes Belt.

**The racial disparity in infant mortality is severe and statistically certain.** Infant mortality in Mississippi's Black communities runs at 15.2 deaths per 1,000 live births versus 5.8 in the White population, a rate ratio of 2.621 with a 95 percent confidence interval of [2.06, 3.33]. The interval was computed entirely in SQL using the Katz log rate ratio formula and is reproduced in `sql/analysis/Q15_disparity_ratio_with_ci.sql`. Because the lower bound of the interval sits well above 1.0, the disparity is not sampling noise.

**A small set of counties accounts for the bulk of preventable risk.** A composite priority score that combines the Maternal Risk Index, the percent of women living in care deserts, county level infant mortality, SVI, and the uninsured rate puts Holmes (MRI 62.6, 100 percent in care desert, IMR 14.6), Sharkey, Claiborne, Yazoo, and Tunica in the top five. Eleven of the top twenty counties sit in the Mississippi Delta. Each county in the output is tagged with a recommended intervention type drawn from mobile obstetric care, coverage outreach, community health worker programs, or chronic disease management.

**Fifteen census tracts carry a triple burden.** They sit simultaneously in the top quintile of the Maternal Risk Index, the top quintile of SVI, and more than 30 miles from the nearest birthing hospital. The drill down query returns each tract's FIPS code, county, distance, and nearest hospital, which is the specific list of addresses for the state health department to act on first.

**HRRP penalties are regressive against safety net hospitals.** Mississippi hospitals in high SVI counties show higher Excess Readmission Ratios than those in low SVI counties even after CMS risk adjustment. The federal readmission penalty therefore falls more harshly on the hospitals that serve the most vulnerable patients.

**The state's annual rate has been climbing over the last five years.** Mississippi moved from 8.3 deaths per 1,000 live births in 2020 to 9.3 in 2021, 9.2 in 2022, 8.9 in 2023, and 9.7 in 2024. The 2024 figure is the highest in the United States and is the number that triggered the August 2025 MSDH Public Health Emergency declaration.

## Methodology

The schema is a Kimball star with surrogate keys, foreign key integrity, and a documented data dictionary. The SQL layer uses window functions (NTILE, RANK, LAG, LEAD, FIRST_VALUE, PERCENT_RANK), recursive CTEs, GROUPING SETS for multi level subtotals, FILTER aggregates for pivoting, and PostGIS spatial operators (the KNN `<->` and `ST_DWithin`). Geographic comparisons run Delta versus rest of state and urban versus rural; population group comparisons run on race, age, and insurance status; trend analysis covers five years. Bonus statistical work includes a Pearson and Spearman correlation matrix, a Mann Whitney U test for the Delta versus rest distribution comparison, and the 95 percent disparity ratio confidence interval in pure SQL.

For details, see [`docs/methodology.md`](docs/methodology.md), [`docs/data_dictionary.md`](docs/data_dictionary.md), [`docs/schema_diagram.md`](docs/schema_diagram.md), and [`docs/findings.md`](docs/findings.md).

## Data quality notes

FIPS codes are stored as strings throughout the pipeline so that the leading zero on Mississippi codes (state FIPS 28) is preserved. The CDC SVI uses a 999 sentinel (stored as a negative number) for missing data, which is converted to SQL `NULL` in the load step. ACS estimates are paired with their margins of error in `fact_acs`. PLACES values are model based small area estimates from the Behavioral Risk Factor Surveillance System, and each row carries its tract level confidence interval. All fact to dimension joins are validated for referential integrity in `notebooks/01_data_quality.ipynb`.

## Author

Chetanchal Saud (`chetanchal.saud@usm.edu`), University of Southern Mississippi.
