"""Descarga el dataset público de Olist desde Kaggle y lo deja en data/raw/.

No hace falta cuenta de Kaggle: el dataset es público.
Uso: python descargar_datos.py
"""

import io
import sys
import urllib.request
import zipfile
from pathlib import Path

URL = "https://www.kaggle.com/api/v1/datasets/download/olistbr/brazilian-ecommerce"
DESTINO = Path(__file__).parent / "data" / "raw"

# El CSV de geolocalización (61 MB) no se usa en el análisis.
ARCHIVOS = [
    "olist_customers_dataset.csv",
    "olist_orders_dataset.csv",
    "olist_order_items_dataset.csv",
    "olist_order_payments_dataset.csv",
    "olist_order_reviews_dataset.csv",
    "olist_products_dataset.csv",
    "olist_sellers_dataset.csv",
    "product_category_name_translation.csv",
]


def descargar(destino: Path = DESTINO) -> None:
    if all((destino / f).exists() for f in ARCHIVOS):
        print(f"Los datos ya están en {destino}")
        return
    destino.mkdir(parents=True, exist_ok=True)
    print("Descargando Olist desde Kaggle (~45 MB)...")
    with urllib.request.urlopen(URL, timeout=120) as resp:
        contenido = resp.read()
    with zipfile.ZipFile(io.BytesIO(contenido)) as z:
        for nombre in ARCHIVOS:
            (destino / nombre).write_bytes(z.read(nombre))
    print(f"Listo: {len(ARCHIVOS)} archivos en {destino}")


if __name__ == "__main__":
    try:
        descargar()
    except Exception as e:  # noqa: BLE001
        sys.exit(f"No se pudo descargar el dataset: {e}")
