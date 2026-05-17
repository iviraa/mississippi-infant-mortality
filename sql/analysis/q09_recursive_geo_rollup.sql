-- Q09: Demonstrates a WITH RECURSIVE common table expression that traverses the geographic hierarchy from tract to county to region to state, then rolls up diabetes prevalence at each level.

WITH RECURSIVE
hierarchy(level, level_name, parent_id, node_id, label, region) AS (
    -- Base case: tracts
    SELECT 1, 'tract', county_fips, tract_fips, tract_fips, region
    FROM dim_geography
    WHERE state_abbr = 'MS'

    UNION ALL

    -- Recursive: roll up each level
    SELECT h.level + 1,
        CASE WHEN h.level + 1 = 2 THEN 'county'
             WHEN h.level + 1 = 3 THEN 'region'
             ELSE 'state' END,
        CASE WHEN h.level + 1 = 2 THEN h.region
             WHEN h.level + 1 = 3 THEN 'MS'
             ELSE NULL END,
        CASE WHEN h.level + 1 = 2 THEN h.parent_id
             WHEN h.level + 1 = 3 THEN h.region
             ELSE 'MS' END,
        CASE WHEN h.level + 1 = 2 THEN h.parent_id
             WHEN h.level + 1 = 3 THEN h.region
             ELSE 'Mississippi' END,
        h.region
    FROM hierarchy h
    WHERE h.level < 4
),
diabetes AS (
    SELECT g.tract_fips, g.county_fips, g.region,
           f.data_value AS diabetes_pct, f.total_population
    FROM fact_places f
    JOIN dim_geography g ON g.geo_sk = f.geo_sk
    JOIN dim_measure m ON m.measure_sk = f.measure_sk
    WHERE m.source = 'PLACES' AND m.measure_id = 'DIABETES'
      AND f.year_sk = (SELECT MAX(year_sk) FROM fact_places)
)
SELECT 'tract' AS level, tract_fips AS node, diabetes_pct AS value, total_population
FROM diabetes ORDER BY diabetes_pct DESC LIMIT 5

UNION ALL

SELECT 'county', g.county_name,
       ROUND((SUM(d.diabetes_pct * d.total_population) /
              NULLIF(SUM(d.total_population), 0))::NUMERIC, 2),
       SUM(d.total_population)
FROM diabetes d
JOIN dim_geography g ON g.tract_fips = d.tract_fips
GROUP BY g.county_name ORDER BY value DESC LIMIT 5;
