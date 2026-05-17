-- Finds the nearest birthing-friendly hospital for every Mississippi tract centroid using a PostGIS KNN lateral join, then computes the great-circle distance in miles and an estimated drive time at 45 mph.

DROP TABLE IF EXISTS mart_drive_time CASCADE;
CREATE TABLE mart_drive_time AS

WITH birthing_hospitals AS (
    SELECT facility_sk, facility_name, county_name, geom
    FROM dim_facility
    WHERE state_abbr IN ('MS','LA','AL','TN','AR') -- include border-state hospitals
      AND is_birthing_friendly = TRUE
      AND geom IS NOT NULL
),
nearest AS (
    SELECT
        g.geo_sk, g.tract_fips, g.county_fips, g.county_name, g.region, g.is_delta,
        g.total_population,
        b.facility_sk AS nearest_hospital_sk,
        b.facility_name AS nearest_hospital_name,
        ST_Distance(g.centroid_geom::geography, b.geom::geography) / 1609.34 AS distance_miles
    FROM dim_geography g
    CROSS JOIN LATERAL (
        SELECT facility_sk, facility_name, geom
        FROM birthing_hospitals
        ORDER BY g.centroid_geom <-> geom
        LIMIT 1
    ) b
    WHERE g.centroid_geom IS NOT NULL
)
SELECT
    *,
    ROUND(distance_miles::NUMERIC, 1) AS distance_miles_rounded,
    ROUND((distance_miles / 45.0 * 60.0)::NUMERIC, 1) AS est_drive_minutes,
    CASE
        WHEN distance_miles <= 15 THEN '0-15 min'
        WHEN distance_miles <= 30 THEN '15-30 min'
        WHEN distance_miles <= 45 THEN '30-45 min'
        WHEN distance_miles <= 60 THEN '45-60 min'
        ELSE '60+ min'
    END AS drive_time_band,
    distance_miles > 30 AS is_care_desert
FROM nearest;

CREATE INDEX idx_drive_time_county ON mart_drive_time (county_fips);
CREATE INDEX idx_drive_time_band ON mart_drive_time (drive_time_band);
ANALYZE mart_drive_time;

SELECT drive_time_band,
       COUNT(*) AS tracts,
       SUM(total_population) AS total_pop,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_tracts,
       ROUND(100.0 * SUM(total_population) / SUM(SUM(total_population)) OVER (), 1) AS pct_pop
FROM mart_drive_time
GROUP BY drive_time_band ORDER BY drive_time_band;
