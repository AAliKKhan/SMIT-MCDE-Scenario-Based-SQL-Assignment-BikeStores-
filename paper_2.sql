use BikeStores;

--Task 1 — Build the Sales Detail Dataset (6 marks)
--Management needs a detailed sales dataset for analysis. Return one row per order item containing:
--order_id and order_date
--customer full name
--store name
--staff full name
--product name
--category name
--brand name
--quantity, list_price, discount
--calculated net_line_revenue

--Include only completed orders (order_status = 4). Sort the result from newest order to oldest.

SELECT
    o.order_id,
    o.order_date,
    c.first_name +' '+ c.last_name AS customer_name,
    s.store_name,
    st.first_name + ' '+ st.last_name AS staff_name,
    p.product_name,
    cat.category_name,
    b.brand_name,
    oi.quantity,
    oi.list_price,
    oi.discount,
    CAST(oi.quantity * oi.list_price *(1 - oi.discount) AS DECIMAL(18, 2))
AS net_line_revenue

FROM sales.orders AS o
INNER JOIN sales.order_items AS oi
    ON oi.order_id = o.order_id
INNER JOIN sales.customers AS c
    ON c.customer_id = o.customer_id
INNER JOIN sales.stores AS s
    ON s.store_id = o.store_id
INNER JOIN sales.staffs AS st
    ON st.staff_id = o.staff_id
INNER JOIN production.products AS p
    ON p.product_id = oi.product_id
INNER JOIN production.categories AS cat
    ON cat.category_id = p.category_id
INNER JOIN production.brands AS b
    ON b.brand_id = p.brand_id
WHERE o.order_status = 4
ORDER BY o.order_date DESC, o.order_id DESC;


--Task 2 — Store Performance Summary (5 marks)
--Create a store-level performance report for completed orders showing:
--store name
--number of distinct orders
--total units sold
--total net revenue
--average order value



SELECT
s.store_name,
COUNT(DISTINCT r.order_id) AS distinct_orders,
SUM(r.order_units) AS total_units_sold,
CAST(SUM(r.order_revenue) AS DECIMAL(18, 2)) AS total_net_revenue,
CAST(AVG(r.order_revenue) AS DECIMAL(18, 2)) AS average_order_value
FROM (
    SELECT
        o.order_id,
        o.store_id,
        SUM(oi.quantity) AS order_units,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS order_revenue
    FROM sales.orders AS o
    INNER JOIN sales.order_items AS oi
        ON oi.order_id = o.order_id
    WHERE o.order_status = 4
    GROUP BY o.order_id, o.store_id
) AS r
INNER JOIN sales.stores AS s
    ON s.store_id = r.store_id
GROUP BY s.store_name
ORDER BY total_net_revenue DESC;


--Task 3 — High-Value Customers (5 marks)
--Management wants to identify high-value customers. Return customers whose total completed-order spending is greater than the average total spending of customers who have completed orders.

--Show customer_id, customer name, completed order count, and total spending. Order the result by total spending descending.


SELECT
    c.customer_id,
    c.first_name + ' ' + c.last_name AS customer_name,
    s.completed_order_count,
    CAST(s.total_spending AS DECIMAL(18, 2)) AS total_spending
FROM (
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS completed_order_count,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount))AS total_spending
    FROM sales.orders AS o
    INNER JOIN sales.order_items AS oi
        ON oi.order_id = o.order_id
    WHERE o.order_status = 4
    GROUP BY o.customer_id
) AS s
INNER JOIN sales.customers AS c
    ON c.customer_id = s.customer_id
WHERE s.total_spending >= (
        SELECT AVG(t.total_spending * 1.0)
        FROM (
            SELECT
                o.customer_id,
                SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_spending
            FROM sales.orders AS o
            INNER JOIN sales.order_items AS oi
                ON oi.order_id = o.order_id
            WHERE o.order_status = 4
            GROUP BY o.customer_id
        ) AS t
     )
ORDER BY s.total_spending DESC;


--Task 4 — Inventory Risk Report (5 marks)
--Operations wants to identify inventory risk. Return products where the stock quantity is below 5 in at least one store.


SELECT
    p.product_name,
    s.store_name,
    st.quantity  AS current_quantity,
    cat.category_name,
    b.brand_name
FROM production.stocks AS st
INNER JOIN production.products AS p
    ON p.product_id = st.product_id
INNER JOIN sales.stores AS s
    ON s.store_id = st.store_id
INNER JOIN production.categories AS cat
    ON cat.category_id = p.category_id
INNER JOIN production.brands AS b
    ON b.brand_id = p.brand_id
WHERE st.quantity < 5
ORDER BY st.quantity ASC, p.product_name ASC;


--Task 5 — Top Products Within Each Category (6 marks)
--For each product category, identify the top 3 products by total net revenue from completed orders.

--Return category name, product name, total units sold, total net revenue, and the product's position within its category. Tied products must receive the same position and the next position should not contain gaps.


SELECT
    cat.category_name,
    r.product_name,
    r.total_units_sold,
    r.total_net_revenue,
    r.position_in_category
FROM (
    SELECT
        p.product_id,
        p.product_name,
        p.category_id,
        SUM(oi.quantity)AS total_units_sold,
        CAST(SUM(oi.quantity * oi.list_price * (1 - oi.discount))
             AS DECIMAL(18, 2))AS total_net_revenue,
        RANK() OVER (
            PARTITION BY p.category_id
            ORDER BY SUM(oi.quantity * oi.list_price * (1 - oi.discount)) DESC
        ) AS position_in_category
    FROM production.products AS p
    INNER JOIN sales.order_items AS oi
        ON oi.product_id = p.product_id
    INNER JOIN sales.orders AS o
        ON o.order_id = oi.order_id
    WHERE o.order_status = 4
    GROUP BY p.product_id, p.product_name, p.category_id
) AS r
INNER JOIN production.categories AS cat
    ON cat.category_id = r.category_id
WHERE r.position_in_category <= 3
ORDER BY cat.category_name ASC, r.position_in_category ASC, r.total_net_revenue DESC;

--Task 6 — Monthly Sales Trend (6 marks)
--Create a monthly sales trend for completed orders.

--For each calendar month return:
--year
--month
--total net revenue
--previous month's total net revenue
--revenue change from the previous month

--The first month may have NULL for the previous-month comparison. Sort chronologically.


SELECT
    m.sale_year,
    m.sale_month,
    m.total_net_revenue,
    LAG(m.total_net_revenue) OVER (ORDER BY m.sale_year, m.sale_month)
 AS previous_month_revenue,
    m.total_net_revenue - LAG(m.total_net_revenue) OVER (ORDER BY m.sale_year, m.sale_month)
AS revenue_change
FROM (
    SELECT
        YEAR(o.order_date)  AS sale_year,
        MONTH(o.order_date) AS sale_month,
        CAST(SUM(oi.quantity * oi.list_price * (1 - oi.discount))
             AS DECIMAL(18, 2))                 AS total_net_revenue
    FROM sales.orders AS o
    INNER JOIN sales.order_items AS oi
        ON oi.order_id = o.order_id
    WHERE o.order_status = 4
    GROUP BY YEAR(o.order_date), MONTH(o.order_date)
) AS m
ORDER BY m.sale_month ASC, m.sale_year ASC;


--Task 9 — Store Sales Procedure (6 marks)
--Create a stored procedure named sales.usp_store_sales_report with these input parameters:
--@store_id
--@start_date
--@end_date

--The procedure should return completed-order sales for the requested store and date range, grouped by product. Return product name, total units sold, and total net revenue, ordered by revenue descending.

--Add appropriate error handling for invalid date ranges where @start_date is later than @end_date.


CREATE OR ALTER PROCEDURE sales.usp_store_sales_report
    @store_id   INT,
    @start_date DATE,
    @end_date   DATE
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        IF @start_date > @end_date
        BEGIN
            ;THROW 50001,
                  'Invalid date range: @start_date cannot be later than @end_date.', 1;
        END

        IF NOT EXISTS (SELECT 1 FROM sales.stores WHERE store_id = @store_id)
        BEGIN
            ;THROW 50002, 'Invalid @store_id: store does not exist.', 1;
        END

        SELECT
            p.product_name,
            SUM(oi.quantity)                                AS total_units_sold,
            CAST(SUM(oi.quantity * oi.list_price * (1 - oi.discount))
                 AS DECIMAL(18, 2))                         AS total_net_revenue
        FROM sales.orders AS o
        INNER JOIN sales.order_items AS oi
            ON oi.order_id = o.order_id
        INNER JOIN production.products AS p
            ON p.product_id = oi.product_id
        WHERE o.store_id = @store_id
          AND o.order_status = 4
          AND o.order_date BETWEEN @start_date AND @end_date
        GROUP BY p.product_name
        ORDER BY total_net_revenue DESC;

    END TRY
    BEGIN CATCH
        THROW;  
    END CATCH;
END;



EXEC sales.usp_store_sales_report
    @store_id   = 1,
    @start_date = '2017-01-01',
    @end_date   = '2017-12-31';


--Task 10 — Management Insight Query (3 marks)
--Write one additional SQL query that you believe would provide useful insight to BikeStores management using at least three tables.

--Below the query, add a SQL comment of no more than three lines explaining:
--1. the business question,
--2. what the result measures, and
--3. why management should care about it.

SELECT
    st.staff_id,
    st.first_name + ' ' + st.last_name     AS staff_name,
    s.store_name,
    st.active,
    COUNT(DISTINCT o.order_id)                               AS completed_orders,
    CAST(SUM(oi.quantity * oi.list_price * (1 - oi.discount))
         AS DECIMAL(18, 2))                                  AS total_net_revenue,
    CAST(AVG(oi.discount) AS DECIMAL(5, 3))                  AS avg_line_discount,
    CAST(SUM(oi.quantity * oi.list_price * (1 - oi.discount))
         / COUNT(DISTINCT o.order_id) AS DECIMAL(18, 2))     AS revenue_per_order
FROM sales.staffs AS st
INNER JOIN sales.stores AS s
    ON s.store_id = st.store_id
INNER JOIN sales.orders AS o
    ON o.staff_id = st.staff_id
INNER JOIN sales.order_items AS oi
    ON oi.order_id = o.order_id
WHERE o.order_status = 4
GROUP BY st.staff_id, st.first_name, st.last_name, s.store_name, st.active
ORDER BY total_net_revenue DESC;
