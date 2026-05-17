-- Q10: Uses GROUPING SETS to return region-by-delta-status detail rows together with region subtotals, delta-status subtotals, and a single statewide grand total in one query without any UNION ALL boilerplate.

WITH places_diabetes AS (
    SELECT g.region, g.is_delta, g.tract_fips, g.total_population,
           f.data_value AS diabetes_pct
    FROM fact_places f
    JOIN dim_geography g ON g.geo_sk = f.geo_sk
    JOIN dim_measure m ON m.measure_sk = f.measure_sk
    WHERE m.source = 'PLACES' AND m.measure_id = 'DIABETES'
      AND f.year_sk = (SELECT MAX(year_sk) FROM fact_places)
)
SELECT
    COALESCE(region, 'STATEWIDE') AS region,
    CASE WHEN GROUPING(is_delta) = 1 THEN 'all'
         WHEN is_delta THEN 'Delta'
         ELSE 'non-Delta' END AS delta_status,
    COUNT(*) AS tracts,
    SUM(total_population) AS population,
    ROUND((SUM(diabetes_pct * total_population)
        / NULLIF(SUM(total_population), 0))::NUMERIC, 2) AS pop_weighted_diabetes_pct,
    ROUND(MIN(diabetes_pct)::NUMERIC, 1) AS min_pct,
    ROUND(MAX(diabetes_pct)::NUMERIC, 1) AS max_pct
FROM places_diabetes
GROUP BY GROUPING SETS (
    (region, is_delta), -- region × delta detail
    (region), -- region subtotal
    (is_delta), -- delta subtotal
    () -- grand total
)
ORDER BY GROUPING(region), region NULLS LAST, GROUPING(is_delta), is_delta DESC;
