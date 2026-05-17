-- Q03: Quantifies what share of Mississippi women aged 15-44 live in a maternity care desert (more than 30 minutes from a birthing-friendly hospital), broken out by region and weighted by ACS B01001 reproductive-age population counts.

WITH women_pop AS (
    SELECT g.tract_fips, g.county_fips, g.region, g.is_delta,
        g.total_population, a.women_reproductive_age
    FROM dim_geography g
    LEFT JOIN acs_headline a ON a.tract_fips = g.tract_fips
)
SELECT
    wp.region,
    COUNT(*) AS tracts,
    SUM(wp.total_population) AS total_pop,
    SUM(wp.women_reproductive_age) AS women_15_44,
    SUM(CASE WHEN d.is_care_desert THEN wp.women_reproductive_age ELSE 0 END) AS women_in_care_desert,
    ROUND((100.0 * SUM(CASE WHEN d.is_care_desert THEN wp.women_reproductive_age ELSE 0 END)
        / NULLIF(SUM(wp.women_reproductive_age), 0))::NUMERIC, 1) AS pct_women_in_care_desert,
    ROUND(AVG(d.distance_miles)::NUMERIC, 1) AS avg_distance_to_birthing_hospital
FROM women_pop wp
LEFT JOIN mart_drive_time d ON d.tract_fips = wp.tract_fips
GROUP BY wp.region

UNION ALL

SELECT
    'STATEWIDE',
    COUNT(*),
    SUM(wp.total_population),
    SUM(wp.women_reproductive_age),
    SUM(CASE WHEN d.is_care_desert THEN wp.women_reproductive_age ELSE 0 END),
    ROUND((100.0 * SUM(CASE WHEN d.is_care_desert THEN wp.women_reproductive_age ELSE 0 END)
        / NULLIF(SUM(wp.women_reproductive_age), 0))::NUMERIC, 1),
    ROUND(AVG(d.distance_miles)::NUMERIC, 1)
FROM women_pop wp
LEFT JOIN mart_drive_time d ON d.tract_fips = wp.tract_fips
ORDER BY pct_women_in_care_desert DESC;
