-- =====================================================================
-- 06_entregas_vs_reviews.sql
-- Pregunta: ¿cuánto castiga un retraso en la entrega a la nota del
--           cliente?
-- Técnicas: CASE para crear tramos, agregación condicional con AVG de
--           un booleano, porcentaje sobre el total con ventana.
-- =====================================================================

WITH entregados AS (
    SELECT
        dias_retraso,
        nota,
        CASE
            WHEN dias_retraso <= -10 THEN '1. 10 o más días antes'
            WHEN dias_retraso <   0  THEN '2. 1 a 9 días antes'
            WHEN dias_retraso =   0  THEN '3. El día previsto'
            WHEN dias_retraso <=  7  THEN '4. 1 a 7 días tarde'
            ELSE                          '5. Más de 7 días tarde'
        END AS tramo
    FROM pedidos_analisis
    WHERE estado_pedido = 'delivered'
      AND fecha_entrega IS NOT NULL
      AND nota IS NOT NULL
)
SELECT
    tramo,
    COUNT(*)                                          AS pedidos,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_pedidos,
    ROUND(AVG(nota), 2)                               AS nota_media,
    ROUND(100.0 * AVG(CASE WHEN nota <= 2 THEN 1 ELSE 0 END), 1)
                                                      AS pct_notas_1_2,
    ROUND(100.0 * AVG(CASE WHEN nota = 5 THEN 1 ELSE 0 END), 1)
                                                      AS pct_notas_5
FROM entregados
GROUP BY tramo
ORDER BY tramo;
