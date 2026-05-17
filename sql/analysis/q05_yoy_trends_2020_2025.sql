-- Q05: Identifies the 20 Mississippi counties whose diabetes prevalence has changed the most since the 2020 PLACES release using LAG, FIRST_VALUE, and LAST_VALUE window functions over the multi-year fact table.

WITH county_yearly AS (
    SELECT
        g.county_fips, g.county_name, g.region,
        m.measure_id, f.year_sk,
        SUM(f.data_value * f.total_population)
            / NULLIF(SUM(f.total_population), 0) AS pop_weighted_value
    FROM fact_places f
    JOIN dim_geography g ON g.geo_sk = f.geo_sk
    JOIN dim_measure m ON m.measure_sk = f.measure_sk
    WHERE m.source = 'PLACES'
      AND m.measure_id IN ('DIABETES', 'CSMOKING', 'DEPRESSION', 'OBESITY', 'BPHIGH')
    GROUP BY g.county_fips, g.county_name, g.region, m.measure_id, f.year_sk
),
with_lag AS (
    SELECT *,
        LAG(pop_weighted_value) OVER w AS prior_year_value,
        FIRST_VALUE(pop_weighted_value) OVER w AS baseline_value,
        LAST_VALUE(pop_weighted_value) OVER (PARTITION BY county_fips, measure_id
                                              ORDER BY year_sk
                                              ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS latest_value
    FROM county_yearly
    WINDOW w AS (PARTITION BY county_fips, measure_id ORDER BY year_sk)
)
SELECT
    county_name, region, measure_id, year_sk,
    ROUND(pop_weighted_value::NUMERIC, 2) AS value,
    ROUND((pop_weighted_value - prior_year_value)::NUMERIC, 2) AS yoy_delta,
    ROUND((pop_weighted_value - baseline_value)::NUMERIC, 2) AS delta_since_baseline,
    CASE WHEN prior_year_value IS NULL THEN 'baseline'
         WHEN pop_weighted_value > prior_year_value THEN 'worsening'
         WHEN pop_weighted_value < prior_year_value THEN 'improving'
         ELSE 'flat'
    END AS direction
FROM with_lag
WHERE year_sk = (SELECT MAX(year_sk) FROM fact_places)
  AND measure_id = 'DIABETES'
ORDER BY delta_since_baseline DESC
LIMIT 20;
