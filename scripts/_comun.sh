#!/usr/bin/env bash
# _comun.sh - utilidades compartidas por los scripts del proyecto.
# NO se ejecuta directamente: se importa con  source scripts/_comun.sh
set -euo pipefail

# Locale numérico fijo: con es_* los decimales se escriben con coma y eso rompe
# los cálculos de awk (ej: comparar "47,45" contra la duración del archivo).
export LC_NUMERIC=C

# --- Rutas del proyecto -----------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
VENV_DIR="$ROOT_DIR/venv"
MP3_DIR="$ROOT_DIR/mp3"
SEPARATED_DIR="$ROOT_DIR/separated"
OUTPUT_DIR="$ROOT_DIR/output"
LOG_DIR="$OUTPUT_DIR/logs"

# --- Colores (solo si la salida es una terminal) ----------------------------
if [[ -t 1 ]]; then
  C_ROJO=$'\033[1;31m'; C_VERDE=$'\033[1;32m'; C_AMAR=$'\033[1;33m'
  C_AZUL=$'\033[1;34m'; C_GRIS=$'\033[0;90m'; C_RESET=$'\033[0m'
else
  C_ROJO=""; C_VERDE=""; C_AMAR=""; C_AZUL=""; C_GRIS=""; C_RESET=""
fi

msg()     { printf '%s\n' "$*"; }
info()    { printf '%s[INFO]%s %s\n'  "$C_AZUL"  "$C_RESET" "$*"; }
ok()      { printf '%s[ OK ]%s %s\n'  "$C_VERDE" "$C_RESET" "$*"; }
aviso()   { printf '%s[AVISO]%s %s\n' "$C_AMAR"  "$C_RESET" "$*" >&2; }
error()   { printf '%s[ERROR]%s %s\n' "$C_ROJO"  "$C_RESET" "$*" >&2; }
die()     { error "$*"; exit 1; }
paso()    { printf '\n%s==> %s%s\n' "$C_AZUL" "$*" "$C_RESET"; }
detalle() { printf '%s     %s%s\n' "$C_GRIS" "$*" "$C_RESET"; }

# --- Entorno virtual --------------------------------------------------------
activar_venv() {
  local act="$VENV_DIR/bin/activate"
  if [[ ! -f "$act" ]]; then
    die "No existe el entorno virtual en $VENV_DIR
    Creálo así:
      cd $ROOT_DIR
      python3 -m venv venv
      source venv/bin/activate
      pip install demucs"
  fi
  # shellcheck disable=SC1090
  source "$act"
  [[ -n "${VIRTUAL_ENV:-}" ]] || die "No se pudo activar el venv ($act)"
  # torch por defecto usa pocos hilos: le damos todos los núcleos disponibles
  export OMP_NUM_THREADS="${OMP_NUM_THREADS:-$(nproc)}"
  info "venv activado: $VIRTUAL_ENV  (hilos: $OMP_NUM_THREADS)"
}

exigir_comando() {
  command -v "$1" >/dev/null 2>&1 || die "Falta el comando '$1'. ${2:-}"
}

# --- Utilidades de rutas y archivos ----------------------------------------
nombre_base() { local b; b="$(basename -- "$1")"; printf '%s' "${b%.*}"; }

resolver_entrada() {  # acepta ruta directa, ruta relativa a la raíz, o nombre suelto en mp3/
  local f="$1"
  [[ -n "$f" ]] || die "No indicaste ningún archivo de entrada."
  [[ -f "$f" ]] && { printf '%s' "$f"; return 0; }
  [[ -f "$ROOT_DIR/$f" ]] && { printf '%s' "$ROOT_DIR/$f"; return 0; }
  if [[ -d "$MP3_DIR" ]]; then
    local enc
    enc="$(find "$MP3_DIR" -type f -iname "$(basename -- "$f")" -print -quit 2>/dev/null || true)"
    [[ -n "$enc" ]] && { printf '%s' "$enc"; return 0; }
  fi
  die "No encontré el archivo '$f' (ni en la ruta indicada ni dentro de $MP3_DIR)"
}

resolver_existente() {  # para carpetas/archivos generados: ruta directa o relativa a la raíz
  local p="$1"
  [[ -e "$p" ]] && { printf '%s' "$p"; return 0; }
  [[ -e "$ROOT_DIR/$p" ]] && { printf '%s' "$ROOT_DIR/$p"; return 0; }
  die "No existe: $p"
}

# --- Contexto de salida: canción y modelo ------------------------------------
absoluta() {  # convierte una ruta relativa (al proyecto) en absoluta
  case "${1:-}" in
    /*) printf '%s' "$1" ;;
    *)  printf '%s/%s' "$ROOT_DIR" "$1" ;;
  esac
}

deducir_contexto() {
  # Dada una carpeta de stems o la ruta de un archivo, imprime "<cancion>|<contexto>":
  #   separated/<modelo>/<cancion>[...]  ->  "Down by the Seaside|htdemucs"
  #   output/<cancion>/<contexto>[...]   ->  "Down by the Seaside|htdemucs"
  # Si no se puede deducir, imprime "|" (ambos vacíos) y quien llama decide.
  # Acepta rutas absolutas, relativas a la raíz o relativas al cwd.
  local ruta="${1:-}" base rel partes=()
  [[ -n "$ruta" ]] || { printf '|'; return 0; }
  # Si es un archivo (o parece serlo por la extensión), miramos su carpeta
  if [[ -f "$ruta" ]] || [[ "$ruta" =~ \.(wav|mp3|flac|ogg|m4a|aif|aiff)$ ]]; then
    base="$(dirname -- "$ruta")"
  else
    base="$ruta"
  fi
  [[ -d "$base" ]] || { printf '|'; return 0; }
  base="$(cd -- "$base" 2>/dev/null && pwd -P)" || { printf '|'; return 0; }
  case "$base" in
    "$ROOT_DIR"/*) rel="${base#"$ROOT_DIR"/}" ;;
    *)             printf '|'; return 0 ;;
  esac
  IFS='/' read -r -a partes <<< "$rel"
  case "${partes[0]:-}" in
    separated)
      if [[ -n "${partes[1]:-}" && -n "${partes[2]:-}" ]]; then
        printf '%s|%s' "${partes[2]}" "${partes[1]}"; return 0
      fi ;;
    output)
      case "${partes[1]:-}" in
        ""|_sueltos|logs) ;;   # sin canción: no hay contexto que deducir
        *)
          if [[ "${partes[2]:-}" == "spleeter" ]]; then
            # output/<cancion>/spleeter/<modelo>[/...]
            if [[ -n "${partes[3]:-}" ]]; then
              printf '%s|%s' "${partes[1]}" "${partes[3]}"; return 0
            fi
          elif [[ -n "${partes[2]:-}" ]]; then
            # output/<cancion>/<contexto>[/...]  (analisis, loops, <modelo>, ...)
            printf '%s|%s' "${partes[1]}" "${partes[2]}"; return 0
          fi ;;
      esac ;;
  esac
  printf '|'
}

raiz_salida() {  # $1 = canción ; si viene vacío, devuelve output/_sueltos
  if [[ -n "${1:-}" ]]; then printf '%s/%s' "$OUTPUT_DIR" "$1"
  else printf '%s/_sueltos' "$OUTPUT_DIR"; fi
}

exigir_archivo() {
  [[ -n "${1:-}" ]] || die "Falta el archivo de entrada."
  [[ -f "$1" ]] || die "No existe el archivo: $1"
  [[ -s "$1" ]] || die "El archivo está vacío: $1"
}

confirmar_sobrescritura() {  # $1=ruta  $2=descripción ; respeta $FORZAR=1
  local ruta="$1" desc="${2:-el archivo}"
  [[ -e "$ruta" ]] || return 0
  if [[ "${FORZAR:-0}" == "1" ]]; then
    aviso "Sobrescribiendo $desc: ${ruta#"$ROOT_DIR"/}"
    return 0
  fi
  if [[ ! -t 0 ]]; then
    die "$desc ya existe: ${ruta#"$ROOT_DIR"/}
    Usá --forzar para sobrescribir en modo no interactivo."
  fi
  printf '%s[?]%s %s ya existe: %s\n    ¿Sobrescribir? [s/N] ' \
    "$C_AMAR" "$C_RESET" "$desc" "${ruta#"$ROOT_DIR"/}"
  local r; read -r r
  [[ "$r" =~ ^[sSyY]$ ]] || { info "Cancelado por el usuario. No se modificó nada."; exit 0; }
}

# --- Info de audio ----------------------------------------------------------
duracion_audio() {
  ffprobe -v error -show_entries format=duration -of csv=p=0 -- "$1" 2>/dev/null || printf '?'
}
formato_audio() {
  ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,sample_rate,channels \
    -of csv=p=0 -- "$1" 2>/dev/null || printf '?'
}
volumen_medio() {  # mean_volume en dB; sirve para verificar que un filtro hizo algo
  ffmpeg -hide_banner -nostdin -i "$1" -af volumedetect -f null - 2>&1 \
    | awk '/mean_volume/ {print $(NF-1)" "$NF}' | tail -1
}
tamano_legible() { du -h -- "$1" 2>/dev/null | cut -f1; }

cabecera() {
  printf '\n%s%s%s\n' "$C_AZUL" "$1" "$C_RESET"
  printf '%s────────────────────────────────────────────────────────────%s\n' "$C_GRIS" "$C_RESET"
}

listar_stems() {  # $1 = carpeta de stems
  local d="$1" f
  [[ -d "$d" ]] || return 0
  for f in "$d"/*.wav; do
    [[ -e "$f" ]] || continue
    printf '   %-12s %7s  %9s s\n' "$(basename -- "$f")" "$(tamano_legible "$f")" "$(duracion_audio "$f")"
  done
}

resumen_archivo() {  # $1 = etiqueta, $2 = ruta
  [[ -f "${2:-}" ]] || return 0
  printf '   %-16s %-50s %7s  %9s s\n' "$1" "${2#"$ROOT_DIR"/}" "$(tamano_legible "$2")" "$(duracion_audio "$2")"
}

# Convierte segundos a mm:ss, para los mensajes de progreso
mmss() { awk -v s="$1" 'BEGIN{printf "%d:%02d", int(s/60), int(s%60)}'; }

# Defensa extra contra locales con coma decimal: "17,45" -> "17.45"
num() { printf '%s' "$1" | tr ',' '.'; }
