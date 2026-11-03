-- =====================================================================
-- 08_geografia.sql
-- Pregunta: ¿dónde están los clientes y en qué estados la logística
--           sale más cara y más lenta?
-- Técnicas: agregación por dimensión, ratios, RANK, comparación con la
--           media nacional mediante ventana sobre todo el conjunto.
-- =====================================================================

WITH por_estado AS (
    SELECT
        estado_cliente                                  AS estado,
        COUNT(*)                                        AS pedidos,
        SUM(gmv)                                        AS gmv,
        SUM(importe_flete)                              AS flete,
        AVG(dias_entrega)                               AS dias_entrega_medios,
        AVG(CASE WHEN dias_retraso > 0 THEN 1.0 ELSE 0 END)
            FILTER (WHERE fecha_entrega IS NOT NULL)    AS ratio_tarde,
        AVG(nota)                                       AS nota_media
    FROM pedidos_analisis
    GROUP BY estado_cliente
)
SELECT
    RANK() OVER (ORDER BY pedidos DESC)                 AS ranking,
    estado,
    pedidos,
    ROUND(100.0 * pedidos / SUM(pedidos) OVER (), 2)    AS pct_pedidos,
    ROUND(gmv / pedidos, 2)                             AS ticket_medio,
    ROUND(100.0 * flete / gmv, 1)                       AS pct_flete_sobre_gmv,
    ROUND(dias_entrega_medios, 1)                       AS dias_entrega_medios,
    ROUND(dias_entrega_medios
          - SUM(dias_entrega_medios * pedidos) OVER ()
            / SUM(pedidos) OVER (), 1)                  AS dias_vs_media_nacional,
    ROUND(100.0 * ratio_tarde, 1)                       AS pct_tarde,
    ROUND(nota_media, 2)                                AS nota_media
FROM por_estado
ORDER BY ranking;
