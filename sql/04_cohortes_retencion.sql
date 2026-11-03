-- =====================================================================
-- 04_cohortes_retencion.sql
-- Pregunta: de los clientes que compran por primera vez en un mes,
--           ¿cuántos vuelven a comprar en los meses siguientes?
-- Técnicas: MIN() OVER (PARTITION BY) para la cohorte, DATE_DIFF en
--           meses, FIRST_VALUE para el tamaño de la cohorte.
-- =====================================================================

WITH actividad AS (
    SELECT DISTINCT
        customer_unique_id,
        mes,
        MIN(mes) OVER (PARTITION BY customer_unique_id) AS cohorte
    FROM pedidos_analisis
),
por_cohorte AS (
    SELECT
        cohorte,
        DATE_DIFF('month', cohorte, mes)      AS mes_n,
        COUNT(DISTINCT customer_unique_id)    AS clientes_activos
    FROM actividad
    GROUP BY cohorte, DATE_DIFF('month', cohorte, mes)
)
SELECT
    cohorte,
    mes_n,
    FIRST_VALUE(clientes_activos) OVER (
        PARTITION BY cohorte ORDER BY mes_n)            AS tamano_cohorte,
    clientes_activos,
    ROUND(100.0 * clientes_activos / FIRST_VALUE(clientes_activos) OVER (
        PARTITION BY cohorte ORDER BY mes_n), 2)        AS retencion_pct
FROM por_cohorte
ORDER BY cohorte, mes_n;
