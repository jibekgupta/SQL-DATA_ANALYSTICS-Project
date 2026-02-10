/*
===============================================================================
Data Segmentation
===============================================================================
Purpose:
    - Bucket entities into meaningful segments for analysis.
    - Two segmentation examples:
        1) Products segmented by cost range
        2) Customers segmented by spending behavior and tenure

Source Tables:
    - gold.dim_products   : product cost data
    - gold.fact_sales     : order-level revenue and dates
    - gold.dim_customers  : customer dimension for joins
===============================================================================
*/


/*
===============================================================================
SECTION 1: Product Segmentation by Cost Range
===============================================================================
Goal:
    - Classify each product into a cost bucket (Below 100, 100-500,
      500-1000, Above 1000) and count how many products fall into each.
===============================================================================
*/


-- ============================================================================
-- Query 1a: Assign each product to a cost range
-- CASE evaluates conditions top-to-bottom; the first TRUE branch wins.
-- ============================================================================
SELECT 
product_key,
product_name,
cost,
CASE
WHEN cost < 100 THEN 'Below 100'                -- budget / low-cost items
WHEN cost BETWEEN 100 AND  500 THEN '100-500'   -- mid-range items
WHEN cost BETWEEN 500 AND 1000 THEN  '500-1000' -- higher-end items
ELSE 'Above 1000'                                -- premium items
END cost_range
FROM gold.dim_products;


-- ============================================================================
-- Query 1b: Count products per cost range using a CTE
-- The CTE (product_segment) assigns buckets, then the outer query counts.
-- ============================================================================
WITH product_segment AS (
SELECT 
product_key,
product_name,
cost,
CASE
WHEN cost < 100 THEN 'Below 100'
WHEN cost BETWEEN 100 AND  500 THEN '100-500'
WHEN cost BETWEEN 500 AND 1000 THEN  '500-1000'
ELSE 'Above 1000'
END cost_range
FROM gold.dim_products)

SELECT
cost_range,
COUNT(product_key) AS total_products              -- number of products in this bucket
FROM product_segment
GROUP BY cost_range
ORDER BY total_products DESC;


/*
===============================================================================
SECTION 2: Customer Segmentation by Spending Behavior
===============================================================================
Goal:
    - Group customers into three segments based on total spend and tenure:
        VIP     : spent > 5000 AND active for >= 365 days
        Regular : spent <= 5000 AND active for >= 365 days
        New     : active for < 365 days (regardless of spend)
    - Count the total number of customers in each segment.

Key Columns:
    - total_spending : lifetime revenue from this customer
    - life_span      : days between first and last order (tenure)
===============================================================================
*/


-- ============================================================================
-- Query 2a: Base aggregation per customer
-- Computes total spend, first order, last order, and lifespan in days.
-- ============================================================================
SELECT
c.customer_key,
SUM(f.sales_amount) AS total_spending,             -- lifetime revenue
MIN(order_date) AS first_order,                    -- earliest purchase date
MAX(order_date) AS last_order,                     -- most recent purchase date
(MAX(order_date) - MIN(order_date)) AS life_span   -- tenure in days
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
ON f.customer_key = c.customer_key
GROUP BY c.customer_key;


-- ============================================================================
-- Query 2b: Assign each customer to a segment using a CTE
-- The CTE builds per-customer metrics, then the outer SELECT applies
-- the segmentation rules via CASE.
-- ============================================================================
WITH customer_spending AS (
SELECT
c.customer_key,
SUM(f.sales_amount) AS total_spending,
MIN(order_date) AS first_order,
MAX(order_date) AS last_order,
(MAX(order_date) - MIN(order_date)) AS life_span
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
ON f.customer_key = c.customer_key
GROUP BY c.customer_key
)

SELECT customer_key,
total_spending,
life_span,
CASE WHEN total_spending > 5000 AND life_span >=365 THEN 'VIP'       -- high spender + long tenure
	WHEN total_spending <= 5000 AND life_span >=365 THEN 'Regular'    -- lower spender but loyal
	ELSE 'New'                                                         -- short tenure
END AS customer_seg
FROM customer_spending;


-- ============================================================================
-- Query 2c: Segment labels only (without spending details)
-- Same logic, just fewer output columns.
-- ============================================================================
WITH customer_spending AS (
SELECT
c.customer_key,
SUM(f.sales_amount) AS total_spending,
MIN(order_date) AS first_order,
MAX(order_date) AS last_order,
(MAX(order_date) - MIN(order_date)) AS life_span
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
ON f.customer_key = c.customer_key
GROUP BY c.customer_key
)

SELECT customer_key,
CASE WHEN total_spending > 5000 AND life_span >=365 THEN 'VIP'
	WHEN total_spending <= 5000 AND life_span >=365 THEN 'Regular'
	ELSE 'New'
END AS customer_seg
FROM customer_spending;


-- ============================================================================
-- Query 2d (FINAL): Count customers per segment
-- Uses a subquery to first label each customer, then groups by segment.
-- ============================================================================
WITH customer_spending AS (
SELECT
c.customer_key,
SUM(f.sales_amount) AS total_spending,
MIN(order_date) AS first_order,
MAX(order_date) AS last_order,
(MAX(order_date) - MIN(order_date)) AS life_span
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
ON f.customer_key = c.customer_key
GROUP BY c.customer_key
)

SELECT
customer_seg,
COUNT(customer_key) AS total_customers             -- how many customers in each segment
FROM (
	SELECT customer_key,
	CASE WHEN total_spending > 5000 AND life_span >=365 THEN 'VIP'
		WHEN total_spending <= 5000 AND life_span >=365 THEN 'Regular'
		ELSE 'New'
	END AS customer_seg
	FROM customer_spending) sub
GROUP BY customer_seg
ORDER BY total_customers DESC;
