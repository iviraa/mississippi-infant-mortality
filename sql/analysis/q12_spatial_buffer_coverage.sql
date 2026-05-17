-- Q12: Reports the share of Mississippi tracts and population that have at least one birthing-friendly hospital within a 30-mile buffer using PostGIS ST_DWithin so the spatial join uses a GiST index.

WITH covered AS (
    SELECT DISTINCT g.tract_fips
    FROM dim_geography g
    JOIN dim_facility f
      ON ST_DWithin(g.centroid_geom::geography, f.geom::geography, 30 * 1609.34)
    WHERE f.is_birthing_friendly
      AND f.geom IS NOT NULL
      AND f.state_abbr IN ('MS','LA','AL','TN','AR')
)
SELECT
    g.region,
    COUNT(*) AS total_tracts,
    COUNT(*) FILTER (WHERE c.tract_fips IS NOT NULL) AS tracts_within_30mi,
    ROUND(100.0 * COUNT(*) FILTER (WHERE c.tract_fips IS NOT NULL) / COUNT(*), 1) AS pct_covered,
    SUM(g.total_population) AS region_pop,
    SUM(g.total_population) FILTER (WHERE c.tract_fips IS NOT NULL) AS pop_within_30mi,
    ROUND(100.0 * SUM(g.total_population) FILTER (WHERE c.tract_fips IS NOT NULL)
        / NULLIF(SUM(g.total_population), 0), 1) AS pct_pop_covered
FROM dim_geography g
LEFT JOIN covered c ON c.tract_fips = g.tract_fips
GROUP BY g.region
ORDER BY pct_pop_covered;
