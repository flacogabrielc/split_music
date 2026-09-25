#!/usr/bin/env python3
"""acordes_html.py - Genera un informe HTML autocontenido con los acordes detectados.

Uso:
    python acordes_html.py <archivo_acordes.txt> --out <ruta.html> [--titulo "Canción (stem)"]

Lee el .txt que produce analizar.py ("timestamp_segundos acorde") y escribe un HTML
que se abre con doble clic (o se imprime a PDF) SIN necesidad de internet:
  · resumen (segmentos, acordes únicos, duración analizada)
  · grilla de diagramas de acorde dibujados en SVG (con digitación cuando se conoce)
  · tabla de cambios (timestamp + acorde + mini diagrama)
  · tira de progresión con la secuencia completa
"""
import argparse
import html
import os
import sys
from collections import Counter, OrderedDict

# --- Teoría mínima: notas y calidades ---------------------------------------
NOTAS = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
BEMOLES = {"Db": "C#", "Eb": "D#", "Gb": "F#", "Ab": "G#", "Bb": "A#", "Cb": "B", "Fb": "E", "E#": "F", "B#": "C"}

# Intervalos (semitonos desde la raíz) por calidad
CALIDADES = {
    "": [0, 4, 7], "m": [0, 3, 7], "5": [0, 7],
    "7": [0, 4, 7, 10], "maj7": [0, 4, 7, 11], "m7": [0, 3, 7, 10],
    "6": [0, 4, 7, 9], "m6": [0, 3, 7, 9], "dim": [0, 3, 6], "aug": [0, 4, 8],
    "sus4": [0, 5, 7], "sus2": [0, 2, 7], "9": [0, 4, 7, 10, 14], "add9": [0, 4, 7, 14],
    "m7b5": [0, 3, 6, 10], "dim7": [0, 3, 6, 9],
}

CALIDAD_TEXTO = {
    "": "mayor", "m": "menor", "7": "séptima (dominante)", "maj7": "séptima mayor",
    "m7": "menor séptima", "6": "sexta", "m6": "menor sexta", "5": "quinta (power chord)",
    "dim": "disminuido", "aug": "aumentado", "sus4": "suspendido 4", "sus2": "suspendido 2",
    "m7b5": "semi-disminuido", "dim7": "disminuido 7",
}

# --- Digitaciones conocidas (cuerda 6ª grave -> 1ª aguda; "x" = no se toca) --
DIGITACIONES = {
    "A": ["x", 0, 2, 2, 2, 0], "Am": ["x", 0, 2, 2, 1, 0], "A7": ["x", 0, 2, 0, 2, 0],
    "Am7": ["x", 0, 2, 0, 1, 0],
    "A6": ["x", 0, 2, 2, 2, 2], "Am6": ["x", 0, 2, 2, 1, 2], "Amaj7": ["x", 0, 2, 1, 2, 0],
    "Asus4": ["x", 0, 2, 2, 3, 0], "A5": ["x", 0, 2, 2, "x", "x"],
    "B7": ["x", 2, 1, 2, 0, 2], "Bm": ["x", 2, 4, 4, 3, 2], "B": ["x", 2, 4, 4, 4, 2],
    "C": ["x", 3, 2, 0, 1, 0], "C7": ["x", 3, 2, 3, 1, 0], "Cmaj7": ["x", 3, 2, 0, 0, 0],
    "Cm": ["x", 3, 5, 5, 4, 3], "C/G": [3, 3, 2, 0, 1, 0], "Cadd9": ["x", 3, 2, 0, 3, 3],
    "D": ["x", "x", 0, 2, 3, 2], "D/A": ["x", 0, 0, 2, 3, 2], "D/F#": [2, "x", 0, 2, 3, 2],
    "Dm": ["x", "x", 0, 2, 3, 1], "D7": ["x", "x", 0, 2, 1, 2], "Dmaj7": ["x", "x", 0, 2, 2, 2],
    "Dm7": ["x", "x", 0, 2, 1, 1], "D6": ["x", "x", 0, 2, 0, 2], "Dsus4": ["x", "x", 0, 2, 3, 3],
    "E": [0, 2, 2, 1, 0, 0], "E/B": ["x", 2, 2, 1, 0, 0], "E7": [0, 2, 0, 1, 0, 0],
    "Em": [0, 2, 2, 0, 0, 0], "Em7": [0, 2, 0, 0, 0, 0], "Esus4": [0, 2, 2, 2, 0, 0],
    "F": [1, 3, 3, 2, 1, 1], "Fmaj7": ["x", "x", 3, 2, 1, 0], "F7": [1, 3, 1, 2, 1, 1],
    "Fm": [1, 3, 3, 1, 1, 1], "F/A": ["x", 0, 3, 2, 1, 1],
    "G": [3, 2, 0, 0, 0, 3], "G7": [3, 2, 0, 0, 0, 1], "Gmaj7": [3, "x", 0, 0, 0, 2],
    "Gm": [3, 5, 5, 3, 3, 3], "G/B": ["x", 2, 0, 0, 0, 3], "Gsus4": [3, 3, 0, 0, 1, 3],

    # --- Agregadas el 24/Sep: completan las familias que estaban incompletas ---
    # (el F6 salía 8 veces en "Down by the Seaside" y no tenía diagrama)
    "Bm7": ["x", 2, 4, 2, 3, 2], "Cm7": ["x", 3, 5, 3, 4, 3],
    "Fm7": [1, 3, 1, 1, 1, 1], "Gm7": [3, 5, 3, 3, 3, 3],
    "Bmaj7": ["x", 2, 4, 3, 4, 2], "Emaj7": [0, 2, 1, 1, 0, 0],
    "C6": ["x", 3, 2, 2, 1, 0], "E6": [0, 2, 2, 1, 2, 0],
    "F6": [1, 3, 0, 2, 1, 1], "G6": [3, 2, 0, 0, 0, 0],
    "Bsus4": ["x", 2, 4, 4, 5, 2], "Csus4": ["x", 3, 3, 0, 1, 1], "Fsus4": [1, 3, 3, 3, 1, 1],
    "B5": ["x", 2, 4, 4, "x", "x"], "C5": ["x", 3, 5, 5, "x", "x"], "D5": ["x", "x", 0, 2, 3, "x"],
    "E5": [0, 2, 2, "x", "x", "x"], "F5": [1, 3, 3, "x", "x", "x"], "G5": [3, 5, 5, "x", "x", "x"],
    "F#7": [2, 4, 2, 3, 2, 2], "F#aug": ["x", "x", 4, 3, 3, 2],
    "D7/F#": [2, "x", 0, 2, 1, 2],
    "G#": [4, 6, 6, 5, 4, 4], "G#m": [4, 6, 6, 4, 4, 4],
    "F#m7b5": [2, "x", 2, 2, 1, "x"],
}


def normalizar_nota(texto):
    """'Db' -> 'C#' ; devuelve None si no es una nota válida."""
    if not texto:
        return None
    t = texto.strip().capitalize()
    if t in BEMOLES:
        return BEMOLES[t]
    if t in NOTAS:
        return t
    return None


def parsear_acorde(simbolo):
    """'D/A' -> ('D', '', 'A'). Devuelve None si es N o no se entiende."""
    s = (simbolo or "").strip()
    if not s or s.upper() == "N":
        return None
    bajo = None
    if "/" in s:
        s, _, parte_bajo = s.partition("/")
        bajo = normalizar_nota(parte_bajo)
    raiz_txt = s[:1].upper()
    resto = s[1:]
    if resto[:1] in ("#", "b") and len(resto) > 0:
        raiz_txt += resto[0]
        resto = resto[1:]
    raiz = normalizar_nota(raiz_txt)
    if raiz is None:
        return None
    return raiz, resto.strip().lower(), bajo


def notas_del_acorde(raiz, calidad):
    """Devuelve los nombres de las notas que componen el acorde."""
    intervalos = CALIDADES.get(calidad)
    if intervalos is None:
        intervalos = [0, 4, 7]
    idx = NOTAS.index(raiz)
    return [NOTAS[(idx + i) % 12] for i in intervalos]


def etiqueta_calidad(calidad):
    if calidad in CALIDAD_TEXTO:
        return CALIDAD_TEXTO[calidad]
    base = calidad[:3]
    if base in ("maj",):
        return "mayor"
    if base in ("min", "m"):
        return "menor"
    return calidad or "mayor"


def buscar_digitacion(simbolo):
    """Devuelve la digitación de <simbolo>, probando también su equivalente enarmónico.

    La tabla está escrita con sostenidos, pero Chordino devuelve bemoles (Ab, Bb, Gb...):
    sin esto, un acorde como 'Ab' nunca encontraría diagrama (Ab = G#).
    """
    if simbolo in DIGITACIONES:
        return DIGITACIONES[simbolo]
    info = parsear_acorde(simbolo)
    if info is None:
        return None
    raiz, calidad, bajo = info
    normalizado = f"{raiz}{calidad}" + (f"/{bajo}" if bajo else "")
    return DIGITACIONES.get(normalizado)


def svg_diagrama(simbolo, ancho=118, alto=146):
    """Dibuja el diagrama del acorde en SVG. Devuelve None si no hay digitación."""
    dig = buscar_digitacion(simbolo)
    if dig is None:
        return None

    izq, arriba = 16.0, 30.0
    ancho_grilla = ancho - 2 * izq
    alto_grilla = alto - arriba - 16.0
    paso_x = ancho_grilla / 5.0          # 6 cuerdas -> 5 espacios
    paso_y = alto_grilla / 5.0           # 5 trastes

    usados = [f for f in dig if isinstance(f, int) and f > 0]
    base = 1 if (not usados or max(usados) <= 5) else min(usados)
    cejilla = None
    if usados:
        cuerdas_con_ese = [i for i, f in enumerate(dig) if f == base]
        if len(cuerdas_con_ese) >= 4 and max(usados) > 5:
            cejilla = (min(cuerdas_con_ese), max(cuerdas_con_ese))

    p = []
    p.append(f'<svg viewBox="0 0 {ancho} {alto}" width="{ancho}" height="{alto}" '
             f'xmlns="http://www.w3.org/2000/svg" role="img" aria-label="acorde {html.escape(simbolo)}">')
    # cejilla (nut) o indicador de traste base
    if base == 1:
        p.append(f'<rect x="{izq:.1f}" y="{arriba:.1f}" width="{ancho_grilla:.1f}" height="5" '
                 f'fill="#e6edf3" rx="1"/>')
    else:
        p.append(f'<text x="{izq - 6:.1f}" y="{arriba + paso_y - 6:.1f}" fill="#8b949e" '
                 f'font-size="11" text-anchor="end">{base}fr</text>')
    # trastes
    for i in range(6):
        y = arriba + i * paso_y
        grosor = 1.6 if i == 0 and base > 1 else 1.0
        p.append(f'<line x1="{izq:.1f}" y1="{y:.1f}" x2="{izq + ancho_grilla:.1f}" y2="{y:.1f}" '
                 f'stroke="#484f58" stroke-width="{grosor}"/>')
    # cuerdas
    for i in range(6):
        x = izq + i * paso_x
        p.append(f'<line x1="{x:.1f}" y1="{arriba:.1f}" x2="{x:.1f}" y2="{arriba + alto_grilla:.1f}" '
                 f'stroke="#8b949e" stroke-width="{1.6 - i * 0.12:.2f}"/>')

    # puntos y marcas x/o
    for i, traste in enumerate(dig):
        x = izq + i * paso_x
        if traste == "x":
            p.append(f'<text x="{x:.1f}" y="{arriba - 8:.1f}" fill="#f85149" font-size="12" '
                     f'text-anchor="middle">x</text>')
        elif traste == 0:
            p.append(f'<circle cx="{x:.1f}" cy="{arriba - 12:.1f}" r="4" fill="none" '
                     f'stroke="#8b949e" stroke-width="1.4"/>')
        else:
            fila = traste - base
            if fila < 0 or fila > 4:
                continue
            cy = arriba + fila * paso_y + paso_y / 2
            p.append(f'<circle cx="{x:.1f}" cy="{cy:.1f}" r="6.5" fill="#f0b429"/>')
    if cejilla is not None:
        i0, i1 = cejilla
        x0, x1 = izq + i0 * paso_x, izq + i1 * paso_x
        cy = arriba + (base - base) * paso_y + paso_y / 2
        p.append(f'<rect x="{x0 - 6.5:.1f}" y="{cy - 6.5:.1f}" width="{x1 - x0 + 13:.1f}" height="13" '
                 f'rx="6.5" fill="#f0b429"/>')
    p.append('</svg>')
    return "".join(p)


def tarjeta_acorde(simbolo, cantidad, total):
    """HTML de una tarjeta con el diagrama del acorde (o solo el nombre + notas)."""
    info = parsear_acorde(simbolo)
    pct = (cantidad / total * 100) if total else 0
    diagrama = svg_diagrama(simbolo)
    if info is not None:
        raiz, calidad, bajo = info
        notas = " · ".join(notas_del_acorde(raiz, calidad))
        subtitulo = etiqueta_calidad(calidad)
        if bajo:
            subtitulo += f" (bajo en {bajo})"
    else:
        notas = "sin acorde detectado"
        subtitulo = "silencio / percusión"
    if diagrama is None:
        diagrama = (f'<div class="sin-diagrama">{html.escape(simbolo)}<span>sin digitación '
                    f'en la tabla</span></div>')
    return f'''      <div class="tarjeta">
        <div class="cabecera-tarjeta">
          <span class="acorde-nombre">{html.escape(simbolo)}</span>
          <span class="veces">{cantidad}× · {pct:.0f}%</span>
        </div>
        <div class="diagrama">{diagrama}</div>
        <div class="calidad">{html.escape(subtitulo)}</div>
        <div class="notas">{html.escape(notas)}</div>
      </div>
'''

CSS = """
:root { color-scheme: dark; }
* { box-sizing: border-box; }
body { margin: 0; padding: 28px 20px 60px; background: #0d1117; color: #e6edf3;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
.contenedor { max-width: 1080px; margin: 0 auto; }
h1 { font-size: 26px; margin: 0 0 4px; }
h2 { font-size: 17px; margin: 34px 0 12px; padding-bottom: 6px; border-bottom: 1px solid #21262d;
  font-weight: 600; }
.sub { color: #8b949e; margin: 0 0 18px; font-size: 14px; }
.chips { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 22px; }
.chip { background: #161b22; border: 1px solid #21262d; border-radius: 999px; padding: 5px 12px;
  font-size: 12px; color: #8b949e; }
.chip b { color: #e6edf3; font-weight: 600; }
.resumen { display: flex; flex-wrap: wrap; gap: 12px; }
.metrica { background: #161b22; border: 1px solid #21262d; border-radius: 10px; padding: 14px 18px;
  min-width: 150px; }
.metrica .valor { font-size: 24px; font-weight: 700; color: #f0b429; }
.metrica .etiqueta { font-size: 12px; color: #8b949e; text-transform: uppercase; letter-spacing: .04em; }
.grilla { display: grid; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); gap: 14px; }
.tarjeta { background: #161b22; border: 1px solid #21262d; border-radius: 12px; padding: 12px;
  text-align: center; }
.cabecera-tarjeta { display: flex; justify-content: space-between; align-items: baseline; gap: 6px; }
.acorde-nombre { font-size: 19px; font-weight: 700; }
.veces { font-size: 11px; color: #8b949e; white-space: nowrap; }
.diagrama { margin: 6px 0 2px; min-height: 146px; display: flex; align-items: center;
  justify-content: center; }
.sin-diagrama { color: #8b949e; font-size: 22px; font-weight: 600; display: flex;
  flex-direction: column; gap: 4px; align-items: center; }
.sin-diagrama span { font-size: 11px; color: #6e7681; font-weight: 400; }
.calidad { font-size: 12px; color: #a5d6ff; }
.notas { font-size: 11px; color: #6e7681; margin-top: 2px; }
.linea { display: flex; height: 34px; border-radius: 8px; overflow: hidden; border: 1px solid #21262d; }
.seg { display: flex; align-items: center; justify-content: center; font-size: 10px; font-weight: 600;
  color: #0d1117; overflow: hidden; white-space: nowrap; }
.tabla { width: 100%; border-collapse: collapse; font-size: 13px; }
.tabla th { text-align: left; color: #8b949e; font-weight: 600; font-size: 12px;
  text-transform: uppercase; letter-spacing: .04em; padding: 6px 8px; border-bottom: 1px solid #21262d; }
.tabla td { padding: 5px 8px; border-bottom: 1px solid #161b22; font-variant-numeric: tabular-nums; }
.tabla tr:hover td { background: #161b22; }
.punto { display: inline-block; width: 10px; height: 10px; border-radius: 3px; margin-right: 7px; }
.pie { margin-top: 34px; color: #6e7681; font-size: 12px; line-height: 1.6;
  border-top: 1px solid #21262d; padding-top: 14px; }
@media print { body { background: #fff; color: #000; } .tarjeta, .metrica { border-color: #ccc; } }
"""

PALETA = ["#f0b429", "#4ade80", "#60a5fa", "#f472b6", "#a78bfa", "#f87171",
          "#34d399", "#fbbf24", "#38bdf8", "#c084fc", "#fb923c", "#2dd4bf"]


def generar_html(titulo, subtitulo, meta, acordes, duracion, bpm=None, tonalidad=""):
    """Arma el documento HTML completo (autocontenido, sin recursos externos)."""
    total = len(acordes)
    conteo = Counter(a for _, a in acordes)
    unicos = list(OrderedDict.fromkeys(a for _, a in acordes))
    colores = {simbolo: PALETA[i % len(PALETA)] for i, simbolo in enumerate(unicos)}
    dur_total = duracion or (acordes[-1][0] if acordes else 0)

    # Grilla de acordes: primero los musicales (por frecuencia), N al final
    ordenados = sorted(conteo.items(), key=lambda kv: (kv[0].upper() == "N", -kv[1]))
    tarjetas = "".join(tarjeta_acorde(s, c, total) for s, c in ordenados)

    chips = "".join(f'<span class="chip">{html.escape(k)}: <b>{html.escape(str(v))}</b></span>'
                    for k, v in meta.items())

    # Métricas extra del análisis de tempo/tonalidad (librosa), si vinieron de analizar.sh
    extras = ""
    if bpm:
        extras += (f'<div class="metrica"><div class="valor">{bpm:g}</div>'
                   f'<div class="etiqueta">BPM</div></div>')
    if tonalidad:
        extras += (f'<div class="metrica"><div class="valor">{html.escape(tonalidad)}</div>'
                   f'<div class="etiqueta">tonalidad</div></div>')

    # Segmentos con duración real (cada acorde dura hasta el siguiente)
    segmentos = []
    for i, (t, simbolo) in enumerate(acordes):
        fin = acordes[i + 1][0] if i + 1 < len(acordes) else dur_total
        segmentos.append((t, simbolo, max(fin - t, 0.001)))
    ancho_total = sum(d for _, _, d in segmentos) or 1

    lineas = "".join(
        f'<div class="seg" style="width:{d / ancho_total * 100:.4f}%;background:{colores[s]}" '
        f'title="{html.escape(s)} · {t:.2f}s (dura {d:.2f}s)">'
        f'{html.escape(s) if d / ancho_total > 0.03 else ""}</div>'
        for t, s, d in segmentos)

    filas = []
    for t, s, d in segmentos:
        info = parsear_acorde(s)
        calidad = etiqueta_calidad(info[1]) if info else "—"
        filas.append(
            f'    <tr><td>{t:8.3f} s</td>'
            f'<td><span class="punto" style="background:{colores[s]}"></span><b>{html.escape(s)}</b></td>'
            f'<td>{d:6.2f} s</td><td>{html.escape(calidad)}</td></tr>')

    return f'''<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Acordes · {html.escape(titulo)}</title>
<style>{CSS}</style>
</head>
<body>
<div class="contenedor">
  <h1>&#127928; {html.escape(titulo)}</h1>
  <p class="sub">{html.escape(subtitulo)}</p>
  <div class="chips">{chips}</div>

  <div class="resumen">
    <div class="metrica"><div class="valor">{total}</div><div class="etiqueta">segmentos</div></div>
    <div class="metrica"><div class="valor">{len(unicos)}</div><div class="etiqueta">acordes distintos</div></div>
    <div class="metrica"><div class="valor">{dur_total:.1f}s</div><div class="etiqueta">duración analizada</div></div>
    <div class="metrica"><div class="valor">{dur_total / 60:.2f}</div><div class="etiqueta">minutos</div></div>
{extras}  </div>

  <h2>Diagramas de acorde</h2>
  <div class="grilla">
{tarjetas}  </div>

  <h2>Línea de tiempo</h2>
  <div class="linea">{lineas}</div>

  <h2>Cambios de acorde</h2>
  <table class="tabla">
    <thead><tr><th>Timestamp</th><th>Acorde</th><th>Duración</th><th>Calidad</th></tr></thead>
    <tbody>
{chr(10).join(filas)}
    </tbody>
  </table>

  <div class="pie">
    Generado por <b>scripts/acordes_html.py</b> a partir de <b>chord-extractor (Chordino)</b>.<br>
    <b>N</b> = sin acorde detectado (silencio, percusión, comienzo o final del tema).<br>
    Las digitaciones son sugerencias para guitarra en afinación estándar (EADGBE); cuando un acorde
    no está en la tabla interna se muestran solo las notas que lo componen.
  </div>
</div>
</body>
</html>
'''


def error(msg, codigo=1):
    print(f"[ERROR] {msg}", file=sys.stderr)
    sys.exit(codigo)


def leer_acordes(ruta):
    """Lee el .txt de analizar.py: 'timestamp_segundos acorde' por línea."""
    acordes = []
    try:
        with open(ruta, encoding="utf-8") as fh:
            for num, linea in enumerate(fh, 1):
                partes = linea.split()
                if len(partes) < 2:
                    continue
                try:
                    t = float(partes[0])
                except ValueError:
                    error(f"línea {num} sin timestamp válido: {linea.strip()!r}", 4)
                acordes.append((t, partes[1]))
    except OSError as exc:
        error(f"No se pudo leer '{ruta}': {exc}", 3)
    return acordes


def leer_metadatos(base_txt):
    """Si existe el .json hermano, saca herramienta/fecha/origen para el encabezado."""
    ruta = (base_txt[:-4] if base_txt.lower().endswith(".txt") else base_txt) + ".json"
    if not os.path.isfile(ruta):
        return {}
    try:
        import json
        with open(ruta, encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:
        return {}


def main():
    p = argparse.ArgumentParser(
        description="Genera un informe HTML autocontenido (con diagramas SVG) de los acordes detectados.")
    p.add_argument("txt", help="archivo .txt de acordes ('timestamp acorde' por línea)")
    p.add_argument("--out", required=True, help="ruta del .html de salida")
    p.add_argument("--titulo", help="título del informe (default: nombre del archivo)")
    p.add_argument("--subtitulo", default="", help="subtítulo (ej: 'stem guitarra · htdemucs_6s')")
    p.add_argument("--duracion", type=float, default=0.0, help="duración del audio en segundos")
    p.add_argument("--bpm", type=float, default=0.0,
                   help="BPM detectado (opcional: se muestra como métrica)")
    p.add_argument("--tonalidad", default="",
                   help="tonalidad detectada (opcional: se muestra como métrica)")
    args = p.parse_args()

    if not os.path.isfile(args.txt):
        error(f"No existe el archivo de acordes: '{args.txt}'", 2)
    acordes = leer_acordes(args.txt)
    if not acordes:
        error(f"'{args.txt}' no tiene acordes (¿está vacío?)", 5)

    datos = leer_metadatos(args.txt)
    titulo = args.titulo or os.path.basename(args.txt).replace("_acordes", "").replace(".txt", "")
    meta = OrderedDict()
    if datos.get("herramienta"):
        meta["herramienta"] = datos["herramienta"]
    if datos.get("generado"):
        meta["generado"] = str(datos["generado"]).replace("T", " ")
    if datos.get("archivo_analizado"):
        meta["origen"] = os.path.basename(str(datos["archivo_analizado"]))
    meta["segmentos"] = len(acordes)
    meta["distintos"] = len(set(a for _, a in acordes))

    doc = generar_html(titulo, args.subtitulo, meta, acordes, args.duracion, args.bpm, args.tonalidad)

    carpeta = os.path.dirname(args.out)
    if carpeta:
        try:
            os.makedirs(carpeta, exist_ok=True)
        except OSError as exc:
            error(f"No se pudo crear '{carpeta}': {exc}", 6)
    try:
        with open(args.out, "w", encoding="utf-8") as fh:
            fh.write(doc)
    except OSError as exc:
        error(f"No se pudo escribir '{args.out}': {exc}", 7)

    print(f"HTML: {args.out}")
    print(f"SEGMENTOS: {len(acordes)}")
    print(f"DISTINTOS: {meta['distintos']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
