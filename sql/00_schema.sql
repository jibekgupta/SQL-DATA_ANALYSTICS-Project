/*
===============================================================================
Database & Schema Setup
===============================================================================
Purpose:
    - Create (or recreate) the DataWarehouseAnalytics database.
    - Define the three core tables in the gold schema:
        1) gold.dim_customers  : customer dimension (who bought)
        2) gold.dim_products   : product dimension (what was sold)
        3) gold.fact_sales     : sales fact table (the transactions)

Notes:
    - Run this script first before loading any data or running analysis queries.
    - DROP statements ensure a clean slate if tables already exist.
===============================================================================
*/


-- Drop and recreate the database (run manually if needed)
DROP DATABASE IF EXISTS "DataWarehouseAnalystics";
CREATE DATABASE "DataWarehouseAnalytics";


-- ============================================================================
-- Table: gold.dim_customers
-- Description: Customer dimension — one row per customer.
-- ============================================================================
CREATE TABLE gold.dim_customers (
  customer_key     INTEGER,          -- surrogate key (unique identifier)
  customer_id      INTEGER,          -- business/source system ID
  customer_number  VARCHAR(20),      -- human-readable customer code (e.g. AW00011000)
  first_name       VARCHAR(50),
  last_name        VARCHAR(50),
  country          VARCHAR(50),      -- customer's country
  marital_status   VARCHAR(20),      -- Married / Single
  gender           VARCHAR(10),      -- Male / Female
  birthdate        DATE,             -- used to calculate age
  create_date      DATE              -- when the customer record was created
);


-- ============================================================================
-- Table: gold.dim_products
-- Description: Product dimension — one row per product.
-- ============================================================================
DROP TABLE IF EXISTS gold.dim_products;

CREATE TABLE gold.dim_products (
  product_key     INTEGER,           -- surrogate key
  product_id      INTEGER,           -- business/source system ID
  product_number  VARCHAR(50),       -- SKU / product code
  product_name    VARCHAR(255),      -- full product name
  category_id     VARCHAR(20),       -- category code
  category        VARCHAR(100),      -- top-level category (e.g. Bikes, Components)
  subcategory     VARCHAR(100),      -- sub-category (e.g. Mountain Bikes, Road Frames)
  maintenance     BOOLEAN,           -- whether the product requires maintenance
  cost            NUMERIC(12,2),     -- unit cost of the product
  product_line    VARCHAR(50),       -- product line (Road, Mountain, etc.)
  start_date      DATE               -- when the product became available
);


-- ============================================================================
-- Table: gold.fact_sales
-- Description: Sales fact table — one row per order line item.
--              Links to dim_customers via customer_key
--              and to dim_products via product_key.
-- ============================================================================
DROP TABLE IF EXISTS gold.fact_sales;

CREATE TABLE gold.fact_sales (
  order_number    VARCHAR(30),       -- order identifier (e.g. SO54496)
  product_key     INTEGER,           -- FK to gold.dim_products
  customer_key    INTEGER,           -- FK to gold.dim_customers
  order_date      DATE,              -- when the order was placed
  shipping_date   DATE,              -- when the order was shipped
  due_date        DATE,              -- expected delivery date
  sales_amount    NUMERIC(12,2),     -- revenue from this line item
  quantity        INTEGER,           -- number of units in this line
  price           NUMERIC(12,2)      -- unit price
);
