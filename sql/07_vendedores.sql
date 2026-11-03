-- =====================================================================
-- 07_vendedores.sql
-- Pregunta: ¿cuánto dependen las ventas de los mejores vendedores y
--           venden mejor (con mejor nota y menos retrasos) que el resto?
-- Técnicas: NTILE para cuartiles, dos niveles de agregación,
--           SUM() OVER () para el peso sobre el total.
-- Nota: la review es del pedido; si un pedido tiene varios vendedores,
--       la nota cuenta para todos (pasa en menos del 2 % de pedidos).
-- =====================================================================

WITH vendedor_pedido AS (
    SELECT
        i.seller_id,
        i.order_id,
        SUM(i.precio)  AS ingresos,
        MAX(p.nota)    AS nota,
        MAX(CASE WHEN p.dias_retraso > 0 THEN 1 ELSE 0 END) AS tarde,
        MAX(CASE WHEN p.fecha_entrega IS NOT NULL THEN 1 ELSE 0 END) AS entregado
    FROM fct_items        AS i
    JOIN pedidos_analisis AS p ON p.order_id = i.order_id
    GROUP BY i.seller_id, i.order_id
),
vendedores AS (
    SELECT
        seller_id,
        COUNT(*)        AS pedidos,
        SUM(ingresos)   AS ingresos,
        AVG(nota)       AS nota_media,
        SUM(tarde) * 1.0 / NULLIF(SUM(entregado), 0) AS ratio_tarde
    FROM vendedor_pedido
    GROUP BY seller_id
),
cuartiles AS (
    SELECT
        *,
        NTILE(4) OVER (ORDER BY ingresos DESC, seller_id) AS cuartil
    FROM vendedores
)
SELECT
    cuartil,
    CASE cuartil
        WHEN 1 THEN 'Top 25 %'
        WHEN 2 THEN '25-50 %'
        WHEN 3 THEN '50-75 %'
        ELSE        'Último 25 %'
    END                                                  AS grupo,
    COUNT(*)                                             AS vendedores,
    CAST(SUM(pedidos) AS BIGINT)                         AS pedidos,
    ROUND(SUM(ingresos), 2)                              AS ingresos,
    ROUND(100.0 * SUM(ingresos) / SUM(SUM(ingresos)) OVER (), 2) AS pct_ingresos,
    ROUND(MEDIAN(pedidos), 1)                            AS mediana_pedidos_vendedor,
    ROUND(SUM(nota_media * pedidos) / SUM(pedidos), 2)   AS nota_media,
    ROUND(100.0 * AVG(ratio_tarde), 1)                   AS pct_pedidos_tarde
FROM cuartiles
GROUP BY cuartil
ORDER BY cuartil;
