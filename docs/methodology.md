# Methodology

This document describes what the pipeline does at each stage, from public data source to published chart.

## Shape of the pipeline

Every dataset moves through the same four stages.

```
Sources  ->  Extract (Python)  ->  CSV files in data/raw/
                                         |
                                         v
                       pandas does the cleaning, then loads typed tables
                                         |
                                         v
                               public schema in Postgres
                                         |
                                         v
                          SQL builds the analytical marts
                                         |
                                         v
                       Jupyter notebooks + Folium + matplotlib
```

Each stage is a separate program file, so any single stage can be re-run in isolation without rebuilding everything upstream.

## Stage 1: extract

The seven Python files in `pipeline/extract_*.py` each download one source to disk. They write CSVs into `data/raw/{source}/` and append a manifest line to `data/raw/_manifest.jsonl` so that there is always an audit trail of which version of each file ended up in the project. After this stage finishes, no other code reaches out to the internet; everything downstream reads from the local raw directory.

## Stage 2: clean and load in pandas

The single file `pipeline/load.py` reads each raw CSV, cleans it in pandas, and writes a typed Postgres table directly into the `public` schema. There is no separate staging or raw layer inside the database, because the pandas cleaning step does the work that a staging layer would have done.

The cleaning rules that matter most are the following. The CDC Social Vulnerability Index uses the value `999` (stored as a negative number) to mean that no data is available for a tract, so every numeric SVI column passes through a helper that converts the sentinel to a SQL `NULL`. The American Community Survey uses three large negative sentinels for the same purpose, and they receive the same treatment. Federal Information Processing Standards (FIPS) codes are stored as strings rather than integers, because storing them as integers would strip the leading zero from counties like Bolivar (`28011`). Finally, CMS hospital files occasionally ship numeric measurements as the string `Too Few to Report`, so the cleaning code coerces any value that fails its expected numeric cast back to `NULL` rather than crashing the load.

## Stage 3: star schema in Postgres

The cleaned tables form a Kimball star schema with four dimensions and seven facts inside a single `public` schema.

The four dimension tables hold the descriptive context. `dim_geography` has one row per Mississippi census tract, including county, region, total population, and a PostGIS polygon for the tract boundary. `dim_measure` is the dictionary of every health, vulnerability, and demographic measure used across all sources. `dim_facility` has one row per CMS certified hospital, including its birthing friendly designation and an approximate point location. `dim_year` is a small lookup with one row per year so that time joins remain clean.

The seven fact tables hold the measurements themselves. `fact_places` records one health value per tract per year from the CDC PLACES feed. `fact_svi` and `fact_svi_wide` store the Social Vulnerability Index in long and wide form respectively. `fact_acs` holds the Census American Community Survey values. `fact_imr` holds Mississippi infant mortality by county and year. `fact_hospital_quality` holds CMS Hospital Readmissions Reduction Program scores and Timely Care measures. `fact_hpsa_county` holds aggregated Health Professional Shortage Area scores per county. Every fact table references its dimensions through surrogate key foreign keys, which keeps the joins fast and consistent.

PostGIS is the one cleaning step that has to happen in SQL rather than pandas. After GeoPandas loads the TIGER tract polygons into Postgres, a SQL statement computes the geographic centroid of each tract and stores it in `dim_geography.centroid_geom`. That centroid is the reference point for every subsequent spatial query.

## Stage 4: analytical marts

The five files in `sql/marts/` build pre-computed answers to specific questions. Each mart is a self-contained SQL script that joins facts and dimensions, runs the appropriate aggregations and window functions, and stores its output in a single table.

`mart_maternal_risk_index` computes a 0 to 100 composite score for every census tract by combining chronic disease prevalence, mental health distress, healthcare access barriers, and overall social vulnerability. Each of the four input components is min max scaled within Mississippi before being averaged, so the resulting score reads as "where this tract ranks within the state."

`mart_drive_time` uses the PostGIS K nearest neighbor operator to find the closest birthing friendly hospital for every tract centroid, then computes the great circle distance in miles and an estimated drive time at 45 miles per hour. Tracts more than 30 miles from the nearest birthing hospital are flagged as care deserts.

`mart_double_burden` joins the maternal risk index, the care desert flag, and the social vulnerability percentile to produce a `burden_count` column ranging from 0 to 3. A tract with `burden_count = 3` ranks in the worst quintile on all three measures and is the most acute case anywhere in the state.

`mart_top20_priority` rolls the tract level data up to the county level and ranks Mississippi's 82 counties on a composite priority score. The top 20 counties are the actionable intervention list for the state health department.

`mart_hrrp_regressivity` aggregates Medicare HRRP scores by the host county's SVI quintile, which tests whether the federal readmission penalty falls more harshly on hospitals serving more vulnerable counties.

## SQL techniques worth pointing out

The marts and the seventeen showcase queries in `sql/analysis/` rely on a handful of techniques that are central to the project's claim to SQL skill.

`NTILE(5)` is used to bucket tracts into vulnerability quintiles, and `RANK`, `DENSE_RANK`, and `ROW_NUMBER` produce the leaderboards for the most vulnerable tracts. `LAG`, `FIRST_VALUE`, and `LAST_VALUE` compute year over year change and change since baseline for the multi year PLACES data.

Almost every mart is structured as a chain of Common Table Expressions so the logic reads top to bottom, which is much easier to follow than nested subqueries when the same intermediate result is needed in more than one place downstream.

PostgreSQL's filtered aggregate syntax (`AGGREGATE(col) FILTER (WHERE cond)`) pivots long format facts into wide format in a single query, replacing the older `tablefunc.crosstab()` function. A single `GROUPING SETS` clause produces region detail rows, region subtotals, Delta versus rest subtotals, and a grand total in one query, with `GROUPING()` labeling which row is which rollup level.

One showcase query (`Q09`) walks the geographic hierarchy from tract up to county up to region up to state using `WITH RECURSIVE`, which is the canonical pattern for any tree shaped rollup in SQL.

The drive time mart relies on the PostGIS K nearest neighbor operator (`<->`) and `ST_DWithin` for buffer queries, both accelerated by GiST indexes so that per tract nearest hospital lookups run in milliseconds.

Finally, `Q15` implements the Katz log rate ratio standard error formula directly in SQL and exponentiates the bounds to produce the 95 percent confidence interval on the Black versus White infant mortality rate ratio.

## Statistics

The statistical work uses only `scipy`. Three tests appear across the notebooks: a Mann Whitney U test comparing the Delta region against the rest of Mississippi, Spearman rank correlations between the SVI themes and the PLACES outcomes, and the 95% confidence interval on the racial disparity ratio that is computed in SQL and displayed in the notebook.

We deliberately did not use machine learning. The questions this project answers are descriptive (where is the crisis happening, who is affected, how big is the gap) rather than predictive (what will the rate be next year), and statistical inference is the right tool family for descriptive questions.

## Reproducibility

The entire pipeline runs end to end with `make all`. That command creates the database, runs the DDL scripts, downloads every source file into `data/raw/`, runs the pandas ETL, builds the five marts, and renders the figures. A reviewer with Python 3.10 or newer, PostgreSQL 14 or newer with PostGIS, and a free Census Bureau API key can reproduce every number in this project on their own machine.

Python dependencies are pinned in `requirements.txt`. Postgres connection details are read from a `.env` file using `python-dotenv`, with `.env.example` checked in as a template.

## Limitations

A few honest caveats apply to the data and the methods.

The CDC PLACES values are not direct observations; they are model based small area estimates produced from the Behavioral Risk Factor Surveillance System telephone survey. Every PLACES row ships with a confidence interval, and we preserve those intervals in `fact_places`, but the underlying point estimates are inherently uncertain.

The drive time figure is the great circle distance from each tract centroid to the nearest birthing friendly hospital, divided by an assumed 45 miles per hour average road speed. This is the standard first pass approximation in the rural health literature. Future refinement could substitute a routing engine such as OSRM or the Google Maps API for actual road network drive times, which would shift the care desert boundary in tracts with significant river crossings or terrain detours.

The Mississippi infant mortality figures are problematic at the county and year level because deaths are rare enough that CDC WONDER suppresses single year county totals to protect privacy. The seed CSV therefore uses 5 year aggregate county rates for the period 2020 through 2024, transcribed from Figure 7 of the MSDH 2025 Infant Mortality Report. State by year rates and race specific rates come from Tables 1 and 2 of the same report. Counties with fewer than five infant deaths over the 5 year window appear as `NULL` in the `imr_per_1000` column.

Finally, every cleaning and aggregation step in this project is scoped to Mississippi. Hospitals in Louisiana, Alabama, Tennessee, and Arkansas appear in the spatial join only so that the nearest birthing hospital query returns a sensible answer for tracts near the state border. All other analysis filters to Mississippi state FIPS code `28`.
