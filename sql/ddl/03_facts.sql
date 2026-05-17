-- Creates the long-format fact tables that reference dimensions via surrogate-key foreign keys.

DROP TABLE IF EXISTS fact_places CASCADE;
CREATE TABLE fact_places (
    geo_sk BIGINT NOT NULL REFERENCES dim_geography(geo_sk),
    measure_sk BIGINT NOT NULL REFERENCES dim_measure(measure_sk),
    year_sk INTEGER NOT NULL REFERENCES dim_year(year_sk),
    data_value NUMERIC,
    low_ci NUMERIC,
    high_ci NUMERIC,
    total_population INTEGER,
    PRIMARY KEY (geo_sk, measure_sk, year_sk)
);
CREATE INDEX idx_fact_places_year ON fact_places (year_sk);
CREATE INDEX idx_fact_places_measure ON fact_places (measure_sk);

DROP TABLE IF EXISTS fact_svi CASCADE;
CREATE TABLE fact_svi (
    geo_sk BIGINT NOT NULL REFERENCES dim_geography(geo_sk),
    measure_sk BIGINT NOT NULL REFERENCES dim_measure(measure_sk),
    year_sk INTEGER NOT NULL REFERENCES dim_year(year_sk),
    data_value NUMERIC,
    PRIMARY KEY (geo_sk, measure_sk, year_sk)
);
CREATE INDEX idx_fact_svi_measure ON fact_svi (measure_sk);

DROP TABLE IF EXISTS fact_svi_wide CASCADE;
CREATE TABLE fact_svi_wide (
    geo_sk BIGINT PRIMARY KEY REFERENCES dim_geography(geo_sk),
    year_sk INTEGER NOT NULL REFERENCES dim_year(year_sk),
    rpl_themes NUMERIC,
    rpl_theme1 NUMERIC,
    rpl_theme2 NUMERIC,
    rpl_theme3 NUMERIC,
    rpl_theme4 NUMERIC,
    f_total SMALLINT,
    ep_pov150 NUMERIC,
    ep_unemp NUMERIC,
    ep_uninsur NUMERIC,
    ep_nohsdp NUMERIC,
    ep_minrty NUMERIC,
    ep_noveh NUMERIC,
    ep_noint NUMERIC,
    ep_disabl NUMERIC,
    ep_sngpnt NUMERIC,
    ep_mobile NUMERIC
);

DROP TABLE IF EXISTS fact_acs CASCADE;
CREATE TABLE fact_acs (
    geo_sk BIGINT NOT NULL REFERENCES dim_geography(geo_sk),
    measure_sk BIGINT NOT NULL REFERENCES dim_measure(measure_sk),
    year_sk INTEGER NOT NULL REFERENCES dim_year(year_sk),
    estimate NUMERIC,
    moe NUMERIC,
    PRIMARY KEY (geo_sk, measure_sk, year_sk)
);
CREATE INDEX idx_fact_acs_measure ON fact_acs (measure_sk);

DROP TABLE IF EXISTS fact_imr CASCADE;
CREATE TABLE fact_imr (
    county_fips VARCHAR(5) NOT NULL,
    year_sk INTEGER NOT NULL REFERENCES dim_year(year_sk),
    live_births INTEGER,
    infant_deaths INTEGER,
    imr_per_1000 NUMERIC,
    neonatal_deaths INTEGER,
    postneonatal_deaths INTEGER,
    PRIMARY KEY (county_fips, year_sk)
);
CREATE INDEX idx_fact_imr_year ON fact_imr (year_sk);

DROP TABLE IF EXISTS fact_hospital_quality CASCADE;
CREATE TABLE fact_hospital_quality (
    facility_sk BIGINT NOT NULL REFERENCES dim_facility(facility_sk),
    measure_id VARCHAR(60) NOT NULL,
    measure_name VARCHAR(255),
    measure_type VARCHAR(40),
    score NUMERIC,
    discharges INTEGER,
    period_start DATE,
    period_end DATE,
    PRIMARY KEY (facility_sk, measure_id, measure_type)
);
CREATE INDEX idx_fact_hospquality_measure ON fact_hospital_quality (measure_id);

DROP TABLE IF EXISTS fact_hpsa_county CASCADE;
CREATE TABLE fact_hpsa_county (
    county_fips VARCHAR(5) NOT NULL,
    discipline VARCHAR(40) NOT NULL,
    avg_hpsa_score NUMERIC,
    max_hpsa_score NUMERIC,
    n_hpsa_designations INTEGER,
    underserved_population BIGINT,
    PRIMARY KEY (county_fips, discipline)
);

-- A staging table for the raw TIGER tract shapes; the only "raw" table we keep
-- because dim_geography needs PostGIS to compute centroids from the polygons.
DROP TABLE IF EXISTS stg_tiger_tract CASCADE;
CREATE TABLE stg_tiger_tract (
    statefp TEXT,
    countyfp TEXT,
    tractce TEXT,
    geoid TEXT,
    name TEXT,
    namelsad TEXT,
    aland BIGINT,
    awater BIGINT,
    intptlat TEXT,
    intptlon TEXT,
    geom geometry(MultiPolygon, 4269)
);
CREATE INDEX IF NOT EXISTS idx_stg_tiger_tract_geom ON stg_tiger_tract USING GIST (geom);

DROP TABLE IF EXISTS stg_tiger_county CASCADE;
CREATE TABLE stg_tiger_county (
    statefp TEXT,
    countyfp TEXT,
    geoid TEXT,
    name TEXT,
    namelsad TEXT,
    aland BIGINT,
    awater BIGINT,
    intptlat TEXT,
    intptlon TEXT,
    geom geometry(MultiPolygon, 4269)
);
CREATE INDEX IF NOT EXISTS idx_stg_tiger_county_geom ON stg_tiger_county USING GIST (geom);
