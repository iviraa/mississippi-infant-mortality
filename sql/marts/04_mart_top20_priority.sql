-- Ranks all 82 Mississippi counties by a composite priority score that min-max scales five inputs (county MRI, share of population in a care desert, infant mortality rate, county SVI percentile, and uninsured rate) and averages them, producing the actionable top-20 intervention list for MSDH.

DROP TABLE IF EXISTS mart_top20_priority CASCADE;
CREATE TABLE mart_top20_priority AS

WITH county_mri AS (
    SELECT
        county_fips, county_name, region, is_delta,
        SUM(total_population) AS county_pop,
        SUM(mri * total_population) / NULLIF(SUM(total_population), 0) AS county_mri,
        SUM(CASE WHEN m.tract_fips IN (
                SELECT tract_fips FROM mart_drive_time WHERE is_care_desert
            ) THEN total_population ELSE 0 END)::NUMERIC
            / NULLIF(SUM(total_population), 0) * 100 AS pct_pop_in_care_desert
    FROM mart_maternal_risk_index m
    GROUP BY county_fips, county_name, region, is_delta
),
imr_latest AS (
    SELECT county_fips, MAX(imr_per_1000) AS imr_per_1000
    FROM fact_imr
    WHERE imr_per_1000 IS NOT NULL AND county_fips <> '28000'
    GROUP BY county_fips
),
svi_county AS (
    SELECT county_fips, rpl_themes AS svi_county_pct, pct_uninsured
    FROM svi_county
),
combined AS (
    SELECT c.*, i.imr_per_1000, s.svi_county_pct, s.pct_uninsured
    FROM county_mri c
    LEFT JOIN imr_latest i ON i.county_fips = c.county_fips
    LEFT JOIN svi_county s ON s.county_fips = c.county_fips
),
scaled AS (
    SELECT c.*,
        100.0 * (county_mri - MIN(county_mri) OVER ()) /
                NULLIF(MAX(county_mri) OVER () - MIN(county_mri) OVER (), 0) AS s_mri,
        100.0 * (pct_pop_in_care_desert - MIN(pct_pop_in_care_desert) OVER ()) /
                NULLIF(MAX(pct_pop_in_care_desert) OVER () - MIN(pct_pop_in_care_desert) OVER (), 0) AS s_desert,
        100.0 * (COALESCE(imr_per_1000, 0) - MIN(COALESCE(imr_per_1000, 0)) OVER ()) /
                NULLIF(MAX(COALESCE(imr_per_1000, 0)) OVER () - MIN(COALESCE(imr_per_1000, 0)) OVER (), 0) AS s_imr,
        100.0 * (svi_county_pct - MIN(svi_county_pct) OVER ()) /
                NULLIF(MAX(svi_county_pct) OVER () - MIN(svi_county_pct) OVER (), 0) AS s_svi,
        100.0 * (pct_uninsured - MIN(pct_uninsured) OVER ()) /
                NULLIF(MAX(pct_uninsured) OVER () - MIN(pct_uninsured) OVER (), 0) AS s_uninsured
    FROM combined c
)
SELECT
    county_fips, county_name, region, is_delta, county_pop,
    ROUND(county_mri::NUMERIC, 1) AS county_mri,
    ROUND(pct_pop_in_care_desert::NUMERIC, 1) AS pct_in_care_desert,
    imr_per_1000,
    ROUND(svi_county_pct::NUMERIC, 3) AS svi_overall_pct,
    ROUND(pct_uninsured::NUMERIC, 1) AS pct_uninsured,
    ROUND(((COALESCE(s_mri, 0) + COALESCE(s_desert, 0) + COALESCE(s_imr, 0)
         + COALESCE(s_svi, 0) + COALESCE(s_uninsured, 0)) / 5.0)::NUMERIC, 1) AS priority_score,
    DENSE_RANK() OVER (ORDER BY
        (COALESCE(s_mri, 0) + COALESCE(s_desert, 0) + COALESCE(s_imr, 0)
       + COALESCE(s_svi, 0) + COALESCE(s_uninsured, 0)) / 5.0 DESC) AS priority_rank
FROM scaled
ORDER BY priority_score DESC;

CREATE INDEX idx_top20_rank ON mart_top20_priority (priority_rank);
ANALYZE mart_top20_priority;

SELECT priority_rank, county_name, region, priority_score, county_mri,
       pct_in_care_desert, imr_per_1000, svi_overall_pct, pct_uninsured
FROM mart_top20_priority ORDER BY priority_rank LIMIT 20;
