-- ========================================== 
-- Question 1
-- Which products and categories drive the most revenue and profit? 
-- analyze revenue, units sold, gross profit, profit margin, top/bottom products, and category performance.

-- ========================================== 

-- 1.1 Total Revenue

Select sum(subtotal - discount_amount) as Total_Revenue
From sales_models.orders
where order_status not in ('Canceled', 'Refunded', 'Returned');


-- 1.2 Units Sold
SELECT
    SUM(subtotal - discount_amount) AS net_revenue,
    SUM(quantity) AS units_sold
FROM sales_models.orders
WHERE order_status NOT IN ('Canceled', 'Refunded', 'Returned');




-- 1.3 Gross Profit & Profit Margin

select Round(
sum((subtotal - discount_amount) - (t2.unit_cost * t1.quantity)),2) as gross_profit,

Round(
sum((subtotal - discount_amount) - (t2.unit_cost * t1.quantity))/ 
sum(subtotal - discount_amount) * 100,2) as profit_margin

from sales_models.orders t1
left join sales_models.products t2
on t1.product_id = t2.product_id
where order_status not in ('Canceled', 'Refunded', 'Returned');

-- 1.4 Category Performance, Gross Profit, Profit Margin Percentage, Units Sold, Total Revenue

select product_category, count(order_id) as number_of_orders, 
sum(subtotal - discount_amount) as Total_Revenue, sum(quantity) as units_sold,

Round(
sum((subtotal - discount_amount) - (t2.unit_cost * t1.quantity)),2) as gross_profit,

Round(
sum((subtotal - discount_amount) - (t2.unit_cost * t1.quantity))/ 
sum(subtotal - discount_amount) * 100,2) as profit_margin

from sales_models.orders t1
left join sales_models.products t2
on t1.product_id = t2.product_id
where order_status not in ('Canceled', 'Refunded', 'Returned')
group by product_category;


-- Top and Bottom products

-- 1.5 Top and Bottom Products by Revenue

SELECT
    p.product_id,
    p.product_name,
    ROUND(
        COALESCE(SUM(o.subtotal - o.discount_amount), 0),
        2
    ) AS net_revenue,

    RANK() OVER (
        ORDER BY COALESCE(SUM(o.subtotal - o.discount_amount), 0) DESC
    ) AS revenue_rank

FROM sales_models.products AS p

LEFT JOIN sales_models.orders AS o
    ON p.product_id = o.product_id
    AND o.order_status NOT IN ('Canceled', 'Refunded', 'Returned')

GROUP BY
    p.product_id,
    p.product_name

ORDER BY revenue_rank;

-- ==========================================
-- Question 2
-- How have monthly revenue, order volume, average order value, and units sold changed over time?

-- ========================================== 

--  2.1 Average Order Value

SELECT
    ROUND(
        SUM(subtotal - discount_amount)
        / COUNT(DISTINCT order_id),
        2
    ) AS average_order_value
FROM sales_models.orders
WHERE order_status NOT IN ('Canceled', 'Refunded', 'Returned');

-- Average Order Value is $240.26

-- 2.2 Total Order Volume

select COUNT(DISTINCT order_id) as order_volume
from orders
WHERE order_status NOT IN ('Canceled', 'Refunded', 'Returned');

-- 4,403 valid orders
 
 -- 2.3 Monthly Order Volume
 select date_format(order_date, '%Y-%m') as month,
 count(order_id) as order_volume
 from sales_models.orders
 WHERE order_status NOT IN ('Canceled', 'Refunded', 'Returned')
 group by date_format(order_date, '%Y-%m')
 order by month;
 
--  2.4 Monthly Revenue

SELECT
    DATE_FORMAT(order_date, '%Y-%m') AS month,
    ROUND(
        SUM(subtotal - discount_amount),
        2
    ) AS net_revenue
FROM sales_models.orders
WHERE order_status NOT IN ('Canceled', 'Returned', 'Refunded')
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY month;
 
 -- 2.5 Month-over-Month Revenue Growth
 
 with monthly_revenue as
 (
 select date_format(order_date, '%Y-%m') as month,
 sum(subtotal - discount_amount) as net_revenue
 from sales_models.orders
 where order_status NOT IN ('Canceled', 'Returned', 'Refunded')
 group by date_format(order_date, '%Y-%m') 
 order by month
 )
  select month, round(net_revenue, 2) as net_revenue,
  round( 
  LAG(net_revenue) OVER (ORDER BY month)
  )as previous_month_revenue,
  
   ROUND( 
   net_revenue - LAG(net_revenue) OVER (ORDER BY month)) AS revenue_change,
   
   ROUND(  
            (net_revenue - LAG(net_revenue) OVER (ORDER BY month)
        )
        /
        LAG(net_revenue) OVER (ORDER BY month)
        * 100,
        2
    ) AS mom_revenue_change_percent
   
   from monthly_revenue
   order by month;
   
   -- 2.6 Monthly Units Sold

SELECT
    DATE_FORMAT(order_date, '%Y-%m') AS month,
    SUM(quantity) AS total_units_sold
FROM sales_models.orders
WHERE order_status NOT IN ('Canceled', 'Returned', 'Refunded')
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY month;
 
 -- ========================================== 
-- Question 3
-- Which products are underperforming or creating inventory concerns?

-- ========================================== 

-- 3.1 Products With No Orders

SELECT
    p.product_id,
    p.product_name
FROM sales_models.products p
LEFT JOIN sales_models.orders o
    ON p.product_id = o.product_id
WHERE o.order_id IS NULL;

-- 3.2 Low-Selling Products

WITH product_sales AS (
    SELECT
        p.product_id,
        p.product_name,
        p.product_category,
        COALESCE(SUM(o.quantity), 0) AS units_sold
    FROM products p
    LEFT JOIN orders o
        ON p.product_id = o.product_id
        AND o.order_status NOT IN ('Canceled', 'Returned', 'Refunded')
    GROUP BY
        p.product_id,
        p.product_name,
        p.product_category
)

SELECT
    product_id,
    product_name,
    product_category,
    units_sold,
    CASE
        WHEN units_sold = 0 THEN 'No Sales'
        WHEN units_sold < (SELECT AVG(units_sold) FROM product_sales)
            THEN 'Low Selling'
        ELSE 'Above Average'
    END AS sales_performance
FROM product_sales
ORDER BY units_sold ASC;

-- 3.3 Sales vs. Inventory

SELECT
    p.product_id,
    p.product_name,
    p.stock_quantity,
    COALESCE(SUM(o.quantity), 0) AS units_sold
FROM sales_models.products p
LEFT JOIN sales_models.orders o
    ON p.product_id = o.product_id
    AND o.order_status NOT IN ('Canceled', 'Returned', 'Refunded')
GROUP BY
    p.product_id,
    p.product_name,
    p.stock_quantity
ORDER BY units_sold;

-- 3.4 High Inventory / Weak Recent Sales

WITH recent_product_sales AS (
    SELECT
        p.product_id,
        p.product_name,
        p.product_category,
        p.stock_quantity,
        COALESCE(SUM(o.quantity), 0) AS units_sold_last_12_months
    FROM sales_models.products AS p
    LEFT JOIN sales_models.orders AS o
        ON p.product_id = o.product_id
        AND o.order_status NOT IN ('Canceled', 'Returned', 'Refunded')
        AND o.order_date >= DATE_SUB(
            (SELECT MAX(order_date)
             FROM sales_models.orders),
            INTERVAL 12 MONTH
        )
    GROUP BY
        p.product_id,
        p.product_name,
        p.product_category,
        p.stock_quantity
),

product_benchmarks AS (
    SELECT
        product_id,
        product_name,
        product_category,
        stock_quantity,
        units_sold_last_12_months,
        AVG(stock_quantity) OVER () AS avg_inventory,
        AVG(units_sold_last_12_months) OVER () AS avg_units_sold
    FROM recent_product_sales
)

SELECT
    product_id,
    product_name,
    product_category,
    stock_quantity,
    units_sold_last_12_months,
    ROUND(avg_inventory, 2) AS avg_inventory,
    ROUND(avg_units_sold, 2) AS avg_units_sold
FROM product_benchmarks
WHERE stock_quantity > avg_inventory
    AND units_sold_last_12_months < avg_units_sold
ORDER BY
    stock_quantity DESC,
    units_sold_last_12_months ASC;
 
 


