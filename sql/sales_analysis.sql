CREATE SCHEMA raw;

CREATE TABLE raw.sales_raw (
    order_id TEXT,
    order_date DATE,
    ship_date DATE,
    ship_mode TEXT,
    customer_id TEXT,
    customer_name TEXT,
    segment TEXT,
    country TEXT,
    city TEXT,
    state TEXT,
    postal_code TEXT,
    region TEXT,
    product_id TEXT,
    category TEXT,
    sub_category TEXT,
    product_name TEXT,
    sales NUMERIC(10,2),
    quantity INT,
    discount NUMERIC(4,2),
    profit NUMERIC(10,2)
);

CREATE SCHEMA analytics;

CREATE TABLE analytics.products AS
SELECT
    product_id,
    MIN(product_name) AS product_name,
    MIN(category) AS category,
    MIN(sub_category) AS sub_category
FROM raw.sales_raw
GROUP BY product_id;

CREATE TABLE analytics.regions AS
SELECT DISTINCT
    country,
    city,
    state,
    region
FROM raw.sales_raw;

CREATE TABLE analytics.sales AS
SELECT
    order_id,
    order_date,
    ship_date,
    ship_mode,
    customer_id,
    customer_name,
    segment,
    product_id,
    country,
    city,
    state,
    region,
    sales,
    quantity,
    discount,
    profit
FROM raw.sales_raw;

ALTER TABLE analytics.products
ADD PRIMARY KEY (product_id);

ALTER TABLE analytics.regions
ADD PRIMARY KEY (country, city, state, region);

ALTER TABLE analytics.sales
ADD COLUMN sale_id SERIAL;

ALTER TABLE analytics.sales
ADD PRIMARY KEY (sale_id);

ALTER TABLE analytics.sales
ADD CONSTRAINT fk_product
FOREIGN KEY (product_id)
REFERENCES analytics.products(product_id);

ALTER TABLE analytics.sales
ADD CONSTRAINT fk_region
FOREIGN KEY (country, city, state, region)
REFERENCES analytics.regions(country, city, state, region);

-- ============================================
-- BUSINESS QUESTION:
-- Which products generate the highest revenue and profit?
--
-- PURPOSE:
-- Identify top-performing products and evaluate profitability.
-- ============================================

SELECT 
    p.product_name,
    SUM(s.sales) AS total_revenue,
    SUM(s.profit) AS total_profit
FROM analytics.sales s
JOIN analytics.products p
ON s.product_id = p.product_id
GROUP BY p.product_name
ORDER BY total_revenue DESC
LIMIT 10;

SELECT 
    p.product_name,
    AVG(s.discount) AS avg_discount,
    SUM(s.sales) AS revenue,
    SUM(s.profit) AS profit
FROM analytics.sales s
JOIN analytics.products p
ON s.product_id = p.product_id
GROUP BY p.product_name
HAVING SUM(s.profit) < 0
ORDER BY revenue DESC;

SELECT 
    region,
    SUM(sales) AS total_revenue,
    SUM(profit) AS total_profit,
    ROUND(SUM(profit) / SUM(sales), 2) AS profit_margin
FROM analytics.sales
GROUP BY region
ORDER BY total_revenue DESC;

SELECT 
    region,
    SUM(sales) AS total_revenue,
    SUM(profit) AS total_profit,
    ROUND(SUM(profit) / SUM(sales), 2) AS profit_margin
FROM analytics.sales
GROUP BY region
HAVING SUM(profit) <= 0
   OR ROUND(SUM(profit) / SUM(sales), 2) < 0.1
ORDER BY profit_margin ASC;

SELECT 
    region,
    p.product_name,
    SUM(s.sales) AS revenue,
    SUM(s.profit) AS profit
FROM analytics.sales s
JOIN analytics.products p
ON s.product_id = p.product_id
WHERE region = 'Central'  
GROUP BY region, p.product_name
HAVING SUM(s.profit) < 0
ORDER BY profit ASC;

SELECT 
    region,
    AVG(discount) AS avg_discount,
    SUM(sales) AS revenue,
    SUM(profit) AS profit
FROM analytics.sales
GROUP BY region
ORDER BY avg_discount DESC;

SELECT 
    region,
    discount,
    AVG(profit) AS avg_profit
FROM analytics.sales
GROUP BY region, discount
ORDER BY region, discount;

-- ============================================
-- BUSINESS QUESTION:
-- Are there seasonal trends in sales?
--
-- PURPOSE:
-- Identify patterns or recurring trends in sales over time
-- to support demand planning and strategic decision-making.
-- ============================================

SELECT 
    DATE_TRUNC('month', order_date) AS month,
    SUM(sales) AS total_revenue
FROM analytics.sales
GROUP BY month
ORDER BY month;

-- ============================================
-- BUSINESS QUESTION:
-- Are there recurring monthly seasonal patterns?
--
-- PURPOSE:
-- Analyze aggregated sales by month of the year
-- to detect consistent seasonal behavior.
-- ============================================

SELECT 
    EXTRACT(MONTH FROM order_date) AS month,
    SUM(sales) AS total_revenue
FROM analytics.sales
GROUP BY month
ORDER BY month;

-- ============================================
-- BUSINESS QUESTION:
-- Are there unusual high-value transactions?
--
-- PURPOSE:
-- Identify extreme sales values that may indicate
-- anomalies, bulk orders, or data issues.
-- ============================================

SELECT 
    order_id,
    product_id,
    sales,
    profit
FROM analytics.sales
WHERE sales > (
    SELECT AVG(sales) + 3 * STDDEV(sales)
    FROM analytics.sales
)
ORDER BY sales DESC;

-- ============================================
-- BUSINESS QUESTION:
-- Are there transactions generating significant losses?
--
-- PURPOSE:
-- Identify extreme negative profit transactions
-- that may indicate pricing or discount issues.
-- ============================================

SELECT 
    order_id,
    product_id,
    sales,
    profit,
    discount
FROM analytics.sales
WHERE profit < (
    SELECT AVG(profit) - 3 * STDDEV(profit)
    FROM analytics.sales
)
ORDER BY profit ASC;

-- ============================================
-- BUSINESS QUESTION:
-- Are high discounts driving anomalies?
--
-- PURPOSE:
-- Analyze whether extreme discount levels
-- correlate with abnormal transactions.
-- ============================================

SELECT 
    discount,
    COUNT(*) AS transactions,
    AVG(profit) AS avg_profit
FROM analytics.sales
GROUP BY discount
ORDER BY discount DESC;

-- ============================================
-- BUSINESS QUESTION:
-- Where should the company focus its commercial efforts?
--
-- PURPOSE:
-- Identify high-performing and underperforming segments
-- based on revenue and profitability.
-- ============================================

SELECT 
    p.category,
    s.region,
    SUM(s.sales) AS total_revenue,
    SUM(s.profit) AS total_profit,
    ROUND(SUM(s.profit) / SUM(s.sales), 2) AS profit_margin
FROM analytics.sales s
JOIN analytics.products p
ON s.product_id = p.product_id
GROUP BY p.category, s.region
ORDER BY total_revenue DESC;

-- ============================================
-- PURPOSE:
-- Identify high-margin segments with growth potential
-- ============================================

SELECT 
    p.category,
    s.region,
    ROUND(SUM(s.profit) / SUM(s.sales), 2) AS profit_margin,
    SUM(s.sales) AS revenue
FROM analytics.sales s
JOIN analytics.products p
ON s.product_id = p.product_id
GROUP BY p.category, s.region
HAVING SUM(s.sales) > 50000
ORDER BY profit_margin DESC;

-- ============================================
-- PURPOSE:
-- Identify high-revenue but low-profit segments
-- ============================================

SELECT 
    p.category,
    s.region,
    SUM(s.sales) AS revenue,
    SUM(s.profit) AS profit
FROM analytics.sales s
JOIN analytics.products p
ON s.product_id = p.product_id
GROUP BY p.category, s.region
HAVING SUM(s.sales) > 50000
   AND SUM(s.profit) < 0
ORDER BY revenue DESC;