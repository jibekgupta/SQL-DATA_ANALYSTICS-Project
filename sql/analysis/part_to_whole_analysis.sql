/*
===============================================================================
Part-to-Whole Analysis (Category Contribution)
===============================================================================
Purpose:
    - Find out which product categories contribute the most to overall sales.
    - Express each category's revenue as a percentage of the grand total.

Source Tables:
    - gold.fact_sales    : order-level revenue data
    - gold.dim_products  : product attributes including category

Key Concepts:
    - SUM() OVER ()               : window function with no partition calculates
                                    the grand total across all rows
    - total_sales::NUMERIC * 100  : cast to NUMERIC before dividing to keep
                                    decimal precision in the percentage
    - CONCAT(..., '%')            : formats the number as a readable string

Output:
    - One row per product category, ordered by highest revenue first.
===============================================================================
*/

WITH category_sales AS (
-- Step 1: Aggregate total sales per product category
SELECT
category,                               -- product category from dim_products
SUM(sales_amount) AS total_sales        -- total revenue for this category
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products p            -- LEFT JOIN keeps sales even if product lookup is missing
ON p.product_key = f.product_key
GROUP BY category)

-- Step 2: Calculate each category's share of overall sales
SELECT category,
total_sales,                                                                        -- revenue for this category
SUM(total_sales) OVER () overall_sales,                                             -- grand total (same value on every row)
CONCAT(ROUND((total_sales::NUMERIC) *100 / SUM(total_sales) OVER (), 2), '%') AS percentage_of_total  -- e.g. "45.12%"
FROM category_sales
ORDER BY total_sales DESC;
