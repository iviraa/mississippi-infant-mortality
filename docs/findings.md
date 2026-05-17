# Key findings

Each finding below cites the SQL query (`Q##`) or notebook that produces it, and every number is reproducible from the pipeline.

## 1. Maternity care deserts cluster in the Delta

51.2 percent of Mississippi Delta women aged 15 to 44 live more than 30 minutes from a birthing friendly hospital. The rest of the state is an order of magnitude better.

| Region | Percent women 15 to 44 in care desert |
|---|---|
| Delta | 51.2% |
| Other rural counties | 9.2% |
| Jackson Metro | 0.5% |
| Gulf Coast | 0% |
| Pine Belt | 0% |

Source: `Q03_care_desert_quantification.sql`, `figures/interactive/02_drive_time_choropleth.html`.

## 2. 54 Mississippi counties have zero birthing friendly hospitals

Out of 82 counties, 54 (66 percent) have no CMS designated birthing friendly hospital, and roughly **111,500 women of reproductive age** live in those counties.

Source: `Q06_birthing_friendly_coverage.sql`.

## 3. Delta diabetes prevalence is 11 percent higher than the rest of Mississippi

Population weighted diabetes prevalence comes in at 17.22 percent in the Mississippi Delta versus 15.45 percent in the rest of the state, against a national average of roughly 11 percent. The Delta versus rest gap is statistically significant by Mann Whitney U test (p < 0.001). Every Delta county lies inside CDC's Diabetes Belt.

Source: `Q02_diabetes_belt.sql`, `figures/static/07_delta_vs_rest_diabetes.png`.

## 4. Infant mortality in Black communities is 2.6 times the rate in White communities

The 2024 infant mortality rate in Mississippi's Black population is 15.2 per 1,000 live births, compared with 5.8 in the White population. The rate ratio is **2.621 with a 95 percent confidence interval of [2.06, 3.33]**, computed in pure SQL using the Katz log rate ratio formula. The lower bound of the interval sits well above 1.0, so this disparity is not sampling noise.

Source: `Q15_disparity_ratio_with_ci.sql`, MSDH 2025 Infant Mortality Report Table 2.

## 5. Every health outcome worsens monotonically with social vulnerability

When Mississippi tracts are bucketed into five SVI quintiles, all six outcomes we tested (diabetes, high blood pressure, obesity, smoking, depression, uninsured rate) climb monotonically from quintile 1 to quintile 5 with no reversals. This dose response gradient is why SVI is included as the structural component of the Maternal Risk Index.

Source: `Q04_disparity_by_svi_quintile.sql`, `figures/static/01_disparity_by_svi_quintile.png`.

## 6. HRRP penalties fall harder on hospitals serving vulnerable counties

Hospitals in the top SVI quintile show higher Excess Readmission Ratios than those in the bottom quintile, even after CMS risk adjustment. Medicare's readmission penalty is regressive against hospitals serving the poorest patients.

Source: `Q07_hrrp_regressivity_pivot.sql`, `figures/static/03_hrrp_regressivity.png`.

## 7. Top 20 priority counties for MSDH intervention

The composite ranking combines the Maternal Risk Index, the percent of women in care deserts, county level infant mortality, SVI, and the uninsured rate. The top five are listed below.

| Rank | County | Region | MRI | Percent in care desert | IMR |
|---|---|---|---|---|---|
| 1 | Holmes | Delta | 62.6 | 100.0% | 14.6 |
| 2 | Sharkey | Delta | 63.5 | 0.0% | 17.6 |
| 3 | Claiborne | Other | 55.5 | 57.4% | 15.4 |
| 4 | Yazoo | Delta | 58.4 | 88.4% | 12.1 |
| 5 | Tunica | Delta | 62.5 | 82.5% | 13.1 |

Eleven of the top twenty counties are in the Mississippi Delta. Each county in the output is tagged with a recommended intervention type (mobile obstetric care, coverage outreach, community health worker, or chronic disease management).

Source: `Q17_actionable_top20_summary.sql`, `figures/static/05_top20_priority_table.png`, `figures/interactive/04_top20_priority.html`.

## 8. Fifteen triple burden tracts where intervention should start

Fifteen census tracts simultaneously sit in the top quintile of the Maternal Risk Index, the top quintile of SVI overall, and more than 30 miles from the nearest birthing hospital. The drill down query returns each tract's FIPS, county, distance, and nearest hospital, which is the specific list of addresses to act on first.

Source: `Q14_double_burden_drilldown.sql`.

## 9. Spearman correlations confirm the SVI to outcome relationship

Every SVI theme correlates positively with every PLACES outcome we tested, with correlation coefficients ranging from 0.32 to 0.73. The strongest associations are SVI Theme 1 (socioeconomic status) with diabetes and uninsured rate, and SVI Theme 4 (housing and transportation) with smoking and mental distress.

Source: `notebooks/00_exploration.ipynb`, `figures/static/04_correlation_heatmap.png`.

## 10. State infant mortality is at a 5 year high

| Year | IMR per 1,000 |
|---|---|
| 2020 | 8.3 |
| 2021 | 9.3 |
| 2022 | 9.2 |
| 2023 | 8.9 |
| 2024 | **9.7** (highest in the United States) |

The 2024 rate triggered the August 21, 2025 MSDH Public Health Emergency declaration that this entire analysis is responding to.

Source: `data/seed/msdh_imr.csv` (MSDH 2025 Infant Mortality Report, Table 1).
