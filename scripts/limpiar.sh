#!/usr/bin/env bash
# limpiar.sh - Aplica un filtro de frecuencia a un WAV (lowpass/highpass/bandpass).
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/_comun.sh"

FORZAR=0
OUT_DIR=""
SALIDA=""
ANCHO=""
TIPO_ANCHO="q"
POLOS="2"
ENTRADA=""
TIPO=""
FREQ=""

uso() {
  cat <<EOF
Uso: ./scripts/limpiar.sh <archivo_wav> <tipo_filtro> <frecuencia> [opciones]

Filtra un WAV. El destino se deduce de la ruta de entrada:
  output/<cancion>/<modelo>/<nombre>.wav   (si reconoce la canción)
  output/_sueltos/<nombre>.wav             (si la entrada es un archivo suelto)

Tipos de filtro:
  lowpass    deja pasar solo lo GRAVE por debajo de <frecuencia> (ej: aislar el
             cuerpo del bajo: lowpass 220)
  highpass   deja pasar solo lo AGUDO por encima de <frecuencia> (ej: sacar el
             retumbe de la voz: highpass 120)
  bandpass   deja pasar solo una BANDA alrededor de <frecuencia>; la frecuencia
             es el CENTRO de la banda

Argumentos:
  <archivo_wav>  Archivo de entrada (ruta o relativa a la raíz)
  <tipo_filtro>  lowpass | highpass | bandpass
  <frecuencia>   En Hz (ej: 220)

Opciones:
  --out <nombre>         Nombre de salida (sin .wav). Por defecto:
                         <archivo>_<tipo>_<frecuencia>
  --out-dir <ruta>       Carpeta de destino explícita (relativa a la raíz o
                         absoluta). Si se indica, NO se deduce la estructura.
  --ancho <valor>        Ancho de la transición (default ffmpeg: 0.707)
  --tipo-ancho <q|h|o>   Unidad del ancho: q=Q-factor, h=Hz, o=octavas. Default: q
  --polos <1|2>          Pendiente del filtro (solo low/highpass). Default: 2
  -f, --forzar           Sobrescribe la salida sin preguntar
  -h, --help             Muestra esta ayuda

Ejemplos:
  ./scripts/limpiar.sh separated/htdemucs/cancion/bass.wav lowpass 220 --out bass_limpio
  ./scripts/limpiar.sh separated/htdemucs/cancion/vocals.wav highpass 120
  ./scripts/limpiar.sh separated/htdemucs/cancion/drums.wav bandpass 8000 --tipo-ancho o --ancho 1
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)    uso; exit 0 ;;
    -f|--forzar)  FORZAR=1; shift ;;
    --out)        [[ $# -ge 2 ]] || die "--out necesita un nombre."; SALIDA="$2"; shift 2 ;;
    --out-dir)    [[ $# -ge 2 ]] || die "--out-dir necesita una ruta."; OUT_DIR="$2"; shift 2 ;;
    --ancho)      [[ $# -ge 2 ]] || die "--ancho necesita un valor."; ANCHO="$2"; shift 2 ;;
    --tipo-ancho) [[ $# -ge 2 ]] || die "--tipo-ancho necesita q, h u o."; TIPO_ANCHO="$2"; shift 2 ;;
    --polos)      [[ $# -ge 2 ]] || die "--polos necesita 1 o 2."; POLOS="$2"; shift 2 ;;
    -*)           uso >&2; die "Opción desconocida: $1" ;;
    *)
      if   [[ -z "$ENTRADA" ]]; then ENTRADA="$1"
      elif [[ -z "$TIPO"    ]]; then TIPO="$1"
      elif [[ -z "$FREQ"    ]]; then FREQ="$1"
      else die "Argumento de más: $1"
      fi
      shift ;;
  esac
done

[[ -n "$ENTRADA" && -n "$TIPO" && -n "$FREQ" ]] || { uso >&2; die "Faltan argumentos: <archivo_wav> <tipo_filtro> <frecuencia>"; }

case "$TIPO" in
  lowpass|highpass|bandpass) ;;
  *) die "Tipo de filtro inválido: '$TIPO'. Válidos: lowpass, highpass, bandpass" ;;
esac
[[ "$FREQ" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "La frecuencia debe ser un número en Hz (ej: 220). Recibido: '$FREQ'"
[[ "$TIPO_ANCHO" =~ ^(q|h|o)$ ]]      || die "--tipo-ancho debe ser q, h u o. Recibido: '$TIPO_ANCHO'"
[[ "$POLOS" =~ ^[12]$ ]]              || die "--polos debe ser 1 o 2. Recibido: '$POLOS'"

ENTRADA="$(resolver_existente "$ENTRADA")"
exigir_archivo "$ENTRADA"
BASE="$(nombre_base "$ENTRADA")"
[[ -n "$SALIDA" ]] || SALIDA="${BASE}_${TIPO}_${FREQ}"

# --- Destino: output/<cancion>/<modelo>/  o  output/_sueltos/ ---------------
IFS='|' read -r CANCION MODELO_CTX <<< "$(deducir_contexto "$ENTRADA")"
if [[ -n "$OUT_DIR" ]]; then
  DIR_SALIDA="$(absoluta "$OUT_DIR")"
elif [[ -n "$CANCION" ]]; then
  DIR_SALIDA="$(raiz_salida "$CANCION")/${MODELO_CTX:-_sueltos}"
else
  DIR_SALIDA="$(raiz_salida "")"
  aviso "No pude deducir la canción desde '${ENTRADA#"$ROOT_DIR"/}': guardo en output/_sueltos/"
fi
DESTINO="$DIR_SALIDA/$SALIDA.wav"

# --- Cadena de filtro -------------------------------------------------------
FILTRO="${TIPO}=f=${FREQ}:width_type=${TIPO_ANCHO}"
[[ -n "$ANCHO" ]] && FILTRO+=":width=${ANCHO}"
# bandpass de ffmpeg es un Butterworth de 2 polos fijo: no acepta "poles"
if [[ "$TIPO" != "bandpass" ]]; then
  FILTRO+=":poles=${POLOS}"
fi

cabecera "FILTRADO DE AUDIO (ffmpeg -af)"
detalle "Entrada : ${ENTRADA#"$ROOT_DIR"/}"
detalle "Filtro  : $FILTRO"
detalle "Salida  : ${DESTINO#"$ROOT_DIR"/}"

exigir_comando ffmpeg "Instalalo con: sudo apt install ffmpeg"
mkdir -p "$DIR_SALIDA"
confirmar_sobrescritura "$DESTINO" "el archivo de salida"

ANTES="$(volumen_medio "$ENTRADA")"

paso "Aplicando filtro"
ffmpeg -hide_banner -nostdin -y -i "$ENTRADA" -af "$FILTRO" -c:a pcm_s16le "$DESTINO"

DESPUES="$(volumen_medio "$DESTINO")"

paso "Resultado"
ok "Archivo filtrado: ${DESTINO#"$ROOT_DIR"/}"
resumen_archivo "original" "$ENTRADA"
resumen_archivo "filtrado" "$DESTINO"
detalle "volumen medio: original $ANTES  ->  filtrado $DESPUES"
detalle "En un $TIPO en $FREQ Hz es normal que el volumen medio BAJE: se está quitando energía."
