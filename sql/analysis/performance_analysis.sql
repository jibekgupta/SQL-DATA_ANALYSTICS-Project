/*
===============================================================================
Performance Analysis (Products | Yearly)
===============================================================================
Purpose:
    - Analyze the yearly performance of each product by comparing:
      1) Current year sales vs the product's multi-year average sales
      2) Current year sales vs the previous year's sales (Year-over-Year)

Source Tables:
    - gold.fact_sales    : order-level revenue data
    - gold.dim_products  : product names

Key Concepts:
    - AVG() OVER (PARTITION BY product_name)
        Computes the mean annual sales across all years for each product.
        Acts as a benchmark — is this year above or below the product's norm?
    - LAG() OVER (PARTITION BY product_name ORDER BY order_year)
        Looks back one row (the previous year) within the same product.
        Returns NULL for the very first year since there is no prior row.
    - CASE ... END
        Labels the comparison result as a human-readable category.

Build-up:
    - The queries below are written incrementally. Each one adds a new
      column on top of the previous query so you can follow the logic
      step by step. The final query (Query 6) is the complete version.
===============================================================================
*/


-- ============================================================================
-- Query 1: Base aggregation — total sales per product per year
-- This is the foundation all later queries build on.
-- ============================================================================
SELECT 
DATE_PART('year',f.order_date) AS order_year,    -- extract year from order date
p.product_name,                                   -- product name from dimension table
SUM(f.sales_amount) AS current_year_sales         -- total revenue for this product in this year
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
ON f.product_key = p.product_key
WHERE f.order_date IS NOT NULL                    -- exclude rows without a valid date
GROUP BY 1,2;


-- ============================================================================
-- Query 2: Add product average sales using a CTE + window function
-- AVG() OVER (PARTITION BY product_name) gives each product's average
-- annual sales across all years in the dataset.
-- ============================================================================
WITH yearly_product_sales AS (
SELECT 
DATE_PART('year',f.order_date) AS order_year,
p.product_name,
SUM(f.sales_amount) AS current_year_sales
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
ON f.product_key = p.product_key
WHERE f.order_date IS NOT NULL
GROUP BY 1,2
)

SELECT 
order_year,
product_name,
current_year_sales,
ROUND(AVG(current_year_sales) OVER (PARTITION BY product_name),0) AS product_avg_sales  -- average annual sales for this product
FROM yearly_product_sales
ORDER BY 2,1;


-- ============================================================================
-- Query 3: Add difference vs average
-- Positive = this year beat the product's average; negative = below average.
-- ============================================================================
WITH yearly_product_sales AS (
SELECT 
DATE_PART('year',f.order_date) AS order_year,
p.product_name,
SUM(f.sales_amount) AS current_year_sales
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
ON f.product_key = p.product_key
WHERE f.order_date IS NOT NULL
GROUP BY 1,2
)

SELECT 
order_year,
product_name,
current_year_sales,
ROUND(AVG(current_year_sales) OVER (PARTITION BY product_name),0) AS product_avg_sales,
current_year_sales - ROUND(AVG(current_year_sales) OVER (PARTITION BY product_name),0) AS diff_avg_sales  -- dollar difference vs average
FROM yearly_product_sales
ORDER BY 2,1;


-- ============================================================================
-- Query 4: Add a label for above/below average
-- CASE converts the numeric difference into a readable category.
-- ============================================================================
WITH yearly_product_sales AS (
SELECT 
DATE_PART('year',f.order_date) AS order_year,
p.product_name,
SUM(f.sales_amount) AS current_year_sales
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
ON f.product_key = p.product_key
WHERE f.order_date IS NOT NULL
GROUP BY 1,2
)

SELECT 
order_year,
product_name,
current_year_sales,
ROUND(AVG(current_year_sales) OVER (PARTITION BY product_name),0) AS product_avg_sales,
current_year_sales - ROUND(AVG(current_year_sales) OVER (PARTITION BY product_name),0) AS diff_avg_sales,
CASE
WHEN current_year_sales - ROUND(AVG(current_year_sales) OVER (PARTITION BY product_name),0) >0 THEN 'Above Average'
WHEN current_year_sales - ROUND(AVG(current_year_sales) OVER (PARTITION BY product_name),0) < 0 THEN 'Below Average'
ELSE 'AVG'
END AS "avg_change"                               -- label: above, below, or exactly average
FROM yearly_product_sales
ORDER BY 2,1;


-- ============================================================================
-- Query 5: Add previous year sales using LAG()
-- LAG() looks at the immediately preceding year for the same product.
-- Returns NULL for a product's first year in the data.
-- ============================================================================
WITH yearly_product_sales AS (
SELECT 
DATE_PART('year',f.order_date) AS order_year,
p.product_name,
SUM(f.sales_amount) AS current_year_sales
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
ON f.product_key = p.product_key
WHERE f.order_date IS NOT NULL
GROUP BY 1,2
)

SELECT 
order_year,
product_name,
current_year_sales,
ROUND(AVG(current_year_sales) OVER (PARTITION BY product_name),0) AS product_avg_sales,
current_year_sales - ROUND(AVG(current_year_sales) OVER (PARTITION BY product_name),0) AS diff_avg_sales,
CASE
WHEN current_year_sales - ROUND(AVG(current_year_sales) OVER (PARTITION BY product_name),0) >0 THEN 'Above Average'
WHEN current_year_sales - ROUND(AVG(current_year_sales) OVER (PARTITION BY product_name),0) < 0 THEN 'Below Average'
ELSE 'AVG'
END AS "avg_change",
LAG(current_year_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS py_sales  -- previous year's sales (NULL if first year)
FROM yearly_product_sales
ORDER BY 2,1;


-- ============================================================================
-- Query 6 (FINAL): Full year-over-year analysis
-- Adds:
--   py_sales   : previous year's sales via LAG()
--   diff_py    : dollar difference between current year and previous year
--   py_change  : label indicating Increase, Decrease, or No Change
-- ============================================================================
WITH yearly_product_sales AS (
SELECT 
DATE_PART('year',f.order_date) AS order_year,
p.product_name,
SUM(f.sales_amount) AS current_year_sales
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
ON f.product_key = p.product_key
WHERE f.order_date IS NOT NULL
GROUP BY 1,2
)

SELECT 
order_year,
product_name,
current_year_sales,
ROUND(AVG(current_year_sales) OVER (PARTITION BY product_name),0) AS product_avg_sales,
current_year_sales - ROUND(AVG(current_year_sales) OVER (PARTITION BY product_name),0) AS diff_avg_sales,
CASE
WHEN current_year_sales - ROUND(AVG(current_year_sales) OVER (PARTITION BY product_name),0) >0 THEN 'Above Average'
WHEN current_year_sales - ROUND(AVG(current_year_sales) OVER (PARTITION BY product_name),0) < 0 THEN 'Below Average'
ELSE 'AVG'
END AS "avg_change",
-- Year-over-year analysis columns
LAG(current_year_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS py_sales,                     -- previous year revenue
current_year_sales - LAG(current_year_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS diff_py, -- dollar change vs last year
CASE
WHEN current_year_sales - LAG(current_year_sales) OVER (PARTITION BY product_name ORDER BY order_year) >0 THEN 'Increase'
WHEN current_year_sales - LAG(current_year_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
ELSE 'no change'
END AS "py_change"                                -- label: Increase, Decrease, or no change
FROM yearly_product_sales
ORDER BY 2,1;
