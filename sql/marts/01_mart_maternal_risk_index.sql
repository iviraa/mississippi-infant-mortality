-- Builds the tract-level Maternal Risk Index by min-max scaling four components (pre-existing chronic disease, mental health distress, access barriers, and structural SVI vulnerability) within Mississippi and averaging them into a single 0-to-100 composite s

DROP TABLE IF EXISTS mart_maternal_risk_index CASCADE;
CREATE TABLE mart_maternal_risk_index AS

WITH places_pivot AS (
    SELECT
        f.geo_sk,
        AVG(f.data_value) FILTER (WHERE m.measure_id IN ('DIABETES','BPHIGH','OBESITY','CSMOKING')) AS pre_existing_avg,
        AVG(f.data_value) FILTER (WHERE m.measure_id IN ('DEPRESSION','MHLTH')) AS mental_health_avg,
        MAX(f.data_value) FILTER (WHERE m.measure_id = 'ACCESS2') AS pct_uninsured_adults,
        MAX(f.data_value) FILTER (WHERE m.measure_id = 'LACKTRPT') AS pct_lack_transport,
        MAX(f.data_value) FILTER (WHERE m.measure_id = 'CHECKUP') AS pct_with_checkup
    FROM fact_places f
    JOIN dim_measure m ON m.measure_sk = f.measure_sk
    WHERE m.source = 'PLACES'
      AND f.year_sk = (SELECT MAX(year_sk) FROM fact_places)
    GROUP BY f.geo_sk
),
combined AS (
    SELECT
        g.tract_fips, g.county_fips, g.county_name, g.region, g.is_delta, g.total_population,
        p.pre_existing_avg,
        p.mental_health_avg,
        (COALESCE(p.pct_uninsured_adults, 0) + COALESCE(p.pct_lack_transport, 0)) / 2.0 AS access_risk_raw,
        s.rpl_themes * 100 AS structural_risk_raw,
        p.pct_with_checkup,
        s.rpl_themes, s.rpl_theme1, s.rpl_theme4
    FROM dim_geography g
    LEFT JOIN places_pivot p ON p.geo_sk = g.geo_sk
    LEFT JOIN fact_svi_wide s ON s.geo_sk = g.geo_sk
),
scaled AS (
    SELECT c.*,
        100.0 * (pre_existing_avg - MIN(pre_existing_avg) OVER ())
              / NULLIF(MAX(pre_existing_avg) OVER () - MIN(pre_existing_avg) OVER (), 0) AS pre_existing_score,
        100.0 * (mental_health_avg - MIN(mental_health_avg) OVER ())
              / NULLIF(MAX(mental_health_avg) OVER () - MIN(mental_health_avg) OVER (), 0) AS mental_health_score,
        100.0 * (access_risk_raw - MIN(access_risk_raw) OVER ())
              / NULLIF(MAX(access_risk_raw) OVER () - MIN(access_risk_raw) OVER (), 0) AS access_score,
        100.0 * (structural_risk_raw - MIN(structural_risk_raw) OVER ())
              / NULLIF(MAX(structural_risk_raw) OVER () - MIN(structural_risk_raw) OVER (), 0) AS structural_score
    FROM combined c
    WHERE pre_existing_avg IS NOT NULL
      AND mental_health_avg IS NOT NULL
      AND structural_risk_raw IS NOT NULL
)
SELECT
    tract_fips, county_fips, county_name, region, is_delta, total_population,
    ROUND(pre_existing_avg::NUMERIC, 2) AS pre_existing_avg,
    ROUND(mental_health_avg::NUMERIC, 2) AS mental_health_avg,
    ROUND(access_risk_raw::NUMERIC, 2) AS access_risk_raw,
    ROUND(structural_risk_raw::NUMERIC, 2) AS structural_risk_raw,
    ROUND(pre_existing_score::NUMERIC, 1) AS pre_existing_score,
    ROUND(mental_health_score::NUMERIC, 1) AS mental_health_score,
    ROUND(access_score::NUMERIC, 1) AS access_score,
    ROUND(structural_score::NUMERIC, 1) AS structural_score,
    ROUND((COALESCE(pre_existing_score, 0)
         + COALESCE(mental_health_score, 0)
         + COALESCE(access_score, 0)
         + COALESCE(structural_score, 0)) / 4.0, 1) AS mri,
    NTILE(5) OVER (ORDER BY (COALESCE(pre_existing_score, 0)
                           + COALESCE(mental_health_score, 0)
                           + COALESCE(access_score, 0)
                           + COALESCE(structural_score, 0)) / 4.0) AS mri_quintile,
    rpl_themes
FROM scaled;

CREATE INDEX idx_mri_county ON mart_maternal_risk_index (county_fips);
CREATE INDEX idx_mri_score ON mart_maternal_risk_index (mri DESC);
ANALYZE mart_maternal_risk_index;

SELECT tract_fips, county_name, region, mri, mri_quintile,
       pre_existing_avg, mental_health_avg, structural_risk_raw
FROM mart_maternal_risk_index ORDER BY mri DESC LIMIT 10;
