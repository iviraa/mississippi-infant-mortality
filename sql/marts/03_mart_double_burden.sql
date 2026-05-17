-- Tags every tract with a 0-to-3 burden_count by checking three independent risk axes (top-quintile MRI, care-desert status with more than 30 miles to L&D, and top-quintile SVI) so the analyst can drill into triple-burden tracts immediately.

DROP TABLE IF EXISTS mart_double_burden CASCADE;
CREATE TABLE mart_double_burden AS
SELECT
    m.tract_fips, m.county_name, m.region, m.is_delta, m.total_population,
    m.mri, m.mri_quintile,
    d.distance_miles_rounded AS distance_to_birthing_hospital_miles,
    d.est_drive_minutes,
    d.drive_time_band,
    d.nearest_hospital_name,
    s.rpl_themes AS svi_overall,
    s.ep_uninsur AS pct_uninsured,
    m.mri_quintile = 5 AS top_mri,
    d.is_care_desert,
    s.rpl_themes >= 0.8 AS top_svi,
    (CASE WHEN m.mri_quintile = 5 THEN 1 ELSE 0 END) +
    (CASE WHEN d.is_care_desert THEN 1 ELSE 0 END) +
    (CASE WHEN s.rpl_themes >= 0.8 THEN 1 ELSE 0 END) AS burden_count
FROM mart_maternal_risk_index m
LEFT JOIN mart_drive_time d ON d.tract_fips = m.tract_fips
LEFT JOIN fact_svi_wide s ON s.geo_sk = (
    SELECT geo_sk FROM dim_geography WHERE tract_fips = m.tract_fips
);

CREATE INDEX idx_double_burden_count ON mart_double_burden (burden_count DESC);
ANALYZE mart_double_burden;

SELECT tract_fips, county_name, region, mri,
       distance_to_birthing_hospital_miles, svi_overall, total_population
FROM mart_double_burden
WHERE burden_count = 3 ORDER BY mri DESC LIMIT 30;
