"""Genera los gráficos del README a partir de los CSV de results/.

Uso: python graficos.py   (después de python ejecutar.py)
"""

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import pandas as pd  # noqa: E402

RAIZ = Path(__file__).parent
RES = RAIZ / "results"
IMG = RAIZ / "docs" / "img"

AZUL = "#1a56db"
GRIS = "#9ca3af"
ROJO = "#dc2626"

plt.rcParams.update({
    "figure.dpi": 120,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "axes.titleweight": "bold",
    "axes.titlesize": 12,
    "font.size": 10,
})


def miles(x, _pos=None):
    return f"{x / 1e6:.1f} M" if x >= 1e6 else f"{x / 1e3:.0f} k"


def kpis_mensuales():
    df = pd.read_csv(RES / "02_kpis_mensuales.csv", parse_dates=["mes"])
    fig, ax = plt.subplots(figsize=(10, 4.2))
    colores = [ROJO if m.month == 11 and m.year == 2017 else AZUL for m in df["mes"]]
    ax.bar(df["mes"], df["gmv"], width=20, color=colores, alpha=0.85, label="GMV mensual")
    ax.plot(df["mes"], df["gmv_media_movil_3m"], color="#111827", lw=2,
            label="Media móvil 3 meses")
    ax.yaxis.set_major_formatter(miles)
    ax.set_ylabel("BRL")
    ax.set_title("Ventas mensuales (GMV): de 137 k a más de 1 M de BRL en un año")
    ax.annotate("Black Friday 2017", xy=(pd.Timestamp("2017-11-01"), 1.17e6),
                xytext=(pd.Timestamp("2017-05-15"), 1.12e6), color=ROJO,
                arrowprops={"arrowstyle": "->", "color": ROJO})
    ax.legend(frameon=False, loc="upper left")
    fig.tight_layout()
    fig.savefig(IMG / "kpis_mensuales.png")
    plt.close(fig)


def pareto():
    df = pd.read_csv(RES / "03_categorias_pareto.csv").head(25)
    fig, ax = plt.subplots(figsize=(10, 4.8))
    color = df["clase_abc"].map({"A": AZUL, "B": GRIS, "C": "#d1d5db"})
    ax.bar(df["categoria"], df["pct_ingresos"], color=color)
    ax.set_ylabel("% de los ingresos")
    ax.tick_params(axis="x", rotation=75, labelsize=8)
    ax2 = ax.twinx()
    ax2.plot(df["categoria"], df["pct_acumulado"], color=ROJO, marker="o", ms=3)
    ax2.axhline(80, color=ROJO, ls="--", lw=1)
    ax2.set_ylim(0, 100)
    ax2.set_ylabel("% acumulado", color=ROJO)
    ax2.spines["right"].set_visible(True)
    n_a = (pd.read_csv(RES / "03_categorias_pareto.csv")["clase_abc"] == "A").sum()
    total = len(pd.read_csv(RES / "03_categorias_pareto.csv"))
    ax.set_title(f"Pareto de categorías: {n_a} de {total} categorías hacen el 80 % de los ingresos")
    fig.tight_layout()
    fig.savefig(IMG / "pareto_categorias.png")
    plt.close(fig)


def cohortes():
    df = pd.read_csv(RES / "04_cohortes_retencion.csv", parse_dates=["cohorte"])
    tabla = (df[(df["mes_n"] >= 1) & (df["mes_n"] <= 12)]
             .pivot(index="cohorte", columns="mes_n", values="retencion_pct")
             .reindex(columns=range(1, 13)))
    # Un hueco es un mes en el que no volvió nadie (0 %), salvo que ese mes
    # caiga después del final de los datos.
    ultimo_mes = pd.Timestamp("2018-08-01")
    for cohorte in tabla.index:
        for n in tabla.columns:
            if cohorte + pd.DateOffset(months=n) <= ultimo_mes and pd.isna(tabla.at[cohorte, n]):
                tabla.at[cohorte, n] = 0.0
    fig, ax = plt.subplots(figsize=(10, 6))
    im = ax.imshow(tabla.values, cmap="Blues", aspect="auto", vmin=0, vmax=1)
    ax.set_xticks(range(12), [str(c) for c in tabla.columns])
    ax.set_yticks(range(len(tabla)), [d.strftime("%Y-%m") for d in tabla.index])
    for i in range(tabla.shape[0]):
        for j in range(tabla.shape[1]):
            v = tabla.values[i, j]
            if pd.notna(v):
                ax.text(j, i, f"{v:.1f}", ha="center", va="center", fontsize=7,
                        color="white" if v > 0.6 else "#111827")
    ax.set_xlabel("Meses desde la primera compra")
    ax.set_ylabel("Cohorte (mes de la primera compra)")
    ax.set_title("Retención por cohorte (%): menos del 1 % vuelve en cualquier mes")
    fig.colorbar(im, ax=ax, label="% de la cohorte que vuelve a comprar")
    fig.tight_layout()
    fig.savefig(IMG / "cohortes.png")
    plt.close(fig)


def entregas():
    df = pd.read_csv(RES / "06_entregas_vs_reviews.csv")
    etiquetas = df["tramo"].str.slice(3)
    fig, ax = plt.subplots(figsize=(10, 4))
    colores = [AZUL, AZUL, GRIS, ROJO, ROJO]
    barras = ax.bar(etiquetas, df["nota_media"], color=colores)
    for b, v, p in zip(barras, df["nota_media"], df["pct_notas_1_2"]):
        ax.text(b.get_x() + b.get_width() / 2, v + 0.08,
                f"{v:.2f}\n({p:.0f} % notas 1-2)", ha="center", fontsize=9)
    ax.set_ylim(0, 5.4)
    ax.set_ylabel("Nota media (1-5)")
    ax.set_title("Un retraso de más de una semana hunde la nota de 4,3 a 1,7")
    fig.tight_layout()
    fig.savefig(IMG / "entregas_vs_reviews.png")
    plt.close(fig)


def estacionalidad():
    df = pd.read_csv(RES / "10_estacionalidad.csv")
    tabla = df.pivot(index="dia", columns="hora", values="pedidos")
    orden = ["lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"]
    tabla = tabla.reindex(orden)
    fig, ax = plt.subplots(figsize=(10, 3.6))
    im = ax.imshow(tabla.values, cmap="Blues", aspect="auto")
    ax.set_xticks(range(24), range(24))
    ax.set_yticks(range(7), orden)
    ax.set_xlabel("Hora de la compra")
    ax.set_title("Cuándo se compra: entre semana de 10 a 22 h; el sábado es el día más flojo")
    fig.colorbar(im, ax=ax, label="Pedidos")
    fig.tight_layout()
    fig.savefig(IMG / "estacionalidad.png")
    plt.close(fig)


def main():
    IMG.mkdir(parents=True, exist_ok=True)
    kpis_mensuales()
    pareto()
    cohortes()
    entregas()
    estacionalidad()
    print(f"Gráficos guardados en {IMG}")


if __name__ == "__main__":
    main()
