# Mississippi Maternal and Infant Mortality Analysis: pipeline orchestration

PYTHON := .venv/bin/python
PIP := .venv/bin/pip

ifneq (,$(wildcard .env))
include .env
export
endif

PSQL := psql -h $${PGHOST:-localhost} -p $${PGPORT:-5432} -U $${PGUSER:-$$USER}
DB := $${PGDATABASE:-ms_health}

.PHONY: install db schema extract load marts figures export all clean help

help:
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-12s\033[0m %s\n", $$1, $$2}'

install: ## Create venv + install requirements
	python3 -m venv .venv
	$(PIP) install --upgrade pip
	$(PIP) install -r requirements.txt
	@echo "Done. Activate with: source .venv/bin/activate"

db: ## Create database + enable PostGIS
	-$(PSQL) -c "CREATE DATABASE $(DB);"
	$(PSQL) -d $(DB) -c "CREATE EXTENSION IF NOT EXISTS postgis;"

schema: ## Run DDL scripts
	$(PSQL) -d $(DB) -f sql/ddl/01_extensions.sql
	$(PSQL) -d $(DB) -f sql/ddl/02_dimensions.sql
	$(PSQL) -d $(DB) -f sql/ddl/03_facts.sql
	$(PSQL) -d $(DB) -f sql/ddl/04_indexes.sql

extract: ## Download source data into data/raw/
	$(PYTHON) -m pipeline.extract_places
	$(PYTHON) -m pipeline.extract_svi
	$(PYTHON) -m pipeline.extract_acs
	$(PYTHON) -m pipeline.extract_cms
	$(PYTHON) -m pipeline.extract_hrsa
	$(PYTHON) -m pipeline.extract_tiger
	$(PYTHON) -m pipeline.extract_msdh

load: ## ETL: clean CSVs in pandas, load typed tables to Postgres
	$(PYTHON) -m pipeline.load

marts: ## Build analytical marts
	$(PSQL) -d $(DB) -f sql/marts/01_mart_maternal_risk_index.sql
	$(PSQL) -d $(DB) -f sql/marts/02_mart_drive_time.sql
	$(PSQL) -d $(DB) -f sql/marts/03_mart_double_burden.sql
	$(PSQL) -d $(DB) -f sql/marts/04_mart_top20_priority.sql
	$(PSQL) -d $(DB) -f sql/marts/05_mart_hrrp_regressivity.sql

figures: ## Render maps + charts
	$(PYTHON) -m pipeline.render_figures

export: ## Export schema.sql and table CSVs to data/processed/
	$(PYTHON) -m pipeline.export

all: db schema extract load marts figures export ## Full pipeline

clean: ## Drop database + clear caches
	-$(PSQL) -c "DROP DATABASE IF EXISTS $(DB);"
	rm -rf data/raw data/cache __pycache__ pipeline/__pycache__
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type d -name .ipynb_checkpoints -exec rm -rf {} +
