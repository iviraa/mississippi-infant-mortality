# Seed data

Curated reference data that ships with the repo because the original sources are behind interactive query tools (CDC WONDER), only available as PDFs (MSDH annual reports), or otherwise not directly downloadable via API.

## `msdh_imr.csv`

Mississippi infant mortality at county and year granularity. All values are transcribed from the [MSDH 2025 Infant Mortality Report](https://msdh.ms.gov/msdhsite/index.cfm/29,21453,299,pdf/Infant_Mortality_Report_2025.pdf).

The file combines three different aggregations from that report. State by year rates for 2020 through 2024 come from Table 1. Race specific 2024 rates (Black 15.2, White 5.8, Hispanic 6.3 per 1,000 live births) come from Table 2. County level rates come from Figure 7, which reports a 5 year aggregate covering 2020 through 2024 so that small populations produce stable estimates. Counties with fewer than five infant deaths over the 5 year window are suppressed in the source and appear as `NULL` in `imr_per_1000`.

The 2024 state rate of 9.7 per 1,000 live births, which is the highest in the United States, is the figure that triggered the August 21, 2025 MSDH Public Health Emergency declaration.

To refresh from source, see `docs/data_dictionary.md` for the field by field specification and which page of the MSDH report each value comes from.
