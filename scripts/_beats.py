#!/usr/bin/env python3
"""_beats.py - Busca el tiempo (beat) más cercano a un segundo dado. Uso interno de loop.sh.

Lee los tiempos de beat que guarda `analizar_bpm.py` (`<cancion>_tempo.json`) y decide si
conviene mover el corte de un loop a ese tiempo, para que el loop arranque EN PULSO y no a
mitad de tiempo (que es lo que suena "tropezado" al repetir).

NO modifica ningún audio: solo devuelve un número. El corte lo hace loop.sh con ffmpeg.

Uso:
    python3 _beats.py <cancion>_tempo.json <segundos> [--tolerancia 0.55]

Salida: líneas "<clave> <valor>" (para leerlas desde bash con sed/awk):
    hay_beats si|no          ¿el análisis tiene tiempos de beat?
    n_beats <n>
    objetivo <t>             el segundo que pediste
    beat_mas_cercano <t>
    indice <i>               posición de ese beat en la lista
    desfasaje_ms <d>         positivo = el beat está DESPUÉS del objetivo
    periodo_local <p>        mediana de los intervalos de beat alrededor
    ajustar si|no            ¿conviene mover el corte a ese beat?
    motivo <texto>           por qué NO conviene (si ajustar=no)

Solo se ajusta si el beat más cercano está dentro de `tolerancia` × período local. Si el
tema tiene un intro sin pulsos, el beat más cercano puede estar a segundos de distancia:
en ese caso NO se ajusta y se explica el motivo.

Código de salida: 0 si pudo leer el JSON, 1 si no.
"""
import argparse
import json
import statistics
import sys


def salir(clave, valor):
    print(f"{clave} {valor}")


def parse_args():
    p = argparse.ArgumentParser(
        description="Busca el tiempo de beat más cercano a un segundo dado.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument("json", help="archivo <cancion>_tempo.json del Analista")
    p.add_argument("segundos", type=float, help="segundo objetivo (ej: 32.5)")
    p.add_argument("--tolerancia", type=float, default=0.55,
                   help="fracción del período local dentro de la cual se acepta el ajuste "
                        "(default: 0.55 = media grilla)")
    return p.parse_args()


def main():
    args = parse_args()
    try:
        with open(args.json, encoding="utf-8") as fh:
            doc = json.load(fh)
    except (OSError, ValueError) as exc:
        print(f"[ERROR] No se pudo leer '{args.json}': {exc}", file=sys.stderr)
        return 1

    tempo = doc.get("tempo") or {}
    beats = [float(b) for b in (tempo.get("beats_s") or [])]
    salir("n_beats", len(beats))
    salir("objetivo", f"{args.segundos:.4f}")
    if not beats:
        salir("hay_beats", "no")
        return 0
    salir("hay_beats", "si")

    idx = min(range(len(beats)), key=lambda i: abs(beats[i] - args.segundos))
    cercano = beats[idx]
    delta = cercano - args.segundos

    # Período local: mediana de los intervalos entre los beats vecinos (hasta ±4)
    desde, hasta = max(0, idx - 4), min(len(beats), idx + 5)
    vecinos = beats[desde:hasta]
    intervalos = [b - a for a, b in zip(vecinos, vecinos[1:])]
    periodo = statistics.median(intervalos) if intervalos else 60.0 / 92.0
    umbral = args.tolerancia * periodo

    salir("beat_mas_cercano", f"{cercano:.4f}")
    salir("indice", idx)
    salir("desfasaje_ms", f"{delta * 1000:+.1f}")
    salir("periodo_local", f"{periodo:.4f}")
    if abs(delta) <= umbral:
        salir("ajustar", "si")
    else:
        salir("ajustar", "no")
        salir("motivo", f"el tiempo más cercano está a {abs(delta):.2f} s "
                        f"(fuera de la grilla: el período local es {periodo:.2f} s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
