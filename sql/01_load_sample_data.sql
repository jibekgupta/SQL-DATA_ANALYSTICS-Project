/*
================================================================================
Load Sample Data (PostgreSQL + psql)
================================================================================

Purpose
- Load the committed sample CSVs from `data/sample/` into the `gold` schema.

How to run
- From the repo root:
    psql "$DATABASE_URL" -f sql/00_schema.sql
    psql "$DATABASE_URL" -f sql/01_load_sample_data.sql

Notes
- Uses psql meta-commands (`\copy`, `\cd`), so this should be executed with `psql`,
  not through a generic SQL runner.
================================================================================
*/

\set ON_ERROR_STOP on
\cd :DIRNAME
\cd ..

TRUNCATE TABLE gold.fact_sales, gold.dim_products, gold.dim_customers;

-- Dimensions first (referenced by fact table)
\copy gold.dim_customers FROM 'data/sample/dim_customers_sample.csv' WITH (FORMAT csv, HEADER true);
\copy gold.dim_products  FROM 'data/sample/dim_products_sample.csv'  WITH (FORMAT csv, HEADER true);

-- Fact table last (requires referenced keys to exist)
\copy gold.fact_sales    FROM 'data/sample/fact_sales_sample.csv'    WITH (FORMAT csv, HEADER true);

