-- =====================================================================
-- 02_kpis_mensuales.sql
-- Pregunta: ¿cómo evolucionan pedidos, ventas y ticket medio mes a mes?
-- Técnicas: CTE, LAG (variación mensual e interanual), media móvil con
--           ventana ROWS BETWEEN, NULLIF para evitar dividir por cero.
-- =====================================================================

WITH mensual AS (
    SELECT
        mes,
        COUNT(*)                            AS pedidos,
        COUNT(DISTINCT customer_unique_id)  AS clientes,
        SUM(gmv)                            AS gmv
    FROM pedidos_analisis
    GROUP BY mes
)
SELECT
    mes,
    pedidos,
    clientes,
    ROUND(gmv, 2)                                         AS gmv,
    ROUND(gmv / pedidos, 2)                               AS ticket_medio,
    ROUND(100.0 * (gmv - LAG(gmv) OVER w)
          / NULLIF(LAG(gmv) OVER w, 0), 1)                AS gmv_vs_mes_anterior_pct,
    ROUND(100.0 * (gmv - LAG(gmv, 12) OVER w)
          / NULLIF(LAG(gmv, 12) OVER w, 0), 1)            AS gmv_vs_ano_anterior_pct,
    ROUND(AVG(gmv) OVER (w ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2)
                                                          AS gmv_media_movil_3m
FROM mensual
WINDOW w AS (ORDER BY mes)
ORDER BY mes;
