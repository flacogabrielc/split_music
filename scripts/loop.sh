#!/usr/bin/env bash
# loop.sh - Extrae un loop exacto (por BPM y compases) de un WAV, sin clicks.
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/_comun.sh"

FORZAR=0
OUT_DIR=""
SALIDA=""
START="0"
FADE="0"
BPM_OPT=""
CUANTIZAR=1
POSICIONALES=()

# Lee el valor de una clave en un archivo "<clave> <valor>" (los _tempo.txt del Analista).
# Toma TODO el resto de la línea, porque hay valores con espacios (ej: "tonalidad_completa C mayor").
valor_tempo() { awk -v k="$2" '$1==k {$1=""; sub(/^[ \t]+/,""); print; exit}' "$1"; }

uso() {
  cat <<EOF
Uso: ./scripts/loop.sh <archivo_wav> <bpm> <compases> [opciones]
     ./scripts/loop.sh <archivo_wav> <compases> [opciones]      ← BPM detectado solo

Extrae un fragmento con la duración EXACTA del loop y lo guarda en
  output/<cancion>/loops/<nombre>.wav
  (si no puede deducir la canción: output/_sueltos/loops/)

Duración = (60 / bpm) * 4 * compases     ← asume compás de 4/4 (4 tiempos)

Si omitís el BPM, se usa el DETECTADO por el Analista para esa canción
(output/<cancion>/analisis/<cancion>_tempo.txt, error < 1%). Se redondea al entero
más cercano y se avisa si cae fuera del rango habitual de un loop (75-170 bpm).

El INICIO se ajusta solo al TIEMPO (beat) más cercano, para que el loop arranque en pulso
y no a mitad de tiempo (que es lo que suena tropezado al repetir). El audio NO se modifica:
solo cambia dónde se corta. Si el tiempo más cercano queda fuera de la grilla (por ejemplo
en un intro sin pulsos), no lo mueve y te avisa.

Argumentos:
  <archivo_wav>  Archivo de entrada (ruta o relativa a la raíz)
  <bpm>          Tempo en pulsos por minuto (ej: 110). Opcional si ya hay análisis.
  <compases>     Cantidad de compases (ej: 8)

Opciones:
  --bpm <n>          BPM explícito (alternativa a pasarlo como 2º argumento)
  --start <seg>      Segundo donde empieza el loop (default: 0). Se ajusta al tiempo más cercano.
  --sin-cuantizar    Corta EXACTO en --start, sin ajustar al tiempo más cercano
  --out <nombre>     Nombre de salida (sin .wav). Default: <archivo>_loop_<n>c_<bpm>bpm
  --out-dir <ruta>   Carpeta de destino explícita (relativa a la raíz o absoluta).
                     Si se indica, NO se deduce la estructura.
  --fade <ms>        Fade in/out de N milisegundos para evitar clicks (default: 0)
  -f, --forzar       Sobrescribe la salida sin preguntar
  -h, --help         Muestra esta ayuda

Ejemplos:
  # BPM a mano (como siempre)
  ./scripts/loop.sh "output/Down by the Seaside/htdemucs/base_ritmica.wav" 110 8 --start 32.5 --fade 5

  # BPM detectado automáticamente (8 compases de "Down by the Seaside" = 92 bpm)
  ./scripts/loop.sh "output/Down by the Seaside/htdemucs/base_ritmica.wav" 8 --start 32.5

  # forzar un BPM puntual
  ./scripts/loop.sh "output/Down by the Seaside/htdemucs/base_ritmica.wav" 8 --bpm 92.5

  # cortar EXACTO en el segundo pedido, sin ajustar a la grilla
  ./scripts/loop.sh "output/Down by the Seaside/htdemucs/base_ritmica.wav" 8 --start 32.5 --sin-cuantizar
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)   uso; exit 0 ;;
    -f|--forzar) FORZAR=1; shift ;;
    --start)     [[ $# -ge 2 ]] || die "--start necesita un valor en segundos."; START="$2"; shift 2 ;;
    --bpm)       [[ $# -ge 2 ]] || die "--bpm necesita un número."; BPM_OPT="$2"; shift 2 ;;
    --sin-cuantizar) CUANTIZAR=0; shift ;;
    --out)       [[ $# -ge 2 ]] || die "--out necesita un nombre."; SALIDA="$2"; shift 2 ;;
    --out-dir)   [[ $# -ge 2 ]] || die "--out-dir necesita una ruta."; OUT_DIR="$2"; shift 2 ;;
    --fade)      [[ $# -ge 2 ]] || die "--fade necesita un valor en milisegundos."; FADE="$2"; shift 2 ;;
    -*)          uso >&2; die "Opción desconocida: $1" ;;
    *)           POSICIONALES+=("$1"); shift ;;
  esac
done

# --- Posicionales: <archivo> [<bpm>] <compases> -----------------------------
case ${#POSICIONALES[@]} in
  3) ARCHIVO="${POSICIONALES[0]}"; BPM="${POSICIONALES[1]}"; COMPASES="${POSICIONALES[2]}" ;;
  2) ARCHIVO="${POSICIONALES[0]}"; BPM=""; COMPASES="${POSICIONALES[1]}" ;;
  *) uso >&2; die "Se esperan 2 o 3 argumentos: <archivo_wav> [<bpm>] <compases>" ;;
esac
if [[ -n "$BPM_OPT" ]]; then
  [[ -z "$BPM" ]] || die "Me pasaste el BPM dos veces (2º argumento '$BPM' y --bpm '$BPM_OPT'). Elegí uno."
  BPM="$BPM_OPT"
fi

[[ "$COMPASES" =~ ^[0-9]+$ ]] && [[ "$COMPASES" -ge 1 ]] \
  || die "Los compases deben ser un entero >= 1 (ej: 8). Recibido: '$COMPASES'"
[[ "$START" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "--start debe ser un número (segundos). Recibido: '$START'"
[[ "$FADE" =~ ^[0-9]+$ ]] || die "--fade debe ser un entero (milisegundos). Recibido: '$FADE'"

ARCHIVO="$(resolver_existente "$ARCHIVO")"
exigir_archivo "$ARCHIVO"
exigir_comando ffmpeg "Instalalo con: sudo apt install ffmpeg"
exigir_comando ffprobe "Instalalo con: sudo apt install ffmpeg"

# --- Contexto: de qué canción y modelo salió el audio ----------------------
IFS='|' read -r CANCION MODELO_CTX <<< "$(deducir_contexto "$ARCHIVO")"

# --- BPM: el que pasaste, o el detectado en el análisis de esa canción ------
AUTO_BPM=0
BPM_EXACTO=""; TONALIDAD_TXT=""
if [[ -z "$BPM" ]]; then
  if [[ -z "$CANCION" ]]; then
    die "Para usar el BPM automático necesito deducir la canción desde la ruta del archivo,
    y no pude hacerlo con '${ARCHIVO#"$ROOT_DIR"/}'.
    Pasá el BPM a mano:  ./scripts/loop.sh \"${ARCHIVO#"$ROOT_DIR"/}\" <bpm> $COMPASES"
  fi
  ARCH_TEMPO="$(raiz_salida "$CANCION")/analisis/${CANCION}_tempo.txt"
  if [[ ! -f "$ARCH_TEMPO" ]]; then
    die "No encontré el BPM detectado de '$CANCION' (falta ${ARCH_TEMPO#"$ROOT_DIR"/}).
    Generálo primero:
      ./scripts/analizar.sh \"$CANCION.mp3\"
    o pasá el BPM a mano:
      ./scripts/loop.sh \"${ARCHIVO#"$ROOT_DIR"/}\" <bpm> $COMPASES"
  fi
  BPM_EXACTO="$(valor_tempo "$ARCH_TEMPO" bpm)"
  TONALIDAD_TXT="$(valor_tempo "$ARCH_TEMPO" tonalidad_completa)"
  [[ -n "$BPM_EXACTO" ]] || die "El análisis '${ARCH_TEMPO#"$ROOT_DIR"/}' no tiene un BPM legible."
  BPM="$(awk -v b="$BPM_EXACTO" 'BEGIN{printf "%d", b+0.5}')"
  AUTO_BPM=1

  BPM_DOBLE="$(valor_tempo "$ARCH_TEMPO" bpm_doble)"
  BPM_MITAD="$(valor_tempo "$ARCH_TEMPO" bpm_mitad)"
  if awk -v b="$BPM_EXACTO" 'BEGIN{exit !(b<75 || b>170)}'; then
    aviso "El BPM detectado ($BPM_EXACTO) está fuera del rango habitual de un loop (75-170 bpm).
    Puede ser la mitad o el doble del real:  mitad = $BPM_MITAD   doble = $BPM_DOBLE
    Si querés forzar otro valor:  --bpm <n>"
  fi
fi

[[ "$BPM" =~ ^[0-9]+([.][0-9]+)?$ ]] && awk -v b="$BPM" 'BEGIN{exit !(b>0)}' \
  || die "El BPM debe ser un número mayor a 0 (ej: 110). Recibido: '$BPM'"

# --- Inicio: moverlo al tiempo (beat) más cercano ---------------------------
# Para que el loop arranque EN PULSO y no a mitad de tiempo (que es lo que suena
# "tropezado" al repetir). NO se modifica el audio: solo cambia el punto de corte.
START_PEDIDO="$START"
CORRECCION_MS=""
if [[ $CUANTIZAR == 1 ]]; then
  BEATS_JSON=""
  if [[ -n "$CANCION" ]]; then
    BEATS_JSON="$(raiz_salida "$CANCION")/analisis/${CANCION}_tempo.json"
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    aviso "No encontré 'python3': corto exacto en $START s (sin ajustar al tiempo más cercano)."
  elif [[ -z "$BEATS_JSON" || ! -f "$BEATS_JSON" ]]; then
    aviso "No tengo los tiempos de beat de la canción, así que corto exacto en $START s.
    Para ajustarlo a la grilla: ./scripts/analizar.sh \"<cancion>.mp3\""
  elif RES_BEATS="$(python3 "$SCRIPT_DIR/_beats.py" "$BEATS_JSON" "$(num "$START")" 2>/dev/null)"; then
    leer_beats() { printf '%s\n' "$RES_BEATS" | sed -n "s/^$1 //p"; }
    if [[ "$(leer_beats hay_beats)" != "si" ]]; then
      aviso "El análisis no tiene tiempos de beat: corto exacto en $START s."
    elif [[ "$(leer_beats ajustar)" == "si" ]]; then
      BEAT="$(leer_beats beat_mas_cercano)"
      DESF="$(leer_beats desfasaje_ms)"
      # si ya está sobre el tiempo (menos de 5 ms) no vale la pena avisar
      if awk -v d="$DESF" 'BEGIN{exit !(d < -5 || d > 5)}'; then
        START="$BEAT"
        CORRECCION_MS="$DESF"
      fi
    else
      aviso "No ajusté el inicio a la grilla: $(leer_beats motivo).
    Corto exacto en $START s."
    fi
  else
    aviso "No pude leer ${BEATS_JSON#"$ROOT_DIR"/}: corto exacto en $START s."
  fi
fi

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
if [[ $AUTO_BPM == 1 ]]; then
  detalle "Tempo     : $BPM bpm  ← DETECTADO (exacto: $BPM_EXACTO · tonalidad: $TONALIDAD_TXT)"
else
  detalle "Tempo     : $BPM bpm  ← indicado por el usuario"
fi
detalle "            1 tiempo = $TIEMPO s  →  1 compás (4/4) = $COMPAS s"
detalle "Loop      : $COMPASES compases = $DUR s  ($MUESTRAS muestras a 44.1 kHz)"
if [[ -n "$CORRECCION_MS" ]]; then
  detalle "Desde     : $START s  hasta $FIN s   ← ajustado a la grilla desde $START_PEDIDO s ($CORRECCION_MS ms)"
else
  detalle "Desde     : $START s  hasta $FIN s"
fi
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
