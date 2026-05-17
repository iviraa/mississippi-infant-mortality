--
-- PostgreSQL database dump
--

\restrict ueResqRHNf7H7eaJeIs80EJIdw5etX2Slai1QYtacINIoUVqXp9eWLSaTUohvFY

-- Dumped from database version 18.4 (Homebrew)
-- Dumped by pg_dump version 18.4 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: dim_facility; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dim_facility (
    facility_sk bigint NOT NULL,
    ccn character varying(10) NOT NULL,
    facility_name character varying(255) NOT NULL,
    address character varying(255),
    city character varying(80),
    state_abbr character varying(2),
    zip_code character varying(10),
    county_name character varying(80),
    county_fips character varying(5),
    hospital_type character varying(80),
    hospital_ownership character varying(80),
    emergency_services boolean,
    is_birthing_friendly boolean,
    overall_rating integer,
    lat numeric(9,6),
    lon numeric(9,6),
    geom public.geometry(Point,4269)
);


--
-- Name: dim_facility_facility_sk_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.dim_facility ALTER COLUMN facility_sk ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.dim_facility_facility_sk_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: dim_geography; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dim_geography (
    geo_sk bigint NOT NULL,
    tract_fips character varying(11) NOT NULL,
    county_fips character varying(5) NOT NULL,
    county_name character varying(60) NOT NULL,
    state_fips character varying(2) NOT NULL,
    state_abbr character varying(2) NOT NULL,
    region character varying(20),
    is_delta boolean DEFAULT false NOT NULL,
    is_gulf_coast boolean DEFAULT false NOT NULL,
    is_rural boolean,
    total_population integer,
    centroid_lat numeric(9,6),
    centroid_lon numeric(9,6),
    geom public.geometry(MultiPolygon,4269),
    centroid_geom public.geometry(Point,4269)
);


--
-- Name: dim_geography_geo_sk_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.dim_geography ALTER COLUMN geo_sk ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.dim_geography_geo_sk_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: dim_measure; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dim_measure (
    measure_sk bigint NOT NULL,
    source character varying(20) NOT NULL,
    measure_id character varying(60) NOT NULL,
    measure_name character varying(255) NOT NULL,
    short_name character varying(80),
    category character varying(80),
    unit character varying(40),
    higher_is_worse boolean
);


--
-- Name: dim_measure_measure_sk_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.dim_measure ALTER COLUMN measure_sk ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.dim_measure_measure_sk_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: dim_year; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dim_year (
    year_sk integer NOT NULL,
    brfss_year integer,
    release_label character varying(60),
    notes text
);


--
-- Name: fact_acs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fact_acs (
    geo_sk bigint NOT NULL,
    measure_sk bigint NOT NULL,
    year_sk integer NOT NULL,
    estimate numeric,
    moe numeric
);


--
-- Name: fact_hospital_quality; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fact_hospital_quality (
    facility_sk bigint NOT NULL,
    measure_id character varying(60) NOT NULL,
    measure_name character varying(255),
    measure_type character varying(40) NOT NULL,
    score numeric,
    discharges integer,
    period_start date,
    period_end date
);


--
-- Name: fact_hpsa_county; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fact_hpsa_county (
    county_fips character varying(5) NOT NULL,
    discipline character varying(40) NOT NULL,
    avg_hpsa_score numeric,
    max_hpsa_score numeric,
    n_hpsa_designations integer,
    underserved_population bigint
);


--
-- Name: fact_imr; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fact_imr (
    county_fips character varying(5) NOT NULL,
    year_sk integer NOT NULL,
    live_births integer,
    infant_deaths integer,
    imr_per_1000 numeric,
    neonatal_deaths integer,
    postneonatal_deaths integer
);


--
-- Name: fact_places; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fact_places (
    geo_sk bigint NOT NULL,
    measure_sk bigint NOT NULL,
    year_sk integer NOT NULL,
    data_value numeric,
    low_ci numeric,
    high_ci numeric,
    total_population integer
);


--
-- Name: fact_svi; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fact_svi (
    geo_sk bigint NOT NULL,
    measure_sk bigint NOT NULL,
    year_sk integer NOT NULL,
    data_value numeric
);


--
-- Name: fact_svi_wide; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fact_svi_wide (
    geo_sk bigint NOT NULL,
    year_sk integer NOT NULL,
    rpl_themes numeric,
    rpl_theme1 numeric,
    rpl_theme2 numeric,
    rpl_theme3 numeric,
    rpl_theme4 numeric,
    f_total smallint,
    ep_pov150 numeric,
    ep_unemp numeric,
    ep_uninsur numeric,
    ep_nohsdp numeric,
    ep_minrty numeric,
    ep_noveh numeric,
    ep_noint numeric,
    ep_disabl numeric,
    ep_sngpnt numeric,
    ep_mobile numeric
);


--
-- Name: mart_double_burden; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mart_double_burden (
    tract_fips character varying(11),
    county_name character varying(60),
    region character varying(20),
    is_delta boolean,
    total_population integer,
    mri numeric,
    mri_quintile integer,
    distance_to_birthing_hospital_miles numeric,
    est_drive_minutes numeric,
    drive_time_band text,
    nearest_hospital_name character varying(255),
    svi_overall numeric,
    pct_uninsured numeric,
    top_mri boolean,
    is_care_desert boolean,
    top_svi boolean,
    burden_count integer
);


--
-- Name: mart_drive_time; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mart_drive_time (
    geo_sk bigint,
    tract_fips character varying(11),
    county_fips character varying(5),
    county_name character varying(60),
    region character varying(20),
    is_delta boolean,
    total_population integer,
    nearest_hospital_sk bigint,
    nearest_hospital_name character varying(255),
    distance_miles double precision,
    distance_miles_rounded numeric,
    est_drive_minutes numeric,
    drive_time_band text,
    is_care_desert boolean
);


--
-- Name: mart_hrrp_regressivity; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mart_hrrp_regressivity (
    county_svi_quintile integer,
    hrrp_measure character varying(60),
    n_hospital_measures bigint,
    avg_excess_readmission_ratio numeric,
    median_err numeric,
    min_err numeric,
    max_err numeric,
    n_worse_than_expected bigint,
    pct_worse_than_expected numeric
);


--
-- Name: mart_maternal_risk_index; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mart_maternal_risk_index (
    tract_fips character varying(11),
    county_fips character varying(5),
    county_name character varying(60),
    region character varying(20),
    is_delta boolean,
    total_population integer,
    pre_existing_avg numeric,
    mental_health_avg numeric,
    access_risk_raw numeric,
    structural_risk_raw numeric,
    pre_existing_score numeric,
    mental_health_score numeric,
    access_score numeric,
    structural_score numeric,
    mri numeric,
    mri_quintile integer,
    rpl_themes numeric
);


--
-- Name: mart_top20_priority; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mart_top20_priority (
    county_fips character varying(5),
    county_name character varying(60),
    region character varying(20),
    is_delta boolean,
    county_pop bigint,
    county_mri numeric,
    pct_in_care_desert numeric,
    imr_per_1000 numeric,
    svi_overall_pct numeric,
    pct_uninsured numeric,
    priority_score numeric,
    priority_rank bigint
);


--
-- Name: stg_msdh_imr_race; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stg_msdh_imr_race (
    county_name text,
    county_fips text,
    year bigint,
    live_births bigint,
    infant_deaths bigint,
    imr_per_1000 double precision,
    notes text
);


--
-- Name: svi_county; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.svi_county (
    county_fips text,
    county_name text,
    rpl_themes double precision,
    pct_uninsured double precision
);


--
-- Name: dim_facility dim_facility_ccn_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dim_facility
    ADD CONSTRAINT dim_facility_ccn_key UNIQUE (ccn);


--
-- Name: dim_facility dim_facility_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dim_facility
    ADD CONSTRAINT dim_facility_pkey PRIMARY KEY (facility_sk);


--
-- Name: dim_geography dim_geography_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dim_geography
    ADD CONSTRAINT dim_geography_pkey PRIMARY KEY (geo_sk);


--
-- Name: dim_geography dim_geography_tract_fips_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dim_geography
    ADD CONSTRAINT dim_geography_tract_fips_key UNIQUE (tract_fips);


--
-- Name: dim_measure dim_measure_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dim_measure
    ADD CONSTRAINT dim_measure_pkey PRIMARY KEY (measure_sk);


--
-- Name: dim_measure dim_measure_source_measure_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dim_measure
    ADD CONSTRAINT dim_measure_source_measure_id_key UNIQUE (source, measure_id);


--
-- Name: dim_year dim_year_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dim_year
    ADD CONSTRAINT dim_year_pkey PRIMARY KEY (year_sk);


--
-- Name: fact_acs fact_acs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_acs
    ADD CONSTRAINT fact_acs_pkey PRIMARY KEY (geo_sk, measure_sk, year_sk);


--
-- Name: fact_hospital_quality fact_hospital_quality_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_hospital_quality
    ADD CONSTRAINT fact_hospital_quality_pkey PRIMARY KEY (facility_sk, measure_id, measure_type);


--
-- Name: fact_hpsa_county fact_hpsa_county_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_hpsa_county
    ADD CONSTRAINT fact_hpsa_county_pkey PRIMARY KEY (county_fips, discipline);


--
-- Name: fact_imr fact_imr_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_imr
    ADD CONSTRAINT fact_imr_pkey PRIMARY KEY (county_fips, year_sk);


--
-- Name: fact_places fact_places_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_places
    ADD CONSTRAINT fact_places_pkey PRIMARY KEY (geo_sk, measure_sk, year_sk);


--
-- Name: fact_svi fact_svi_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_svi
    ADD CONSTRAINT fact_svi_pkey PRIMARY KEY (geo_sk, measure_sk, year_sk);


--
-- Name: fact_svi_wide fact_svi_wide_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_svi_wide
    ADD CONSTRAINT fact_svi_wide_pkey PRIMARY KEY (geo_sk);


--
-- Name: idx_dim_facility_birthing; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dim_facility_birthing ON public.dim_facility USING btree (is_birthing_friendly) WHERE is_birthing_friendly;


--
-- Name: idx_dim_facility_county; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dim_facility_county ON public.dim_facility USING btree (county_fips);


--
-- Name: idx_dim_facility_geom; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dim_facility_geom ON public.dim_facility USING gist (geom);


--
-- Name: idx_dim_facility_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dim_facility_state ON public.dim_facility USING btree (state_abbr);


--
-- Name: idx_dim_geography_centroid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dim_geography_centroid ON public.dim_geography USING gist (centroid_geom);


--
-- Name: idx_dim_geography_county; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dim_geography_county ON public.dim_geography USING btree (county_fips);


--
-- Name: idx_dim_geography_geom; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dim_geography_geom ON public.dim_geography USING gist (geom);


--
-- Name: idx_dim_geography_region; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dim_geography_region ON public.dim_geography USING btree (region);


--
-- Name: idx_dim_measure_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dim_measure_category ON public.dim_measure USING btree (category);


--
-- Name: idx_double_burden_count; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_double_burden_count ON public.mart_double_burden USING btree (burden_count DESC);


--
-- Name: idx_drive_time_band; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_drive_time_band ON public.mart_drive_time USING btree (drive_time_band);


--
-- Name: idx_drive_time_county; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_drive_time_county ON public.mart_drive_time USING btree (county_fips);


--
-- Name: idx_fact_acs_geo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fact_acs_geo ON public.fact_acs USING btree (geo_sk, year_sk);


--
-- Name: idx_fact_acs_measure; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fact_acs_measure ON public.fact_acs USING btree (measure_sk);


--
-- Name: idx_fact_hospquality_measure; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fact_hospquality_measure ON public.fact_hospital_quality USING btree (measure_id);


--
-- Name: idx_fact_imr_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fact_imr_year ON public.fact_imr USING btree (year_sk);


--
-- Name: idx_fact_places_geo_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fact_places_geo_year ON public.fact_places USING btree (geo_sk, year_sk);


--
-- Name: idx_fact_places_measure; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fact_places_measure ON public.fact_places USING btree (measure_sk);


--
-- Name: idx_fact_places_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fact_places_year ON public.fact_places USING btree (year_sk);


--
-- Name: idx_fact_svi_measure; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fact_svi_measure ON public.fact_svi USING btree (measure_sk);


--
-- Name: idx_mri_county; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mri_county ON public.mart_maternal_risk_index USING btree (county_fips);


--
-- Name: idx_mri_score; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mri_score ON public.mart_maternal_risk_index USING btree (mri DESC);


--
-- Name: idx_svi_county_fips; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_svi_county_fips ON public.svi_county USING btree (county_fips);


--
-- Name: idx_top20_rank; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_top20_rank ON public.mart_top20_priority USING btree (priority_rank);


--
-- Name: fact_acs fact_acs_geo_sk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_acs
    ADD CONSTRAINT fact_acs_geo_sk_fkey FOREIGN KEY (geo_sk) REFERENCES public.dim_geography(geo_sk);


--
-- Name: fact_acs fact_acs_measure_sk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_acs
    ADD CONSTRAINT fact_acs_measure_sk_fkey FOREIGN KEY (measure_sk) REFERENCES public.dim_measure(measure_sk);


--
-- Name: fact_acs fact_acs_year_sk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_acs
    ADD CONSTRAINT fact_acs_year_sk_fkey FOREIGN KEY (year_sk) REFERENCES public.dim_year(year_sk);


--
-- Name: fact_hospital_quality fact_hospital_quality_facility_sk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_hospital_quality
    ADD CONSTRAINT fact_hospital_quality_facility_sk_fkey FOREIGN KEY (facility_sk) REFERENCES public.dim_facility(facility_sk);


--
-- Name: fact_imr fact_imr_year_sk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_imr
    ADD CONSTRAINT fact_imr_year_sk_fkey FOREIGN KEY (year_sk) REFERENCES public.dim_year(year_sk);


--
-- Name: fact_places fact_places_geo_sk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_places
    ADD CONSTRAINT fact_places_geo_sk_fkey FOREIGN KEY (geo_sk) REFERENCES public.dim_geography(geo_sk);


--
-- Name: fact_places fact_places_measure_sk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_places
    ADD CONSTRAINT fact_places_measure_sk_fkey FOREIGN KEY (measure_sk) REFERENCES public.dim_measure(measure_sk);


--
-- Name: fact_places fact_places_year_sk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_places
    ADD CONSTRAINT fact_places_year_sk_fkey FOREIGN KEY (year_sk) REFERENCES public.dim_year(year_sk);


--
-- Name: fact_svi fact_svi_geo_sk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_svi
    ADD CONSTRAINT fact_svi_geo_sk_fkey FOREIGN KEY (geo_sk) REFERENCES public.dim_geography(geo_sk);


--
-- Name: fact_svi fact_svi_measure_sk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_svi
    ADD CONSTRAINT fact_svi_measure_sk_fkey FOREIGN KEY (measure_sk) REFERENCES public.dim_measure(measure_sk);


--
-- Name: fact_svi_wide fact_svi_wide_geo_sk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_svi_wide
    ADD CONSTRAINT fact_svi_wide_geo_sk_fkey FOREIGN KEY (geo_sk) REFERENCES public.dim_geography(geo_sk);


--
-- Name: fact_svi_wide fact_svi_wide_year_sk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_svi_wide
    ADD CONSTRAINT fact_svi_wide_year_sk_fkey FOREIGN KEY (year_sk) REFERENCES public.dim_year(year_sk);


--
-- Name: fact_svi fact_svi_year_sk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_svi
    ADD CONSTRAINT fact_svi_year_sk_fkey FOREIGN KEY (year_sk) REFERENCES public.dim_year(year_sk);


--
-- PostgreSQL database dump complete
--

\unrestrict ueResqRHNf7H7eaJeIs80EJIdw5etX2Slai1QYtacINIoUVqXp9eWLSaTUohvFY

