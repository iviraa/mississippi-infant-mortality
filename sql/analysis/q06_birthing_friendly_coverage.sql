-- Q06: Lists every Mississippi county with the count of birthing-friendly hospitals it contains and the number of women aged 15-44 who would be affected if it has none, using LEFT JOINs and STRING_AGG to surface the facility list per county.

WITH counties AS (
    SELECT DISTINCT county_fips, county_name, region, is_delta
    FROM dim_geography
),
hospitals_per_county AS (
    SELECT
        county_fips,
        COUNT(*) AS n_hospitals,
        COUNT(*) FILTER (WHERE is_birthing_friendly) AS n_birthing_friendly,
        COUNT(*) FILTER (WHERE hospital_type LIKE 'Critical Access%') AS n_critical_access,
        STRING_AGG(facility_name, '; ' ORDER BY facility_name) AS facility_list
    FROM dim_facility
    WHERE state_abbr = 'MS'
    GROUP BY county_fips
),
women_per_county AS (
    SELECT g.county_fips, SUM(a.women_reproductive_age) AS women_15_44
    FROM dim_geography g
    LEFT JOIN acs_headline a ON a.tract_fips = g.tract_fips
    GROUP BY g.county_fips
)
SELECT
    c.county_fips, c.county_name, c.region, c.is_delta,
    COALESCE(h.n_hospitals, 0) AS hospitals,
    COALESCE(h.n_birthing_friendly, 0) AS birthing_friendly_hospitals,
    COALESCE(h.n_critical_access, 0) AS critical_access_hospitals,
    COALESCE(w.women_15_44, 0) AS women_15_44,
    CASE WHEN COALESCE(h.n_birthing_friendly, 0) = 0 THEN 'NO L&D HOSPITAL'
         WHEN h.n_birthing_friendly = 1 THEN 'Single L&D'
         ELSE 'Multiple L&D'
    END AS coverage_status
FROM counties c
LEFT JOIN hospitals_per_county h USING (county_fips)
LEFT JOIN women_per_county w USING (county_fips)
ORDER BY birthing_friendly_hospitals ASC, women_15_44 DESC;
