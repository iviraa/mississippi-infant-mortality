-- Q01: Returns the 20 most socially vulnerable Mississippi census tracts ranked by SVI overall percentile and demonstrates four window functions (ROW_NUMBER, DENSE_RANK, PERCENT_RANK, NTILE) in a single query.

WITH ranked AS (
    SELECT
        g.tract_fips,
        g.county_name,
        g.region,
        g.is_delta,
        g.total_population,
        s.rpl_themes AS svi_overall,
        s.rpl_theme1 AS svi_ses,
        s.rpl_theme4 AS svi_housing_transport,
        ROW_NUMBER() OVER (ORDER BY s.rpl_themes DESC NULLS LAST) AS rn,
        DENSE_RANK() OVER (ORDER BY s.rpl_themes DESC NULLS LAST) AS svi_rank,
        PERCENT_RANK() OVER (ORDER BY s.rpl_themes) AS svi_pctile,
        NTILE(5) OVER (ORDER BY s.rpl_themes) AS svi_quintile
    FROM dim_geography g
    JOIN fact_svi_wide s ON s.geo_sk = g.geo_sk
)
SELECT rn, tract_fips, county_name, region, total_population,
       ROUND(svi_overall::NUMERIC, 3) AS svi_overall,
       ROUND(svi_ses::NUMERIC, 3) AS svi_ses,
       ROUND(svi_housing_transport::NUMERIC, 3) AS svi_housing_transport,
       svi_rank,
       ROUND(svi_pctile::NUMERIC * 100, 1) AS svi_pctile,
       svi_quintile
FROM ranked
WHERE rn <= 20
ORDER BY rn;
