-- Q16: Runs ten data quality assertions covering FK integrity, range bounds, completeness, and expected row counts so any pipeline regression surfaces immediately.

SELECT 'dim_geography: NULL tract_fips' AS check_name,
       COUNT(*) AS bad_rows, 'Should be 0' AS expected
FROM dim_geography WHERE tract_fips IS NULL OR LENGTH(tract_fips) <> 11;

SELECT 'fact_places: orphan geo_sk', COUNT(*), 'Should be 0'
FROM fact_places f
LEFT JOIN dim_geography g ON g.geo_sk = f.geo_sk
WHERE g.geo_sk IS NULL;

SELECT 'fact_places: orphan measure_sk', COUNT(*), 'Should be 0'
FROM fact_places f
LEFT JOIN dim_measure m ON m.measure_sk = f.measure_sk
WHERE m.measure_sk IS NULL;

SELECT 'fact_places: out-of-range %', COUNT(*), 'Should be 0'
FROM fact_places f
JOIN dim_measure m ON m.measure_sk = f.measure_sk
WHERE m.unit = 'percent'
  AND (f.data_value < 0 OR f.data_value > 100);

SELECT 'fact_svi_wide: out-of-range RPL_THEMES', COUNT(*), 'Should be 0'
FROM fact_svi_wide WHERE rpl_themes < 0 OR rpl_themes > 1;

SELECT 'distinct counties in dim_geography', COUNT(DISTINCT county_fips),
       'Should be 82 (MS county count)'
FROM dim_geography;

SELECT 'fact_places year coverage', COUNT(DISTINCT year_sk),
       'Should be 4-6 (PLACES releases)'
FROM fact_places;

SELECT 'fact_imr: NULL imr (suppressed)' AS check_name,
       COUNT(*) AS bad_rows,
       'Expected: many (small-N counties)' AS expected
FROM fact_imr WHERE imr_per_1000 IS NULL;

SELECT 'dim_facility: missing geom', COUNT(*), 'Should be near 0'
FROM dim_facility WHERE geom IS NULL;

SELECT 'mart_maternal_risk_index rows', COUNT(*), '~875 (MS tract count)'
FROM mart_maternal_risk_index
UNION ALL SELECT 'mart_drive_time', COUNT(*), '~875' FROM mart_drive_time
UNION ALL SELECT 'mart_top20_priority', COUNT(*), '82 (MS counties)' FROM mart_top20_priority;
