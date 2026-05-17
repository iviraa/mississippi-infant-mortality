-- Q17: Produces the headline actionable deliverable by joining the top-20 priority counties to their birthing-hospital count and primary-care HPSA score, then assigns each county a recommended intervention type via a CASE expression.

SELECT
    p.priority_rank AS rank,
    p.county_name,
    p.region,
    CASE WHEN p.is_delta THEN 'Delta' ELSE '' END AS delta,
    p.county_pop AS population,
    p.priority_score AS priority,
    p.county_mri AS mri,
    p.pct_in_care_desert || '%' AS pct_in_care_desert,
    COALESCE(p.imr_per_1000::TEXT, 'suppressed') AS imr,
    p.svi_overall_pct AS svi_pct,
    p.pct_uninsured || '%' AS uninsured,
    (SELECT COUNT(*) FROM dim_facility f
     WHERE f.county_fips = p.county_fips
       AND f.is_birthing_friendly) AS birthing_hospitals,
    (SELECT MAX(avg_hpsa_score) FROM fact_hpsa_county h
     WHERE h.county_fips = p.county_fips
       AND h.discipline = 'Primary Care') AS primary_care_hpsa_score,
    CASE
        WHEN p.pct_in_care_desert > 50 AND p.county_mri > 70 THEN 'STAND UP MOBILE OB CARE'
        WHEN p.county_mri > 70 AND p.pct_uninsured > 20 THEN 'EXPAND COVERAGE OUTREACH'
        WHEN p.svi_overall_pct > 0.85 AND p.county_mri > 60 THEN 'COMMUNITY HEALTH WORKER PROGRAM'
        ELSE 'TARGETED CHRONIC DISEASE INTERVENTION'
    END AS recommended_intervention
FROM mart_top20_priority p
WHERE p.priority_rank <= 20
ORDER BY p.priority_rank;
