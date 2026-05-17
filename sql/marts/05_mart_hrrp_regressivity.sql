-- Aggregates HRRP Excess Readmission Ratios by hospital host-county SVI quintile and HRRP measure to test whether Medicare's readmission penalty falls more harshly on hospitals serving more vulnerable counties.

DROP TABLE IF EXISTS mart_hrrp_regressivity CASCADE;
CREATE TABLE mart_hrrp_regressivity AS

WITH hospital_svi AS (
    SELECT
        f.facility_sk, f.facility_name, f.county_fips, f.county_name,
        s.rpl_themes AS county_svi_pct,
        NTILE(5) OVER (ORDER BY s.rpl_themes) AS county_svi_quintile
    FROM dim_facility f
    JOIN svi_county s ON s.county_fips = f.county_fips
    WHERE f.state_abbr = 'MS'
)
SELECT
    h.county_svi_quintile,
    q.measure_id AS hrrp_measure,
    COUNT(*) AS n_hospital_measures,
    ROUND(AVG(q.score)::NUMERIC, 4) AS avg_excess_readmission_ratio,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY q.score)::NUMERIC, 4) AS median_err,
    ROUND(MIN(q.score)::NUMERIC, 4) AS min_err,
    ROUND(MAX(q.score)::NUMERIC, 4) AS max_err,
    SUM(CASE WHEN q.score > 1.0 THEN 1 ELSE 0 END) AS n_worse_than_expected,
    ROUND(100.0 * SUM(CASE WHEN q.score > 1.0 THEN 1 ELSE 0 END) / COUNT(*), 1)
                                                 AS pct_worse_than_expected
FROM fact_hospital_quality q
JOIN hospital_svi h ON h.facility_sk = q.facility_sk
WHERE q.measure_type = 'HRRP'
GROUP BY h.county_svi_quintile, q.measure_id
ORDER BY h.county_svi_quintile, q.measure_id;

ANALYZE mart_hrrp_regressivity;

SELECT county_svi_quintile,
       SUM(n_hospital_measures) AS measures,
       ROUND(SUM(avg_excess_readmission_ratio * n_hospital_measures)
           / SUM(n_hospital_measures), 4) AS weighted_avg_err,
       ROUND(SUM(n_worse_than_expected)::NUMERIC * 100
           / SUM(n_hospital_measures), 1) AS pct_worse_than_expected
FROM mart_hrrp_regressivity
GROUP BY county_svi_quintile ORDER BY county_svi_quintile;
