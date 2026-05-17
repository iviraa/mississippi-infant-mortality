# SQL analysis showcase

Standalone SQL queries that demonstrate the techniques used across the analytical marts: window functions, common table expressions, recursive rollups, GROUPING SETS, PostGIS spatial operators, pivots via FILTER, and statistical inference in SQL.

Each query is self-contained. Copy-paste any of them into `psql` or another SQL client after `make all` has populated the marts.

| # | File | Technique | Insight |
|---|---|---|---|
| 01 | `q01_top_vulnerable_tracts.sql` | RANK, ROW_NUMBER, PERCENT_RANK, NTILE | Top 20 most vulnerable MS tracts |
| 02 | `q02_diabetes_belt.sql` | Region grouping via CASE | MS Delta vs rest on diabetes |
| 03 | `q03_care_desert_quantification.sql` | Population weighted aggregates | Percent of MS women more than 30 minutes from an L&D hospital |
| 04 | `q04_disparity_by_svi_quintile.sql` | NTILE quintiles + FILTER | Health outcomes by SVI quintile |
| 05 | `q05_yoy_trends_2020_2025.sql` | LAG, FIRST_VALUE, LAST_VALUE | Counties improving vs deteriorating |
| 06 | `q06_birthing_friendly_coverage.sql` | LEFT JOIN coverage analysis | Counties with no L&D hospital |
| 07 | `q07_hrrp_regressivity_pivot.sql` | PIVOT via FILTER | HRRP average ERR by SVI quintile and measure |
| 08 | `q08_chronic_burden_correlation.sql` | PERCENTILE_CONT thresholds | High diabetes plus high uninsured tracts |
| 09 | `q09_recursive_geo_rollup.sql` | WITH RECURSIVE | Tract to county to region rollup |
| 10 | `q10_grouping_sets_subtotals.sql` | GROUPING SETS | Region plus state subtotals in one query |
| 11 | `q11_spatial_nearest_hospital.sql` | PostGIS KNN `<->` | Nearest L&D hospital per tract |
| 12 | `q12_spatial_buffer_coverage.sql` | PostGIS ST_DWithin | Tracts within 30 miles of any hospital |
| 13 | `q13_5year_pivot_health.sql` | Multi year pivot | Key measures by region and year |
| 14 | `q14_double_burden_drilldown.sql` | Multi CTE drill down | Triple burden tracts with full context |
| 15 | `q15_disparity_ratio_with_ci.sql` | Disparity ratio plus 95% CI in SQL | Black vs White IMR ratio with CI |
| 16 | `q16_data_quality_checks.sql` | Assertions | FK integrity, completeness, range checks |
| 17 | `q17_actionable_top20_summary.sql` | Final summary join | Top 20 priority counties with context |
