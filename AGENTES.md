# 🤖 AGENTES.md — Roles de trabajo del proyecto spleeter

Este archivo define **4 roles** con los que se puede trabajar el proyecto invocándolos
en lenguaje natural desde el chat. Cada rol es, en la práctica, una **envoltura de los
scripts existentes**: los roles describen *qué se puede pedir*, y los scripts definen
*qué se puede ejecutar realmente*.

> Regla de oro: **si un pedido no se puede mapear a uno de estos scripts, el rol no lo
> hace** (ver la lista de "Límites" de cada rol y la sección *Pendientes* al final).

---

## 🗂️ Convenciones del proyecto

Resumen de dónde vive cada cosa (así se puede pedir un archivo **sin escribir la ruta completa**):

| Qué | Dónde |
|---|---|
| **Audio fuente** (entrada) | `mp3/` — incluidas sus subcarpetas por canción (ej: `mp3/Down by the Seaside/`) |
| **Stems** (Demucs) | `output/<cancion>/spleeter/<modelo>/` (`separated/` es solo el staging temporal) |
| **Mezclas, filtros y loops** | `output/<cancion>/<modelo>/`, `output/<cancion>/loops/` y `output/<cancion>/analisis/` (o `output/_sueltos/` si no se deduce la canción) · `output/logs/` es global |
| **Scripts** | `scripts/` — siempre se invocan como `./scripts/<nombre>.sh` desde la raíz del proyecto |

- Si se nombra un archivo de audio **sin ruta**, se asume **`mp3/`** (y se busca también en sus subcarpetas).
- Los nombres con espacios van **siempre entre comillas dobles** (`"Down by the Seaside.mp3"`).
- ⚙️ **Las reglas completas de trabajo** —confirmar antes de ejecutar, no tocar `venv/`, no borrar sin permiso,
  idioma y formatos soportados— están en **[`.clinerules`](.clinerules)** (raíz del proyecto).
  Este archivo (`AGENTES.md`) describe los **roles** y sus límites; `.clinerules` describe las **reglas de operación**.

---

## 📋 Tabla resumen

| # | Rol | Para qué sirve (una línea) | Script que usa | Salida |
|---|---|---|---|---|
| 1 | **Separador** | Convierte una canción en pistas (stems) independientes | `scripts/separar.sh` | `output/<cancion>/spleeter/<modelo>/` |
| 2 | **Mezclador** | Combina pistas y ajusta sus volúmenes relativos | `scripts/mezclar.sh` | `output/<cancion>/<modelo>/<nombre>.wav` |
| 3 | **Masterizador** | Filtra frecuencias para limpiar/oscurecer/aclarar una pista | `scripts/limpiar.sh` | `output/<cancion>/<modelo>/<nombre>.wav` (o `output/_sueltos/`) |
| 4 | **Looper** | Extrae un loop exacto (N compases a un BPM dado) | `scripts/loop.sh` | `output/<cancion>/loops/<nombre>.wav` |
| 5 | **Analista** | Detecta acordes (con timestamps), **BPM y tonalidad** de un audio | `scripts/analizar.sh` | `output/<cancion>/analisis/<nombre>_acordes.{txt,json,html}` + `<nombre>_tempo.{txt,json}` |
| — | *(Maestro)* | Encadena los 4 roles de una sola vez | `scripts/procesar.sh` | `output/<cancion>/<modelo>/` + `output/<cancion>/loops/` |

---

## 🗣️ Cómo invocar un rol en Cline

**Forma de pedirlo** (ejemplos):

- *"Actuá como Separador y separá «Down by the Seaside.mp3» en 6 pistas."*
- *"Como Mezclador, armame la base rítmica de ese tema."*
- *"Ponete el sombrero de Masterizador y limpiame el bajo."*
- *"Rol Looper: 8 compases a 110 BPM desde el segundo 32."*

**Qué debe hacer Cline cuando recibe ese pedido** (protocolo):

1. **Leer este archivo** (`AGENTES.md`) para recordar el rol y sus capacidades.
2. **Confirmar el rol elegido** y traducir el pedido a parámetros concretos
   (archivo, modelo, stems, filtros, BPM, compases, nombre de salida).
3. **Si falta un dato imprescindible, preguntar** en vez de inventarlo
   (ej: el BPM del Looper, o qué stems quiere el Mezclador).
4. **Mostrar el comando exacto** que va a ejecutar, con todas las rutas entre comillas dobles.
5. **Ejecutarlo** y reportar: ruta de salida, tamaño, duración y cualquier warning.
6. **Nunca violar las reglas comunes:**

| Regla común a todos los roles | Detalle |
|---|---|
| No tocar `mp3/` ni `venv/` | Son solo lectura siempre |
| No borrar datos sin permiso | Si algo "sobra", avisar; nunca borrar por cuenta propia |
| No sobrescribir sin avisar | El pedido interactivo sale solo; en modo no interactivo hay que usar `--forzar` |
| Comillas dobles en rutas | Los nombres tienen espacios (`Down by the Seaside`) |
| El venv se activa solo | Cada script lo hace internamente; no hay que activarlo a mano |
| Avisar los tiempos | Demucs tarda **~1× el tiempo real** en CPU: un tema de 5 min ≈ 4–6 min |

---

## 🔄 Flujo típico

```
   canción (mp3/)
        │
        ▼
 ┌─────────────┐   output/<tema>/spleeter/htdemucs/ (drums, bass, other, vocals)
 │ 1 SEPARADOR │ ─────────────────────────────────────────────────────┐
 └─────────────┘                                                      │
                                      ┌─────────────┐                 │
                                      │ 2 MEZCLADOR │◄────────────────┘
                                      └─────────────┘  output/<cancion>/<modelo>/base_ritmica.wav
                                             │
                                             ▼
                                      ┌───────────────┐
                                      │ 3 MASTERIZADOR│  output/<cancion>/<modelo>/bajo_lowpass220.wav
                                      └───────────────┘
                                             │
                                             ▼
                                      ┌─────────────┐
                                      │ 4 LOOPER    │  output/<cancion>/loops/loop_8c_110bpm.wav
                                      └─────────────┘
                                             │
                                             ▼
                                   practicar / remixear / DAW
```

**Orden recomendado:** Separador → Mezclador → Masterizador → Looper.
Atajo: si querés los 4 pasos con parámetros por defecto, usá **`procesar.sh`**:

```bash
./scripts/procesar.sh "Down by the Seaside.mp3" htdemucs --bpm 110 --start 32.5 --prefijo down_seaside
```

---

# 1️⃣ Separador

**Descripción:** Convierte una canción en pistas (stems) independientes con Demucs.

**Script que usa:** `scripts/separar.sh`

**Modelos disponibles:**

| Modelo | Pistas | Cuándo usarlo |
|---|---|---|
| `htdemucs` (**default**) | 4: drums, bass, other, vocals | Empezar siempre por acá: mejor equilibrio calidad/tiempo |
| `htdemucs_ft` | 4 (mismas) | Fine-tuned con 4 modelos: mejor calidad (sobre todo voces), **~4× más lento** |
| `htdemucs_6s` | 6: + **guitar**, **piano** | Cuando necesitás guitarra o piano (experimental) |
| `mdx_extra` | 4 | Variante de la familia MDX, como "segunda opinión" |

**Capacidades concretas:**

- Separar en **4 pistas** (default) o en **6 pistas** (`htdemucs_6s`).
- Generar **solo stems específicos** (ahorra tiempo y disco): `DEMUCS_ARGS="--stems drums bass"`.
- Generar salida **binaria** (un stem vs el resto): `DEMUCS_ARGS="--two-stems=vocals"` → `vocals.wav` + `no_vocals.wav`.
- Elegir **clip-mode**: `rescale` (default, evita saturación bajando todo), `clamp` (preserva mejor las proporciones, puede distorsionar picos), `none`.
- Cambiar el formato de salida: `DEMUCS_ARGS="--int24"` (WAV 24 bits, más headroom) o `DEMUCS_ARGS="--mp3"`.
- Buscar el archivo por **nombre suelto** (lo resuelve dentro de `mp3/`) o por ruta.
- Dejar **log** en `output/logs/` y avisar si aparece el warning de Hugging Face (`HF_TOKEN`).
- Aceptar `-f/--forzar` para rehacer una separación existente.

**Frases que debe reconocer:**

- "separame en 4 pistas X" · "separá X en stems" · "descomponé X"
- "dame solo la guitarra de X" · "quiero únicamente batería y bajo de X" *(stems específicos)*
- "voz e instrumental de X" · "sacá la voz de X" · "X sin voz" *(binario)*
- "usá el modelo fine-tuned en X" · "con el modelo de 6 pistas" · "probá con mdx_extra"
- "preservá los volúmenes originales" *(→ `--clip-mode clamp`)*
- "volvé a separar X desde cero" *(→ `--forzar`)*

**Límites (NO hace):**

- ❌ No mezcla stems entre sí.
- ❌ No aplica filtros de frecuencia ni EQ.
- ❌ No corta loops ni cambia el tempo.
- ❌ No normaliza loudness ni ajusta volúmenes finales.
- ❌ No reorganiza ni borra archivos.

**Comandos equivalentes:**

```bash
# 4 pistas (default)
./scripts/separar.sh "Down by the Seaside.mp3"

# 6 pistas (con guitarra y piano)
./scripts/separar.sh "Down by the Seaside.mp3" htdemucs_6s

# fine-tuned, preservando proporciones de volumen
DEMUCS_ARGS="--clip-mode clamp" ./scripts/separar.sh "Down by the Seaside.mp3" htdemucs_ft

# solo guitarra
DEMUCS_ARGS="--stems guitar" ./scripts/separar.sh "Down by the Seaside.mp3" htdemucs_6s

# voz vs todo lo demás
DEMUCS_ARGS="--two-stems=vocals" ./scripts/separar.sh "Down by the Seaside.mp3" htdemucs
```

---

# 2️⃣ Mezclador

**Descripción:** Combina pistas (o un subconjunto) en un solo WAV con volúmenes relativos ajustables.

**Script que usa:** `scripts/mezclar.sh`

**Capacidades concretas:**

- Combinar **cualquier subconjunto** de stems: `drums bass vocals other guitar piano`.
- Sumar sin aplicar normalización automática (`amix` con **`normalize=0`**) → se preservan las
  proporciones originales entre pistas.
- Ajustar el **volumen de cada pista** con la variable `VOLS`:
  - **factor lineal**: `0.7` (más bajo), `1.0` (sin cambios), `1.2` (más alto)
  - **decibeles**: `3dB`, `-6dB` (verificado: ffmpeg acepta ambos)
  - se pueden **mezclar unidades** en el mismo pedido: `VOLS="drums=3dB,bass=0.7"`
- Crear "base rítmica" (drums+bass), "instrumental", "sin voz", "todo menos la guitarra", karaoke casero, etc.
- **Reportar niveles**: muestra el volumen medio (dB) del primer stem y de la mezcla → sirve para detectar saturación.
- **Dónde escribe:** `output/<cancion>/<modelo>/<nombre>.wav`, deduciendo canción y modelo de la carpeta de stems.
- Nombrar la salida con `--out`, forzar el destino con `--out-dir <ruta>` y aceptar `-f/--forzar`.

**Frases que debe reconocer:**

- "mezclame batería y bajo de X" · "uní drums y bass" · "armame la base rítmica"
- "base rítmica con batería +3" · "subí 2 dB la batería" · "bajá el bajo a 0.7"
- "sin voz de X" · "sacale la voz" · "dame el instrumental"
- "todo menos la guitarra" · "sin piano" · "todo el tema sin voz"
- "juntá las 6 pistas otra vez" *(para comparar contra el original)*

**Límites (NO hace):**

- ❌ No separa stems (necesita que ya existan en `output/<cancion>/spleeter/<modelo>/`).
- ❌ No filtra frecuencias, ni EQ, ni efectos (reverb/delay/compresión).
- ❌ No corta loops.
- ❌ No normaliza loudness final: si la suma satura, **hay que bajar `VOLS`** (el script te lo recuerda).
- ⚠️ No adivina nombres: los stems deben existir tal cual (`drums.wav`, `bass.wav`...). Si separaste
  con `--two-stems`, los archivos se llaman `X.wav` y `no_X.wav` y hay que pasar esos nombres.

**Comandos equivalentes:**

```bash
# base rítmica (batería + bajo, volúmenes originales)
#   -> output/Down by the Seaside/htdemucs/base_ritmica.wav
./scripts/mezclar.sh "output/Down by the Seaside/spleeter/htdemucs" drums bass --out base_ritmica

# base rítmica con la batería +3 dB y el bajo al 70 %
VOLS="drums=3dB,bass=0.7" ./scripts/mezclar.sh "output/Down by the Seaside/spleeter/htdemucs" drums bass --out base_ritmica_boost

# instrumental (sin voz)
./scripts/mezclar.sh "output/Down by the Seaside/spleeter/htdemucs" drums bass other --out instrumental

# sin guitarra (modelo de 6 pistas)
./scripts/mezclar.sh "output/Down by the Seaside/spleeter/htdemucs_6s" drums bass other vocals piano --out sin_guitarra
```

---

# 3️⃣ Masterizador

**Descripción:** Aplica filtros de frecuencia a una pista para limpiarla, oscurecerla o aclararla.

**Script que usa:** `scripts/limpiar.sh`

**Capacidades concretas:**

- Aplicar **3 tipos de filtro**: `lowpass`, `highpass`, `bandpass`.
- Controlar la **pendiente** con `--polos 1|2` (2 = 12 dB/oct, más agresivo).
- Controlar el **ancho/transición** con `--ancho` + `--tipo-ancho q|h|o` (Q-factor, Hz u octavas).
- **Limpiar bleed** (sangrado) entre stems: el caso típico es `lowpass 220` al bajo para sacarle
  la guitarra y el ruido agudo que se filtró en la separación.
- **Oscurecer** una pista (`lowpass`), **adelgazar** (`highpass`) o **aislar una banda** (`bandpass`).
- **Verificar el resultado**: informa el volumen medio (dB) antes y después con `volumedetect`.
- **Dónde escribe:** `output/<cancion>/<modelo>/<nombre>.wav` si reconoce la ruta de entrada;
  si la entrada es un archivo suelto, escribe en `output/_sueltos/` y lo avisa.
- Nombrar la salida con `--out`, forzar el destino con `--out-dir <ruta>` y aceptar `-f/--forzar`.

**Frases que debe reconocer:**

- "limpiá el bajo con lowpass 220" · "sacale los agudos al bajo" · "dejá solo el cuerpo del bajo"
- "sacale agudos a la batería" · "oscurecé la guitarra" · "sacale los graves a la voz"
- "highpass 120 a la voz" · "sacá el retumbe de X"
- "bandpass 8000 a la batería" · "quedate solo con los platillos"
- "filtro más suave" · "menos abrupto" *(→ `--polos 1` o `--ancho` más grande)*

**Límites (NO hace):**

- ❌ No aplica **compresión**, **reverb** ni **delay** *(pendiente futuro)*.
- ❌ No hace **EQ multibanda** ni curvas de ecualización.
- ❌ **No normaliza loudness** *(verificado: el script no usa `loudnorm`)* → **TODO / pendiente**.
- ❌ No separa, no mezcla y no corta loops.
- ⚠️ `bandpass` toma **una sola frecuencia: el centro** de la banda (no un rango). Para pedir
  "bandpass 200-5000" hay dos caminos:

```bash
# Opción A (una pasada): centro geométrico + ancho en octavas
#   centro = sqrt(200*5000) ≈ 1000 Hz   ·   relación 5000/200 = 25 → ~4.6 octavas
./scripts/limpiar.sh "output/Down by the Seaside/spleeter/htdemucs_6s/guitar.wav" \
  bandpass 1000 --tipo-ancho o --ancho 4.6 --out guitarra_200_5000

# Opción B (dos pasadas, más precisa): primero highpass 200, después lowpass 5000
./scripts/limpiar.sh "output/Down by the Seaside/spleeter/htdemucs_6s/guitar.wav" highpass 200 --out guitarra_hp200
./scripts/limpiar.sh "output/Down by the Seaside/htdemucs_6s/guitarra_hp200.wav" lowpass 5000 --out guitarra_200_5000
```

**Comandos equivalentes:**

```bash
# el caso estrella: bajo limpio
./scripts/limpiar.sh "output/Down by the Seaside/spleeter/htdemucs/bass.wav" lowpass 220 --out bass_limpio

# filtrar la voz: sacar el retumbe de graves
./scripts/limpiar.sh "output/Down by the Seaside/spleeter/htdemucs/vocals.wav" highpass 120 --out voz_sin_retumbe

# batería más oscura (menos platillos)
./scripts/limpiar.sh "output/Down by the Seaside/spleeter/htdemucs/drums.wav" lowpass 6000 --out bateria_oscura

# filtro suave de un polo (6 dB/oct en vez de 12)
./scripts/limpiar.sh "output/Down by the Seaside/spleeter/htdemucs/bass.wav" lowpass 300 --polos 1 --out bass_suave
```

---

# 4️⃣ Looper

**Descripción:** Extrae un loop de N compases a un BPM dado, con corte exacto al sample.

**Script que usa:** `scripts/loop.sh`

**Capacidades concretas:**

- Extraer un loop cuya duración es exactamente **`(60 / BPM) * 4 * compases`** (asume **4/4**).
- **Usar el BPM detectado automáticamente**: si omitís el `<bpm>`, lo lee de
  `output/<cancion>/analisis/<cancion>_tempo.txt` (el análisis del **mix**, que es el más confiable),
  lo **redondea** al entero más cercano e informa de dónde salió (exacto + tonalidad). También podés
  pasarlo con `--bpm <n>`.
- **Advertir sobre la octava**: si el BPM detectado cae fuera de **75-170 bpm**, avisa de que puede ser
  la mitad o el doble del real y muestra los dos valores… pero **no lo corrige solo** (el usuario decide
  con `--bpm`). Caso real: el stem de batería de *Boogie with Stu* da 66.56 cuando el tema es 133.21.
- Empezar en un **segundo específico** con `--start` (acepta decimales: `32.5`).
- Agregar **fade in/out** con `--fade <ms>` para evitar clicks al loopear.
- **Verificar el resultado**: informa duración esperada, real y la **diferencia en ms**
  (medido en las pruebas: `17.454560 s` esperado vs `17.454558 s` real → **0.0 ms**, corte sample-perfecto).
- **Abortar con mensaje claro** si el loop se saldría del final del archivo, indicando el `--start` máximo.
- **Dónde escribe:** `output/<cancion>/loops/<nombre>.wav`, deduciendo la canción de la ruta de entrada;
  si no puede, escribe en `output/_sueltos/loops/` y lo avisa.
- Nombrar la salida con `--out` (default: `<archivo>_loop_<n>c_<bpm>bpm`), forzar el destino con
  `--out-dir <ruta>` y aceptar `-f/--forzar`.

**Frases que debe reconocer:**

- "loop de 8 compases a 110 BPM" · "dame 8 compases a 110"
- "hacé un loop de 8 compases" · "sacame un loop de este tema" *(sin BPM: se detecta solo)*
- "loop de 4 compases desde el segundo 30" · "un loop que arranque en 32.5"
- "16 compases a 128" · "sacame un loop de un minuto" *(traducir: elegir BPM y compases equivalentes)*
- "que no tenga click" *(→ `--fade 5`)*
- "no me sale ningún loop de 8 compases a 90" *(→ interpretar el aviso de que se sale del archivo y proponer alternativas)*

**Límites (NO hace):**

- ❌ No separa, no mezcla y no filtra.
- ❌ **No ajusta el `--start` a la grilla de beats**: el BPM sí es automático, pero *dónde empieza*
  el loop lo elegís vos. Si el `--start` no cae en un tiempo, el loop arranca a mitad de compás
  (*pendiente*: usar los beats detectados del `_tempo.json` para sugerir el `--start` exacto).
- ❌ **No cambia el tempo del audio** (no hay time-stretch/warp): solo **recorta**. Si el BPM real del
  tema no es exactamente el indicado, el loop se va a desfasar al repetir.
- ⚠️ Asume **compás de 4/4**: para 3/4, 6/8 o 7/8 la fórmula no aplica *(pendiente)*.

**Comandos equivalentes:**

```bash
# 8 compases a 110 BPM desde el segundo 32.5 (= 17.454560 s exactos)
#   -> output/Down by the Seaside/loops/base_loop_8c.wav
./scripts/loop.sh "output/Down by the Seaside/htdemucs/base_ritmica.wav" 110 8 --start 32.5 --out base_loop_8c

# SIN BPM: lo detecta solo (Down by the Seaside = 91.85 -> 92 bpm) = 20.869568 s
./scripts/loop.sh "output/Down by the Seaside/htdemucs/base_ritmica.wav" 8 --start 32.5

# forzar un BPM puntual en vez del detectado
./scripts/loop.sh "output/Down by the Seaside/htdemucs/base_ritmica.wav" 8 --bpm 92.5

# con fade de 5 ms para que no haya click al loopear
./scripts/loop.sh "output/Down by the Seaside/htdemucs/base_ritmica.wav" 110 8 --start 32.5 --fade 5 --out base_loop_8c_fade

# 4 compases desde el segundo 30 (entre comillas: las rutas tienen espacios)
./scripts/loop.sh "output/Down by the Seaside/htdemucs/bass_limpio.wav" 96 4 --start 30 --out bajo_loop_4c
```

---

# 5️⃣ Analista

**Descripción:** Detecta la secuencia de acordes (con timestamps) usando chord-extractor / Chordino y, además, el **BPM y la tonalidad** con librosa.

**Script que usa:** `scripts/analizar.sh` (+ `scripts/analizar.py` para los acordes y `scripts/analizar_bpm.py` para BPM y tonalidad)

**Capacidades concretas:**

- Extraer la **secuencia de acordes** con su **timestamp** (el segundo exacto de cada cambio de acorde).
- Analizar un **archivo completo** (canción o stem) o **cada stem por separado** (`--stems`).
- Escribir **cinco archivos**: `_acordes.txt` (`timestamp acorde`, una línea por segmento),
  `_acordes.json` (los mismos datos + metadatos), `_acordes.html` (informe para abrir en el
  navegador con **diagramas de acorde en SVG**, línea de tiempo proporcional, tabla de cambios y
  las **métricas de BPM y tonalidad**; autocontenido, sin internet), `_tempo.txt` (resumen
  `clave valor`) y `_tempo.json` (candidatos de tonalidad, croma por nota y **todos los tiempos de
  beat**, que el Looper puede reutilizar).
- Detectar el **BPM** con `librosa.beat.beat_track` + **refinamiento por peine** sobre todo el audio
  (busca el tempo que mejor alinea los onsets de punta a punta), y la **tonalidad** correlacionando
  el croma con los 24 perfiles de **Krumhansl-Kessler**. Informa `confianza`, `ambigua` y los 5
  candidatos con su puntaje.
- `--sin-html` omite el informe, `--sin-tempo` saltea BPM y tonalidad, y `--tempo-rapido` calcula el
  BPM sin el refinamiento (más rápido).
- Resolver el audio por **nombre suelto** (lo busca en `mp3/` y subcarpetas) o por ruta.
- Destino automático: `output/<cancion>/analisis/`, con fallback a `output/_sueltos/analisis/`.
- Reportar: herramienta usada, cantidad de segmentos, primeros acordes y rutas de salida.
- `--out <nombre>` para nombrar la salida, `--out-dir <ruta>` para forzar destino, `-f/--forzar`.

**Frases que debe reconocer:**

- "sacame los acordes de X" · "¿qué acordes tiene X?" · "decime la progresión de X"
- "acordes de la guitarra (o del bajo / del piano) de X" *(→ analizar ese stem)*
- "analizá todos los stems de X" · "los acordes de cada instrumento de X" *(→ `--stems`)*
- "¿cuándo cambia de acorde?" *(→ leer los timestamps del `.txt`)*

**Límites (NO hace):**

- ❌ No separa, no mezcla y no filtra (eso es Separador / Mezclador / Masterizador).
- ❌ **No detecta la estructura** del tema (intro / verso / estribillo): pendiente.
- ❌ No transcribe melodías ni batería a MIDI.
- ❌ No cambia el tono ni el tempo (no hace transposición ni time-stretch).
- ⚠️ El **BPM** puede confundirse con el doble o la mitad en temas de pulso ambiguo: `_tempo.txt`
  lo avisa con `posible_octava` y trae `bpm_mitad` y `bpm_doble`.
- ⚠️ La **tonalidad** es orientativa (heurística, no análisis armónico): en temas con poca armonía
  sale `ambigua si`. En stems puramente rítmicos (batería) no tiene sentido.
- ⚠️ Analizá **el tema completo** cuando te interese la tonalidad: en un stem de bajo el croma se
  sesga hacia el bajo y la tonalidad sale mal.
- ⚠️ Chordino asume afinación estándar (A=440) y funciona mejor con material armónico.
- ⚠️ Devuelve `N` cuando no detecta acorde (silencio, ruido, percusión, comienzo del tema).

**Comandos equivalentes:**

```bash
# Acordes de una canción (solo el nombre: lo busca en mp3/)
./scripts/analizar.sh "Down by the Seaside.mp3"
#   -> output/Down by the Seaside/analisis/Down by the Seaside_acordes.{txt,json}

# Acordes de un stem puntual
./scripts/analizar.sh "output/Boogie with Stu/spleeter/htdemucs_6s/bass.wav" --out bajo

# Todos los stems de una canción, uno por uno
./scripts/analizar.sh "output/Boogie with Stu/spleeter/htdemucs_6s" --stems

# Leer el BPM y la tonalidad ya calculados
grep -E '^(bpm|bpm_refinado|tonalidad_completa|confianza|ambigua) ' \
  "output/Down by the Seaside/analisis/Down by the Seaside_tempo.txt"

# Leer los acordes ya calculados
head -20 "output/Down by the Seaside/analisis/Down by the Seaside_acordes.txt"
```

---

## ⏳ Pendientes / futuras capacidades (TODOs)

| Rol | Falta | Cómo se haría |
|---|---|---|
| Masterizador | **Normalización de loudness** (LUFS) | filtro nuevo en `limpiar.sh` con `loudnorm=I=-14:TP=-1:LRA=11` o `dynaudnorm` |
| Masterizador | **Compresión / reverb / delay / EQ** | cadenas ffmpeg: `acompressor`, `aecho`, `equalizer` |
| Masterizador | **Rango real** en `bandpass` (ej. 200-5000) | agregar `--hasta <hz>` que combine `highpass` + `lowpass` en un solo pase |
| Looper | **Ajustar el `--start` a la grilla de beats** | ✅ el BPM ya es automático (`loop.sh` lo lee del `_tempo.txt`). Falta que `loop.sh` lea los beats de `<cancion>_tempo.json` y proponga/valide el `--start` exacto en vez de dejarlo "a ojo" |
| Looper | **Time-stretch / warp** al BPM objetivo | `atempo` (ffmpeg) o `rubberband` (mejor calidad) |
| Looper | **Compases ≠ 4/4** | parámetro `--tiempos-por-compas` (por defecto 4) |
| Analista | **Estructura** del tema (intro/verso/estribillo) | ✅ BPM y tonalidad ya están hechos (`scripts/analizar_bpm.py`, validado: <1 % de error en BPM y tonalidad correcta en las 2 canciones de prueba). Falta la estructura: segmentación por auto-similitud (`librosa.segment`) |
| Analista | Alternativa "todo en uno" (acordes + batería + voz a MIDI): **Omnizart** | evaluado y descartado por ahora: publica **solo sdist** (hay que compilar), arrastra **TensorFlow (~600 MB)** y libs de sistema (`vamp`, `pyfluidsynth`). Si se retoma, va en un venv aparte |
| Nuevo rol | **Grabador**: pasar stems a MIDI (batería, bajo, melodía) | `basic-pitch` (pip) o detección de onsets + clasificación |

> Cuando se implemente alguno de estos pendientes, **actualizar la sección del rol** en este archivo:
> el objetivo de `AGENTES.md` es describir únicamente **lo que realmente se puede hacer hoy**.
