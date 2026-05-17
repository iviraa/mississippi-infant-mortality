-- Q11: Finds each Mississippi tract's nearest birthing-friendly hospital across MS and four bordering states using a PostGIS lateral join with the GiST-accelerated KNN distance operator.

SELECT
    g.tract_fips,
    g.county_name,
    g.region,
    g.total_population,
    nearest.facility_name AS nearest_hospital,
    nearest.county_name AS nearest_hospital_county,
    nearest.state_abbr AS nearest_hospital_state,
    ROUND((ST_Distance(g.centroid_geom::geography, nearest.geom::geography) / 1609.34)::NUMERIC, 1) AS distance_miles,
    ROUND((ST_Distance(g.centroid_geom::geography, nearest.geom::geography) / 1609.34 / 45.0 * 60.0)::NUMERIC, 0) AS est_drive_minutes
FROM dim_geography g
CROSS JOIN LATERAL (
    SELECT facility_name, county_name, state_abbr, geom
    FROM dim_facility
    WHERE is_birthing_friendly
      AND geom IS NOT NULL
      AND state_abbr IN ('MS','LA','AL','TN','AR')
    ORDER BY g.centroid_geom <-> geom
    LIMIT 1
) AS nearest
WHERE g.centroid_geom IS NOT NULL
ORDER BY distance_miles DESC
LIMIT 25;
