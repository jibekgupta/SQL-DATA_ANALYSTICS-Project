/*
===============================================================================
Cumulative Analysis (Running Totals & Running Averages)
===============================================================================
Purpose:
    - Calculate total sales per month and build running (cumulative) totals
      and running averages over time using window functions.

Source Table:
    - gold.fact_sales

Key Concepts:
    - SUM() OVER (ORDER BY ...)   : cumulative sum across ordered rows
    - PARTITION BY year            : resets the running total each calendar year
    - AVG() OVER (ORDER BY ...)   : running average up to the current row
    - DATE_TRUNC('month', ...)    : groups dates into monthly buckets
    - DATE_TRUNC('year', ...)     : groups dates into yearly buckets

Notes:
    - All queries filter out NULL order_date rows.
===============================================================================
*/


-- ============================================================================
-- Query 1: Monthly totals (month number only, all years combined)
-- Useful as a seasonality check — shows which calendar months sell the most.
-- ============================================================================
SELECT
DATE_PART('month',order_date) AS sales_month,    -- month number (1-12)
SUM(sales_amount) AS total_sales                 -- combined revenue across all years for this month
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY 1
ORDER BY 1;


-- ============================================================================
-- Query 2: Monthly totals (year-month grain)
-- DATE_TRUNC keeps year+month together so Jan 2013 and Jan 2014 stay separate.
-- ============================================================================
SELECT
DATE_TRUNC('month',order_date)::DATE AS order_date,  -- first day of the month
SUM(sales_amount) AS total_sales
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY 1
ORDER BY 1;


-- ============================================================================
-- Query 3: All-time running total by month
-- SUM() OVER (ORDER BY order_date) adds up every month from the first to the
-- current row, giving a cumulative revenue line.
-- ============================================================================
SELECT
order_date,
total_sales,
SUM(total_sales) OVER (ORDER BY order_date) AS running_total_sales  -- cumulative sum across all months
FROM 
(SELECT
DATE_TRUNC('month', order_date)::DATE AS order_date,
SUM(sales_amount) AS total_sales
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY 1
ORDER BY 1
) AS sub;


-- ============================================================================
-- Query 4: Year-to-date (YTD) running total by month
-- PARTITION BY year resets the running total at the start of each calendar year,
-- so you can compare Jan-Jun 2013 vs Jan-Jun 2014 etc.
-- ============================================================================
SELECT 
order_date,
total_sales,
SUM(total_sales) 
OVER (
PARTITION BY EXTRACT(YEAR FROM order_date)   -- reset running total each year
ORDER BY order_date) AS running_total_sales  -- YTD cumulative sum
FROM
(SELECT
DATE_TRUNC('month', order_date)::DATE AS order_date,
SUM(sales_amount) AS total_sales
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY 1
ORDER BY 1
) AS sub;


-- ============================================================================
-- Query 5: All-time running total by year
-- Same idea as Query 3 but at yearly grain instead of monthly.
-- ============================================================================
SELECT
order_date,
total_sales,
SUM(total_sales) OVER (ORDER BY order_date) AS running_total_sale_by_year  -- cumulative across years
FROM 
(SELECT
DATE_TRUNC('year', order_date)::DATE AS order_date,   -- truncate to Jan 1 of each year
SUM(sales_amount) AS total_sales
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY 1
ORDER BY 1
) AS sub;


-- ============================================================================
-- Query 6: Yearly totals with average price
-- Provides a per-year summary of total revenue and average unit price.
-- ============================================================================
SELECT
DATE_TRUNC('year',order_date)::DATE AS order_date,
SUM(sales_amount) AS total_sum,       -- total revenue for the year
ROUND(AVG(price), 2)as avg_price      -- average unit price across all order lines that year
FROM gold.fact_sales
WHERE  order_date IS NOT NULL
GROUP BY 1
ORDER BY 1;


-- ============================================================================
-- Query 7: Running total sales + running average price by year
-- Combines cumulative revenue with a running average of the yearly avg price.
-- running_avg_price smooths out price fluctuations over successive years.
-- ============================================================================
SELECT
order_date,
total_sales,
SUM(total_sales) OVER (ORDER BY order_date) AS running_total_sales,          -- cumulative revenue
avg_price,
ROUND(AVG(avg_price) OVER (ORDER BY order_date), 2) AS running_avg_price    -- running avg of yearly avg price
FROM 
(SELECT
DATE_TRUNC('year',order_date)::DATE AS order_date,
SUM(sales_amount) AS total_sales,
ROUND(AVG(price), 2)as avg_price
FROM gold.fact_sales
WHERE  order_date IS NOT NULL
GROUP BY 1
ORDER BY 1
) AS sub;
