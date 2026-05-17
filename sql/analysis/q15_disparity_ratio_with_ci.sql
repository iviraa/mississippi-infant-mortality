-- Q15: Computes the Black-versus-white infant mortality rate ratio and its 95% confidence interval entirely in SQL by implementing the Katz log-rate-ratio standard error formula and exponentiating the bounds.

WITH rates AS (
    SELECT county_name, year, live_births, infant_deaths, imr_per_1000
    FROM stg_msdh_imr_race
),
black_white AS (
    SELECT
        MAX(infant_deaths) FILTER (WHERE county_name ILIKE '%Black race%') AS d_black,
        MAX(live_births) FILTER (WHERE county_name ILIKE '%Black race%') AS n_black,
        MAX(imr_per_1000) FILTER (WHERE county_name ILIKE '%Black race%') AS imr_black,
        MAX(infant_deaths) FILTER (WHERE county_name ILIKE '%White race%') AS d_white,
        MAX(live_births) FILTER (WHERE county_name ILIKE '%White race%') AS n_white,
        MAX(imr_per_1000) FILTER (WHERE county_name ILIKE '%White race%') AS imr_white
    FROM rates
    WHERE year = (SELECT MAX(year) FROM rates)
)
SELECT
    imr_black, imr_white,
    ROUND((imr_black / imr_white)::NUMERIC, 3) AS rate_ratio,
    ROUND(EXP(LN(imr_black / imr_white)
        - 1.96 * SQRT(1.0/d_black - 1.0/n_black + 1.0/d_white - 1.0/n_white))::NUMERIC, 3) AS ci_lower_95,
    ROUND(EXP(LN(imr_black / imr_white)
        + 1.96 * SQRT(1.0/d_black - 1.0/n_black + 1.0/d_white - 1.0/n_white))::NUMERIC, 3) AS ci_upper_95,
    ROUND(SQRT(1.0/d_black - 1.0/n_black + 1.0/d_white - 1.0/n_white)::NUMERIC, 4) AS se_log_ratio,
    'Black vs white infant mortality, MS 2024' AS interpretation
FROM black_white;
