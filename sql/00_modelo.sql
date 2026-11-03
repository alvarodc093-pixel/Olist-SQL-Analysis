-- =====================================================================
-- 00_modelo.sql
-- Construye el modelo de análisis a partir de las tablas raw_* (los CSV
-- de Olist tal cual). Deja un esquema en estrella sencillo:
--
--   dim_clientes, dim_productos, dim_vendedores
--   fct_items, fct_pagos, fct_reviews, fct_pedidos
--   pedidos_analisis  (vista: la base común de todas las consultas)
--
-- Decisiones:
--   * Un cliente real es customer_unique_id: Olist crea un customer_id
--     nuevo en cada pedido, así que contar customer_id infla los clientes.
--   * Items y pagos se agregan por pedido ANTES de unirlos, para evitar
--     el "fan-out" (un pedido con 3 items y 2 pagos daría 6 filas).
--   * Si un pedido tiene varias reviews, me quedo con la más reciente.
--   * Periodo de análisis: 2017-01 a 2018-08, los meses completos.
-- =====================================================================

CREATE OR REPLACE TABLE dim_clientes AS
SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix AS cp,
    customer_city            AS ciudad,
    customer_state           AS estado
FROM raw_customers;

CREATE OR REPLACE TABLE dim_productos AS
SELECT
    p.product_id,
    COALESCE(t.product_category_name_english,
             p.product_category_name,
             'sin_categoria')          AS categoria,
    p.product_weight_g                 AS peso_g,
    p.product_photos_qty               AS n_fotos
FROM raw_products AS p
LEFT JOIN raw_category_translation AS t
       ON t.product_category_name = p.product_category_name;

CREATE OR REPLACE TABLE dim_vendedores AS
SELECT
    seller_id,
    seller_city  AS ciudad,
    seller_state AS estado
FROM raw_sellers;

CREATE OR REPLACE TABLE fct_items AS
SELECT
    order_id,
    order_item_id   AS n_item,
    product_id,
    seller_id,
    price           AS precio,
    freight_value   AS flete
FROM raw_order_items;

CREATE OR REPLACE TABLE fct_pagos AS
SELECT
    order_id,
    payment_sequential   AS secuencia,
    payment_type         AS tipo_pago,
    payment_installments AS cuotas,
    payment_value        AS importe
FROM raw_order_payments;

-- Una review por pedido: la última respondida.
CREATE OR REPLACE TABLE fct_reviews AS
WITH ordenadas AS (
    SELECT
        order_id,
        review_score,
        review_creation_date,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY review_answer_timestamp DESC, review_id
        ) AS rn
    FROM raw_order_reviews
)
SELECT order_id, review_score AS nota, review_creation_date AS fecha_review
FROM ordenadas
WHERE rn = 1;

-- Tabla de hechos principal: una fila por pedido.
CREATE OR REPLACE TABLE fct_pedidos AS
WITH items_pedido AS (
    SELECT
        order_id,
        COUNT(*)      AS n_items,
        SUM(precio)   AS importe_productos,
        SUM(flete)    AS importe_flete
    FROM fct_items
    GROUP BY order_id
),
pagos_pedido AS (
    SELECT order_id, SUM(importe) AS importe_pagado
    FROM fct_pagos
    GROUP BY order_id
)
SELECT
    o.order_id,
    c.customer_unique_id,
    c.estado                                         AS estado_cliente,
    o.order_status                                   AS estado_pedido,
    o.order_purchase_timestamp                       AS fecha_compra,
    CAST(DATE_TRUNC('month', o.order_purchase_timestamp) AS DATE) AS mes,
    o.order_delivered_customer_date                  AS fecha_entrega,
    o.order_estimated_delivery_date                  AS fecha_estimada,
    DATE_DIFF('day', o.order_purchase_timestamp,
                     o.order_delivered_customer_date) AS dias_entrega,
    DATE_DIFF('day', CAST(o.order_estimated_delivery_date AS DATE),
                     CAST(o.order_delivered_customer_date AS DATE)) AS dias_retraso,
    COALESCE(i.n_items, 0)                           AS n_items,
    COALESCE(i.importe_productos, 0)                 AS importe_productos,
    COALESCE(i.importe_flete, 0)                     AS importe_flete,
    COALESCE(i.importe_productos, 0)
      + COALESCE(i.importe_flete, 0)                 AS gmv,
    p.importe_pagado,
    r.nota
FROM raw_orders        AS o
JOIN dim_clientes      AS c ON c.customer_id = o.customer_id
LEFT JOIN items_pedido AS i ON i.order_id    = o.order_id
LEFT JOIN pagos_pedido AS p ON p.order_id    = o.order_id
LEFT JOIN fct_reviews  AS r ON r.order_id    = o.order_id;

-- Base común de todas las consultas: pedidos reales (no cancelados ni
-- sin stock), con al menos un producto y dentro del periodo completo.
CREATE OR REPLACE VIEW pedidos_analisis AS
SELECT *
FROM fct_pedidos
WHERE estado_pedido NOT IN ('canceled', 'unavailable')
  AND n_items > 0
  AND mes BETWEEN DATE '2017-01-01' AND DATE '2018-08-01';
