/*
===============================================================================
Customer Report
===============================================================================
Purpose:
    - Consolidate key customer metrics and behaviors into a single report.

Highlights:
    1. Gathers essential fields such as names, ages, and transaction details.
    2. Segments customers into categories (VIP, Regular, New) and age groups.
    3. Aggregates customer-level metrics:
        - total orders
        - total sales
        - total quantity purchased
        - total products
        - lifespan (in months)
    4. Calculates valuable KPIs:
        - recency (months since last order)
        - average order value
        - average monthly spend

Source Tables:
    - gold.fact_sales      : order-level data (revenue, dates, quantities)
    - gold.dim_customers   : customer attributes (name, birthdate, etc.)

Build-up:
    - The file contains incremental queries that build toward the final
      CREATE VIEW statement at the bottom. Each step adds a layer of logic.
===============================================================================
*/


-- ============================================================================
-- Step 1: Base Query
-- Retrieves core columns from fact_sales joined to dim_customers.
-- CONCAT builds a full name; AGE calculates the customer's current age.
-- Rows without an order_date are excluded.
-- ============================================================================
SELECT 
f.order_number,
f.product_key,
f.order_date,
f.sales_amount,
f.quantity,
c.customer_key,
c.customer_number,
CONCAT(c.first_name, ' ', c.last_name) AS customer_name,  -- full name
DATE_PART('year',AGE(c.birthdate)) AS age                  -- current age in years
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
ON c.customer_key = f.customer_key
WHERE f.order_date IS NOT NULL;


-- ============================================================================
-- Step 2: Customer Aggregation
-- Wraps the base query in a CTE and groups by customer to produce:
--   total_orders   : number of distinct orders
--   total_sales    : lifetime revenue
--   total_quantity : total units purchased
--   total_products : number of distinct products bought
--   last_order_date: most recent order
--   lifespan       : months between first and last order (using AGE)
-- ============================================================================
WITH base_query
AS (
SELECT 
f.order_number,
f.product_key,
f.order_date,
f.sales_amount,
f.quantity,
c.customer_key,
c.customer_number,
CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
DATE_PART('year',AGE(c.birthdate)) AS age
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
ON c.customer_key = f.customer_key
WHERE f.order_date IS NOT NULL
)

SELECT 
customer_key,
customer_number,
customer_name,
age,
COUNT(DISTINCT order_number) AS total_orders,
SUM(sales_amount) AS total_sales,
SUM(quantity) AS total_quantity,
COUNT(DISTINCT product_key) AS total_products,
MAX(order_date) AS last_order_date,
(DATE_PART('year', AGE(MAX(order_date), MIN(order_date))) * 12 + 
 DATE_PART('month', AGE(MAX(order_date), MIN(order_date)))) AS lifespan  -- months between first and last order
FROM base_query
GROUP BY customer_key,
customer_number,
customer_name,
age;


-- ============================================================================
-- Step 3 (incomplete CTE — kept for reference)
-- This was a work-in-progress combining base_query + customer_aggregation
-- but has no final SELECT. See Step 4 for the completed version.
-- ============================================================================
WITH base_query
AS (
SELECT 
f.order_number,
f.product_key,
f.order_date,
f.sales_amount,
f.quantity,
c.customer_key,
c.customer_number,
CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
DATE_PART('year',AGE(c.birthdate)) AS age
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
ON c.customer_key = f.customer_key
WHERE f.order_date IS NOT NULL
)
, customer_aggregation AS (
SELECT 
customer_key,
customer_number,
customer_name,
age,
COUNT(DISTINCT order_number) AS total_orders,
SUM(sales_amount) AS total_sales,
SUM(quantity) AS total_quantity,
COUNT(DISTINCT product_key) AS total_products,
MAX(order_date) AS last_order_date,
(DATE_PART('year', AGE(MAX(order_date), MIN(order_date))) * 12 + 
 DATE_PART('month', AGE(MAX(order_date), MIN(order_date)))) AS lifespan
FROM base_query
GROUP BY customer_key,
customer_number,
customer_name,
age)


-- ============================================================================
-- Step 4: Full report query with segmentation and KPIs
-- Adds on top of the aggregation:
--   age_group         : buckets age into ranges (Under 20, 20-29, etc.)
--   customer_segment  : VIP / Regular / New based on lifespan + total_sales
--   recency_months    : months since last purchase (from today)
--   avg_order_value   : total_sales / total_orders (guarded against divide-by-zero)
--   avg_monthly_spend : total_sales / lifespan (if lifespan is 0, returns total_sales)
-- ============================================================================
WITH base_query
AS (
SELECT 
f.order_number,
f.product_key,
f.order_date,
f.sales_amount,
f.quantity,
c.customer_key,
c.customer_number,
CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
DATE_PART('year',AGE(c.birthdate)) AS age
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
ON c.customer_key = f.customer_key
WHERE f.order_date IS NOT NULL
)
, customer_aggregation AS (
SELECT 
customer_key,
customer_number,
customer_name,
age,
COUNT(DISTINCT order_number) AS total_orders,
SUM(sales_amount) AS total_sales,
SUM(quantity) AS total_quantity,
COUNT(DISTINCT product_key) AS total_products,
MAX(order_date) AS last_order_date,
(DATE_PART('year', AGE(MAX(order_date), MIN(order_date))) * 12 + 
 DATE_PART('month', AGE(MAX(order_date), MIN(order_date)))) AS lifespan
FROM base_query
GROUP BY customer_key,
customer_number,
customer_name,
age)

SELECT 
customer_key,
customer_number,
customer_name,
age,
-- Age group buckets
CASE WHEN age <20 THEN 'Under 20'
	WHEN Age BETWEEN 20 AND 29 THEN '20-29'
	WHEN age BETWEEN 30 AND 39 THEN '30-39'
	WHEN age BETWEEN 40 AND 49 THEN '40-49'
	ELSE '50 and above'
END AS age_group,
-- Customer segment: based on lifespan (months) and total sales
CASE WHEN lifespan >=12 AND total_sales >5000 THEN 'VIP'        -- long-term high spender
	WHEN lifespan >=12 AND total_Sales <5000 THEN 'Regular'      -- long-term lower spender
	ELSE 'New'                                                     -- short tenure
END AS customer_segment,
-- Recency: how many months since the customer's last order
(DATE_PART('year', AGE(CURRENT_DATE, last_order_date)) * 12 + 
 DATE_PART('month', AGE(CURRENT_DATE, last_order_date))) AS recency_months,
-- Average order value (AOV): revenue per order, guarded against zero orders
CASE WHEN total_sales = 0 THEN 0
	ELSE ROUND(total_sales / total_orders, 2) 
END  AS avg_order_value,
-- Average monthly spend: revenue spread over active months
-- If lifespan is 0 (single purchase), just show total sales
CASE WHEN lifespan =0 THEN ROUND(total_sales::NUMERIC,2)
	ELSE ROUND((total_sales / lifespan)::NUMERIC, 2)
END AS avg_monthly_spend,
total_orders,
total_sales,
total_quantity,
total_products,
last_order_date,
lifespan
FROM customer_aggregation
;


-- ============================================================================
-- Step 5 (FINAL): Create the report as a reusable database VIEW
-- This packages all the logic above into gold.report_customer so it
-- can be queried like a table:  SELECT * FROM gold.report_customer;
-- ============================================================================
CREATE VIEW gold.report_customer  AS (
WITH base_query
AS (
-- Base: join facts to customer dimension, build full name and age
SELECT 
f.order_number,
f.product_key,
f.order_date,
f.sales_amount,
f.quantity,
c.customer_key,
c.customer_number,
CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
DATE_PART('year',AGE(c.birthdate)) AS age
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
ON c.customer_key = f.customer_key
WHERE f.order_date IS NOT NULL
)
, customer_aggregation AS (
-- Aggregate to one row per customer with totals and lifespan
SELECT 
customer_key,
customer_number,
customer_name,
age,
COUNT(DISTINCT order_number) AS total_orders,
SUM(sales_amount) AS total_sales,
SUM(quantity) AS total_quantity,
COUNT(DISTINCT product_key) AS total_products,
MAX(order_date) AS last_order_date,
(DATE_PART('year', AGE(MAX(order_date), MIN(order_date))) * 12 + 
 DATE_PART('month', AGE(MAX(order_date), MIN(order_date)))) AS lifespan
FROM base_query
GROUP BY customer_key,
customer_number,
customer_name,
age)

-- Final SELECT: add segmentation, age groups, and KPIs
SELECT 
customer_key,
customer_number,
customer_name,
age,
CASE WHEN age <20 THEN 'Under 20'
	WHEN Age BETWEEN 20 AND 29 THEN '20-29'
	WHEN age BETWEEN 30 AND 39 THEN '30-39'
	WHEN age BETWEEN 40 AND 49 THEN '40-49'
	ELSE '50 and above'
END AS age_group,

CASE WHEN lifespan >=12 AND total_sales >5000 THEN 'VIP'
	WHEN lifespan >=12 AND total_Sales <5000 THEN 'Regular'
	ELSE 'New'
END AS customer_segment,
(DATE_PART('year', AGE(CURRENT_DATE, last_order_date)) * 12 + 
 DATE_PART('month', AGE(CURRENT_DATE, last_order_date))) AS recency_months,
CASE WHEN total_sales = 0 THEN 0
	ELSE ROUND(total_sales / total_orders, 2) 
END  AS avg_order_value,
CASE WHEN lifespan =0 THEN ROUND(total_sales::NUMERIC,2)
	ELSE ROUND((total_sales / lifespan)::NUMERIC, 2)
END AS avg_monthly_spend,
total_orders,
total_sales,
total_quantity,
total_products,
last_order_date,
lifespan
FROM customer_aggregation
);
