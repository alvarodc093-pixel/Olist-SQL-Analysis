"""Tests de la lógica SQL con un mini dataset hecho a mano.

Cada número esperado se puede calcular de cabeza, así que si una consulta
cambia y da otro resultado, el test lo detecta. No necesitan los datos
reales: se ejecutan siempre, también en CI.
"""

import duckdb
import pytest

from ejecutar import CARPETA_SQL, construir_modelo, ejecutar_consulta

RAW_SQL = """
CREATE TABLE raw_customers AS SELECT * FROM (VALUES
    ('c1', 'ana',   '01000', 'sao paulo', 'SP'),
    ('c2', 'ana',   '01000', 'sao paulo', 'SP'),
    ('c3', 'bruno', '20000', 'rio',       'RJ'),
    ('c4', 'carla', '20000', 'rio',       'RJ'),
    ('c5', 'dani',  '01000', 'sao paulo', 'SP')
) t(customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state);

CREATE TABLE raw_orders AS SELECT * FROM (VALUES
    -- ana compra en enero y vuelve en marzo
    ('o1', 'c1', 'delivered', TIMESTAMP '2017-01-10 10:00', TIMESTAMP '2017-01-15 00:00', TIMESTAMP '2017-01-20 00:00'),
    ('o2', 'c2', 'delivered', TIMESTAMP '2017-03-05 21:00', TIMESTAMP '2017-03-20 00:00', TIMESTAMP '2017-03-10 00:00'),
    -- bruno compra en enero, entrega a tiempo
    ('o3', 'c3', 'delivered', TIMESTAMP '2017-01-20 12:00', TIMESTAMP '2017-01-25 00:00', TIMESTAMP '2017-01-25 00:00'),
    -- carla cancela: no cuenta
    ('o4', 'c4', 'canceled',  TIMESTAMP '2017-02-01 09:00', NULL,                         TIMESTAMP '2017-02-20 00:00'),
    -- dani compra en 2016: fuera del periodo
    ('o5', 'c5', 'delivered', TIMESTAMP '2016-10-01 09:00', TIMESTAMP '2016-10-10 00:00', TIMESTAMP '2016-10-20 00:00')
) t(order_id, customer_id, order_status, order_purchase_timestamp,
    order_delivered_customer_date, order_estimated_delivery_date);

CREATE TABLE raw_order_items AS SELECT * FROM (VALUES
    ('o1', 1, 'p1', 's1', 100.0, 10.0),
    ('o1', 2, 'p2', 's2',  50.0,  5.0),
    ('o2', 1, 'p1', 's1', 100.0, 20.0),
    ('o3', 1, 'p3', 's2', 200.0, 15.0),
    ('o4', 1, 'p1', 's1', 100.0, 10.0),
    ('o5', 1, 'p1', 's1', 100.0, 10.0)
) t(order_id, order_item_id, product_id, seller_id, price, freight_value);

CREATE TABLE raw_order_payments AS SELECT * FROM (VALUES
    -- o1 se paga con dos métodos: si se uniera sin agregar, duplicaría items
    ('o1', 1, 'credit_card', 3, 120.0),
    ('o1', 2, 'voucher',     1,  45.0),
    ('o2', 1, 'boleto',      1, 120.0),
    ('o3', 1, 'credit_card', 8, 215.0),
    ('o4', 1, 'credit_card', 1, 110.0),
    ('o5', 1, 'credit_card', 1, 110.0)
) t(order_id, payment_sequential, payment_type, payment_installments, payment_value);

CREATE TABLE raw_order_reviews AS SELECT * FROM (VALUES
    -- o1 tiene dos reviews: vale la última (5)
    ('r1', 'o1', 2, TIMESTAMP '2017-01-21 00:00', TIMESTAMP '2017-01-22 00:00'),
    ('r2', 'o1', 5, TIMESTAMP '2017-01-23 00:00', TIMESTAMP '2017-01-24 00:00'),
    ('r3', 'o2', 1, TIMESTAMP '2017-03-21 00:00', TIMESTAMP '2017-03-22 00:00'),
    ('r4', 'o3', 4, TIMESTAMP '2017-01-26 00:00', TIMESTAMP '2017-01-27 00:00')
) t(review_id, order_id, review_score, review_creation_date, review_answer_timestamp);

CREATE TABLE raw_products AS SELECT * FROM (VALUES
    ('p1', 'beleza_saude', 500, 1),
    ('p2', NULL,           300, 2),
    ('p3', 'relogios_presentes', 200, 3)
) t(product_id, product_category_name, product_weight_g, product_photos_qty);

CREATE TABLE raw_sellers AS SELECT * FROM (VALUES
    ('s1', 'sao paulo', 'SP'),
    ('s2', 'curitiba',  'PR')
) t(seller_id, seller_city, seller_state);

CREATE TABLE raw_category_translation AS SELECT * FROM (VALUES
    ('beleza_saude', 'health_beauty'),
    ('relogios_presentes', 'watches_gifts')
) t(product_category_name, product_category_name_english);
"""


@pytest.fixture(scope="module")
def con():
    c = duckdb.connect()
    c.execute(RAW_SQL)
    construir_modelo(c)
    yield c
    c.close()


def consulta(con, nombre):
    return ejecutar_consulta(con, CARPETA_SQL / nombre)


def test_base_de_analisis_excluye_cancelados_y_fuera_de_periodo(con):
    ids = {r[0] for r in con.execute("SELECT order_id FROM pedidos_analisis").fetchall()}
    assert ids == {"o1", "o2", "o3"}


def test_items_y_pagos_no_se_duplican(con):
    gmv_o1, pagado_o1 = con.execute(
        "SELECT gmv, importe_pagado FROM fct_pedidos WHERE order_id = 'o1'"
    ).fetchone()
    assert gmv_o1 == pytest.approx(165.0)
    assert pagado_o1 == pytest.approx(165.0)


def test_se_usa_la_ultima_review(con):
    assert con.execute("SELECT nota FROM fct_reviews WHERE order_id = 'o1'").fetchone()[0] == 5


def test_producto_sin_categoria(con):
    cat = con.execute("SELECT categoria FROM dim_productos WHERE product_id = 'p2'").fetchone()[0]
    assert cat == "sin_categoria"


def test_kpis_mensuales(con):
    df = consulta(con, "02_kpis_mensuales.sql").set_index("mes")
    enero = df.loc[df.index.astype(str).str.startswith("2017-01")].iloc[0]
    assert enero["pedidos"] == 2
    assert enero["clientes"] == 2
    assert enero["gmv"] == pytest.approx(380.0)          # 165 + 215
    assert enero["ticket_medio"] == pytest.approx(190.0)


def test_pareto_suma_100(con):
    df = consulta(con, "03_categorias_pareto.sql")
    assert df["pct_acumulado"].iloc[-1] == pytest.approx(100.0)
    # health_beauty (100 + 100) y watches_gifts (200) empatan: RANK les da
    # el puesto 1 a las dos y el siguiente salta al 3.
    rangos = dict(zip(df["categoria"], df["ranking"]))
    assert rangos == {"health_beauty": 1, "watches_gifts": 1, "sin_categoria": 3}


def test_cohortes(con):
    df = consulta(con, "04_cohortes_retencion.sql")
    enero = df[df["cohorte"].astype(str).str.startswith("2017-01")].set_index("mes_n")
    assert enero.loc[0, "tamano_cohorte"] == 2               # ana y bruno
    assert enero.loc[0, "retencion_pct"] == 100.0
    assert enero.loc[2, "clientes_activos"] == 1             # ana vuelve en marzo
    assert enero.loc[2, "retencion_pct"] == 50.0


def test_recompra(con):
    fila = consulta(con, "05_recompra.sql").iloc[0]
    assert fila["clientes"] == 2
    assert fila["clientes_recurrentes"] == 1
    assert fila["pct_recurrentes"] == 50.0
    assert fila["mediana_dias_segunda_compra"] == 54         # 10-ene -> 5-mar


def test_entregas_vs_reviews(con):
    df = consulta(con, "06_entregas_vs_reviews.sql").set_index("tramo")
    assert "1. 10 o más días antes" not in df.index
    assert df.loc["2. 1 a 9 días antes", "nota_media"] == 5.0      # o1: 5 días antes
    assert df.loc["3. El día previsto", "nota_media"] == 4.0       # o3
    assert df.loc["5. Más de 7 días tarde", "pct_notas_1_2"] == 100.0  # o2: 10 días tarde


def test_pagos_metodo_principal(con):
    df = consulta(con, "09_pagos.sql").set_index("tipo_pago")
    # En o1 la tarjeta paga más que el vale, así que el vale no aparece.
    assert "voucher" not in df.index
    assert df.loc["credit_card", "pedidos"] == 2
    assert df.loc["boleto", "pedidos"] == 1


def test_todas_las_consultas_tienen_pregunta():
    for archivo in sorted(CARPETA_SQL.glob("*.sql")):
        if archivo.name == "00_modelo.sql":
            continue
        assert "Pregunta:" in archivo.read_text(encoding="utf-8"), archivo.name
