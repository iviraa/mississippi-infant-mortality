"""Render figures: 4 interactive Folium maps + 7 static charts."""
from __future__ import annotations

import warnings

import folium
import geopandas as gpd
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns
from folium.features import GeoJsonTooltip
from sqlalchemy import text

from pipeline._http import log
from pipeline.config import FIGURES_DIR
from pipeline.db import get_engine

warnings.filterwarnings("ignore")
sns.set_theme(style="whitegrid", context="talk")
plt.rcParams.update({"figure.dpi": 110, "savefig.dpi": 200, "savefig.bbox": "tight"})

INTERACTIVE = FIGURES_DIR / "interactive"
STATIC = FIGURES_DIR / "static"
INTERACTIVE.mkdir(parents=True, exist_ok=True)
STATIC.mkdir(parents=True, exist_ok=True)

ENGINE = get_engine()
MS_CENTER = [32.7, -89.6]


def query(sql: str) -> pd.DataFrame:
    return pd.read_sql(text(sql), ENGINE)


def load_tracts() -> gpd.GeoDataFrame:
    return gpd.read_postgis("""
        SELECT g.tract_fips, g.county_name, g.region, g.is_delta,
               g.total_population, g.geom
        FROM dim_geography g
        WHERE g.geom IS NOT NULL
    """, ENGINE, geom_col="geom")


# Interactive maps

def map_mri():
    log.info("rendering MRI choropleth")
    tracts = load_tracts()
    mri = query("SELECT tract_fips, mri, mri_quintile FROM mart_maternal_risk_index")
    gdf = tracts.merge(mri, on="tract_fips", how="left")

    m = folium.Map(location=MS_CENTER, zoom_start=7, tiles="cartodbpositron")
    folium.Choropleth(
        geo_data=gdf.__geo_interface__, data=gdf,
        columns=["tract_fips", "mri"],
        key_on="feature.properties.tract_fips",
        fill_color="YlOrRd", fill_opacity=0.78, line_opacity=0.15,
        legend_name="Maternal Risk Index (0-100)",
        nan_fill_color="#cccccc",
    ).add_to(m)
    folium.GeoJson(
        gdf.__geo_interface__,
        style_function=lambda x: {"color": "transparent", "fillOpacity": 0},
        tooltip=GeoJsonTooltip(
            fields=["county_name", "tract_fips", "mri", "mri_quintile"],
            aliases=["County", "Tract", "MRI", "Quintile"], localize=True,
        ),
    ).add_to(m)
    folium.LayerControl().add_to(m)
    m.save(INTERACTIVE / "01_mri_choropleth.html")


def map_drive_time():
    log.info("rendering drive-time choropleth")
    tracts = load_tracts()
    dt = query("""
        SELECT tract_fips, distance_miles_rounded, est_drive_minutes,
               drive_time_band, nearest_hospital_name, is_care_desert
        FROM mart_drive_time
    """)
    gdf = tracts.merge(dt, on="tract_fips", how="left")

    m = folium.Map(location=MS_CENTER, zoom_start=7, tiles="cartodbpositron")
    folium.Choropleth(
        geo_data=gdf.__geo_interface__, data=gdf,
        columns=["tract_fips", "distance_miles_rounded"],
        key_on="feature.properties.tract_fips",
        fill_color="PuRd", fill_opacity=0.78, line_opacity=0.15,
        legend_name="Distance to nearest birthing hospital (mi)",
        nan_fill_color="#cccccc",
    ).add_to(m)
    folium.GeoJson(
        gdf.__geo_interface__,
        style_function=lambda x: {"color": "transparent", "fillOpacity": 0},
        tooltip=GeoJsonTooltip(
            fields=["county_name", "distance_miles_rounded", "est_drive_minutes",
                    "drive_time_band", "nearest_hospital_name"],
            aliases=["County", "Miles", "Est. drive (min)", "Band", "Nearest"],
        ),
    ).add_to(m)
    hosp = query("""
        SELECT facility_name, county_name, lat, lon
        FROM dim_facility
        WHERE state_abbr = 'MS' AND is_birthing_friendly AND lat IS NOT NULL
    """)
    for _, h in hosp.iterrows():
        folium.CircleMarker(
            location=[h["lat"], h["lon"]], radius=5, color="navy",
            fill=True, fill_opacity=0.9,
            popup=f"<b>{h['facility_name']}</b><br>{h['county_name']}",
        ).add_to(m)
    m.save(INTERACTIVE / "02_drive_time_choropleth.html")


def map_double_burden():
    log.info("rendering double-burden overlay")
    tracts = load_tracts()
    db = query("""
        SELECT tract_fips, mri, distance_to_birthing_hospital_miles,
               svi_overall, burden_count
        FROM mart_double_burden
    """)
    gdf = tracts.merge(db, on="tract_fips", how="left")

    m = folium.Map(location=MS_CENTER, zoom_start=7, tiles="cartodbpositron")
    color = {0: "#dddddd", 1: "#fed976", 2: "#fd8d3c", 3: "#bd0026"}
    folium.GeoJson(
        gdf.__geo_interface__,
        style_function=lambda f: {
            "fillColor": color.get(f["properties"].get("burden_count") or 0, "#dddddd"),
            "color": "white", "weight": 0.4, "fillOpacity": 0.85,
        },
        tooltip=GeoJsonTooltip(
            fields=["county_name", "burden_count", "mri",
                    "distance_to_birthing_hospital_miles", "svi_overall"],
            aliases=["County", "Burdens", "MRI", "Miles to L&D", "SVI"],
        ),
    ).add_to(m)
    legend = """
    <div style="position: fixed; bottom: 30px; left: 30px; width: 220px;
                background: white; padding: 10px; border: 1px solid #888;
                border-radius: 6px; font-family: sans-serif;">
        <b>Burden count</b> (0-3)<br>
        <i style='background:#bd0026;width:18px;height:14px;display:inline-block'></i> 3 (triple burden)<br>
        <i style='background:#fd8d3c;width:18px;height:14px;display:inline-block'></i> 2<br>
        <i style='background:#fed976;width:18px;height:14px;display:inline-block'></i> 1<br>
        <i style='background:#dddddd;width:18px;height:14px;display:inline-block'></i> 0<br>
        <small>Burdens: top-MRI, &gt;30mi to L&amp;D, top-SVI</small>
    </div>"""
    m.get_root().html.add_child(folium.Element(legend))
    m.save(INTERACTIVE / "03_double_burden_overlay.html")


def map_top20():
    log.info("rendering top-20 priority county map")
    counties = gpd.read_postgis("""
        SELECT geoid AS county_fips, name AS county_label, geom
        FROM stg_tiger_county WHERE statefp = '28'
    """, ENGINE, geom_col="geom")
    p = query("""
        SELECT county_fips, county_name, priority_rank, priority_score, county_mri,
               pct_in_care_desert, imr_per_1000
        FROM mart_top20_priority
    """)
    gdf = counties.merge(p, on="county_fips", how="left")
    gdf["top20"] = (gdf["priority_rank"] <= 20).astype(int)

    m = folium.Map(location=MS_CENTER, zoom_start=7, tiles="cartodbpositron")
    folium.Choropleth(
        geo_data=gdf.__geo_interface__, data=gdf,
        columns=["county_fips", "priority_score"],
        key_on="feature.properties.county_fips",
        fill_color="OrRd", fill_opacity=0.85, line_opacity=0.4,
        legend_name="Priority score (0-100)",
    ).add_to(m)
    folium.GeoJson(
        gdf.__geo_interface__,
        style_function=lambda f: {
            "color": "black" if f["properties"].get("top20") else "white",
            "weight": 3.5 if f["properties"].get("top20") else 0.5,
            "fillOpacity": 0,
        },
        tooltip=GeoJsonTooltip(
            fields=["county_name", "priority_rank", "priority_score",
                    "county_mri", "pct_in_care_desert", "imr_per_1000"],
            aliases=["County", "Rank", "Priority", "MRI", "% in care desert", "IMR"],
        ),
    ).add_to(m)
    m.save(INTERACTIVE / "04_top20_priority.html")


# Static charts

def chart_disparity_by_svi():
    log.info("chart: disparity by SVI quintile")
    df = query("""
        WITH svi_buckets AS (
            SELECT g.geo_sk, NTILE(5) OVER (ORDER BY s.rpl_themes) AS q
            FROM dim_geography g
            JOIN fact_svi_wide s ON s.geo_sk = g.geo_sk
            WHERE s.rpl_themes IS NOT NULL
        )
        SELECT b.q AS svi_quintile, m.short_name AS measure,
               AVG(f.data_value) AS avg_value
        FROM svi_buckets b
        JOIN fact_places f ON f.geo_sk = b.geo_sk
        JOIN dim_measure m ON m.measure_sk = f.measure_sk
        WHERE m.source = 'PLACES'
          AND m.measure_id IN ('DIABETES','BPHIGH','OBESITY','CSMOKING','DEPRESSION','ACCESS2')
          AND f.year_sk = (SELECT MAX(year_sk) FROM fact_places)
        GROUP BY b.q, m.short_name
        ORDER BY b.q, m.short_name
    """)
    pivot = df.pivot(index="svi_quintile", columns="measure", values="avg_value")
    fig, ax = plt.subplots(figsize=(11, 6))
    pivot.plot(kind="bar", ax=ax, colormap="tab10", width=0.8)
    ax.set_xlabel("SVI quintile (1 = least vulnerable, 5 = most vulnerable)")
    ax.set_ylabel("Prevalence (%)")
    ax.set_title("Health outcomes worsen monotonically with social vulnerability")
    ax.legend(loc="upper left", bbox_to_anchor=(1.0, 1.0), title="Measure")
    plt.xticks(rotation=0)
    plt.savefig(STATIC / "01_disparity_by_svi_quintile.png")
    plt.close()


def chart_5year_trends():
    log.info("chart: 5 year trends")
    df = query("""
        SELECT f.year_sk AS year, g.region,
               m.short_name AS measure,
               AVG(f.data_value) AS value
        FROM fact_places f
        JOIN dim_geography g ON g.geo_sk = f.geo_sk
        JOIN dim_measure m ON m.measure_sk = f.measure_sk
        WHERE m.source = 'PLACES'
          AND m.measure_id IN ('DIABETES','DEPRESSION','OBESITY','CSMOKING')
        GROUP BY f.year_sk, g.region, m.short_name
        ORDER BY f.year_sk
    """)
    g = sns.FacetGrid(df, col="measure", col_wrap=2, hue="region",
                      height=3.5, aspect=1.4, sharey=False)
    g.map(sns.lineplot, "year", "value", marker="o", linewidth=2)
    g.add_legend(title="Region")
    g.set_axis_labels("Year", "Prevalence (%)")
    g.fig.suptitle("Mississippi 5 year health trends by region", y=1.04)
    plt.savefig(STATIC / "02_5year_trends.png")
    plt.close()


def chart_hrrp_regressivity():
    log.info("chart: HRRP regressivity")
    df = query("""
        SELECT county_svi_quintile,
               SUM(avg_excess_readmission_ratio * n_hospital_measures)
                 / SUM(n_hospital_measures) AS weighted_avg_err
        FROM mart_hrrp_regressivity
        GROUP BY county_svi_quintile ORDER BY county_svi_quintile
    """)
    fig, ax = plt.subplots(figsize=(9, 5))
    bars = ax.bar(df["county_svi_quintile"].astype(str), df["weighted_avg_err"],
                  color=sns.color_palette("Reds", 5))
    ax.axhline(1.0, color="black", linestyle="--", linewidth=1, label="ERR = 1.0 (expected)")
    ax.set_xlabel("County SVI quintile (1 = least vulnerable)")
    ax.set_ylabel("Avg HRRP Excess Readmission Ratio")
    ax.set_title("HRRP penalties fall harder on hospitals serving high-vulnerability counties")
    ax.legend()
    for bar, val in zip(bars, df["weighted_avg_err"]):
        ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 0.005,
                f"{val:.3f}", ha="center", fontsize=10)
    plt.savefig(STATIC / "03_hrrp_regressivity.png")
    plt.close()


def chart_correlation_heatmap():
    log.info("chart: correlation heatmap")
    from scipy.stats import spearmanr
    df = query("""
        SELECT g.tract_fips,
               s.rpl_theme1, s.rpl_theme2, s.rpl_theme3, s.rpl_theme4, s.rpl_themes,
               MAX(f.data_value) FILTER (WHERE m.measure_id = 'DIABETES')   AS diabetes,
               MAX(f.data_value) FILTER (WHERE m.measure_id = 'BPHIGH')     AS bp_high,
               MAX(f.data_value) FILTER (WHERE m.measure_id = 'OBESITY')    AS obesity,
               MAX(f.data_value) FILTER (WHERE m.measure_id = 'CSMOKING')   AS smoking,
               MAX(f.data_value) FILTER (WHERE m.measure_id = 'DEPRESSION') AS depression,
               MAX(f.data_value) FILTER (WHERE m.measure_id = 'ACCESS2')    AS uninsured
        FROM dim_geography g
        JOIN fact_svi_wide s ON s.geo_sk = g.geo_sk
        JOIN fact_places f ON f.geo_sk = g.geo_sk
        JOIN dim_measure m ON m.measure_sk = f.measure_sk
        WHERE m.source = 'PLACES'
          AND f.year_sk = (SELECT MAX(year_sk) FROM fact_places)
        GROUP BY g.tract_fips, s.rpl_theme1, s.rpl_theme2,
                 s.rpl_theme3, s.rpl_theme4, s.rpl_themes
    """)
    svi_cols = ["rpl_themes", "rpl_theme1", "rpl_theme2", "rpl_theme3", "rpl_theme4"]
    health_cols = ["diabetes", "bp_high", "obesity", "smoking", "depression", "uninsured"]
    df = df.dropna(subset=svi_cols + health_cols)

    corr = pd.DataFrame(index=svi_cols, columns=health_cols, dtype=float)
    for s in svi_cols:
        for h in health_cols:
            r, _ = spearmanr(df[s], df[h])
            corr.loc[s, h] = r
    corr = corr.astype(float)

    fig, ax = plt.subplots(figsize=(8, 5))
    sns.heatmap(corr, annot=True, fmt=".2f", cmap="RdBu_r", center=0,
                vmin=-1, vmax=1, square=True,
                cbar_kws={"label": "Spearman ρ"}, ax=ax)
    ax.set_title(f"SVI themes vs PLACES outcomes (Spearman, n={len(df):,})")
    ax.set_xlabel("PLACES outcome")
    ax.set_ylabel("SVI theme")
    plt.savefig(STATIC / "04_correlation_heatmap.png")
    plt.close()


def chart_top20_table():
    log.info("chart: top-20 priority counties table")
    df = query("""
        SELECT priority_rank, county_name, region, county_mri, pct_in_care_desert,
               imr_per_1000, svi_overall_pct
        FROM mart_top20_priority
        WHERE priority_rank <= 20 ORDER BY priority_rank
    """)
    fig, ax = plt.subplots(figsize=(11, 7))
    ax.axis("off")
    df_disp = df.copy()
    df_disp["imr_per_1000"] = df_disp["imr_per_1000"].fillna(" - ")
    df_disp.columns = ["Rank", "County", "Region", "MRI", "% in care desert",
                       "IMR / 1k", "SVI %ile"]
    tbl = ax.table(cellText=df_disp.values, colLabels=df_disp.columns,
                   loc="center", cellLoc="center")
    tbl.auto_set_font_size(False)
    tbl.set_fontsize(9)
    tbl.scale(1, 1.4)
    ax.set_title("Top 20 priority counties for MSDH intervention", pad=20)
    plt.savefig(STATIC / "05_top20_priority_table.png")
    plt.close()


def chart_care_desert_by_region():
    log.info("chart: care desert by region")
    df = query("""
        SELECT g.region,
               SUM(g.total_population) FILTER (WHERE d.is_care_desert) AS pop_in_desert,
               SUM(g.total_population) AS total_pop
        FROM dim_geography g
        LEFT JOIN mart_drive_time d ON d.tract_fips = g.tract_fips
        GROUP BY g.region
        ORDER BY SUM(g.total_population) FILTER (WHERE d.is_care_desert)::numeric
                 / NULLIF(SUM(g.total_population), 0) DESC
    """)
    df["pct"] = 100.0 * df["pop_in_desert"].fillna(0) / df["total_pop"]
    fig, ax = plt.subplots(figsize=(9, 5))
    sns.barplot(data=df, x="region", y="pct", hue="region",
                palette="Reds_r", legend=False, ax=ax)
    for i, v in enumerate(df["pct"]):
        ax.text(i, v + 0.5, f"{v:.1f}%", ha="center")
    ax.set_ylabel("% population >30 min from a birthing-friendly hospital")
    ax.set_xlabel("Region")
    ax.set_title("Maternity care deserts by Mississippi region")
    plt.xticks(rotation=15)
    plt.savefig(STATIC / "06_care_desert_by_region.png")
    plt.close()


def chart_delta_vs_rest_diabetes():
    log.info("chart: Delta vs rest diabetes distribution")
    df = query("""
        SELECT g.is_delta, f.data_value AS diabetes
        FROM fact_places f
        JOIN dim_geography g ON g.geo_sk = f.geo_sk
        JOIN dim_measure m ON m.measure_sk = f.measure_sk
        WHERE m.source = 'PLACES' AND m.measure_id = 'DIABETES'
          AND f.year_sk = (SELECT MAX(year_sk) FROM fact_places)
    """)
    df["region"] = df["is_delta"].map({True: "Delta", False: "Rest of MS"})
    fig, ax = plt.subplots(figsize=(8, 5))
    sns.violinplot(data=df, x="region", y="diabetes", hue="region",
                   palette={"Delta": "#bd0026", "Rest of MS": "#74a9cf"},
                   inner="quartile", legend=False, ax=ax)
    ax.set_ylabel("Diabetes prevalence (%)")
    ax.set_xlabel("")
    ax.set_title("Tract-level diabetes prevalence: MS Delta vs rest of state")
    ax.axhline(11, color="black", linestyle=":", alpha=0.6, label="National avg ≈ 11%")
    ax.legend()
    plt.savefig(STATIC / "07_delta_vs_rest_diabetes.png")
    plt.close()


def chart_disparity_forest():
    log.info("chart: Black vs White IMR forest plot")
    df = query("""
        WITH bw AS (
            SELECT
                MAX(infant_deaths) FILTER (WHERE county_name ILIKE '%Black race%') AS d_b,
                MAX(live_births)   FILTER (WHERE county_name ILIKE '%Black race%') AS n_b,
                MAX(imr_per_1000)  FILTER (WHERE county_name ILIKE '%Black race%') AS imr_b,
                MAX(infant_deaths) FILTER (WHERE county_name ILIKE '%White race%') AS d_w,
                MAX(live_births)   FILTER (WHERE county_name ILIKE '%White race%') AS n_w,
                MAX(imr_per_1000)  FILTER (WHERE county_name ILIKE '%White race%') AS imr_w
            FROM stg_msdh_imr_race
        )
        SELECT imr_b, imr_w,
            imr_b / imr_w AS rr,
            EXP(LN(imr_b / imr_w) - 1.96 * SQRT(1.0/d_b - 1.0/n_b + 1.0/d_w - 1.0/n_w)) AS ci_lo,
            EXP(LN(imr_b / imr_w) + 1.96 * SQRT(1.0/d_b - 1.0/n_b + 1.0/d_w - 1.0/n_w)) AS ci_hi
        FROM bw
    """).iloc[0]

    rr = float(df["rr"])
    ci_lo = float(df["ci_lo"])
    ci_hi = float(df["ci_hi"])

    fig, ax = plt.subplots(figsize=(9, 3.2))
    ax.axvline(1.0, color="#666666", linestyle="--", linewidth=1.2,
               label="Null effect (RR = 1.0)")
    ax.errorbar(rr, 0.5, xerr=[[rr - ci_lo], [ci_hi - rr]],
                fmt="s", color="#bd0026", markersize=18,
                capsize=10, capthick=2.2, elinewidth=2.2)
    ax.annotate(f"RR = {rr:.2f}\n95% CI [{ci_lo:.2f}, {ci_hi:.2f}]",
                xy=(rr, 0.5), xytext=(rr, 0.78),
                ha="center", va="bottom", fontsize=13, fontweight="bold")
    ax.set_xlim(0.5, max(4.0, ci_hi + 0.6))
    ax.set_ylim(0, 1)
    ax.set_yticks([])
    ax.set_xlabel("Infant mortality rate ratio, Black vs White (Mississippi 2024)")
    ax.set_title("Black vs White infant mortality rate ratio with 95% confidence interval")
    for spine in ("left", "right", "top"):
        ax.spines[spine].set_visible(False)
    ax.legend(loc="upper left", frameon=False, fontsize=11)
    plt.tight_layout()
    plt.savefig(STATIC / "08_disparity_forest.png")
    plt.close()


def _ms_polygon_axes(figsize=(9, 11)):
    fig, ax = plt.subplots(figsize=figsize)
    ax.set_axis_off()
    return fig, ax


def static_map_mri():
    log.info("static map: MRI choropleth")
    tracts = load_tracts().to_crs(epsg=5070)
    mri = query("SELECT tract_fips, mri FROM mart_maternal_risk_index")
    gdf = tracts.merge(mri, on="tract_fips", how="left")

    fig, ax = _ms_polygon_axes()
    gdf.plot(column="mri", cmap="YlOrRd", linewidth=0.15, edgecolor="white",
             legend=True, missing_kwds={"color": "#cccccc"}, ax=ax,
             legend_kwds={"label": "Maternal Risk Index (0 to 100)",
                          "orientation": "horizontal", "shrink": 0.55, "pad": 0.02})
    ax.set_title("Maternal Risk Index by Mississippi census tract", fontsize=16, pad=12)
    plt.savefig(STATIC / "09_mri_choropleth.png")
    plt.close()


def static_map_drive_time():
    log.info("static map: drive time choropleth")
    tracts = load_tracts().to_crs(epsg=5070)
    dt = query("""
        SELECT tract_fips, distance_miles_rounded
        FROM mart_drive_time
    """)
    gdf = tracts.merge(dt, on="tract_fips", how="left")

    hosp = query("""
        SELECT lat, lon FROM dim_facility
        WHERE state_abbr = 'MS' AND is_birthing_friendly AND lat IS NOT NULL
    """)
    hosp_gdf = gpd.GeoDataFrame(
        hosp, geometry=gpd.points_from_xy(hosp["lon"], hosp["lat"]),
        crs="EPSG:4326",
    ).to_crs(epsg=5070)

    fig, ax = _ms_polygon_axes()
    gdf.plot(column="distance_miles_rounded", cmap="PuRd", linewidth=0.15,
             edgecolor="white", legend=True,
             missing_kwds={"color": "#cccccc"}, ax=ax,
             legend_kwds={"label": "Drive distance to nearest birthing hospital (mi)",
                          "orientation": "horizontal", "shrink": 0.55, "pad": 0.02})
    hosp_gdf.plot(ax=ax, color="navy", markersize=28, marker="o",
                  edgecolor="white", linewidth=0.6, label="Birthing-friendly hospital")
    ax.legend(loc="lower left", frameon=True, fontsize=10)
    ax.set_title("Drive distance to nearest birthing-friendly hospital", fontsize=16, pad=12)
    plt.savefig(STATIC / "10_drive_time_choropleth.png")
    plt.close()


def static_map_double_burden():
    log.info("static map: double burden overlay")
    tracts = load_tracts().to_crs(epsg=5070)
    db = query("SELECT tract_fips, burden_count FROM mart_double_burden")
    gdf = tracts.merge(db, on="tract_fips", how="left")
    gdf["burden_count"] = gdf["burden_count"].fillna(0).astype(int)

    color_map = {0: "#dddddd", 1: "#fed976", 2: "#fd8d3c", 3: "#bd0026"}
    gdf["color"] = gdf["burden_count"].map(color_map)

    fig, ax = _ms_polygon_axes()
    gdf.plot(color=gdf["color"], linewidth=0.2, edgecolor="white", ax=ax)

    from matplotlib.patches import Patch
    legend_handles = [
        Patch(facecolor="#bd0026", edgecolor="white", label="3 (triple burden)"),
        Patch(facecolor="#fd8d3c", edgecolor="white", label="2"),
        Patch(facecolor="#fed976", edgecolor="white", label="1"),
        Patch(facecolor="#dddddd", edgecolor="white", label="0"),
    ]
    ax.legend(handles=legend_handles, title="Burden count",
              loc="lower left", frameon=True, fontsize=10, title_fontsize=11)
    ax.set_title("Tracts carrying multiple maternal risk burdens", fontsize=16, pad=12)
    plt.savefig(STATIC / "11_double_burden_overlay.png")
    plt.close()


def static_map_top20():
    log.info("static map: top 20 priority counties")
    counties = gpd.read_postgis("""
        SELECT geoid AS county_fips, geom
        FROM stg_tiger_county WHERE statefp = '28'
    """, ENGINE, geom_col="geom").to_crs(epsg=5070)
    p = query("""
        SELECT county_fips, county_name, priority_rank, priority_score
        FROM mart_top20_priority
    """)
    gdf = counties.merge(p, on="county_fips", how="left")
    gdf["top20"] = (gdf["priority_rank"] <= 20).fillna(False)

    fig, ax = _ms_polygon_axes()
    gdf.plot(column="priority_score", cmap="OrRd", linewidth=0.5,
             edgecolor="white", legend=True, ax=ax,
             missing_kwds={"color": "#eeeeee"},
             legend_kwds={"label": "Priority score (0 to 100)",
                          "orientation": "horizontal", "shrink": 0.55, "pad": 0.02})
    gdf[gdf["top20"]].boundary.plot(ax=ax, edgecolor="black", linewidth=2.2)

    # Label the top 5 counties
    top5 = gdf[gdf["priority_rank"] <= 5].copy()
    top5["centroid"] = top5.geometry.centroid
    for _, row in top5.iterrows():
        ax.annotate(f'{int(row["priority_rank"])}. {row["county_name"]}',
                    xy=(row["centroid"].x, row["centroid"].y),
                    ha="center", va="center", fontsize=10, fontweight="bold",
                    color="black",
                    bbox=dict(boxstyle="round,pad=0.25", fc="white",
                              ec="black", lw=0.6, alpha=0.9))
    ax.set_title("Top 20 priority counties for state intervention", fontsize=16, pad=12)
    plt.savefig(STATIC / "12_top20_priority_map.png")
    plt.close()


def main() -> None:
    log.info("=== Rendering interactive maps ===")
    map_mri()
    map_drive_time()
    map_double_burden()
    map_top20()

    log.info("=== Rendering static charts ===")
    chart_disparity_by_svi()
    chart_5year_trends()
    chart_hrrp_regressivity()
    chart_correlation_heatmap()
    chart_top20_table()
    chart_care_desert_by_region()
    chart_delta_vs_rest_diabetes()
    chart_disparity_forest()

    log.info("=== Rendering static versions of interactive maps ===")
    static_map_mri()
    static_map_drive_time()
    static_map_double_burden()
    static_map_top20()
    log.info("=== Figures complete ===")


if __name__ == "__main__":
    main()
