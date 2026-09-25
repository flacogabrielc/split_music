#!/usr/bin/env bash
# separar.sh - Separa un audio en stems con Demucs, siempre dentro del venv.
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/_comun.sh"

MODELOS_VALIDOS=(htdemucs htdemucs_ft htdemucs_6s mdx_extra)
MODELO_DEFECTO=htdemucs
FORZAR=0
POSICIONALES=()

uso() {
  cat <<EOF
Uso: ./scripts/separar.sh <archivo_audio> [modelo] [opciones]

Separa <archivo_audio> en stems con Demucs. La salida queda en
  separated/<modelo>/<nombre_del_tema>/
El archivo original NUNCA se modifica (solo lectura).

Argumentos:
  <archivo_audio>  Ruta al archivo, ruta relativa a la raíz, o solo el nombre
                   (en ese caso se busca dentro de mp3/).
  [modelo]         Modelo de Demucs. Por defecto: $MODELO_DEFECTO
                   Válidos: ${MODELOS_VALIDOS[*]}

Opciones:
  -f, --forzar     Sobrescribe una separación existente sin preguntar
  -h, --help       Muestra esta ayuda

Variables de entorno:
  DEMUCS_ARGS      Args extra para demucs
                   ej:  DEMUCS_ARGS="--clip-mode clamp"   DEMUCS_ARGS="--mp3"
  OMP_NUM_THREADS  Nº de hilos de CPU (por defecto: todos los núcleos)

Ejemplos:
  ./scripts/separar.sh "Down by the Seaside.mp3"
  ./scripts/separar.sh "mp3/mi_tema.wav" htdemucs_6s
  DEMUCS_ARGS="--clip-mode clamp" ./scripts/separar.sh tema.mp3 htdemucs_ft
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)   uso; exit 0 ;;
    -f|--forzar) FORZAR=1; shift ;;
    -*)          uso >&2; die "Opción desconocida: $1" ;;
    *)           POSICIONALES+=("$1"); shift ;;
  esac
done

if [[ ${#POSICIONALES[@]} -lt 1 ]]; then
  uso >&2; die "Falta el archivo de audio de entrada."
fi
if [[ ${#POSICIONALES[@]} -gt 2 ]]; then
  die "Demasiados argumentos: ${POSICIONALES[*]}  (máximo: <archivo> [modelo])"
fi

ENTRADA="${POSICIONALES[0]}"
MODELO="${POSICIONALES[1]:-$MODELO_DEFECTO}"

# --- Validaciones previas (antes de activar nada) ---------------------------
coincide=0
for m in "${MODELOS_VALIDOS[@]}"; do [[ "$m" == "$MODELO" ]] && coincide=1; done
if [[ $coincide -eq 0 ]]; then
  die "Modelo inválido: '$MODELO'. Válidos: ${MODELOS_VALIDOS[*]}"
fi

ENTRADA="$(resolver_entrada "$ENTRADA")"
exigir_archivo "$ENTRADA"
TRACK="$(nombre_base "$ENTRADA")"
# Demucs escribe primero en separated/ (su área de trabajo) y al terminar movemos
# los stems a output/<cancion>/spleeter/<modelo>/: así cada canción queda junta.
DESTINO_STAGING="$SEPARATED_DIR/$MODELO/$TRACK"
DESTINO="$OUTPUT_DIR/$TRACK/spleeter/$MODELO"

cabecera "SEPARACIÓN DE STEMS CON DEMUCS"
detalle "Entrada : ${ENTRADA#"$ROOT_DIR"/}"
detalle "Modelo  : $MODELO"
detalle "Salida  : ${DESTINO#"$ROOT_DIR"/}"
detalle "Formato : $(formato_audio "$ENTRADA") · $(mmss "$(duracion_audio "$ENTRADA")") de audio"
detalle "Staging : ${DESTINO_STAGING#"$ROOT_DIR"/}  (Demucs escribe acá; luego se mueve a Salida)"

activar_venv
exigir_comando demucs "Instalalo con: source venv/bin/activate && pip install demucs"
exigir_comando ffprobe "Instalalo con: sudo apt install ffmpeg"

if [[ -d "$DESTINO" ]] && compgen -G "$DESTINO/*.wav" >/dev/null; then
  confirmar_sobrescritura "$DESTINO" "la separación existente"
fi

mkdir -p "$SEPARATED_DIR" "$(dirname "$DESTINO")" "$LOG_DIR"
LOG="$LOG_DIR/separar_$(date +%Y%m%d-%H%M%S)_${TRACK// /_}.log"

aviso "Demucs puede tardar VARIOS MINUTOS (corre en CPU, no hay GPU disponible)."
detalle "No cierres la terminal. Log en vivo: ${LOG#"$ROOT_DIR"/}"
if [[ ! -d "$HOME/.cache/huggingface/hub" && ! -d "$HOME/.cache/torch/hub/checkpoints" ]]; then
  detalle "Primera corrida: se descarga el modelo desde Hugging Face Hub (~80 MB a ~350 MB)."
fi
printf '\n'

# --- Ejecución --------------------------------------------------------------
INICIO=$(date +%s)
set +e
# shellcheck disable=SC2086 # DEMUCS_ARGS se expande a propósito en varias palabras
demucs -n "$MODELO" -o "$SEPARATED_DIR" ${DEMUCS_ARGS:-} "$ENTRADA" 2>&1 | tee "$LOG"
RC=${PIPESTATUS[0]}
set -e
FIN=$(date +%s)
DURADO=$((FIN - INICIO))

if [[ $RC -ne 0 ]]; then
  error "Demucs terminó con error (código $RC)."
  detalle "Últimas líneas del log:"
  tail -n 15 "$LOG" >&2
  die "Revisá el log completo en: ${LOG#"$ROOT_DIR"/}"
fi

if grep -qiE 'unauthenticated|HF_TOKEN|huggingface' "$LOG"; then
  aviso "Demucs avisó por Hugging Face Hub. Para silenciar el warning (y acelerar
    descargas) definí un token antes de correr:  export HF_TOKEN=\"hf_tu_token\"
    Ver la sección 'HF_TOKEN' del README.md. No es obligatorio para funcionar."
fi

# --- Resultado --------------------------------------------------------------
paso "Listo en $(mmss "$DURADO")"
if [[ -d "$DESTINO_STAGING" ]]; then
  mkdir -p "$(dirname "$DESTINO")"
  if [[ -d "$DESTINO" && -n "$TRACK" && "$DESTINO" == "$OUTPUT_DIR"/* ]]; then
    rm -rf -- "$DESTINO"   # ya se confirmó/forzó la sobrescritura arriba
  fi
  mv -- "$DESTINO_STAGING" "$DESTINO"
  # limpiar las carpetas vacías que deja el staging (separated/<modelo>, ...)
  rmdir -p --ignore-fail-on-non-empty "$SEPARATED_DIR/$MODELO" 2>/dev/null || true
fi
if [[ -d "$DESTINO" ]] && compgen -G "$DESTINO/*.wav" >/dev/null; then
  ok "Stems generados en: ${DESTINO#"$ROOT_DIR"/}"
  msg ""
  printf '   %-12s %7s  %11s\n' "ARCHIVO" "TAMAÑO" "DURACIÓN"
  listar_stems "$DESTINO"
  msg ""
  detalle "Siguiente paso: ./scripts/mezclar.sh \"${DESTINO#"$ROOT_DIR"/}\" drums bass --out base_ritmica"
else
  aviso "Demucs terminó bien pero no encuentro los stems en ${DESTINO#"$ROOT_DIR"/}. Revisá el log."
fi
