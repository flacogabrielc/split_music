#!/usr/bin/env bash
# loop.sh - Extrae un loop exacto (por BPM y compases) de un WAV, sin clicks.
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/_comun.sh"

FORZAR=0
OUT_DIR=""
SALIDA=""
START="0"
FADE="0"
POSICIONALES=()

uso() {
  cat <<EOF
Uso: ./scripts/loop.sh <archivo_wav> <bpm> <compases> [opciones]

Extrae un fragmento con la duración EXACTA del loop y lo guarda en
  output/<cancion>/loops/<nombre>.wav
  (si no puede deducir la canción: output/_sueltos/loops/)

Duración = (60 / bpm) * 4 * compases     ← asume compás de 4/4 (4 tiempos)

Argumentos:
  <archivo_wav>  Archivo de entrada (ruta o relativa a la raíz)
  <bpm>          Tempo, en pulsos por minuto (ej: 110)
  <compases>     Cantidad de compases (ej: 8)

Opciones:
  --start <seg>      Segundo donde empieza el loop (default: 0)
  --out <nombre>     Nombre de salida (sin .wav). Default: <archivo>_loop_<n>c_<bpm>bpm
  --out-dir <ruta>   Carpeta de destino explícita (relativa a la raíz o absoluta).
                     Si se indica, NO se deduce la estructura.
  --fade <ms>        Fade in/out de N milisegundos para evitar clicks (default: 0)
  -f, --forzar       Sobrescribe la salida sin preguntar
  -h, --help         Muestra esta ayuda

Ejemplo:
  ./scripts/loop.sh "output/Down by the Seaside/htdemucs/base_ritmica.wav" 110 8 --start 32.5 --fade 5
  → 110 bpm, 8 compases = 17.454545 s = 769.091 muestras a 44.1 kHz
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)   uso; exit 0 ;;
    -f|--forzar) FORZAR=1; shift ;;
    --start)     [[ $# -ge 2 ]] || die "--start necesita un valor en segundos."; START="$2"; shift 2 ;;
    --out)       [[ $# -ge 2 ]] || die "--out necesita un nombre."; SALIDA="$2"; shift 2 ;;
    --out-dir)   [[ $# -ge 2 ]] || die "--out-dir necesita una ruta."; OUT_DIR="$2"; shift 2 ;;
    --fade)      [[ $# -ge 2 ]] || die "--fade necesita un valor en milisegundos."; FADE="$2"; shift 2 ;;
    -*)          uso >&2; die "Opción desconocida: $1" ;;
    *)           POSICIONALES+=("$1"); shift ;;
  esac
done

[[ ${#POSICIONALES[@]} -eq 3 ]] || { uso >&2; die "Se esperan 3 argumentos: <archivo_wav> <bpm> <compases>"; }
ARCHIVO="${POSICIONALES[0]}"; BPM="${POSICIONALES[1]}"; COMPASES="${POSICIONALES[2]}"

[[ "$BPM" =~ ^[0-9]+([.][0-9]+)?$ ]] && awk -v b="$BPM" 'BEGIN{exit !(b>0)}' \
  || die "El BPM debe ser un número mayor a 0 (ej: 110). Recibido: '$BPM'"
[[ "$COMPASES" =~ ^[0-9]+$ ]] && [[ "$COMPASES" -ge 1 ]] \
  || die "Los compases deben ser un entero >= 1 (ej: 8). Recibido: '$COMPASES'"
[[ "$START" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "--start debe ser un número (segundos). Recibido: '$START'"
[[ "$FADE" =~ ^[0-9]+$ ]] || die "--fade debe ser un entero (milisegundos). Recibido: '$FADE'"

ARCHIVO="$(resolver_existente "$ARCHIVO")"
exigir_archivo "$ARCHIVO"
exigir_comando ffmpeg "Instalalo con: sudo apt install ffmpeg"
exigir_comando ffprobe "Instalalo con: sudo apt install ffmpeg"

# --- Cálculo exacto de la duración -----------------------------------------
TIEMPO=$(awk -v b="$BPM" 'BEGIN{printf "%.6f", 60/b}')
COMPAS=$(awk -v t="$TIEMPO" 'BEGIN{printf "%.6f", 4*t}')
DUR=$(awk -v t="$TIEMPO" -v c="$COMPASES" 'BEGIN{printf "%.6f", t*4*c}')
MUESTRAS=$(awk -v d="$DUR" 'BEGIN{printf "%.1f", d*44100}')
DUR_ARCHIVO="$(duracion_audio "$ARCHIVO")"

FIN=$(awk -v s="$(num "$START")" -v d="$(num "$DUR")" 'BEGIN{printf "%.6f", s+d}')
awk -v f="$(num "$FIN")" -v da="$(num "$DUR_ARCHIVO")" 'BEGIN{exit !(f <= da + 0.05)}' || die \
"El loop se sale del archivo: start($START) + duración($DUR) = $FIN s, pero el archivo dura $DUR_ARCHIVO s.
    Probá con --start más chico (máximo: $(awk -v d="$(num "$DUR_ARCHIVO")" -v x="$(num "$DUR")" 'BEGIN{printf "%.3f", d-x}') s)."

BASE="$(nombre_base "$ARCHIVO")"
[[ -n "$SALIDA" ]] || SALIDA="${BASE}_loop_${COMPASES}c_${BPM}bpm"

# --- Destino: output/<cancion>/loops/  o  output/_sueltos/loops/ ------------
IFS='|' read -r CANCION MODELO_CTX <<< "$(deducir_contexto "$ARCHIVO")"
if [[ -n "$OUT_DIR" ]]; then
  DIR_SALIDA="$(absoluta "$OUT_DIR")"
elif [[ -n "$CANCION" ]]; then
  DIR_SALIDA="$(raiz_salida "$CANCION")/loops"
else
  DIR_SALIDA="$(raiz_salida "")/loops"
  aviso "No pude deducir la canción desde '${ARCHIVO#"$ROOT_DIR"/}': guardo en output/_sueltos/loops/"
fi
DESTINO="$DIR_SALIDA/$SALIDA.wav"

cabecera "EXTRACCIÓN DE LOOP"
detalle "Entrada   : ${ARCHIVO#"$ROOT_DIR"/}  ($(mmss "$DUR_ARCHIVO"))"
detalle "Tempo     : $BPM bpm  →  1 tiempo = $TIEMPO s  →  1 compás (4/4) = $COMPAS s"
detalle "Loop      : $COMPASES compases = $DUR s  ($MUESTRAS muestras a 44.1 kHz)"
detalle "Desde     : $START s  hasta $FIN s"
detalle "Salida    : ${DESTINO#"$ROOT_DIR"/}"

mkdir -p "$DIR_SALIDA"
confirmar_sobrescritura "$DESTINO" "el loop de salida"

AF=()
if [[ "$FADE" != "0" ]]; then
  FD=$(awk -v f="$FADE" 'BEGIN{printf "%.4f", f/1000}')
  ST_FIN=$(awk -v d="$DUR" -v f="$FD" 'BEGIN{printf "%.4f", d-f}')
  AF=(-af "afade=t=in:st=0:d=$FD,afade=t=out:st=$ST_FIN:d=$FD")
  detalle "Fade in/out  : ${FADE} ms (para evitar clicks al loopear)"
fi

paso "Extrayendo el loop con ffmpeg"
# -ss antes de -i: búsqueda rápida; con transcodificación ffmpeg ajusta al
# sample exacto (accurate_seek), así el loop no se desfasa.
ffmpeg -hide_banner -nostdin -y -ss "$START" -i "$ARCHIVO" -t "$DUR" \
  "${AF[@]}" -c:a pcm_s16le "$DESTINO"

# --- Verificación real de la duración --------------------------------------
REAL="$(duracion_audio "$DESTINO")"
ERROR_MS=$(awk -v r="$REAL" -v d="$DUR" 'BEGIN{printf "%+.1f", (r-d)*1000}')

paso "Resultado"
ok "Loop creado: ${DESTINO#"$ROOT_DIR"/}"
resumen_archivo "loop" "$DESTINO"
detalle "Duración esperada: $DUR s  |  real: $REAL s  |  diferencia: $ERROR_MS ms"
detalle "Para loopear en un reproductor/DAW: activá 'loop' y quedará perfecto."
