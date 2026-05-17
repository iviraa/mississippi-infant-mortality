-- Q04: Demonstrates the SVI dose-response pattern by bucketing tracts into NTILE(5) quintiles and pivoting six health outcomes (diabetes, BP high, obesity, smoking, depression, uninsured) population-weighted within each quintile.

WITH svi_buckets AS (
    SELECT
        g.geo_sk, g.tract_fips, g.total_population,
        s.rpl_themes,
        NTILE(5) OVER (ORDER BY s.rpl_themes) AS svi_quintile
    FROM dim_geography g
    JOIN fact_svi_wide s ON s.geo_sk = g.geo_sk
    WHERE s.rpl_themes IS NOT NULL
),
places_pivot AS (
    SELECT
        b.svi_quintile, b.tract_fips, b.total_population,
        AVG(f.data_value) FILTER (WHERE m.measure_id = 'DIABETES') AS diabetes_pct,
        AVG(f.data_value) FILTER (WHERE m.measure_id = 'BPHIGH') AS bphigh_pct,
        AVG(f.data_value) FILTER (WHERE m.measure_id = 'OBESITY') AS obesity_pct,
        AVG(f.data_value) FILTER (WHERE m.measure_id = 'CSMOKING') AS smoking_pct,
        AVG(f.data_value) FILTER (WHERE m.measure_id = 'DEPRESSION') AS depression_pct,
        AVG(f.data_value) FILTER (WHERE m.measure_id = 'ACCESS2') AS uninsured_18_64_pct,
        AVG(f.data_value) FILTER (WHERE m.measure_id = 'CHECKUP') AS routine_checkup_pct
    FROM svi_buckets b
    JOIN fact_places f ON f.geo_sk = b.geo_sk
    JOIN dim_measure m ON m.measure_sk = f.measure_sk
    WHERE m.source = 'PLACES'
      AND f.year_sk = (SELECT MAX(year_sk) FROM fact_places)
    GROUP BY b.svi_quintile, b.tract_fips, b.total_population
)
SELECT
    svi_quintile,
    COUNT(*) AS tracts,
    SUM(total_population) AS pop,
    ROUND(SUM(diabetes_pct * total_population) / NULLIF(SUM(total_population), 0)::NUMERIC, 2) AS diabetes,
    ROUND(SUM(bphigh_pct * total_population) / NULLIF(SUM(total_population), 0)::NUMERIC, 2) AS bp_high,
    ROUND(SUM(obesity_pct * total_population) / NULLIF(SUM(total_population), 0)::NUMERIC, 2) AS obesity,
    ROUND(SUM(smoking_pct * total_population) / NULLIF(SUM(total_population), 0)::NUMERIC, 2) AS smoking,
    ROUND(SUM(depression_pct* total_population) / NULLIF(SUM(total_population), 0)::NUMERIC, 2) AS depression,
    ROUND(SUM(uninsured_18_64_pct * total_population) / NULLIF(SUM(total_population), 0)::NUMERIC, 2) AS uninsured_adults,
    ROUND(SUM(routine_checkup_pct * total_population) / NULLIF(SUM(total_population), 0)::NUMERIC, 2) AS had_checkup
FROM places_pivot
GROUP BY svi_quintile
ORDER BY svi_quintile;
