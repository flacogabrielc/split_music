#!/usr/bin/env python3
"""analizar_bpm.py - Detecta el BPM (tempo) y la tonalidad de un audio con librosa.

Complementa a analizar.py (que saca los ACORDES con chord-extractor/Chordino): Chordino
no informa tempo ni tonalidad, así que eso se calcula acá con librosa.

Uso:
    python analizar_bpm.py <archivo_audio> --out <ruta_base>

Escribe dos archivos:
    <ruta_base>.txt    resumen "clave valor", una línea por dato (fácil de leer con awk/cut)
    <ruta_base>.json   los mismos datos + candidatos de tonalidad + tiempos de beat

Ejemplo:
    python analizar_bpm.py "mp3/tema.mp3" --out "output/tema/analisis/tema_tempo"
      -> output/tema/analisis/tema_tempo.txt
      -> output/tema/analisis/tema_tempo.json

Método:
    - BPM: librosa.beat.beat_track (tempo global) + refinamiento con la mediana de los
      intervalos entre beats detectados (más robusto que el prior interno de librosa).
    - Tonalidad: chroma_cqt + correlación contra los 24 perfiles de Krumhansl-Kessler
      (12 mayores + 12 menores), más una regla de tónica/dominante.

Recomendación de uso: analizar el TEMA COMPLETO. En stems de batería+bajo el croma se
sesga hacia el bajo y la tonalidad sale mal (los acordes de un stem rítmico no tienen
sentido musical).
"""
import argparse
import json
import os
import sys
from datetime import datetime

import numpy as np

# --- Constantes -------------------------------------------------------------
HERRAMIENTA = "librosa (beat_track + chroma_cqt + perfiles de Krumhansl-Kessler)"
SR_ANALISIS = 22050          # mono, suficiente para tempo/tonalidad y más rápido
HOP_ANALISIS = 256           # hop del onset envelope. Con 512 (default de librosa) el BPM
                             # de temas rápidos sale BAJO: en "Boogie with Stu" daba 129.2
                             # cuando el real es 133; con 256 da 132.5.
NOTAS = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

# Refinamiento del BPM por "peine": busca el tempo que mejor alinea los onsets a lo largo
# de TODO el audio (un tempo correcto se mantiene alineado; uno equivocado se desincroniza).
REFINAR_MARGEN = 0.08        # fracción alrededor del BPM inicial donde busca (±8%)
REFINAR_PASO = 0.1           # resolución de la búsqueda, en BPM
REFINAR_FASES = 20           # cuántas fases distintas se prueban por período

# Perfiles de Krumhansl-Kessler (referencia clásica de percepción tonal)
PERFIL_MAYOR = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
PERFIL_MENOR = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])

# Rango "creíble" de tempo: si el detector se va por octava, se avisa de la alternativa
BPM_MIN = 60.0
BPM_MAX = 180.0


def error(msg, codigo=1):
    """Mensaje de error claro por stderr y salida con código."""
    print(f"[ERROR] {msg}", file=sys.stderr)
    sys.exit(codigo)


def aviso(msg):
    print(f"[AVISO] {msg}", file=sys.stderr)


def parse_args():
    p = argparse.ArgumentParser(
        description="Detecta el BPM (tempo) y la tonalidad de un audio usando librosa.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "La salida es <ruta_base>.txt y <ruta_base>.json.\n"
            "Si --out termina en .txt o .json se le quita la extensión y se usan ambas."
        ),
    )
    p.add_argument("archivo", help="archivo de audio de entrada (wav/mp3/flac/ogg/m4a)")
    p.add_argument("--sin-refinar", action="store_true",
                   help="no busca el BPM por peine (más rápido, menos preciso)")
    p.add_argument("--out", required=True,
                   help="ruta base de salida, SIN extensión (ej: output/tema/analisis/tema_tempo)")
    return p.parse_args()


def normalizar_base(ruta):
    """Devuelve la ruta base sin extensión .txt/.json (si la tuviera)."""
    bajo = ruta.lower()
    for ext in (".txt", ".json"):
        if bajo.endswith(ext):
            return ruta[: -len(ext)]
    return ruta


def cargar_librosa():
    """Importa librosa con un mensaje de error útil si falta."""
    try:
        import librosa
    except ImportError as exc:
        error(
            "No se pudo importar librosa: "
            f"{exc}\n"
            "    Instalalo con:\n"
            "      ./venv/bin/pip install -r requirements.txt"
        )
    return librosa


def correlacion(a, b):
    """Coeficiente de correlación de Pearson entre dos vectores (0 si alguno es nulo)."""
    a = a - a.mean()
    b = b - b.mean()
    den = np.linalg.norm(a) * np.linalg.norm(b)
    return float(np.dot(a, b) / den) if den else 0.0


def refinar_bpm(oenv, sr, hop, bpm_aprox):
    """Busca el tempo que mejor alinea los onsets a lo largo de todo el audio ("peine").

    Un tempo correcto se mantiene alineado durante minutos; uno equivocado se
    desincroniza y pierde energía. Es más preciso que la autocorrelación local.
    """
    n = int(oenv.size)
    dur = n * hop / sr
    mejor_score, mejor_bpm = -1.0, float(bpm_aprox)
    for bpm in np.arange(bpm_aprox * (1 - REFINAR_MARGEN),
                         bpm_aprox * (1 + REFINAR_MARGEN), REFINAR_PASO):
        periodo = 60.0 / bpm
        for fase in np.linspace(0.0, periodo, REFINAR_FASES, endpoint=False):
            idx = np.round(np.arange(fase, dur, periodo) * sr / hop).astype(int)
            idx = idx[idx < n]
            if idx.size < 10:
                continue
            score = float(oenv[idx].mean())
            if score > mejor_score:
                mejor_score, mejor_bpm = score, float(bpm)
    return mejor_bpm


def detectar_tempo(librosa, y, sr, refinar=True):
    """BPM: beat_track (hop fino) + mediana de intervalos + refinamiento por peine."""
    oenv = librosa.onset.onset_strength(y=y, sr=sr, hop_length=HOP_ANALISIS)
    tempo, beats = librosa.beat.beat_track(
        onset_envelope=oenv, sr=sr, hop_length=HOP_ANALISIS, units="time"
    )
    bpm_beat_track = float(np.atleast_1d(tempo)[0])
    beats = np.asarray(beats, dtype=float)

    intervalos = np.diff(beats)
    if intervalos.size >= 4:
        # descarto el 10% más extremo de cada lado: beats perdidos o de más
        lo, hi = np.percentile(intervalos, [5, 95])
        filtrados = intervalos[(intervalos >= lo) & (intervalos <= hi)]
        base = filtrados if filtrados.size else intervalos
        bpm_mediana = 60.0 / float(np.median(base))
    else:
        bpm_mediana = bpm_beat_track

    bpm = bpm_mediana if bpm_mediana > 0 else bpm_beat_track
    bpm_refinado = None
    if refinar and bpm > 0:
        oenv_norm = (oenv - oenv.min()) / (oenv.max() - oenv.min() + 1e-9)
        bpm_refinado = refinar_bpm(oenv_norm, sr, HOP_ANALISIS, bpm)
        bpm = bpm_refinado

    return {
        "bpm": round(bpm, 2),
        "bpm_beat_track": round(bpm_beat_track, 2),
        "bpm_mediana": round(bpm_mediana, 2),
        "bpm_refinado": round(bpm_refinado, 2) if bpm_refinado else None,
        "discrepancia_pct": round(abs(bpm - bpm_beat_track) / bpm * 100, 2) if bpm else 0.0,
        "hop_length": HOP_ANALISIS,
        "beats_detectados": int(beats.size),
        "beats_s": [round(float(b), 4) for b in beats],
        "alternativas_bpm": [round(bpm / 2.0, 2), round(bpm * 2.0, 2)],
        "posible_octava": bool(bpm < BPM_MIN or bpm > BPM_MAX),
    }


def detectar_tonalidad(librosa, y, sr):
    """Tonalidad por correlación del croma medio con los 24 perfiles de Krumhansl."""
    croma = librosa.feature.chroma_cqt(y=y, sr=sr)
    croma_media = croma.mean(axis=1)
    total = float(croma_media.sum())
    if total <= 0:
        error("El croma quedó en cero: el audio parece silencio o demasiado corto.")
    croma_norm = croma_media / total

    candidatos = []
    for i in range(12):
        mayor = correlacion(np.roll(PERFIL_MAYOR, i), croma_norm)
        menor = correlacion(np.roll(PERFIL_MENOR, i), croma_norm)
        candidatos.append({"tonica": NOTAS[i], "modo": "mayor", "compacta": NOTAS[i],
                           "completa": f"{NOTAS[i]} mayor", "score": mayor})
        candidatos.append({"tonica": NOTAS[i], "modo": "menor", "compacta": NOTAS[i] + "m",
                           "completa": f"{NOTAS[i]} menor", "score": menor})
    candidatos.sort(key=lambda c: -c["score"])

    mejor, segundo = candidatos[0], candidatos[1]
    margen = mejor["score"] - segundo["score"]
    return {
        "tonica": mejor["tonica"],
        "modo": mejor["modo"],
        "compacta": mejor["compacta"],
        "completa": f"{mejor['tonica']} {'mayor' if mejor['modo'] == 'mayor' else 'menor'}",
        "confianza": round(mejor["score"], 4),
        "margen": round(margen, 4),
        "ambigua": bool(margen < 0.05),
        "candidatos": [{**c, "score": round(c["score"], 4)} for c in candidatos[:5]],
        "croma_porcentaje": {NOTAS[i]: round(float(croma_norm[i]) * 100, 1) for i in range(12)},
    }


def escribir_txt(base, datos):
    """Escribe el resumen '<clave> <valor>', una línea por dato."""
    ruta = base + ".txt"
    tempo, ton = datos["tempo"], datos["tonalidad"]
    lineas = [
        "# BPM y tonalidad - detectado con librosa",
        "# formato: <clave> <valor>",
        f"archivo {datos['archivo_analizado']}",
        f"duracion_s {datos['duracion_s']}",
        f"bpm {tempo['bpm']}",
        f"bpm_beat_track {tempo['bpm_beat_track']}",
        f"bpm_mediana {tempo['bpm_mediana']}",
        f"bpm_refinado {tempo['bpm_refinado'] if tempo['bpm_refinado'] else '-'}",
        f"discrepancia_pct {tempo['discrepancia_pct']}",
        f"beats {tempo['beats_detectados']}",
        f"bpm_mitad {tempo['alternativas_bpm'][0]}",
        f"bpm_doble {tempo['alternativas_bpm'][1]}",
        f"posible_octava {'si' if tempo['posible_octava'] else 'no'}",
        f"tonalidad {ton['compacta']}",
        f"tonalidad_completa {ton['completa']}",
        f"modo {ton['modo']}",
        f"confianza {ton['confianza']}",
        f"margen {ton['margen']}",
        f"ambigua {'si' if ton['ambigua'] else 'no'}",
    ]
    try:
        with open(ruta, "w", encoding="utf-8") as fh:
            fh.write("\n".join(lineas) + "\n")
    except OSError as exc:
        error(f"No se pudo escribir '{ruta}': {exc}")
    return ruta


def escribir_json(base, datos, archivo):
    """Escribe todos los datos (incluye los candidatos de tonalidad y los tiempos de beat)."""
    ruta = base + ".json"
    doc = {
        "archivo_analizado": os.path.abspath(archivo),
        "herramienta": HERRAMIENTA,
        "generado": datetime.now().isoformat(timespec="seconds"),
        "duracion_s": datos["duracion_s"],
        "tasa_muestreo_analisis": SR_ANALISIS,
        "tempo": datos["tempo"],
        "tonalidad": datos["tonalidad"],
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

    librosa = cargar_librosa()

    base = normalizar_base(args.out)
    carpeta = os.path.dirname(base) or "."
    try:
        os.makedirs(carpeta, exist_ok=True)
    except OSError as exc:
        error(f"No se pudo crear la carpeta de salida '{carpeta}': {exc}")

    try:
        y, sr = librosa.load(args.archivo, sr=SR_ANALISIS, mono=True)
    except Exception as exc:
        error(
            f"No se pudo leer el audio '{args.archivo}': {exc}\n"
            "    Causas frecuentes: archivo corrupto, formato no soportado o duración muy corta."
        )
    if y.size == 0 or not sr:
        error("El audio quedó vacío al leerlo (¿archivo corrupto o duración cero?)")

    tempo = detectar_tempo(librosa, y, sr, refinar=not args.sin_refinar)
    ton = detectar_tonalidad(librosa, y, sr)
    datos = {
        "archivo_analizado": args.archivo,
        "duracion_s": round(len(y) / sr, 3),
        "tempo": tempo,
        "tonalidad": ton,
    }

    txt = escribir_txt(base, datos)
    jsn = escribir_json(base, datos, args.archivo)

    # Resumen legible por máquina (lo consume analizar.sh)
    print(f"HERRAMIENTA: {HERRAMIENTA}")
    print(f"BPM: {tempo['bpm']}")
    print(f"BPM_BEAT_TRACK: {tempo['bpm_beat_track']}")
    print(f"BPM_MEDIANA: {tempo['bpm_mediana']}")
    print(f"BPM_REFINADO: {tempo['bpm_refinado']}")
    print(f"DISCREPANCIA_PCT: {tempo['discrepancia_pct']}")
    print(f"BEATS: {tempo['beats_detectados']}")
    print(f"TONALIDAD: {ton['completa']}")
    print(f"TONALIDAD_COMPACTA: {ton['compacta']}")
    print(f"CONFIANZA: {ton['confianza']}")
    print(f"AMBIGUA: {'si' if ton['ambigua'] else 'no'}")
    print(f"TXT: {txt}")
    print(f"JSON: {jsn}")

    if ton["ambigua"]:
        aviso(
            f"Tonalidad ambigua: '{ton['completa']}' le saca solo {ton['margen']} de ventaja a "
            f"'{ton['candidatos'][1]['completa']}'. Tomalo como orientativo."
        )
    if tempo["posible_octava"]:
        aviso(
            f"El BPM detectado ({tempo['bpm']}) está fuera del rango habitual "
            f"({BPM_MIN:.0f}-{BPM_MAX:.0f}): puede ser el doble o la mitad del real "
            f"(alternativas: {tempo['alternativas_bpm'][0]} o {tempo['alternativas_bpm'][1]})."
        )
    if tempo["beats_detectados"] < 8:
        aviso(f"Se detectaron muy pocos beats ({tempo['beats_detectados']}): el BPM es poco fiable.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
