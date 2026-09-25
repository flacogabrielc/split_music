#!/usr/bin/env python3
"""analizar.py - Extrae la secuencia de acordes de un audio con chord-extractor (Chordino).

Uso:
    python analizar.py <archivo_audio> --out <ruta_base>

Escribe dos archivos:
    <ruta_base>.txt    "timestamp_segundos acorde", una línea por segmento
    <ruta_base>.json   metadatos + lista de {"timestamp": float, "acorde": str}

Ejemplo:
    python analizar.py "mp3/tema.mp3" --out "output/tema/analisis/tema_acordes"
      -> output/tema/analisis/tema_acordes.txt
      -> output/tema/analisis/tema_acordes.json
"""
import argparse
import json
import os
import sys
from datetime import datetime

HERRAMIENTA = "chord-extractor 0.1.3 / Chordino (nnls-chroma)"


def error(msg, codigo=1):
    """Mensaje de error claro por stderr y salida con código."""
    print(f"[ERROR] {msg}", file=sys.stderr)
    sys.exit(codigo)


def parse_args():
    p = argparse.ArgumentParser(
        description="Extrae acordes (con timestamps) de un archivo de audio usando Chordino.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "El archivo de salida es <ruta_base>.txt y <ruta_base>.json.\n"
            "Si --out termina en .txt o .json se le quita la extensión y se usan ambas."
        ),
    )
    p.add_argument("archivo", help="archivo de audio de entrada (wav/mp3/flac/ogg/m4a)")
    p.add_argument("--out", required=True,
                   help="ruta base de salida, SIN extensión (ej: output/tema/analisis/tema_acordes)")
    p.add_argument("--decimales", type=int, default=3,
                   help="decimales para el timestamp en el .txt (default: 3)")
    return p.parse_args()


def normalizar_base(ruta):
    """Devuelve la ruta base sin extensión .txt/.json (si la tuviera)."""
    bajo = ruta.lower()
    for ext in (".txt", ".json"):
        if bajo.endswith(ext):
            return ruta[: -len(ext)]
    return ruta


def cargar_extractor():
    """Importa e inicializa Chordino con mensajes de error útiles."""
    try:
        from chord_extractor.extractors import Chordino  # noqa: WPS433 (import local a propósito)
    except ImportError as exc:
        error(
            "No se pudo importar chord-extractor: "
            f"{exc}\n"
            "    Instalalo con:\n"
            "      ./venv/bin/pip install --ignore-requires-python --no-build-isolation chord-extractor"
        )
    try:
        return Chordino()
    except Exception as exc:  # el plugin nnls-chroma.so tiene que ser cargable
        error(
            f"No se pudo inicializar Chordino: {exc}\n"
            "    Verificá que exista el plugin incluido en el paquete:\n"
            "      ./venv/bin/python -c \"import chord_extractor, os; print(os.path.dirname(chord_extractor.__file__))\"\n"
            "    (debe contener _lib/nnls-chroma.so)"
        )


def extraer(extractor, archivo):
    """Ejecuta la extracción de acordes y devuelve una lista de dicts."""
    try:
        segmentos = extractor.extract(archivo)
    except Exception as exc:
        error(
            f"Falló la extracción de acordes de '{archivo}': {exc}\n"
            "    Causas frecuentes: archivo corrupto, formato no soportado o duración muy corta."
        )
    if segmentos is None:
        error(f"El extractor no devolvió resultados para '{archivo}'.")
    acordes = []
    for seg in segmentos:
        try:
            acordes.append({
                "timestamp": round(float(seg.timestamp), 4),
                "acorde": str(seg.chord),
            })
        except AttributeError:
            error(f"Segmento con formato inesperado: {seg!r} (se esperaban campos .timestamp y .chord)")
    return acordes


def escribir_txt(base, acordes, decimales):
    ruta = base + ".txt"
    try:
        with open(ruta, "w", encoding="utf-8") as fh:
            for a in acordes:
                fh.write(f"{a['timestamp']:.{decimales}f} {a['acorde']}\n")
    except OSError as exc:
        error(f"No se pudo escribir '{ruta}': {exc}")
    return ruta


def escribir_json(base, acordes, archivo):
    ruta = base + ".json"
    doc = {
        "archivo_analizado": os.path.abspath(archivo),
        "herramienta": HERRAMIENTA,
        "generado": datetime.now().isoformat(timespec="seconds"),
        "total_segmentos": len(acordes),
        "acordes": acordes,
    }
    try:
        with open(ruta, "w", encoding="utf-8") as fh:
            json.dump(doc, fh, ensure_ascii=False, indent=2)
            fh.write("\n")
    except OSError as exc:
        error(f"No se pudo escribir '{ruta}': {exc}")
    return ruta


def main():
    args = parse_args()
    if not os.path.isfile(args.archivo):
        error(f"No existe el archivo: '{args.archivo}'")
    if os.path.getsize(args.archivo) == 0:
        error(f"El archivo está vacío: '{args.archivo}'")

    base = normalizar_base(args.out)
    carpeta = os.path.dirname(base) or "."
    try:
        os.makedirs(carpeta, exist_ok=True)
    except OSError as exc:
        error(f"No se pudo crear la carpeta de salida '{carpeta}': {exc}")

    extractor = cargar_extractor()
    acordes = extraer(extractor, args.archivo)

    txt = escribir_txt(base, acordes, args.decimales)
    jsn = escribir_json(base, acordes, args.archivo)

    # Resumen legible por máquina (lo consume analizar.sh)
    print(f"HERRAMIENTA: {HERRAMIENTA}")
    print(f"SEGMENTOS: {len(acordes)}")
    print(f"TXT: {txt}")
    print(f"JSON: {jsn}")
    print("SECUENCIA: " + " ".join(a["acorde"] for a in acordes))
    if not acordes:
        print("[AVISO] No se detectó ningún acorde (¿silencio o audio muy corto?)", file=sys.stderr)
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
