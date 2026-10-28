-- Практическая работа №6. Подзапросы, EXISTS и CTE

-- A1. Скалярный подзапрос: товары дороже средней цены
SELECT product_name, price
FROM products
WHERE price > (SELECT AVG(price) FROM products)
ORDER BY price DESC;

-- A2. Самый дорогой активный товар
SELECT product_name, price
FROM products
WHERE is_active = true
  AND price = (SELECT MAX(price) FROM products WHERE is_active = true);

-- A3. IN: клиенты, у которых есть заказы
SELECT full_name, city
FROM customers
WHERE customer_id IN (SELECT customer_id FROM orders)
ORDER BY full_name;

-- A4. Подзапрос в FROM: средний чек
SELECT ROUND(AVG(x.order_total), 2) AS avg_order_value
FROM (
  SELECT order_id, SUM(quantity * unit_price) AS order_total
  FROM order_items
  GROUP BY order_id
) AS x;

-- A5. Заказы с суммой выше 100000
SELECT x.order_id, x.order_total
FROM (
  SELECT order_id, SUM(quantity * unit_price) AS order_total
  FROM order_items
  GROUP BY order_id
) AS x
WHERE x.order_total > 100000
ORDER BY x.order_total DESC;

-- A6. Коррелированный подзапрос: товары дороже средней цены своей категории
SELECT p.product_name, p.category, p.price
FROM products p
WHERE p.price > (
  SELECT AVG(p2.price)
  FROM products p2
  WHERE p2.category = p.category
)
ORDER BY p.category, p.price DESC;

-- B1. EXISTS: клиенты хотя бы с одним оплаченным заказом
SELECT c.full_name
FROM customers c
WHERE EXISTS (
  SELECT 1 FROM orders o
  WHERE o.customer_id = c.customer_id AND o.status = 'paid'
)
ORDER BY c.full_name;

-- B2. NOT EXISTS: клиенты без заказов
SELECT c.customer_id, c.full_name
FROM customers c
WHERE NOT EXISTS (
  SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id
);

-- B3. NOT EXISTS: товары без продаж
SELECT p.product_id, p.product_name
FROM products p
WHERE NOT EXISTS (
  SELECT 1 FROM order_items oi WHERE oi.product_id = p.product_id
)
ORDER BY p.product_id;

-- B4. Товары без продаж за период май - июль 2026
SELECT p.product_id, p.product_name
FROM products p
WHERE NOT EXISTS (
  SELECT 1
  FROM order_items oi
  JOIN orders o ON o.order_id = oi.order_id
  WHERE oi.product_id = p.product_id
    AND o.order_date >= '2026-05-01'
    AND o.order_date <  '2026-08-01'
)
ORDER BY p.product_id;

-- B5. Клиенты, которые покупали, но никогда не покупали аксессуары
SELECT c.full_name
FROM customers c
WHERE EXISTS (
  SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id
)
AND NOT EXISTS (
  SELECT 1
  FROM orders o
  JOIN order_items oi ON oi.order_id = o.order_id
  JOIN products p ON p.product_id = oi.product_id
  WHERE o.customer_id = c.customer_id AND p.category = 'Аксессуары'
)
ORDER BY c.full_name;

-- C1. Клиентский отчёт: order_totals -> customer_stats -> customers
WITH order_totals AS (
  SELECT order_id, SUM(quantity * unit_price) AS total
  FROM order_items
  GROUP BY order_id
),
customer_stats AS (
  SELECT o.customer_id,
         COUNT(*) AS orders_count,
         SUM(ot.total) AS revenue,
         ROUND(AVG(ot.total), 2) AS avg_order_value,
         MAX(o.order_date) AS last_order
  FROM orders o
  JOIN order_totals ot ON ot.order_id = o.order_id
  GROUP BY o.customer_id
)
SELECT c.full_name, c.city,
       COALESCE(cs.orders_count, 0) AS orders_count,
       COALESCE(cs.revenue, 0) AS revenue,
       cs.avg_order_value,
       cs.last_order
FROM customers c
LEFT JOIN customer_stats cs ON cs.customer_id = c.customer_id
ORDER BY revenue DESC, c.full_name;

-- C1. Проверка этапа order_totals: 12 заказов, сумма 957940
WITH order_totals AS (
  SELECT order_id, SUM(quantity * unit_price) AS total
  FROM order_items
  GROUP BY order_id
)
SELECT COUNT(*) AS rows_count,
       COUNT(DISTINCT order_id) AS unique_orders,
       SUM(total) AS total_sum
FROM order_totals;

-- C1. Проверка этапа customer_stats: 9 клиентов, 12 заказов, сумма 957940
WITH order_totals AS (
  SELECT order_id, SUM(quantity * unit_price) AS total
  FROM order_items
  GROUP BY order_id
),
customer_stats AS (
  SELECT o.customer_id, COUNT(*) AS orders_count, SUM(ot.total) AS revenue
  FROM orders o
  JOIN order_totals ot ON ot.order_id = o.order_id
  GROUP BY o.customer_id
)
SELECT COUNT(*) AS customers_with_orders,
       SUM(orders_count) AS orders_sum,
       SUM(revenue) AS revenue_sum
FROM customer_stats;

-- Контроль по исходным позициям: 957940
SELECT SUM(quantity * unit_price) AS total_revenue FROM order_items;

-- C2. Мой вопрос: выручка и средний чек по городам за май - июль 2026
-- order_totals = заказ, city_orders = заказ с городом, city_stats = город
WITH order_totals AS (
  SELECT order_id, SUM(quantity * unit_price) AS total
  FROM order_items
  GROUP BY order_id
),
city_orders AS (
  SELECT c.city, o.order_id, ot.total
  FROM orders o
  JOIN customers c ON c.customer_id = o.customer_id
  JOIN order_totals ot ON ot.order_id = o.order_id
  WHERE o.order_date >= '2026-05-01'
    AND o.order_date <  '2026-08-01'
),
city_stats AS (
  SELECT city,
         COUNT(*) AS orders_count,
         SUM(total) AS revenue,
         ROUND(AVG(total), 2) AS avg_order_value
  FROM city_orders
  GROUP BY city
)
SELECT * FROM city_stats
ORDER BY revenue DESC;

-- C2. Проверка этапа city_orders: 5 заказов за период
WITH order_totals AS (
  SELECT order_id, SUM(quantity * unit_price) AS total
  FROM order_items
  GROUP BY order_id
),
city_orders AS (
  SELECT c.city, o.order_id, ot.total
  FROM orders o
  JOIN customers c ON c.customer_id = o.customer_id
  JOIN order_totals ot ON ot.order_id = o.order_id
  WHERE o.order_date >= '2026-05-01'
    AND o.order_date <  '2026-08-01'
)
SELECT * FROM city_orders ORDER BY order_id;
