#!/usr/bin/env bash
# analizar.sh - Extrae la secuencia de acordes de un audio (chord-extractor / Chordino).
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/_comun.sh"

FORZAR=0
STEMS=0
HTML=1
SALIDA=""
OUT_DIR=""
POSICIONALES=()

uso() {
  cat <<EOF
Uso: ./scripts/analizar.sh <archivo_audio|carpeta_stems> [--stems] [--out <nombre>] [--out-dir <ruta>]

Extrae la secuencia de acordes con timestamps usando chord-extractor (plugin Chordino)
y escribe TRES archivos por análisis:
  <salida>.txt   -> "timestamp_segundos acorde" (una línea por segmento)
  <salida>.json  -> los mismos datos + metadatos (herramienta, fecha, total)
  <salida>.html  -> informe para abrir en el navegador: diagramas de acorde dibujados
                    en SVG, línea de tiempo y tabla de cambios (autocontenido, sin internet)

Destino por defecto:
  output/<cancion>/analisis/<nombre>_acordes.{txt,json}
  (si no se puede deducir la canción: output/_sueltos/analisis/)

Argumentos:
  <archivo_audio>   Archivo de audio (ruta, relativa a la raíz, o nombre suelto en mp3/)
  <carpeta_stems>   Con --stems: carpeta de stems (ej: separated/htdemucs/Cancion)

Opciones:
  --stems           Analiza CADA stem .wav de la carpeta por separado
  --sin-html        No genera el informe .html (solo .txt y .json)
  --out <nombre>    Nombre base de salida (sin .txt/.json). Default: <archivo> o <stem>
  --out-dir <ruta>  Carpeta de destino explícita (relativa a la raíz o absoluta)
  -f, --forzar      Sobrescribe resultados existentes sin preguntar
  -h, --help        Muestra esta ayuda

Ejemplos:
  ./scripts/analizar.sh "Down by the Seaside.mp3"
  ./scripts/analizar.sh "separated/htdemucs/Down by the Seaside/bass.wav" --out acordes_bajo
  ./scripts/analizar.sh "separated/htdemucs/Down by the Seaside" --stems
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)   uso; exit 0 ;;
    -f|--forzar) FORZAR=1; shift ;;
    --stems)     STEMS=1; shift ;;
    --sin-html)  HTML=0; shift ;;
    --out)       [[ $# -ge 2 ]] || die "--out necesita un nombre."; SALIDA="$2"; shift 2 ;;
    --out-dir)   [[ $# -ge 2 ]] || die "--out-dir necesita una ruta."; OUT_DIR="$2"; shift 2 ;;
    -*)          uso >&2; die "Opción desconocida: $1" ;;
    *)           POSICIONALES+=("$1"); shift ;;
  esac
done

[[ ${#POSICIONALES[@]} -ge 1 ]] || { uso >&2; die "Falta el archivo de audio (o la carpeta de stems con --stems)."; }
[[ ${#POSICIONALES[@]} -le 1 ]] || die "Demasiados argumentos: ${POSICIONALES[*]}  (máximo: <archivo>)"
ENTRADA="${POSICIONALES[0]}"

# --- Venv: usa venv-analisis/ si existe, si no el venv del proyecto ---------
if [[ -d "$ROOT_DIR/venv-analisis" ]]; then
  VENV_DIR="$ROOT_DIR/venv-analisis"
  VENV_NOMBRE="venv-analisis"
else
  VENV_NOMBRE="venv"
fi
activar_venv
PY="$VIRTUAL_ENV/bin/python"
[[ -x "$PY" ]] || die "No encuentro el intérprete de Python en $VIRTUAL_ENV"
[[ -f "$SCRIPT_DIR/analizar.py" ]] || die "Falta el script: $SCRIPT_DIR/analizar.py"
exigir_comando ffprobe "Instalalo con: sudo apt install ffmpeg"

if ! "$PY" -c 'import chord_extractor' >/dev/null 2>&1; then
  die "chord-extractor no está instalado en el venv '$VENV_NOMBRE'.
    Instalalo con:
      ./$VENV_NOMBRE/bin/pip install --ignore-requires-python --no-build-isolation chord-extractor"
fi
info "venv en uso: $VENV_NOMBRE  |  herramienta: chord-extractor (Chordino)"

# --- Resolver entrada y armar la lista de audios ----------------------------
if [[ $STEMS == 1 ]]; then
  # carpeta de stems: ruta directa o relativa a la raíz del proyecto
  ENTRADA="$(resolver_existente "$ENTRADA")"
  if [[ -f "$ENTRADA" ]]; then REF="$(dirname -- "$ENTRADA")"; else REF="$ENTRADA"; fi
  [[ -d "$REF" ]] || die "Con --stems esperaba una carpeta de stems, y '$REF' no es una carpeta."
  compgen -G "$REF/*.wav" >/dev/null || die "No hay archivos .wav en '${REF#"$ROOT_DIR"/}'"
  LISTA=()
  for f in "$REF"/*.wav; do LISTA+=("$f"); done
else
  # archivo de audio: ruta, relativa a la raíz, o solo el nombre (se busca en mp3/)
  ENTRADA="$(resolver_entrada "$ENTRADA")"
  exigir_archivo "$ENTRADA"
  REF="$ENTRADA"
  LISTA=("$ENTRADA")
fi

# --- Destino: output/<cancion>/analisis/ (o _sueltos/analisis/) -------------
IFS='|' read -r CANCION MODELO_CTX <<< "$(deducir_contexto "$REF")"
# Caso especial: si el audio sale de mp3/, la canción es el nombre del archivo.
# (deducir_contexto solo reconoce rutas de separated/ y output/)
if [[ -z "$CANCION" && $STEMS == 0 ]]; then
  case "$REF" in
    "$MP3_DIR"/*) CANCION="$(nombre_base "$REF")" ;;
  esac
fi
if [[ -n "$OUT_DIR" ]]; then
  DIR_SALIDA="$(absoluta "$OUT_DIR")"
elif [[ -n "$CANCION" ]]; then
  DIR_SALIDA="$(raiz_salida "$CANCION")/analisis"
else
  DIR_SALIDA="$(raiz_salida "")/analisis"
  aviso "No pude deducir la canción desde '${REF#"$ROOT_DIR"/}': guardo en output/_sueltos/analisis/"
fi
mkdir -p "$DIR_SALIDA"

cabecera "ANÁLISIS DE ACORDES (chord-extractor / Chordino)"
if [[ $STEMS == 1 ]]; then
  detalle "Entrada   : ${REF#"$ROOT_DIR"/}  (${#LISTA[@]} stems)"
  detalle "Modo      : --stems (uno por uno)"
else
  detalle "Entrada   : ${REF#"$ROOT_DIR"/}  ($(mmss "$(duracion_audio "$REF")"))"
  detalle "Modo      : archivo completo"
fi
detalle "Salida    : ${DIR_SALIDA#"$ROOT_DIR"/}"

# --- Analizar ---------------------------------------------------------------
ANALIZADOS=0
FALLOS=0
RESUMEN=()
ULTIMO_TXT=""

for AUDIO in "${LISTA[@]}"; do
  ESTEM="$(nombre_base "$AUDIO")"
  if [[ -n "$SALIDA" ]]; then
    if [[ $STEMS == 1 ]]; then NOMBRE="${SALIDA}_${ESTEM}"; else NOMBRE="$SALIDA"; fi
  else
    NOMBRE="$ESTEM"
  fi
  case "$NOMBRE" in *_acordes) ;; *) NOMBRE="${NOMBRE}_acordes" ;; esac
  RUTA_BASE="$DIR_SALIDA/$NOMBRE"

  confirmar_sobrescritura "$RUTA_BASE.txt" "el resultado del análisis"

  paso "Analizando: ${AUDIO#"$ROOT_DIR"/}"
  if ! RESULTADO="$("$PY" "$SCRIPT_DIR/analizar.py" "$AUDIO" --out "$RUTA_BASE")"; then
    error "Falló el análisis de '${AUDIO#"$ROOT_DIR"/}' (ver mensaje de arriba)"
    FALLOS=$((FALLOS + 1))
    continue
  fi
  SEGS="$(printf '%s\n' "$RESULTADO" | sed -n 's/^SEGMENTOS: //p')"
  SEQ="$(printf '%s\n' "$RESULTADO" | sed -n 's/^SECUENCIA: //p')"
  ANALIZADOS=$((ANALIZADOS + 1))
  ULTIMO_TXT="$RUTA_BASE.txt"

  # --- Informe HTML autocontenido (diagramas de acorde en SVG) --------------
  ARCHIVOS=".txt + .json"
  if [[ $HTML == 1 ]]; then
    if [[ -n "$MODELO_CTX" ]]; then
      SUBT_HTML="stem $ESTEM · $MODELO_CTX · ${CANCION:-$ESTEM}"
    else
      SUBT_HTML="canción completa · ${CANCION:-$ESTEM}"
    fi
    if "$PY" "$SCRIPT_DIR/acordes_html.py" "$RUTA_BASE.txt" --out "$RUTA_BASE.html" \
         --titulo "${CANCION:-$ESTEM}" --subtitulo "$SUBT_HTML" \
         --duracion "$(duracion_audio "$AUDIO")" >/dev/null 2>&1; then
      ARCHIVOS=".txt + .json + .html"
    else
      aviso "No se pudo generar el informe HTML de '$ESTEM' (el .txt y el .json quedaron bien)"
    fi
  fi

  ok "'$ESTEM': $SEGS segmentos -> ${RUTA_BASE#"$ROOT_DIR"/}$ARCHIVOS"
  msg "     primeros acordes: $(printf '%s' "$SEQ" | awk '{for(i=1;i<=10&&i<=NF;i++) printf "%s ", $i}')"
  RESUMEN+=("$ESTEM|$SEGS|${RUTA_BASE#"$ROOT_DIR"/}")
done

# --- Primeros acordes del archivo completo (formato tabla) ------------------
if [[ $STEMS == 0 && $ANALIZADOS -eq 1 && -n "$ULTIMO_TXT" ]]; then
  msg ""
  msg "   primeros acordes detectados:"
  printf '   %-12s %s\n' "TIMESTAMP" "ACORDE"
  tail -n +1 "$ULTIMO_TXT" | head -15 | awk '{printf "   %-12s %s\n", $1, $2}'
fi

# --- Resumen ----------------------------------------------------------------
paso "Resumen"
printf '   %-26s %9s  %s\n' "ARCHIVO" "SEGMENTOS" "SALIDA"
for fila in "${RESUMEN[@]}"; do
  IFS='|' read -r n s r <<< "$fila"
  printf '   %-26s %9s  %s.txt\n' "$n" "$s" "$r"
done
msg ""
detalle "Formato del .txt: <timestamp_segundos> <acorde>   (ej: 0.464 C)"

if [[ $ANALIZADOS -eq 0 ]]; then
  die "No se generó ningún análisis (fallos: $FALLOS)."
fi
[[ $FALLOS -gt 0 ]] && aviso "$FALLOS análisis fallaron. Ver los mensajes de arriba."
ok "Listo: $ANALIZADOS análisis en ${DIR_SALIDA#"$ROOT_DIR"/} (herramienta: chord-extractor / Chordino)"
