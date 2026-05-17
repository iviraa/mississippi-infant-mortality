-- Q07: Pivots HRRP Excess Readmission Ratios into one column per measure (AMI, HF, PN, COPD, hip-knee, CABG) crossed against hospital host-county SVI quintile using FILTER aggregates, so a regressivity gradient is visible in a single table.

WITH hospital_quintile AS (
    SELECT
        f.facility_sk, f.facility_name, f.county_name,
        s.rpl_themes AS county_svi,
        NTILE(5) OVER (ORDER BY s.rpl_themes) AS svi_quintile
    FROM dim_facility f
    JOIN svi_county s ON s.county_fips = f.county_fips
    WHERE f.state_abbr = 'MS'
)
SELECT
    h.svi_quintile,
    COUNT(DISTINCT h.facility_sk) AS hospitals,
    ROUND(AVG(q.score) FILTER (WHERE q.measure_id = 'READM-30-AMI-HRRP')::NUMERIC, 3) AS ami_err,
    ROUND(AVG(q.score) FILTER (WHERE q.measure_id = 'READM-30-HF-HRRP')::NUMERIC, 3) AS hf_err,
    ROUND(AVG(q.score) FILTER (WHERE q.measure_id = 'READM-30-PN-HRRP')::NUMERIC, 3) AS pn_err,
    ROUND(AVG(q.score) FILTER (WHERE q.measure_id = 'READM-30-COPD-HRRP')::NUMERIC, 3) AS copd_err,
    ROUND(AVG(q.score) FILTER (WHERE q.measure_id = 'READM-30-HIP-KNEE-HRRP')::NUMERIC, 3) AS hip_knee_err,
    ROUND(AVG(q.score) FILTER (WHERE q.measure_id = 'READM-30-CABG-HRRP')::NUMERIC, 3) AS cabg_err,
    ROUND(AVG(q.score)::NUMERIC, 3) AS overall_avg_err,
    ROUND(100.0 * SUM(CASE WHEN q.score > 1.0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_worse_than_expected
FROM hospital_quintile h
JOIN fact_hospital_quality q ON q.facility_sk = h.facility_sk
WHERE q.measure_type = 'HRRP'
GROUP BY h.svi_quintile
ORDER BY h.svi_quintile;
