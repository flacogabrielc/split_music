#!/usr/bin/env bash
# procesar.sh - Script maestro: separa, arma la base rítmica, filtra el bajo y saca un loop.
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/_comun.sh"

FORZAR=0
RE_SEPARAR=0
BPM=""
COMPASES=8
START="0"
PREFIJO=""
POSICIONALES=()

uso() {
  cat <<EOF
Uso: ./scripts/procesar.sh <archivo_audio> [modelo] [opciones]

Flujo completo, en 4 pasos:
  1) separar los stems con Demucs              (se reutiliza si ya existe)
  2) base rítmica = drums + bass        -> output/<cancion>/<modelo>/<prefijo>_base_ritmica.wav
  3) bajo filtrado = bass lowpass 220   -> output/<cancion>/<modelo>/<prefijo>_bajo_lowpass220.wav
  4) loop de N compases de la base      -> output/<cancion>/loops/<prefijo>_loop_<n>c_<bpm>bpm.wav
                                           (solo si indicás --bpm)

Argumentos:
  <archivo_audio>  Ruta al archivo, relativa a la raíz, o nombre suelto (busca en mp3/)
  [modelo]         Modelo de Demucs (default: htdemucs)
                   Válidos: htdemucs, htdemucs_ft, htdemucs_6s, mdx_extra

Opciones:
  --bpm <n>        Tempo para el loop del paso 4 (si no lo pasás, se omite el loop)
  --compases <n>   Compases del loop (default: 8)
  --start <seg>    Segundo donde arranca el loop (default: 0)
  --prefijo <txt>  Prefijo de los archivos de salida (default: nombre del tema).
                   Útil si el tema tiene espacios en el nombre.
  --re-separar     Vuelve a separar aunque los stems ya existan
  -f, --forzar     Sobrescribe las salidas sin preguntar
  -h, --help       Muestra esta ayuda

Ejemplos:
  ./scripts/procesar.sh "Down by the Seaside.mp3"
  ./scripts/procesar.sh "Down by the Seaside.mp3" htdemucs --bpm 110 --start 32.5 --prefijo down_seaside
  ./scripts/procesar.sh tema.mp3 htdemucs_6s --bpm 128 --compases 16
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)    uso; exit 0 ;;
    -f|--forzar)  FORZAR=1; shift ;;
    --re-separar) RE_SEPARAR=1; shift ;;
    --bpm)        [[ $# -ge 2 ]] || die "--bpm necesita un valor."; BPM="$2"; shift 2 ;;
    --compases)   [[ $# -ge 2 ]] || die "--compases necesita un valor."; COMPASES="$2"; shift 2 ;;
    --start)      [[ $# -ge 2 ]] || die "--start necesita un valor en segundos."; START="$2"; shift 2 ;;
    --prefijo)    [[ $# -ge 2 ]] || die "--prefijo necesita un texto."; PREFIJO="$2"; shift 2 ;;
    -*)           uso >&2; die "Opción desconocida: $1" ;;
    *)            POSICIONALES+=("$1"); shift ;;
  esac
done

[[ ${#POSICIONALES[@]} -ge 1 ]] || { uso >&2; die "Falta el archivo de audio."; }
[[ ${#POSICIONALES[@]} -le 2 ]] || die "Demasiados argumentos: ${POSICIONALES[*]}"
ENTRADA="${POSICIONALES[0]}"
MODELO="${POSICIONALES[1]:-htdemucs}"

if [[ -n "$BPM" ]]; then
  [[ "$BPM" =~ ^[0-9]+([.][0-9]+)?$ ]] && awk -v b="$BPM" 'BEGIN{exit !(b>0)}' \
    || die "El BPM debe ser un número mayor a 0. Recibido: '$BPM'"
fi
[[ "$COMPASES" =~ ^[0-9]+$ ]] && [[ "$COMPASES" -ge 1 ]] || die "--compases debe ser un entero >= 1"
[[ "$START" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "--start debe ser un número en segundos"

ENTRADA="$(resolver_entrada "$ENTRADA")"
exigir_archivo "$ENTRADA"
TRACK="$(nombre_base "$ENTRADA")"
[[ -n "$PREFIJO" ]] || PREFIJO="$TRACK"
STEMS="$OUTPUT_DIR/$TRACK/spleeter/$MODELO"
# Compatibilidad: si los stems todavía están en la estructura vieja, usarlos igual
if [[ ! -d "$STEMS" && -d "$SEPARATED_DIR/$MODELO/$TRACK" ]]; then
  STEMS="$SEPARATED_DIR/$MODELO/$TRACK"
  aviso "Stems en la ubicación vieja (${STEMS#"$ROOT_DIR"/}). Re-separá para migrarlos a output/<cancion>/spleeter/."
fi
DIR_CANCION="$OUTPUT_DIR/$TRACK/$MODELO"
DIR_LOOPS="$OUTPUT_DIR/$TRACK/loops"
mkdir -p "$SEPARATED_DIR" "$OUTPUT_DIR"

FORZAR_FLAG=(); [[ $FORZAR == 1 ]] && FORZAR_FLAG=(--forzar)

cabecera "FLUJO COMPLETO DE PROCESAMIENTO"
detalle "Entrada : ${ENTRADA#"$ROOT_DIR"/}  ($(mmss "$(duracion_audio "$ENTRADA")"))"
detalle "Modelo  : $MODELO"
detalle "Stems   : ${STEMS#"$ROOT_DIR"/}"
detalle "Prefijo : $PREFIJO"
detalle "Salida  : ${DIR_CANCION#"$ROOT_DIR"/}"
detalle "Loops   : ${DIR_LOOPS#"$ROOT_DIR"/}"
if [[ -n "$BPM" ]]; then
  detalle "Loop    : $COMPASES compases a $BPM bpm desde $START s"
else
  detalle "Loop    : se omite (pasá --bpm <n> para generarlo)"
fi

# --- PASO 1/4: separar ------------------------------------------------------
paso "PASO 1/4 · Separar stems con Demucs"
if [[ -d "$STEMS" ]] && compgen -G "$STEMS/*.wav" >/dev/null && [[ $RE_SEPARAR == 0 ]]; then
  ok "Ya hay stems en ${STEMS#"$ROOT_DIR"/}: los reutilizo (usá --re-separar para rehacerlos)."
else
  "$SCRIPT_DIR/separar.sh" "$ENTRADA" "$MODELO" "${FORZAR_FLAG[@]}"
fi
[[ -f "$STEMS/bass.wav" ]]  || die "No encuentro bass.wav en ${STEMS#"$ROOT_DIR"/}. Ojo: con --two-stems no se generan todos los stems."
[[ -f "$STEMS/drums.wav" ]] || die "No encuentro drums.wav en ${STEMS#"$ROOT_DIR"/}"
ok "Stems listos."

# --- PASO 2/4: base rítmica -------------------------------------------------
paso "PASO 2/4 · Base rítmica (drums + bass)"
"$SCRIPT_DIR/mezclar.sh" "$STEMS" drums bass --out "${PREFIJO}_base_ritmica" "${FORZAR_FLAG[@]}"
BASE="$DIR_CANCION/${PREFIJO}_base_ritmica.wav"
BASE_REL="${BASE#"$ROOT_DIR"/}"
[[ -f "$BASE" ]] || die "No se generó la base rítmica esperada: $BASE"

# --- PASO 3/4: bajo filtrado ------------------------------------------------
paso "PASO 3/4 · Bajo filtrado (lowpass 220 Hz)"
"$SCRIPT_DIR/limpiar.sh" "$STEMS/bass.wav" lowpass 220 --out "${PREFIJO}_bajo_lowpass220" "${FORZAR_FLAG[@]}"
BAJO="$DIR_CANCION/${PREFIJO}_bajo_lowpass220.wav"
[[ -f "$BAJO" ]] || die "No se generó el bajo filtrado esperado: $BAJO"

# --- PASO 4/4: loop ---------------------------------------------------------
LOOP=""
if [[ -n "$BPM" ]]; then
  paso "PASO 4/4 · Loop de $COMPASES compases a $BPM bpm"
  "$SCRIPT_DIR/loop.sh" "$BASE" "$BPM" "$COMPASES" --start "$START" \
    --out "${PREFIJO}_loop_${COMPASES}c_${BPM}bpm" "${FORZAR_FLAG[@]}"
  LOOP="$DIR_LOOPS/${PREFIJO}_loop_${COMPASES}c_${BPM}bpm.wav"
else
  paso "PASO 4/4 · Loop (omitido)"
  aviso "No indicaste --bpm, así que no se generó el loop.
    Cuando lo sepas, corré:
      ./scripts/loop.sh \"$BASE_REL\" <bpm> $COMPASES --start $START"
fi

# --- RESUMEN ----------------------------------------------------------------
cabecera "RESUMEN DE ARCHIVOS GENERADOS"
printf '   %-16s %-50s %7s  %11s\n' "QUÉ" "ARCHIVO" "TAMAÑO" "DURACIÓN"
printf '%s   %s%s\n' "$C_GRIS" "──────────────────────────────────────────────────────────────────────────────────" "$C_RESET"
resumen_archivo "stem bajo"     "$STEMS/bass.wav"
resumen_archivo "stem batería"  "$STEMS/drums.wav"
resumen_archivo "base rítmica"  "$BASE"
resumen_archivo "bajo filtrado" "$BAJO"
[[ -n "$LOOP" ]] && resumen_archivo "loop" "$LOOP"
msg ""
ok "Todo listo. Los MP3 originales y la carpeta separated/ quedaron intactos."
detalle "Para escuchar:  ffplay \"$BASE_REL\""
