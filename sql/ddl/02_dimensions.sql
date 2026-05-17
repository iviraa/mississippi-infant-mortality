-- Creates the four star-schema dimensions with surrogate keys and seeds dim_year.

DROP TABLE IF EXISTS dim_geography CASCADE;
CREATE TABLE dim_geography (
    geo_sk BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tract_fips VARCHAR(11) NOT NULL UNIQUE,
    county_fips VARCHAR(5) NOT NULL,
    county_name VARCHAR(60) NOT NULL,
    state_fips VARCHAR(2) NOT NULL,
    state_abbr VARCHAR(2) NOT NULL,
    region VARCHAR(20),
    is_delta BOOLEAN NOT NULL DEFAULT FALSE,
    is_gulf_coast BOOLEAN NOT NULL DEFAULT FALSE,
    is_rural BOOLEAN,
    total_population INTEGER,
    centroid_lat NUMERIC(9, 6),
    centroid_lon NUMERIC(9, 6),
    geom geometry(MultiPolygon, 4269),
    centroid_geom geometry(Point, 4269)
);
CREATE INDEX idx_dim_geography_county ON dim_geography (county_fips);
CREATE INDEX idx_dim_geography_region ON dim_geography (region);
CREATE INDEX idx_dim_geography_geom ON dim_geography USING GIST (geom);
CREATE INDEX idx_dim_geography_centroid ON dim_geography USING GIST (centroid_geom);

DROP TABLE IF EXISTS dim_measure CASCADE;
CREATE TABLE dim_measure (
    measure_sk BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source VARCHAR(20) NOT NULL,
    measure_id VARCHAR(60) NOT NULL,
    measure_name VARCHAR(255) NOT NULL,
    short_name VARCHAR(80),
    category VARCHAR(80),
    unit VARCHAR(40),
    higher_is_worse BOOLEAN,
    UNIQUE (source, measure_id)
);
CREATE INDEX idx_dim_measure_category ON dim_measure (category);

DROP TABLE IF EXISTS dim_facility CASCADE;
CREATE TABLE dim_facility (
    facility_sk BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ccn VARCHAR(10) NOT NULL UNIQUE,
    facility_name VARCHAR(255) NOT NULL,
    address VARCHAR(255),
    city VARCHAR(80),
    state_abbr VARCHAR(2),
    zip_code VARCHAR(10),
    county_name VARCHAR(80),
    county_fips VARCHAR(5),
    hospital_type VARCHAR(80),
    hospital_ownership VARCHAR(80),
    emergency_services BOOLEAN,
    is_birthing_friendly BOOLEAN,
    overall_rating INTEGER,
    lat NUMERIC(9, 6),
    lon NUMERIC(9, 6),
    geom geometry(Point, 4269)
);
CREATE INDEX idx_dim_facility_county ON dim_facility (county_fips);
CREATE INDEX idx_dim_facility_state ON dim_facility (state_abbr);
CREATE INDEX idx_dim_facility_geom ON dim_facility USING GIST (geom);
CREATE INDEX idx_dim_facility_birthing ON dim_facility (is_birthing_friendly) WHERE is_birthing_friendly;

DROP TABLE IF EXISTS dim_year CASCADE;
CREATE TABLE dim_year (
    year_sk INTEGER PRIMARY KEY,
    brfss_year INTEGER,
    release_label VARCHAR(60),
    notes TEXT
);

INSERT INTO dim_year (year_sk, brfss_year, release_label) VALUES
    (2017, 2017, 'BRFSS 2017'),
    (2018, 2018, 'BRFSS 2018 (PLACES 2020 release)'),
    (2019, 2019, 'BRFSS 2019 (PLACES 2021 release)'),
    (2020, 2020, 'BRFSS 2020 (PLACES 2022 release)'),
    (2021, 2021, 'BRFSS 2021 (PLACES 2023 release)'),
    (2022, 2022, 'BRFSS 2022 (PLACES 2024 release)'),
    (2023, 2023, 'BRFSS 2023 (PLACES 2025 release)'),
    (2024, 2024, 'MSDH 2024 reporting year')
ON CONFLICT DO NOTHING;
