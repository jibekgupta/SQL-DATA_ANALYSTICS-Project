/*
===============================================================================
Change Over Time Analysis
===============================================================================
Purpose:
    - Analyze how sales, customers, and quantity trend over different
      time granularities: daily, yearly, monthly, and year-month.

Source Table:
    - gold.fact_sales

Key Columns Used:
    - order_date       : when the order was placed
    - sales_amount     : revenue from each order line
    - customer_key     : identifies the customer (used for distinct count)
    - quantity         : number of units sold

Notes:
    - All queries filter out NULL order_date rows since time-based
      grouping requires a valid date.
===============================================================================
*/


-- ============================================================================
-- Query 1: Raw daily sales (one row per order line, ordered by date)
-- Useful for spotting individual high/low-value transactions over time.
-- ============================================================================
SELECT 
order_date,
sales_amount
FROM gold.fact_sales
WHERE order_date IS NOT NULL
ORDER BY order_date;


-- ============================================================================
-- Query 2: Daily total sales (aggregated per day)
-- Collapses all order lines on the same day into a single total.
-- ============================================================================
SELECT 
order_date,
SUM(sales_amount) AS total_sales       -- total revenue for each calendar day
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY order_date
ORDER BY order_date;


-- ============================================================================
-- Query 3: Yearly trend
-- Shows how total sales, customer count, and quantity change year over year.
-- DATE_PART('year', ...) extracts the year component from order_date.
-- ============================================================================
SELECT 
DATE_PART('year',order_date) AS order_year,
SUM(sales_amount) AS total_sales,                -- total revenue for the year
COUNT(DISTINCT customer_key) AS total_customers,  -- unique buyers that year
SUM(quantity) AS total_quantity                    -- total units sold
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY order_year
ORDER BY 1;


-- ============================================================================
-- Query 4: Monthly trend (month number only, all years combined)
-- Useful for spotting seasonality (e.g. December always high).
-- Note: this mixes years together — month 1 includes Jan of every year.
-- ============================================================================
SELECT 
DATE_PART('month',order_date) AS order_month,
SUM(sales_amount) AS total_sales,
COUNT(DISTINCT customer_key) AS total_customers,
SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY order_month
ORDER BY 1;


-- ============================================================================
-- Query 5: Year-month trend (separate year and month columns)
-- More granular than yearly; does not mix years like Query 4.
-- ============================================================================
SELECT 
DATE_PART('year', order_date) AS order_year,
DATE_PART('month', order_date) AS order_mont,
SUM(sales_amount) AS total_sales,
COUNT(DISTINCT customer_key) AS total_customers,
SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY 1,2
ORDER BY 1,2;


-- ============================================================================
-- Query 6: Year-month trend using DATE_TRUNC
-- DATE_TRUNC('month', ...) truncates each date to the 1st of its month,
-- producing a proper DATE value (e.g. 2013-03-01) that is easy to chart.
-- ============================================================================
SELECT 
DATE_TRUNC('month', order_date)::DATE AS order_year,
SUM(sales_amount) AS total_sales,
COUNT(DISTINCT customer_key) AS total_customers,
SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY 1
ORDER BY 1;
