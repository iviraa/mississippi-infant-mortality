-- Q08: Surfaces the 25 Mississippi tracts that simultaneously rank in the top quintile of both diabetes prevalence and uninsured-adult rate, with thresholds computed dynamically via PERCENTILE_CONT so the cutoffs adapt to the data distribution.

WITH measures AS (
    SELECT
        g.geo_sk, g.tract_fips, g.county_name, g.region, g.total_population,
        MAX(f.data_value) FILTER (WHERE m.measure_id = 'DIABETES') AS diabetes,
        MAX(f.data_value) FILTER (WHERE m.measure_id = 'BPHIGH') AS bphigh,
        MAX(f.data_value) FILTER (WHERE m.measure_id = 'CHD') AS chd,
        MAX(f.data_value) FILTER (WHERE m.measure_id = 'ACCESS2') AS uninsured_adults,
        MAX(f.data_value) FILTER (WHERE m.measure_id = 'CHECKUP') AS had_checkup
    FROM dim_geography g
    JOIN fact_places f ON f.geo_sk = g.geo_sk
    JOIN dim_measure m ON m.measure_sk = f.measure_sk
    WHERE m.source = 'PLACES'
      AND f.year_sk = (SELECT MAX(year_sk) FROM fact_places)
    GROUP BY g.geo_sk, g.tract_fips, g.county_name, g.region, g.total_population
),
thresholds AS (
    SELECT
        PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY diabetes) AS diabetes_p80,
        PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY uninsured_adults) AS uninsured_p80,
        PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY chd) AS chd_p80
    FROM measures
)
SELECT
    m.tract_fips, m.county_name, m.region, m.total_population,
    ROUND(m.diabetes::NUMERIC, 1) AS diabetes_pct,
    ROUND(m.bphigh::NUMERIC, 1) AS bp_high_pct,
    ROUND(m.chd::NUMERIC, 1) AS chd_pct,
    ROUND(m.uninsured_adults::NUMERIC, 1) AS uninsured_pct,
    ROUND(m.had_checkup::NUMERIC, 1) AS checkup_pct,
    ROUND(((m.diabetes + m.bphigh + m.chd) / 3.0
        + (100.0 - m.had_checkup))::NUMERIC, 2) AS burden_score
FROM measures m, thresholds t
WHERE m.diabetes > t.diabetes_p80
  AND m.uninsured_adults > t.uninsured_p80
ORDER BY burden_score DESC
LIMIT 25;
