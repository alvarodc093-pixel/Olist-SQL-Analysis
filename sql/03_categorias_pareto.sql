-- =====================================================================
-- 03_categorias_pareto.sql
-- Pregunta: ¿qué categorías concentran las ventas? ¿Se cumple el 80/20?
-- Técnicas: JOIN a dimensión, RANK, SUM acumulada con ventana,
--           porcentaje sobre el total con SUM() OVER (), CASE para la
--           clasificación ABC.
-- =====================================================================

WITH ventas_categoria AS (
    SELECT
        pr.categoria,
        COUNT(DISTINCT i.order_id)  AS pedidos,
        COUNT(*)                    AS unidades,
        SUM(i.precio)               AS ingresos
    FROM fct_items        AS i
    JOIN pedidos_analisis AS p  ON p.order_id   = i.order_id
    JOIN dim_productos    AS pr ON pr.product_id = i.product_id
    GROUP BY pr.categoria
),
acumulado AS (
    SELECT
        *,
        RANK() OVER (ORDER BY ingresos DESC)            AS ranking,
        100.0 * ingresos / SUM(ingresos) OVER ()        AS pct_ingresos,
        100.0 * SUM(ingresos) OVER (
                    ORDER BY ingresos DESC, categoria
                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
              / SUM(ingresos) OVER ()                   AS pct_acumulado
    FROM ventas_categoria
)
SELECT
    ranking,
    categoria,
    pedidos,
    unidades,
    ROUND(ingresos, 2)                 AS ingresos,
    ROUND(ingresos / unidades, 2)      AS precio_medio,
    ROUND(pct_ingresos, 2)             AS pct_ingresos,
    ROUND(pct_acumulado, 2)            AS pct_acumulado,
    CASE
        WHEN pct_acumulado - pct_ingresos < 80 THEN 'A'
        WHEN pct_acumulado - pct_ingresos < 95 THEN 'B'
        ELSE 'C'
    END                                AS clase_abc
FROM acumulado
ORDER BY ranking, categoria;
