-- =====================================================================
-- 10_estacionalidad.sql
-- Pregunta: ¿qué días y a qué horas compran los clientes?
-- Técnicas: EXTRACT de partes de fecha, agregación en dos dimensiones,
--           índice frente a la media con ventana.
-- =====================================================================

WITH por_hora AS (
    SELECT
        EXTRACT(isodow FROM fecha_compra) AS dia_semana,   -- 1 = lunes
        EXTRACT(hour   FROM fecha_compra) AS hora,
        COUNT(*)                          AS pedidos
    FROM pedidos_analisis
    GROUP BY 1, 2
)
SELECT
    dia_semana,
    CASE dia_semana
        WHEN 1 THEN 'lunes'   WHEN 2 THEN 'martes' WHEN 3 THEN 'miércoles'
        WHEN 4 THEN 'jueves'  WHEN 5 THEN 'viernes' WHEN 6 THEN 'sábado'
        ELSE 'domingo'
    END                                               AS dia,
    hora,
    pedidos,
    ROUND(100.0 * pedidos / AVG(pedidos) OVER (), 0)  AS indice_vs_media
FROM por_hora
ORDER BY dia_semana, hora;
