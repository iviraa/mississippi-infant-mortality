-- Q14: Drills into every triple-burden tract (top-quintile MRI, more than 30 miles to L&D, and top-quintile SVI) with the full context columns an MSDH analyst would want when targeting an intervention.

WITH base AS (
    SELECT
        m.tract_fips, g.county_name, g.region, g.is_delta, g.total_population,
        m.mri, m.mri_quintile,
        m.pre_existing_avg, m.mental_health_avg,
        d.distance_miles_rounded AS dist_to_birthing,
        d.est_drive_minutes,
        d.nearest_hospital_name,
        s.rpl_themes AS svi,
        s.ep_uninsur AS pct_uninsured,
        s.ep_minrty AS pct_minority,
        s.ep_noveh AS pct_no_vehicle,
        s.ep_noint AS pct_no_internet
    FROM mart_maternal_risk_index m
    JOIN dim_geography g ON g.tract_fips = m.tract_fips
    LEFT JOIN mart_drive_time d ON d.tract_fips = m.tract_fips
    LEFT JOIN fact_svi_wide s ON s.geo_sk = g.geo_sk
)
SELECT
    tract_fips, county_name, region, is_delta, total_population,
    mri,
    pre_existing_avg AS chronic_disease_pct,
    mental_health_avg AS mental_health_pct,
    dist_to_birthing AS miles_to_l_and_d,
    est_drive_minutes AS drive_minutes,
    nearest_hospital_name,
    ROUND(svi::NUMERIC, 3) AS svi_overall,
    pct_uninsured, pct_no_vehicle, pct_no_internet
FROM base
WHERE mri_quintile = 5
  AND dist_to_birthing > 30
  AND svi >= 0.8
ORDER BY mri DESC;
