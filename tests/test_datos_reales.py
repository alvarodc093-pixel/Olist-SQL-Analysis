"""Tests de coherencia sobre el dataset real de Olist.

Comprueban que las distintas consultas cuadran entre sí (el mismo total de
ventas visto desde varios ángulos). Se saltan si no se ha descargado el
dataset (python descargar_datos.py).
"""

import duckdb
import pytest

from ejecutar import CARPETA_RAW, TABLAS_RAW, cargar_raw, consultas, construir_modelo, ejecutar_consulta

hay_datos = all((CARPETA_RAW / f).exists() for f in TABLAS_RAW.values())
pytestmark = pytest.mark.skipif(not hay_datos, reason="Falta el dataset: python descargar_datos.py")


@pytest.fixture(scope="module")
def res():
    con = duckdb.connect()
    cargar_raw(con)
    construir_modelo(con)
    resultados = {a.stem: ejecutar_consulta(con, a) for a in consultas()}
    resultados["_base"] = con.execute(
        "SELECT COUNT(*) AS pedidos, SUM(gmv) AS gmv, SUM(importe_productos) AS productos, "
        "COUNT(DISTINCT customer_unique_id) AS clientes FROM pedidos_analisis"
    ).df().iloc[0]
    con.close()
    return resultados


def test_volumen_esperado(res):
    assert 95_000 < res["_base"]["pedidos"] < 100_000


def test_calidad_sin_duplicados_ni_huerfanos(res):
    calidad = res["01_calidad_datos"].set_index("comprobacion")["valor"]
    assert calidad["Pedidos duplicados (order_id)"] == 0
    assert calidad["Items cuyo pedido no existe"] == 0
    assert calidad["Entregas anteriores a la compra"] == 0


def test_kpis_cuadran_con_la_base(res):
    kpis = res["02_kpis_mensuales"]
    assert len(kpis) == 20
    assert kpis["pedidos"].sum() == res["_base"]["pedidos"]
    assert kpis["gmv"].sum() == pytest.approx(res["_base"]["gmv"], abs=1)


def test_categorias_cuadran_con_la_base(res):
    assert res["03_categorias_pareto"]["ingresos"].sum() == pytest.approx(res["_base"]["productos"], abs=1)


def test_estados_cuadran_con_la_base(res):
    assert res["08_geografia"]["pedidos"].sum() == res["_base"]["pedidos"]


def test_estacionalidad_cuadra_con_la_base(res):
    assert res["10_estacionalidad"]["pedidos"].sum() == res["_base"]["pedidos"]
    assert len(res["10_estacionalidad"]) == 7 * 24


def test_cohortes_suman_todos_los_clientes(res):
    coh = res["04_cohortes_retencion"]
    mes0 = coh[coh["mes_n"] == 0]
    assert (mes0["retencion_pct"] == 100).all()
    assert mes0["clientes_activos"].sum() == res["_base"]["clientes"]


def test_vendedores_suman_100(res):
    assert res["07_vendedores"]["pct_ingresos"].sum() == pytest.approx(100, abs=0.05)


def test_black_friday_es_el_mayor_pico(res):
    assert str(res["11_dias_pico"].iloc[0]["dia"]).startswith("2017-11-24")
