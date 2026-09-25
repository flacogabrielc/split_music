#!/usr/bin/env bash
# mezclar.sh - Mezcla varios stems en un único WAV con ffmpeg (amix, normalize=0).
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/_comun.sh"

FORZAR=0
SALIDA=""
CARPETA=""
OUT_DIR=""
STEMS=()

uso() {
  cat <<EOF
Uso: ./scripts/mezclar.sh <carpeta_stems> <stem1> <stem2> [...] --out <nombre> [opciones]

Suma (mezcla) los stems indicados en un solo WAV. El destino se deduce de la
carpeta de stems que recibe:
  output/<cancion>/<modelo>/<nombre>.wav

Se usa amix con normalize=0 a propósito: NO reescala los niveles, así se
preservan las proporciones originales. Como consecuencia, la suma puede
saturar; en ese caso bajá los volúmenes con la variable VOLS.

Argumentos:
  <carpeta_stems>  Carpeta con los .wav (o ruta relativa a la raíz)
  <stem1> <stem2>  Nombres de los stems sin .wav (drums, bass, vocals, other,
                   guitar, piano). También acepta "drums.wav".
  --out, -o        Nombre del archivo de salida (sin .wav). Obligatorio.
  --out-dir <ruta> Carpeta de destino explícita (relativa a la raíz o absoluta).
                   Si se indica, NO se deduce <cancion>/<modelo>.

Opciones:
  -f, --forzar     Sobrescribe la salida existente sin preguntar
  -h, --help       Muestra esta ayuda

Variables de entorno:
  VOLS             Volúmenes individuales, separados por coma.
                   Ej:  VOLS="drums=1.0,bass=0.8"   (por defecto: todos 1.0)

Ejemplos:
  ./scripts/mezclar.sh "separated/htdemucs/cancion" drums bass --out base_ritmica
  VOLS="drums=0.9,bass=0.7" ./scripts/mezclar.sh separated/htdemucs/cancion drums bass --out base
  ./scripts/mezclar.sh "separated/htdemucs_6s/cancion" drums bass other --out instrumental
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)   uso; exit 0 ;;
    -f|--forzar) FORZAR=1; shift ;;
    -o|--out)    [[ $# -ge 2 ]] || die "--out necesita un nombre de salida."; SALIDA="$2"; shift 2 ;;
    --out-dir)   [[ $# -ge 2 ]] || die "--out-dir necesita una ruta."; OUT_DIR="$2"; shift 2 ;;
    -*)          uso >&2; die "Opción desconocida: $1" ;;
    *)           if [[ -z "$CARPETA" ]]; then CARPETA="$1"; else STEMS+=("$1"); fi; shift ;;
  esac
done

[[ -n "$CARPETA" ]] || { uso >&2; die "Falta la carpeta de stems."; }
[[ ${#STEMS[@]} -ge 2 ]] || { uso >&2; die "Indicá al menos 2 stems para mezclar."; }
[[ -n "$SALIDA" ]] || { uso >&2; die "Falta --out <nombre_salida>."; }

CARPETA="$(resolver_existente "$CARPETA")"
[[ -d "$CARPETA" ]] || die "No es una carpeta: $CARPETA"

# --- Resolver cada stem a su archivo .wav ----------------------------------
ARCHIVOS=()
for s in "${STEMS[@]}"; do
  cand="$CARPETA/${s%.wav}.wav"
  if [[ -f "$cand" ]]; then
    ARCHIVOS+=("$cand")
  else
    error "No encontré el stem '$s' en ${CARPETA#"$ROOT_DIR"/}"
    listar_stems "$CARPETA" >&2
    die "Stem inexistente: $s"
  fi
done

# --- Volúmenes individuales (variable opcional VOLS) ------------------------
declare -A VOL
for s in "${STEMS[@]}"; do VOL["${s%.wav}"]=1.0; done
if [[ -n "${VOLS:-}" ]]; then
  IFS=',' read -r -a pares <<<"$VOLS"
  for par in "${pares[@]}"; do
    [[ "$par" == *=* ]] || die "VOLS mal formado: '$par' (se espera stem=valor, ej: drums=1.0,bass=0.8)"
    clave="${par%%=*}"; valor="${par#*=}"
    if [[ -z "${VOL[$clave]:-}" ]]; then
      aviso "VOLS menciona '$clave', que no está en esta mezcla; lo ignoro."
      continue
    fi
    VOL["$clave"]="$valor"
  done
fi

# --- Destino: output/<cancion>/<modelo>/ ------------------------------------
IFS='|' read -r CANCION MODELO_CTX <<< "$(deducir_contexto "$CARPETA")"
if [[ -n "$OUT_DIR" ]]; then
  DIR_SALIDA="$(absoluta "$OUT_DIR")"
elif [[ -n "$CANCION" ]]; then
  DIR_SALIDA="$(raiz_salida "$CANCION")/${MODELO_CTX:-_sueltos}"
else
  DIR_SALIDA="$(raiz_salida "")"
  aviso "No pude deducir canción/modelo desde '${CARPETA#"$ROOT_DIR"/}': guardo en output/_sueltos/"
fi
DESTINO="$DIR_SALIDA/$SALIDA.wav"

cabecera "MEZCLA DE STEMS (amix, normalize=0)"
detalle "Carpeta : ${CARPETA#"$ROOT_DIR"/}"
detalle "Salida  : ${DESTINO#"$ROOT_DIR"/}"
msg ""
printf '   %-14s %-10s %s\n' "STEM" "VOLUMEN" "ARCHIVO DE ORIGEN"
for s in "${STEMS[@]}"; do
  k="${s%.wav}"
  printf '   %-14s %-10s %s\n' "$k" "${VOL[$k]}" "${CARPETA#"$ROOT_DIR"/}/$k.wav"
done

# --- Construir el filter_complex -------------------------------------------
exigir_comando ffmpeg "Instalalo con: sudo apt install ffmpeg"
ENTRADAS=(); FILTRO=""; CADENA=""; i=0
for s in "${STEMS[@]}"; do
  k="${s%.wav}"
  ENTRADAS+=(-i "$CARPETA/$k.wav")
  FILTRO+="[${i}:a]volume=${VOL[$k]}[v${i}];"
  CADENA+="[v${i}]"
  i=$((i + 1))
done
FILTRO+="${CADENA}amix=inputs=${i}:normalize=0:duration=longest[mezcla]"

mkdir -p "$DIR_SALIDA"
confirmar_sobrescritura "$DESTINO" "el archivo de salida"

paso "Mezclando ${#STEMS[@]} stems con ffmpeg"
ffmpeg -hide_banner -nostdin -y "${ENTRADAS[@]}" -filter_complex "$FILTRO" \
  -map "[mezcla]" -c:a pcm_s16le "$DESTINO"

paso "Resultado"
ok "Mezcla creada: ${DESTINO#"$ROOT_DIR"/}"
resumen_archivo "salida" "$DESTINO"
antes="$(volumen_medio "${ARCHIVOS[0]}")"
despues="$(volumen_medio "$DESTINO")"
detalle "volumen medio del 1er stem: $antes   |   de la mezcla: $despues"
aviso "Si escuchás saturación, repetí con volúmenes más bajos:
    VOLS=\"${STEMS[0]%.wav}=0.8,${STEMS[1]%.wav}=0.7\" ./scripts/mezclar.sh ..."
