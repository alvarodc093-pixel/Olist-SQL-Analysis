-- =====================================================================
-- 09_pagos.sql
-- Pregunta: ¿cómo pagan los clientes y qué relación hay entre el pago a
--           plazos y el importe del pedido?
-- Técnicas: método principal por pedido con ROW_NUMBER, CASE para
--           tramos, agregación condicional.
-- =====================================================================

WITH pago_principal AS (
    -- Un pedido puede combinar vale + tarjeta: me quedo con el método
    -- que paga más.
    SELECT
        pg.order_id,
        pg.tipo_pago,
        pg.cuotas,
        ROW_NUMBER() OVER (PARTITION BY pg.order_id
                           ORDER BY pg.importe DESC, pg.secuencia) AS rn
    FROM fct_pagos        AS pg
    JOIN pedidos_analisis AS p ON p.order_id = pg.order_id
)
SELECT
    pp.tipo_pago,
    COUNT(*)                                             AS pedidos,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)    AS pct_pedidos,
    ROUND(AVG(p.gmv), 2)                                 AS ticket_medio,
    ROUND(AVG(pp.cuotas), 2)                             AS cuotas_medias,
    ROUND(100.0 * AVG(CASE WHEN pp.cuotas >= 6 THEN 1 ELSE 0 END), 1)
                                                         AS pct_6_o_mas_cuotas,
    ROUND(AVG(p.gmv) FILTER (WHERE pp.cuotas = 1), 2)    AS ticket_medio_1_cuota,
    ROUND(AVG(p.gmv) FILTER (WHERE pp.cuotas >= 6), 2)   AS ticket_medio_6_o_mas_cuotas
FROM pago_principal   AS pp
JOIN pedidos_analisis AS p ON p.order_id = pp.order_id
WHERE pp.rn = 1
GROUP BY pp.tipo_pago
ORDER BY pedidos DESC;
