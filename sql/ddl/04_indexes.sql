-- Adds composite indexes for hot analytical filters and ANALYZEs every table.

CREATE INDEX IF NOT EXISTS idx_fact_places_geo_year ON fact_places (geo_sk, year_sk);
CREATE INDEX IF NOT EXISTS idx_fact_acs_geo ON fact_acs (geo_sk, year_sk);

ANALYZE dim_geography;
ANALYZE dim_measure;
ANALYZE dim_facility;
ANALYZE dim_year;
ANALYZE fact_places;
ANALYZE fact_svi;
ANALYZE fact_svi_wide;
ANALYZE fact_acs;
ANALYZE fact_imr;
ANALYZE fact_hospital_quality;
ANALYZE fact_hpsa_county;
