-- =====================================================================
-- 01_calidad_datos.sql
-- Pregunta: ¿me puedo fiar de los datos antes de analizarlos?
-- Técnicas: UNION ALL de comprobaciones, NOT EXISTS, GROUP BY + HAVING,
--           subconsultas escalares.
-- =====================================================================

SELECT 'Pedidos duplicados (order_id)' AS comprobacion,
       COUNT(*) AS valor,
       'Debe ser 0' AS nota
FROM (
    SELECT order_id FROM raw_orders GROUP BY order_id HAVING COUNT(*) > 1
) AS d

UNION ALL
SELECT 'Items cuyo pedido no existe',
       COUNT(*),
       'Debe ser 0 (integridad referencial)'
FROM raw_order_items AS i
WHERE NOT EXISTS (SELECT 1 FROM raw_orders AS o WHERE o.order_id = i.order_id)

UNION ALL
SELECT 'Pedidos sin ningún item',
       COUNT(*),
       'Casi todos cancelados o sin stock: se excluyen'
FROM raw_orders AS o
WHERE NOT EXISTS (SELECT 1 FROM raw_order_items AS i WHERE i.order_id = o.order_id)

UNION ALL
SELECT 'Pedidos sin pago registrado',
       COUNT(*),
       'Se mantienen: el importe sale de los items'
FROM raw_orders AS o
WHERE NOT EXISTS (SELECT 1 FROM raw_order_payments AS p WHERE p.order_id = o.order_id)

UNION ALL
SELECT 'Productos sin categoría',
       COUNT(*),
       'Se agrupan como sin_categoria'
FROM raw_products
WHERE product_category_name IS NULL

UNION ALL
SELECT 'Pedidos entregados sin fecha de entrega',
       COUNT(*),
       'Se quedan fuera del análisis de plazos'
FROM raw_orders
WHERE order_status = 'delivered' AND order_delivered_customer_date IS NULL

UNION ALL
SELECT 'Entregas anteriores a la compra',
       COUNT(*),
       'Debe ser 0'
FROM raw_orders
WHERE order_delivered_customer_date < order_purchase_timestamp

UNION ALL
SELECT 'Pedidos con más de una review',
       COUNT(*),
       'Me quedo con la última'
FROM (
    SELECT order_id FROM raw_order_reviews GROUP BY order_id HAVING COUNT(*) > 1
) AS d

UNION ALL
SELECT 'Pedidos donde pago y productos+flete difieren > 1 BRL',
       COUNT(*),
       'Vales e intereses de cuotas: uso productos+flete como GMV'
FROM fct_pedidos
WHERE importe_pagado IS NOT NULL
  AND ABS(importe_pagado - gmv) > 1

UNION ALL
SELECT 'customer_id distintos',
       (SELECT COUNT(DISTINCT customer_id) FROM raw_customers),
       'Uno por pedido: no sirve para contar clientes'

UNION ALL
SELECT 'customer_unique_id distintos',
       (SELECT COUNT(DISTINCT customer_unique_id) FROM raw_customers),
       'Clientes reales'

UNION ALL
SELECT 'Filas si se unen items y pagos sin agregar',
       (SELECT COUNT(*) FROM raw_order_items AS i
          JOIN raw_order_payments AS p ON p.order_id = i.order_id),
       'Fan-out: por eso se agrega por pedido antes de unir'

UNION ALL
SELECT 'Pedidos en la base de análisis',
       (SELECT COUNT(*) FROM pedidos_analisis),
       '2017-01 a 2018-08, sin cancelados ni sin stock';
