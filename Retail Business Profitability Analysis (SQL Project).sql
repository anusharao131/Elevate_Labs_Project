--Project Title: Retail Business Performance & Profitability Analysis Using SQL
--Objective:
--To analyze transactional retail data from the superstore_cleaned table in order to uncover profit-draining 
--categories, identify high- and low-performing products and regions, monitor trends in sales and profitability
--over time, and provide actionable insights for inventory and seasonal sales strategies. This analysis leverages
--SQL queries, Common Table Expressions (CTEs), and window functions to generate insights supporting data-driven
--business decisions.

-----------------------------------------------------------------------------------------------------------------

CREATE TABLE superstore_cleaned (
    row_id INTEGER,
    order_id TEXT,
    order_date DATE,
    ship_date DATE,
    ship_mode TEXT,
    customer_id TEXT,
    customer_name TEXT,
    segment TEXT,
    country_region TEXT,
    city TEXT,
    state TEXT,
    postal_code TEXT,
    region TEXT,
    product_id TEXT,
    category TEXT,
    sub_category TEXT,
    product_name TEXT,
    sales NUMERIC,
    quantity INTEGER,
    discount NUMERIC,
    profit NUMERIC
);
-----------------------------------------------------------------------------------------------------------------
select * from superstore_cleaned;
-----------------------------------------------------------------------------------------------------------------

-- Query 1: Profit Margin by Category and Sub-Category
--Objective: Identify which product categories and sub-categories generate the highest and lowest profit margins.
--Formula: Profit Margin (%) = (Total Profit / Total Sales) * 100

WITH category_profit AS (
    SELECT 
        category,sub_category,
		SUM(sales) AS total_sales,
		SUM(profit) AS total_profit,
        ROUND(SUM(profit) * 100.0 / NULLIF(SUM(sales), 0), 2) AS profit_margin_percentage
    FROM superstore_cleaned
    GROUP BY category, sub_category)
SELECT *
FROM category_profit
ORDER BY profit_margin_percentage ASC;

-----------------------------------------------------------------------------------------------------------------

-- Query 2: Total Profit and Margin by Region
-- Objective: Find which regions perform best and worst in terms of profitability.
--Formula: Profit Margin (%) = (Total Profit / Total Sales) * 100

SELECT 
    region,
	SUM(sales) AS total_sales,
    SUM(profit) AS total_profit,
    ROUND(SUM(profit) * 100.0 / NULLIF(SUM(sales), 0), 2) AS profit_margin_percentage
FROM superstore_cleaned
GROUP BY region
ORDER BY total_profit DESC;
-----------------------------------------------------------------------------------------------------------------
--Query 3: Monthly Sales and Profit Trend
--Objective: Track how sales and profit change over time to identify seasonality and growth trends.

WITH monthly_summary AS (
SELECT DATE_TRUNC('month', order_date) AS order_month,
        SUM(sales) AS total_sales, 
		SUM(profit) AS total_profit
    FROM superstore_cleaned
    GROUP BY DATE_TRUNC('month', order_date)),
trend_analysis AS (
    SELECT 
	order_month,
	total_sales,
	total_profit,
   --Window functions to calculate month-over-month changes
        LAG(total_sales) OVER (ORDER BY order_month) AS prev_month_sales,
        LAG(total_profit) OVER (ORDER BY order_month) AS prev_month_profit
    FROM monthly_summary)
SELECT
order_month,
total_sales,
total_profit,
    ROUND((total_sales - prev_month_sales) * 100.0 / NULLIF(prev_month_sales, 0), 2) AS sales_growth_pct,
    ROUND((total_profit - prev_month_profit) * 100.0 / NULLIF(prev_month_profit, 0), 2) AS profit_growth_pct
FROM trend_analysis ORDER BY order_month;

-----------------------------------------------------------------------------------------------------------------

--Query 4: Top 5 Products by Sales
--Objective: Identify the top 5 products that contribute most to total sales.

WITH product_sales AS (
    SELECT product_name,SUM(sales) AS total_sales
    FROM superstore_cleaned
    GROUP BY product_name
),
ranked_products AS (
    SELECT product_name,total_sales,
           RANK() OVER (ORDER BY total_sales DESC) AS sales_rank
    FROM product_sales)
SELECT *
FROM ranked_products
WHERE sales_rank <= 5;
-----------------------------------------------------------------------------------------------------------------

--Query 5: Average Profit by Product
--Objective: Calculate the average profit for each product to identify which products yield higher returns on average.

WITH product_profit AS (
    SELECT product_name,
           AVG(profit) AS average_profit
    FROM superstore_cleaned
    GROUP BY product_name
)
SELECT product_name,
       round(average_profit,2)
FROM product_profit
ORDER BY average_profit DESC;
-----------------------------------------------------------------------------------------------------------------

--Query 6: Correlation Between Inventory Turnover and Profitability
--Objective: Analyze whether faster-moving items (higher order counts) correlate with higher profitability.
--NOTE:Since the Superstore dataset doesn't contain inventory quantities directly, 
--we'll approximate inventory turnover using order count and profitability as profit margin.

WITH product_metrics AS (
    SELECT product_name,
	COUNT(DISTINCT order_id) AS order_count,
	SUM(sales) AS total_sales,
    SUM(profit) AS total_profit,
           CASE
		   WHEN SUM(sales) = 0 THEN 0 ELSE ROUND(SUM(profit) * 100.0 / SUM(sales), 2) 
           END AS profit_margin
    FROM superstore_cleaned
    GROUP BY product_name)
SELECT *
FROM product_metrics
ORDER BY order_count DESC;

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
####Query 7: Region-Wise Monthly Sales and Profit Trend
####Objective: Understand how sales and profit change over time in each region to uncover 
seasonal trends or regional growth.

WITH monthly_region_data AS (
    SELECT region,
           DATE_TRUNC('month', order_date) AS order_month,
		   SUM(sales) AS total_sales,
		   SUM(profit) AS total_profit
    FROM superstore_cleaned
    GROUP BY region, DATE_TRUNC('month', order_date)),
region_trend_with_growth AS (
    SELECT region,
	order_month,
	total_sales,
	total_profit,
           ROUND(
               (total_sales - LAG(total_sales) OVER (PARTITION BY region ORDER BY order_month)) * 100.0 /
               NULLIF(LAG(total_sales) OVER (PARTITION BY region ORDER BY order_month), 0), 2
           ) AS sales_growth_pct
    FROM monthly_region_data
)
SELECT *
FROM region_trend_with_growth
ORDER BY region, order_month;
-----------------------------------------------------------------------------------------------------------------
--Query 8: Identify Slow-Moving Products
--Objective: Find products with the lowest number of orders to help flag slow movers and possible overstock issues.

WITH product_order_counts AS (
    SELECT product_name,
           COUNT(DISTINCT order_id) AS order_frequency,
           SUM(sales) AS total_sales,
           SUM(profit) AS total_profit
    FROM superstore_cleaned
    GROUP BY product_name
	),
ranked_products AS (
    SELECT *, RANK() OVER (ORDER BY order_frequency ASC) AS low_order_rank
    FROM product_order_counts)
SELECT * 
FROM ranked_products
WHERE low_order_rank <= 10;

-----------------------------------------------------------------------------------------------------------------
--Query 9: Quarterly Profit Margin by Category
--Objective:Analyze profit efficiency across categories on a quarterly basis to detect seasonal profitability patterns.

WITH category_quarterly_profit AS (
    SELECT category,
           DATE_TRUNC('quarter', order_date) AS order_quarter,
           SUM(sales) AS total_sales,
           SUM(profit) AS total_profit,
           ROUND(SUM(profit) * 100.0 / NULLIF(SUM(sales), 0), 2) AS profit_margin_pct
    FROM superstore_cleaned
    GROUP BY category, DATE_TRUNC('quarter', order_date)
)
SELECT * 
FROM category_quarterly_profit
ORDER BY category, order_quarter
-----------------------------------------------------------------------------------------------------------------
--Query 10: Top 5 States by Total Profit per Region
--Objective: Identify the top 5 most profitable states in each region to guide region-specific strategies.

WITH state_profit AS (
    SELECT region, 
	state,
           SUM(profit) AS total_profit
    FROM superstore_cleaned
    GROUP BY region, state
	),
ranked_states AS (
    SELECT *,
           RANK() OVER (PARTITION BY region ORDER BY total_profit DESC) AS region_profit_rank
    FROM state_profit
	)
SELECT *
FROM ranked_states
WHERE region_profit_rank <= 5
ORDER BY region, region_profit_rank;






















