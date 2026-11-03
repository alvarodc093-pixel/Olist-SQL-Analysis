-- =====================================================================
-- 05_recompra.sql
-- Pregunta: ¿cuántos clientes repiten, cuánto tardan en volver y qué
--           parte de las ventas viene de ellos?
-- Técnicas: ROW_NUMBER y LEAD por cliente, PERCENTILE_CONT (mediana),
--           agregación condicional con FILTER.
-- =====================================================================

WITH pedidos_cliente AS (
    SELECT
        customer_unique_id,
        fecha_compra,
        gmv,
        ROW_NUMBER() OVER (PARTITION BY customer_unique_id
                           ORDER BY fecha_compra)               AS n_pedido,
        LEAD(fecha_compra) OVER (PARTITION BY customer_unique_id
                                 ORDER BY fecha_compra)         AS siguiente_compra
    FROM pedidos_analisis
),
clientes AS (
    SELECT
        customer_unique_id,
        COUNT(*)  AS n_pedidos,
        SUM(gmv)  AS gmv,
        MAX(CASE WHEN n_pedido = 1
                 THEN DATE_DIFF('day', fecha_compra, siguiente_compra)
            END)  AS dias_hasta_segunda
    FROM pedidos_cliente
    GROUP BY customer_unique_id
)
SELECT
    COUNT(*)                                             AS clientes,
    COUNT(*) FILTER (WHERE n_pedidos > 1)                AS clientes_recurrentes,
    ROUND(100.0 * COUNT(*) FILTER (WHERE n_pedidos > 1)
          / COUNT(*), 2)                                 AS pct_recurrentes,
    ROUND(100.0 * SUM(gmv) FILTER (WHERE n_pedidos > 1)
          / SUM(gmv), 2)                                 AS pct_gmv_recurrentes,
    ROUND(AVG(n_pedidos), 3)                             AS pedidos_por_cliente,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY dias_hasta_segunda)
                                                         AS mediana_dias_segunda_compra,
    ROUND(100.0 * COUNT(*) FILTER (WHERE dias_hasta_segunda = 0)
          / NULLIF(COUNT(dias_hasta_segunda), 0), 1)     AS pct_segunda_compra_mismo_dia
FROM clientes;
