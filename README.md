# 🎛️ spleeter — Separación de stems y experimentos (Demucs)

Proyecto local para separar canciones en pistas, mezclarlas, filtrarlas y sacar
loops para practicar guitarra o armar remixes. Todo el procesamiento es **local**
(no manda audio a ningún servicio) y corre en **CPU**.

> Todos los scripts activan el venv por sí solos, así que podés llamarlos desde
> cualquier carpeta. El archivo original **nunca** se modifica.
>
> 🤖 **¿Preferís pedir las tareas en lenguaje natural?** Ver [`AGENTES.md`](AGENTES.md), que define
> los roles **Separador, Mezclador, Masterizador y Looper** (resumen en la
> [sección 11](#11-roles-de-trabajo)).

---

## 1. Estructura del proyecto

```
~/proyectos/spleeter/
├── venv/         # entorno virtual (Demucs + torch). NO TOCAR (no versionado: ver 2.1)
├── mp3/          # canciones de entrada (solo lectura)
├── separated/    # área de trabajo temporal de Demucs (el script mueve los stems a
│                 # output/<cancion>/spleeter/<modelo>/)
├── output/       # salidas organizadas: output/<cancion>/<modelo>/, .../loops/ y .../analisis/
│                 # + output/_sueltos/ (sin contexto) y output/logs/ (global)
├── scripts/      # los scripts de automatización
│   ├── _comun.sh     # utilidades internas (no se ejecuta solo)
│   ├── separar.sh
│   ├── mezclar.sh
│   ├── limpiar.sh
│   ├── loop.sh
│   ├── procesar.sh
│   ├── analizar.sh   # rol Analista (acordes + BPM + tonalidad)
│   ├── analizar.py   # wrapper de chord-extractor que usa analizar.sh
│   ├── analizar_bpm.py  # BPM y tonalidad con librosa (lo usa analizar.sh)
│   ├── acordes_html.py  # genera el informe HTML con diagramas SVG
│   ├── _beats.py        # busca el tiempo (beat) más cercano a un segundo; lo usa loop.sh
│   └── validar_digitaciones.py  # verifica que la tabla de voicings sea correcta
├── .clinerules             # reglas del proyecto para Cline (rutas, roles, confirmaciones)
├── AGENTES.md              # roles de trabajo para pedir tareas en lenguaje natural
├── COMANDOS_MANUALES.txt   # notas personales (comandos de demucs a mano)
├── PENDIENTES.md           # estado actual y tareas pendientes (memoria del proyecto)
├── freeze_antes_chordextractor.txt  # snapshot del venv antes de instalar chord-extractor
├── requirements.txt        # dependencias del venv (ver 2.1 para recrearlo desde cero)
├── .gitignore              # deja fuera venv/, mp3/, output/ y separated/ (~7 GB)
└── README.md
```

---

## 2. Entorno: cómo activar el venv

Los scripts **lo activan solos**, pero si querés trabajar a mano:

```bash
cd ~/proyectos/spleeter
source venv/bin/activate      # el prompt pasa a mostrar (venv)
demucs --version
deactivate                    # para salir
```

Verificado en esta máquina: **Python 3.12.3 · demucs 4.1.0 · torch 2.14.0+cu130**
· CUDA disponible: **NO** → todo corre en CPU (con los 8 núcleos del equipo).

### 2.1 Instalación desde cero (en otra PC)

El repositorio de GitHub tiene **solo scripts y documentación** (~488 KB). `venv/`, `mp3/`,
`output/` y `separated/` están en `.gitignore` porque pesan ~7 GB y se regeneran.

```bash
# 1) Clonar (el repo es público: leer no pide credenciales)
git clone https://github.com/flacogabrielc/split_music.git
cd split_music

# 2) Recrear el entorno virtual (Python 3.12)
python3 -m venv venv
./venv/bin/pip install -r requirements.txt
./venv/bin/pip install --ignore-requires-python --no-build-isolation chord-extractor

# 3) Dependencia del sistema
sudo apt install ffmpeg
```

- ⚠️ **`chord-extractor` va aparte**: declara `Requires-Python: >=3.8,<3.12`, así que un
  `pip install -r requirements.txt` pelado **falla en Python 3.12**. Con `--ignore-requires-python`
  funciona igual (el plugin Chordino y el Vamp SDK vienen empaquetados: no hace falta sudo).
- ⚠️ El venv completo pesa **~6 GB** (torch 2.14.0 en CPU): la descarga tarda.
  La receta también está escrita adentro de `requirements.txt`.
- `mp3/` **no** viene en el repo (audio con copyright): copiá ahí tus canciones.
- Para subir cambios desde esta máquina alcanza con `git push` (el remote usa **SSH**).

---

## 3. Uso rápido (el flujo de 1 minuto)

```bash
cd ~/proyectos/spleeter

# 1) separar en 4 stems (tarda minutos: ver sección de tiempos)
./scripts/separar.sh "Down by the Seaside.mp3"

# 2) base rítmica para tocar encima (batería + bajo)
./scripts/mezclar.sh "output/Down by the Seaside/spleeter/htdemucs" drums bass --out base_ritmica

# 3) dejar solo el cuerpo del bajo
./scripts/limpiar.sh "output/Down by the Seaside/spleeter/htdemucs/bass.wav" lowpass 220 --out bajo_limpio

# 4) loop exacto de 8 compases a 110 bpm, arrancando en el segundo 32.5
./scripts/loop.sh "output/Down by the Seaside/htdemucs/base_ritmica.wav" 110 8 --start 32.5

# 5) TODO junto, en un comando
./scripts/procesar.sh "Down by the Seaside.mp3" htdemucs --bpm 110 --start 32.5 --prefijo down_seaside
```

Los resultados quedan **organizados por canción y contexto** (`output/<cancion>/<modelo>/` para
mezclas y filtros, `output/<cancion>/loops/` para loops). Para escuchar cualquiera:
`ffplay "output/Down by the Seaside/htdemucs/base_ritmica.wav"`


---

## 4. Los scripts, uno por uno

### `separar.sh` — separa en stems

```bash
./scripts/separar.sh <archivo_audio> [modelo] [opciones]
```

| Opción / variable | Qué hace |
|---|---|
| `[modelo]` | `htdemucs` (default), `htdemucs_ft`, `htdemucs_6s`, `mdx_extra` |
| `-f, --forzar` | Sobrescribe una separación existente sin preguntar |
| `DEMUCS_ARGS="..."` | Args extra para demucs (ej: `--clip-mode clamp`, `--mp3`) |
| `OMP_NUM_THREADS` | Hilos de CPU (por defecto: todos los núcleos) |

Acepta la ruta completa, una ruta relativa a la raíz del proyecto, o **solo el
nombre** del archivo (lo busca dentro de `mp3/`). Deja un log por corrida en
`output/logs/`.

```bash
./scripts/separar.sh "Down by the Seaside.mp3"
./scripts/separar.sh "Down by the Seaside.mp3" htdemucs_6s
DEMUCS_ARGS="--clip-mode clamp" ./scripts/separar.sh tema.mp3 htdemucs_ft
```

### `mezclar.sh` — suma stems con volúmenes controlados

```bash
./scripts/mezclar.sh <carpeta_stems> <stem1> <stem2> ... --out <nombre>
```

Usa `amix` con **`normalize=0`** a propósito: no reescala nada, así se mantienen
las proporciones de volumen originales. Volúmenes individuales con `VOLS`:

```bash
./scripts/mezclar.sh "output/cancion/spleeter/htdemucs" drums bass --out base_ritmica
VOLS="drums=0.9,bass=0.7" ./scripts/mezclar.sh output/cancion/spleeter/htdemucs drums bass --out base
./scripts/mezclar.sh output/cancion/spleeter/htdemucs_6s drums bass other guitar --out banda
```

**Dónde escribe:** `output/<cancion>/<modelo>/<nombre>.wav`, deduciendo canción y modelo de la
carpeta de stems (`output/Down by the Seaside/spleeter/htdemucs` → `output/Down by the Seaside/htdemucs/`).
Con `--out-dir <ruta>` se fuerza otro destino.

> ⚠️ Con `normalize=0` la suma puede **saturar**. Si escuchás distorsión, bajá los
> niveles con `VOLS` (ej: `drums=0.8,bass=0.7`). El script te lo recuerda al
> terminar y muestra el volumen medio (dB) de la mezcla.

### `limpiar.sh` — filtros de frecuencia

```bash
./scripts/limpiar.sh <archivo_wav> <lowpass|highpass|bandpass> <frecuencia> [opciones]
```

| Opción | Default | Para qué |
|---|---|---|
| `--out <nombre>` | `<archivo>_<tipo>_<freq>` | Nombre de salida |
| `--out-dir <ruta>` | (deducida) | Fuerza la carpeta de destino |
| `--polos <1\|2>` | `2` | Pendiente del filtro (2 polos = 12 dB/oct) |
| `--ancho <valor>` | `0.707` | Ancho de la transición |
| `--tipo-ancho <q\|h\|o>` | `q` | Unidad del ancho (Q, Hz u octavas) |

```bash
./scripts/limpiar.sh output/cancion/spleeter/htdemucs/bass.wav lowpass 220 --out bass_limpio
./scripts/limpiar.sh output/cancion/spleeter/htdemucs/vocals.wav highpass 120
./scripts/limpiar.sh output/cancion/spleeter/htdemucs/drums.wav bandpass 8000 --tipo-ancho o --ancho 1
```

Nota: en `bandpass` la `frecuencia` es el **centro** de la banda, y no acepta
`--polos` (ffmpeg lo implementa como Butterworth de 2 polos fijo). El script
muestra el volumen medio antes y después, para confirmar que el filtro actuó.

**Dónde escribe:** `output/<cancion>/<modelo>/<nombre>.wav` si reconoce la ruta de entrada;
si la entrada es un archivo suelto, va a `output/_sueltos/` y te lo avisa.
Con `--out-dir <ruta>` se fuerza otro destino.

### `loop.sh` — loop matemáticamente exacto

```bash
./scripts/loop.sh <archivo_wav> <bpm> <compases> [--start <seg>] [--fade <ms>]
./scripts/loop.sh <archivo_wav> <compases> [opciones]      ← BPM detectado solo
```

Duración = `(60 / bpm) * 4 * compases` ← **asume compás de 4/4**.

**El BPM ahora es opcional.** Si lo omitís (o usás `--bpm <n>`), `loop.sh` lee el BPM que detectó el
Analista para esa canción en `output/<cancion>/analisis/<cancion>_tempo.txt` — el del **mix**, no el
del stem, porque en un stem puramente rítmico el pulso es ambiguo. Lo redondea al entero y te informa
de dónde salió:

```bash
# sin BPM: usa el detectado (Down by the Seaside = 91.85 → 92 bpm)
./scripts/loop.sh "output/Down by the Seaside/htdemucs/base_ritmica.wav" 8 --start 32.5
# Tempo: 92 bpm ← DETECTADO (exacto: 91.85 · tonalidad: C mayor)  → 8 compases = 20.869568 s

# a mano, como siempre
./scripts/loop.sh "output/Down by the Seaside/htdemucs/base_ritmica.wav" 110 8 --start 32.5 --fade 5
# 110 bpm, 8 compases = 17.454560 s = 769.091 muestras a 44.1 kHz

# forzar un BPM puntual
./scripts/loop.sh "output/Down by the Seaside/htdemucs/base_ritmica.wav" 8 --bpm 92.5
```

⚠️ Si el BPM detectado cae **fuera de 75-170 bpm**, el script avisa de que puede ser la mitad o el
doble del real (te muestra los dos valores) y **no lo corrige solo**: lo forzás con `--bpm <n>`.
Si la canción todavía no tiene análisis, aborta indicándote el comando exacto
(`./scripts/analizar.sh "<cancion>.mp3"`).

**El inicio se ajusta solo al tiempo más cercano.** Si el `--start` no cae en un pulso, el loop
arrancaría a mitad de tiempo y sonaría "tropezado" al repetir. El script lo mueve al beat más
cercano (leyendo los tiempos que guardó el Analista en `<cancion>_tempo.json`) y te lo informa:

```bash
./scripts/loop.sh "output/Down by the Seaside/htdemucs/base_ritmica.wav" 8 --start 32.5
#   Desde     : 32.4151 s  hasta 53.284668 s   ← ajustado a la grilla desde 32.5 s (-84.9 ms)
```

⚠️ **El audio no se modifica**: solo cambia *dónde* corta. Verificado comparando el md5 del PCM
decodificado del loop contra un corte directo con `ffmpeg`: son **idénticos**. Como no hay
estiramiento, el loop conserva **la tonalidad y el tempo originales del disco**.
Si el tiempo más cercano queda fuera de la grilla (por ejemplo en un intro sin pulsos) no lo mueve
y te avisa; con `--sin-cuantizar` cortás exacto en el `--start` que pediste.

Verificación real de una corrida: esperado `17.454560 s`, obtenido `17.454558 s`
→ **diferencia 0.0 ms**: corte sample-perfecto. Usá `--fade 5` si notás un click
al loopear. Si el loop se pasaría del final del archivo, el script aborta y te
informa la posición máxima permitida.

**Dónde escribe:** `output/<cancion>/loops/<nombre>.wav`, deduciendo la canción de la ruta del
archivo de entrada; si no puede deducirla, va a `output/_sueltos/loops/` y te lo avisa.
Con `--out-dir <ruta>` se fuerza otro destino.

### `procesar.sh` — el flujo completo

```bash
./scripts/procesar.sh <archivo_audio> [modelo] [--bpm N] [--compases N] [--start S] [--prefijo TXT] [--re-separar] [-f]
```

Hace los 4 pasos: **separar → base rítmica (drums+bass) → bajo con lowpass 220 →
loop (solo si pasás `--bpm`)** y al final imprime un resumen con tamaños y
duraciones. Si los stems ya existen, los **reutiliza** (no repite los minutos de
Demucs) salvo que uses `--re-separar`.

**Dónde escribe:** `output/<cancion>/<modelo>/` (base rítmica y bajo filtrado) y
`output/<cancion>/loops/` (el loop), usando la misma estructura que los demás scripts.

```bash
./scripts/procesar.sh "Down by the Seaside.mp3"
./scripts/procesar.sh "Down by the Seaside.mp3" htdemucs --bpm 110 --start 32.5 --prefijo down_seaside
./scripts/procesar.sh tema.mp3 htdemucs_6s --bpm 128 --compases 16
```

### `analizar.sh` — acordes, BPM y tonalidad (rol Analista)

```bash
./scripts/analizar.sh <archivo_audio|carpeta_stems> [--stems] [--sin-tempo] [--out <nombre>] [--out-dir <ruta>]
```

Extrae la **secuencia de acordes** (Chordino) y el **BPM + la tonalidad** (librosa), y escribe
**cinco archivos**:

| Archivo | Contenido |
|---|---|
| `<nombre>_acordes.txt` | `timestamp_segundos acorde`, una línea por segmento (ej: `1.022 F`) |
| `<nombre>_acordes.json` | los mismos datos + metadatos (herramienta, fecha, total de segmentos) |
| `<nombre>_acordes.html` | informe para el navegador: **diagramas de acorde en SVG**, línea de tiempo proporcional, tabla de cambios y las **métricas de BPM/tonalidad** (autocontenido, sin internet) |
| `<nombre>_tempo.txt` | resumen `<clave> <valor>`: `bpm`, `bpm_refinado`, `beats`, `tonalidad`, `confianza`, `ambigua` |
| `<nombre>_tempo.json` | lo mismo + los **5 candidatos de tonalidad** con su puntaje, el croma por nota y **todos los tiempos de beat** (útil para el Looper) |

| Opción | Para qué |
|---|---|
| `--stems` | Analiza **cada stem** `.wav` de la carpeta por separado |
| `--sin-html` | No genera el `.html` (solo `.txt` y `.json`) |
| `--sin-tempo` | No calcula BPM ni tonalidad (solo acordes) |
| `--tempo-rapido` | Calcula el BPM sin el refinamiento por peine (más rápido, menos preciso) |
| `--out <nombre>` | Nombre base de salida (se le agrega `_acordes`) |
| `--out-dir <ruta>` | Fuerza la carpeta de destino |
| `-f, --forzar` | Sobrescribe sin preguntar |

**Dónde escribe:** `output/<cancion>/analisis/` (o `output/_sueltos/analisis/` si no puede deducir
la canción). Acepta el **nombre suelto** del archivo (lo busca en `mp3/` y subcarpetas).

```bash
# canción completa (por nombre; tarda ~5 s por canción de 5 min)
./scripts/analizar.sh "Down by the Seaside.mp3"

# solo un instrumento
./scripts/analizar.sh "output/Boogie with Stu/spleeter/htdemucs_6s/bass.wav" --out bajo

# todos los stems, uno por uno
./scripts/analizar.sh "output/Boogie with Stu/spleeter/htdemucs_6s" --stems
```

Herramientas: **chord-extractor 0.1.3** (plugin **Chordino** `nnls-chroma`) para los acordes y
**librosa** para el **BPM y la tonalidad**, ambas instaladas en `venv/`. `N` en la salida significa
"sin acorde detectado" (silencio/percusión).

**Precisión del BPM y la tonalidad** (medido contra [songbpm.com](https://songbpm.com) y la
secuencia de acordes de cada tema):

| Canción | BPM detectado | BPM real | Tonalidad detectada | Tonalidad real |
|---|---|---|---|---|
| Down by the Seaside | 91.85 | 92 | C mayor | C mayor ✅ |
| Boogie with Stu | 132.11 | 133 | A mayor | A mayor ✅ |

- El **BPM** se calcula con `beat_track` y se **refina con una búsqueda de peine** sobre todo el
  audio (`--tempo-rapido` lo saltea). Error típico observado: **< 1 %**.
- La **tonalidad** sale de correlacionar el croma con los 24 perfiles de **Krumhansl-Kessler**.
  Es **orientativa**: `_tempo.txt` trae `confianza` y `ambigua`, y el `.json` los 5 candidatos.
- ⚠️ **Analizá el tema completo**: en stems de batería+bajo el croma se sesga hacia el bajo y la
  tonalidad sale mal (en un stem rítmico los acordes tampoco tienen sentido musical).

---

## 5. Los modelos de Demucs

| Modelo | Pistas | Qué esperar |
|---|---|---|
| **`htdemucs`** (default) | 4: drums, bass, other, vocals | El mejor equilibrio. Es el que usá para empezar |
| `htdemucs_ft` | 4 (las mismas) | Fine-tuned (4 modelos en vez de 1): mejor calidad, sobre todo en voces, pero **~4× más lento** |
| `htdemucs_6s` | 6: + guitar, piano | Pistas extra **experimentales** (ver sección 7) |
| `mdx_extra` | 4 | Otra familia de modelos (MDX). Útil como segunda opinión; más lento |

**Tiempos medidos en este equipo** (8 núcleos, sin GPU, `htdemucs`): un clip de
**30 s tardó 27 s** de proceso → más o menos **1× el tiempo real**. Para un tema de
5:15 (315 s) estimá **4–6 minutos**; con `htdemucs_ft` (4× más lento), **15–25
minutos**. Por eso `procesar.sh` reutiliza los stems si ya existen.

**Espacio en disco** (medido): cada stem WAV de un tema de 5 min pesa **~54 MB**,
así que 4 pistas ≈ **215 MB** y 6 pistas ≈ **325 MB** por canción.

---

## 6. `clip-mode`: por qué afecta los volúmenes

Cuando la suma de los stems reconstruye un pico por encima de 1.0, Demucs tiene
que decidir qué hacer. Eso cambia los niveles **relativos**:

| `--clip-mode` | Qué hace | Efecto |
|---|---|---|
| `rescale` (**default**) | Baja el volumen de **todos** los stems por igual para evitar saturación | Nunca distorsiona, pero **altera las proporciones** entre pistas (todo queda más bajo) |
| `clamp` | Recorta (hard clipping) solo lo que se pasa de 0 dB | **Preserva mejor las proporciones** originales, a costa de posible distorsión audible en los picos |
| `none` | No toca nada | Puede saturar si la señal es fuerte |

Para **practicar o mezclar** (donde te importan los niveles relativos entre
batería y bajo), probá `clamp`:

```bash
DEMUCS_ARGS="--clip-mode clamp" ./scripts/separar.sh tema.mp3 htdemucs
DEMUCS_ARGS="--int24" ./scripts/separar.sh tema.mp3 htdemucs     # WAV de 24 bits (más headroom)
```

Ojo: los archivos ya separados con `rescale` **no** se pueden "arreglar" después
(el daño es de nivel, no de formato) → si vas a comparar, re-separá con
`--re-separar`.

---

## 7. Limitación del modelo de 6 pistas (guitarra)

`htdemucs_6s` agrega `guitar.wav` y `piano.wav`, pero **es un modelo experimental**:
la guitarra sale aceptable y el piano suele tener más artefactos (sangrado de
otros instrumentos). Para guitarra, dos trucos útiles:

```bash
# Solo guitarra + todo lo demás (binario)
DEMUCS_ARGS="--two-stems=guitar" ./scripts/separar.sh tema.mp3 htdemucs_6s

# Solo los stems que te interesan (ahorra tiempo y disco)
DEMUCS_ARGS="--stems guitar" ./scripts/separar.sh tema.mp3 htdemucs_6s
```

⚠️ Con `--two-stems` la salida tiene nombres distintos (`guitar.wav` y
`no_guitar.wav`), y `procesar.sh` **no** sirve para ese caso: necesita
`drums.wav` y `bass.wav` (te avisa con un error claro si faltan).

---

## 8. HF_TOKEN (warning de Hugging Face Hub)

Demucs 4.1 **descarga los modelos desde Hugging Face Hub** (los cachea en
`~/.cache/huggingface/hub`, acá quedaron 133 MB). Si no hay token, aparece:

```
Warning: You are sending unauthenticated requests to the HF Hub.
Please set a HF_TOKEN to enable higher rate limits and faster downloads.
```

**No es un error**: la separación funciona igual. Si querés silenciarlo y tener
descargas más rápidas / sin límite de rate:

```bash
# 1) creá un token en https://huggingface.co/settings/tokens (rol: read)
# 2) exportalo en la sesión actual
export HF_TOKEN="hf_tu_token_aca"

# 3) o dejalo permanente en tu shell
echo 'export HF_TOKEN="hf_tu_token_aca"' >> ~/.bashrc && source ~/.bashrc

# 4) alternativa persistente desde el venv (guardado en ~/.cache/huggingface/token)
source venv/bin/activate && hf auth login
```

Los scripts **no** hardcodean ningún token: leen la variable de entorno de tu
sistema, y al terminar `separar.sh` te avisa si detectó ese warning.

---

## 9. Notas técnicas (decisiones de diseño)

- **`_comun.sh`**: utilidades compartidas (rutas, colores, activación del venv,
  validaciones, `ffprobe`/`volumedetect`). No se ejecuta solo: se importa con
  `source`. Lo usan los 5 scripts, así no hay 40 líneas duplicadas en cada uno.
- **El venv se activa dentro de cada script**: si no existe, fallan con las
  instrucciones para crearlo en vez de tirar un error críptico.
- **`amix` con `normalize=0`**: ffmpeg por defecto divide cada entrada por la
  cantidad de entradas (`normalize=1`), lo que **bajaría el volumen** de cada
  stem y falsearía la mezcla. Con `normalize=0` se suman tal cual.
- **`-ss` antes de `-i`** en `loop.sh`: búsqueda rápida + `accurate_seek`
  (activado por defecto al transcodificar) → corte ajustado al sample exacto
  (medido: 0.0 ms de error).
- **`export LC_NUMERIC=C`** en `_comun.sh`: con locale `es_*` los decimales se
  escriben con coma y `awk` rompe las comparaciones (nos pasó: rechazaba un loop
  válido). Además hay un helper `num()` que convierte `17,45` → `17.45`.
- **`OMP_NUM_THREADS=$(nproc)`**: torch arranca con 4 hilos por defecto en este
  equipo (8 núcleos disponibles) → se le da todo lo que hay.
- **Organización de `output/`**: los scripts deducen `<cancion>` y `<modelo>` desde la ruta de
  entrada con el helper `deducir_contexto()` de `_comun.sh` (reconoce `output/<cancion>/spleeter/<modelo>/`
  y `output/<cancion>/<contexto>/`). Si no puede deducirlo, escribe en `output/_sueltos/` y avisa.
  `--out-dir <ruta>` fuerza el destino.
- **Caso especial de `analizar.sh`**: si el audio viene de `mp3/`, la canción se deduce del
  **nombre del archivo** (los demás scripts usan `deducir_contexto()`, que solo entiende
  `output/`; y `separated/<modelo>/<cancion>/` por compatibilidad con datos viejos).
- **Instalación de chord-extractor (rol Analista)**: su metadata declara `Requires-Python: <3.12`,
  así que en Python 3.12 hay que forzar el pin, y `vamp` necesita numpy en el entorno de build:
  ```bash
  ./venv/bin/pip install --ignore-requires-python --no-build-isolation chord-extractor
  ```
  Verificado que **no baja `numpy` ni toca `torch`/`demucs`** (snapshot previo del venv en
  `freeze_antes_chordextractor.txt`). El plugin Chordino viene compilado **dentro** del paquete
  (`chord_extractor/_lib/nnls-chroma.so`) y el Vamp SDK viene **dentro** del sdist de `vamp`,
  por lo que no hizo falta instalar nada por apt ni usar sudo.
- **Informe HTML de acordes** (`acordes_html.py`): se genera con **Python puro** (sin librerías
  externas ni CDN). Los diagramas son **SVG dibujados por código** y el HTML es **autocontenido**,
  así que se abre sin internet y se puede imprimir a PDF directamente. Las digitaciones salen de una
  tabla interna para afinación estándar (EADGBE) con **69 voicings**; si el acorde viene con bemoles
  (`Ab`, `Gb`) se resuelve por **equivalente enarmónico** (`G#`, `F#`), porque Chordino los entrega
  con bemol y la tabla está escrita con sostenido. Si un acorde no está en la tabla, la tarjeta
  muestra el nombre y las notas que lo componen. La tabla se verifica con
  `./scripts/validar_digitaciones.py`: deriva las notas de cada cifrado y las compara con la
  fórmula del acorde (así se detectan voicings mal escritos al agregarlos). El informe incluye
  resumen, grilla de diagramas,
  **línea de tiempo proporcional** (cada acorde con el ancho de su duración real), tabla de cambios
  y un pie que explica el significado de `N`.
- **Logs**: cada separación deja un log en `output/logs/separar_<fecha>_<tema>.log`.
- **No sobrescribir sin avisar**: si el destino ya existe, pregunta `[s/N]`. En
  modo no interactivo (scripts, cron) **aborta** y te dice que uses `--forzar`.
- **Solo lectura**: los scripts nunca escriben en `mp3/` ni en `venv/`.

---

## 10. Problemas frecuentes

| Síntoma | Causa / solución |
|---|---|
| `No existe el entorno virtual en .../venv` | El venv no está: `cd ~/proyectos/spleeter && python3 -m venv venv && source venv/bin/activate && pip install demucs` |
| `Falta el comando 'ffmpeg'` | `sudo apt install ffmpeg` |
| `Modelo inválido: ...` | Solo se aceptan: `htdemucs htdemucs_ft htdemucs_6s mdx_extra` |
| Tarda muchísimo | Normal en CPU: ~1× el tiempo real. Reutilizá stems (por defecto) y evitá `htdemucs_ft` si no lo necesitás |
| `No encuentro bass.wav / drums.wav` | Separaste con `--two-stems` (salida `x.wav` y `no_x.wav`). Re-separá con el modelo completo |
| La mezcla satura/distorsiona | Es esperable con `normalize=0`: bajá niveles con `VOLS="drums=0.8,bass=0.7"` |
| El loop tiene un click | Agregá `--fade 5` (5 ms de fade in/out) |
| El loop "no calza" al repetir | El BPM real del tema no es exacto (los temas en vivo varían). Probá otro BPM o mové `--start` unos ms |
| El bass filtrado suena raro | `lowpass 220` a 2 polos es 12 dB/oct: probá `--polos 1` (más suave) u otra frecuencia |
| Warning de HF Hub | Inofensivo, ver sección 8 |
| No me deja sobrescribir en un script automático | Agregá `--forzar` (o `-f`) |

---

## 11. Roles de trabajo

El proyecto tiene un archivo hermano, **[`AGENTES.md`](AGENTES.md)**, que define **4 roles de trabajo**
pensados para invocarse **en lenguaje natural** desde el chat (sin escribir el comando):

| Rol | Script | Qué hace |
|---|---|---|
| **1. Separador** | `scripts/separar.sh` | Separa la canción en stems (4 pistas, 6 pistas, stems sueltos o binario) |
| **2. Mezclador** | `scripts/mezclar.sh` | Combina stems y ajusta volúmenes por pista (`VOLS`, en factor o dB) |
| **3. Masterizador** | `scripts/limpiar.sh` | Filtra frecuencias: `lowpass`, `highpass`, `bandpass` |
| **4. Looper** | `scripts/loop.sh` | Extrae loops exactos: N compases a un BPM, desde un segundo dado |

### Cómo se usa

Decile a Cline algo como:

- *"Actuá como **Separador** y separá «Down by the Seaside.mp3» en 6 pistas."*
- *"Como **Mezclador**, armame la base rítmica con la batería +3 dB."*
- *"Ponete el sombrero de **Masterizador** y limpiame el bajo con lowpass 220."*
- *"Rol **Looper**: 8 compases a 110 BPM desde el segundo 32.5."*

Cline entonces: **lee `AGENTES.md`** para recordar capacidades y límites del rol → traduce el pedido a
parámetros → muestra el **comando exacto** → lo ejecuta → reporta ruta, tamaño, duración y warnings.

`AGENTES.md` incluye, para cada rol: descripción de una línea, script que usa, **capacidades concretas**,
**frases que reconoce**, **límites** (lo que NO hace) y **comandos equivalentes**.
También trae la tabla de **pendientes/TODOs** (normalización de loudness, compresión/reverb,
`bandpass` por rango, detección automática de BPM, time-stretch, nuevos roles *Analista* y *Grabador*)
y el **flujo típico**: Separador → Mezclador → Masterizador → Looper.

> 📌 **Regla de mantenimiento:** si agregás capacidades nuevas a los scripts, actualizá `AGENTES.md`
> en la misma pasada, para que los roles sigan describiendo solo lo que de verdad se puede hacer.
