"""Construye la base de datos DuckDB y ejecuta todas las consultas de sql/.

1. Carga los CSV de data/raw/ como tablas raw_*.
2. Ejecuta sql/00_modelo.sql (modelo en estrella + vista pedidos_analisis).
3. Ejecuta el resto de archivos .sql y guarda cada resultado en results/.

Uso: python ejecutar.py
"""

from pathlib import Path

import duckdb

RAIZ = Path(__file__).parent
CARPETA_SQL = RAIZ / "sql"
CARPETA_RAW = RAIZ / "data" / "raw"
CARPETA_RESULTADOS = RAIZ / "results"
BASE_DATOS = RAIZ / "data" / "olist.duckdb"

TABLAS_RAW = {
    "raw_customers": "olist_customers_dataset.csv",
    "raw_orders": "olist_orders_dataset.csv",
    "raw_order_items": "olist_order_items_dataset.csv",
    "raw_order_payments": "olist_order_payments_dataset.csv",
    "raw_order_reviews": "olist_order_reviews_dataset.csv",
    "raw_products": "olist_products_dataset.csv",
    "raw_sellers": "olist_sellers_dataset.csv",
    "raw_category_translation": "product_category_name_translation.csv",
}


def cargar_raw(con: duckdb.DuckDBPyConnection, carpeta: Path = CARPETA_RAW) -> None:
    for tabla, archivo in TABLAS_RAW.items():
        ruta = (carpeta / archivo).as_posix()
        con.execute(
            f"CREATE OR REPLACE TABLE {tabla} AS "
            f"SELECT * FROM read_csv('{ruta}', header = true, auto_detect = true)"
        )


def construir_modelo(con: duckdb.DuckDBPyConnection) -> None:
    con.execute((CARPETA_SQL / "00_modelo.sql").read_text(encoding="utf-8"))


def consultas() -> list[Path]:
    """Archivos de análisis, en orden (todos menos el modelo)."""
    return sorted(p for p in CARPETA_SQL.glob("*.sql") if p.name != "00_modelo.sql")


def ejecutar_consulta(con: duckdb.DuckDBPyConnection, archivo: Path):
    return con.execute(archivo.read_text(encoding="utf-8")).df()


def main() -> None:
    BASE_DATOS.unlink(missing_ok=True)
    CARPETA_RESULTADOS.mkdir(exist_ok=True)
    con = duckdb.connect(str(BASE_DATOS))
    cargar_raw(con)
    construir_modelo(con)
    for archivo in consultas():
        df = ejecutar_consulta(con, archivo)
        df.to_csv(CARPETA_RESULTADOS / f"{archivo.stem}.csv", index=False)
        print(f"{archivo.name:<30} {len(df):>4} filas")
    con.close()


if __name__ == "__main__":
    main()
