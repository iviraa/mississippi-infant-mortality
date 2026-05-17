-- Q02: Compares population-weighted diabetes prevalence in the 18-county Mississippi Delta against the rest of the state and reports how many tracts in each region exceed the national average.

WITH places_diabetes AS (
    SELECT
        g.tract_fips, g.county_name, g.region, g.is_delta,
        g.total_population,
        f.data_value AS diabetes_pct,
        f.low_ci, f.high_ci
    FROM fact_places f
    JOIN dim_geography g ON g.geo_sk = f.geo_sk
    JOIN dim_measure m ON m.measure_sk = f.measure_sk
    WHERE m.source = 'PLACES'
      AND m.measure_id = 'DIABETES'
      AND f.year_sk = (SELECT MAX(year_sk) FROM fact_places)
)
SELECT
    CASE WHEN is_delta THEN 'Delta (18 counties)' ELSE 'Rest of MS' END AS region_group,
    COUNT(*) AS tracts,
    SUM(total_population) AS population,
    ROUND(SUM(diabetes_pct * total_population)
        / NULLIF(SUM(total_population), 0)::NUMERIC, 2) AS pop_weighted_diabetes_pct,
    ROUND(MIN(diabetes_pct)::NUMERIC, 1) AS min_pct,
    ROUND(MAX(diabetes_pct)::NUMERIC, 1) AS max_pct,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY diabetes_pct)::NUMERIC, 1) AS median_pct,
    SUM(CASE WHEN diabetes_pct > 11 THEN 1 ELSE 0 END) AS tracts_above_national_avg,
    ROUND(100.0 * SUM(CASE WHEN diabetes_pct > 11 THEN 1 ELSE 0 END) / COUNT(*), 1)
                                                                     AS pct_tracts_above_national_avg
FROM places_diabetes
GROUP BY is_delta
ORDER BY is_delta DESC;
