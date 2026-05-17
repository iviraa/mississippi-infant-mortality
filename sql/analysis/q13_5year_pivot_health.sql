-- Q13: Pivots eight key health measures (diabetes, obesity, smoking, BP high, depression, mental distress, routine checkup, uninsured 18-64) into one column each, broken out by region and PLACES release year so multi-year trends read at a glance.

SELECT
    f.year_sk AS year,
    g.region,
    ROUND(AVG(f.data_value) FILTER (WHERE m.measure_id = 'DIABETES')::NUMERIC, 2) AS diabetes,
    ROUND(AVG(f.data_value) FILTER (WHERE m.measure_id = 'OBESITY')::NUMERIC, 2) AS obesity,
    ROUND(AVG(f.data_value) FILTER (WHERE m.measure_id = 'CSMOKING')::NUMERIC, 2) AS smoking,
    ROUND(AVG(f.data_value) FILTER (WHERE m.measure_id = 'BPHIGH')::NUMERIC, 2) AS bp_high,
    ROUND(AVG(f.data_value) FILTER (WHERE m.measure_id = 'DEPRESSION')::NUMERIC, 2) AS depression,
    ROUND(AVG(f.data_value) FILTER (WHERE m.measure_id = 'MHLTH')::NUMERIC, 2) AS frequent_mental_distress,
    ROUND(AVG(f.data_value) FILTER (WHERE m.measure_id = 'CHECKUP')::NUMERIC, 2) AS routine_checkup,
    ROUND(AVG(f.data_value) FILTER (WHERE m.measure_id = 'ACCESS2')::NUMERIC, 2) AS uninsured_18_64
FROM fact_places f
JOIN dim_geography g ON g.geo_sk = f.geo_sk
JOIN dim_measure m ON m.measure_sk = f.measure_sk
WHERE m.source = 'PLACES'
  AND m.measure_id IN ('DIABETES','OBESITY','CSMOKING','BPHIGH','DEPRESSION','MHLTH','CHECKUP','ACCESS2')
GROUP BY f.year_sk, g.region
ORDER BY f.year_sk, g.region;
