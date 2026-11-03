-- =====================================================================
-- 11_dias_pico.sql
-- Pregunta: ¿qué días vendieron mucho más de lo normal (Black Friday,
--           campañas)?
-- Técnicas: media y desviación móviles de los 28 días anteriores con
--           ventana, z-score, top-N con ROW_NUMBER.
-- =====================================================================

WITH diario AS (
    SELECT
        CAST(fecha_compra AS DATE)  AS dia,
        COUNT(*)                    AS pedidos,
        SUM(gmv)                    AS gmv
    FROM pedidos_analisis
    GROUP BY 1
),
con_referencia AS (
    SELECT
        *,
        AVG(pedidos)         OVER w28 AS media_28d,
        STDDEV_SAMP(pedidos) OVER w28 AS desv_28d
    FROM diario
    WINDOW w28 AS (ORDER BY dia ROWS BETWEEN 28 PRECEDING AND 1 PRECEDING)
),
puntuados AS (
    SELECT
        *,
        (pedidos - media_28d) / NULLIF(desv_28d, 0) AS z_score,
        ROW_NUMBER() OVER (ORDER BY (pedidos - media_28d) / NULLIF(desv_28d, 0) DESC) AS ranking
    FROM con_referencia
    WHERE dia >= DATE '2017-03-01'   -- con historia suficiente para comparar
)
SELECT
    ranking,
    dia,
    CASE EXTRACT(isodow FROM dia)
        WHEN 1 THEN 'lunes'   WHEN 2 THEN 'martes' WHEN 3 THEN 'miércoles'
        WHEN 4 THEN 'jueves'  WHEN 5 THEN 'viernes' WHEN 6 THEN 'sábado'
        ELSE 'domingo'
    END                                    AS dia_semana,
    pedidos,
    ROUND(gmv, 2)                          AS gmv,
    ROUND(media_28d, 1)                    AS media_28d_previos,
    ROUND(pedidos / media_28d, 2)          AS veces_la_media,
    ROUND(z_score, 1)                      AS z_score
FROM puntuados
WHERE ranking <= 10
ORDER BY ranking;
