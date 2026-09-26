# 📌 ESTADO Y PENDIENTES — spleeter

> **Archivo de continuidad.** Cline no tiene memoria entre sesiones: lo que "recuerda" es lo que
> está escrito acá. Para retomar, pedile:
> *"leé `~/proyectos/spleeter/PENDIENTES.md` y seguimos"*
> (o abrí la carpeta `~/proyectos/spleeter` como workspace, así se cargan `.clinerules` y `AGENTES.md` solos).

**Última actualización:** 25/Sep/2026 (noche) — **diagnóstico del entorno** (madrugada) + **requerimiento
de "recursos para improvisar"** y **diseño del panel de verificación de tonalidad** (noche). Único archivo
tocado hoy: este `PENDIENTES.md` (**sin commitear**).

> 📥 **Agregado el 25/Sep a la noche — NADA de esto está implementado todavía:**
> 1. **🎼 Recursos para improvisar** (escalas, grados, licks y voicings según tonalidad y género) → sección 🎼.
> 2. **🔎 Panel de verificación de tonalidad** (varias voces + AcousticBrainz como 2ª opinión) → misma sección 🎼.
> 3. **🖥️ Interfaz** → queda **recomendado: web local** (ver ⏳ punto 1; falta el OK del usuario).
> 4. **Hallazgo del día**: al croma se le va el **modo** (mayor/menor) — lo decide la **armonía** (ver 🎼).
> 5. **📱 Android (APK)** → pedido también el 25/Sep: **posible como cliente liviano** que envuelve la UI
>    web; el procesamiento (Demucs/Chordino) **queda en la PC** (ver ⏳ punto 6).

## 🎯 Para retomar mañana

Estado: `main` ↔ `origin/main` **al día** · **23 archivos versionados** · working tree **limpio** (el plan de
negocio es local y está en `.gitignore`). Retomá con *"leé `~/proyectos/spleeter/PENDIENTES.md` y seguimos"*.

**🧭 Premisa del proyecto (25/Sep):** *"Ambición sí, frustración 0. Que llegue donde llegue, que salga lo que
salga."* → **cero gasto hasta que una fase lo pida por criterio** · **una fase por vez y cada una termina en
algo mostrable** (demo, app publicada, un pago) · si una fase **no** da el criterio, **se corta y se anota**:
ese "no" es **información, no fracaso** (averiguarlo costó ~$0).

**Orden acordado el 25/Sep:**
1. **🧰 Entorno** → packs A→D de la sección 🧰 (arrancar por el **pack A**, que es el de riesgo nulo).
2. **🖥️ Interfaz** → **recomendado: web local** (ver ⏳ punto 1; falta el OK del usuario).
3. **🎼 Recursos para improvisar** (sección 🎼) → pedido nuevo del 25/Sep; se apoya en el rol Analista y
   en el **panel de tonalidad**, que es lo que hay que resolver primero.
4. Después, lo que ya venía: mejoras del HTML (**multi-stem**) y estructura del tema.
5. **📱 Android (APK)** → más adelante, como **cliente liviano** de la UI (ver ⏳ punto 6).

**Tarea rápida aparte (2 min), todavía pendiente:** el loop viejo
`output/Down by the Seaside/loops/base_loop_8c.wav` se
generó a **110 BPM** cuando el tema es **92**, así que son **6,7 compases, no 8** (se desfasa al
repetir). Hoy sale bien en un comando:
```bash
./scripts/loop.sh "output/Down by the Seaside/htdemucs/base_ritmica.wav" 8 --start 32.5
#   -> Tempo 92 bpm (detectado) | inicio 32.4151 s (ajustado desde 32.5, -85 ms)
```

---

## ✅ Hecho y verificado

- **Estructura consolidada por canción**: `output/<cancion>/{spleeter/<modelo>, <modelo>, loops, analisis}`
  (+ `output/_sueltos/` y `output/logs/`). `separated/` quedó como *staging temporal* de Demucs.
- **Scripts** (12): `separar.sh`, `mezclar.sh`, `limpiar.sh`, `loop.sh`, `procesar.sh`,
  `analizar.sh` + `analizar.py` + `analizar_bpm.py` + `acordes_html.py` + `_comun.sh`
  + `_beats.py` (busca el beat más cercano a un segundo; lo usa `loop.sh`)
  + `validar_digitaciones.py` (verificador de la tabla de voicings).
- **Roles documentados** en `AGENTES.md`: Separador, Mezclador, Masterizador, Looper, **Analista**.
- **Rol Analista operativo**: chord-extractor 0.1.3 (Chordino) → `.txt` + `.json` + `.html`
  (informe con **diagramas SVG**, línea de tiempo proporcional y tabla de cambios).
- **BPM y tonalidad (rol Analista COMPLETO)** — 24/Sep: nuevo `scripts/analizar_bpm.py` (librosa),
  integrado a `analizar.sh` (escribe `<nombre>_tempo.{txt,json}` y agrega las métricas al HTML).
  **Validado contra verdad externa** (songbpm.com + la secuencia de acordes del propio audio):
  `Down by the Seaside` → **91.85 BPM** (real 92) y **C mayor** ✅; `Boogie with Stu` → **132.11**
  (real 133) y **A mayor** ✅. Error de BPM **<1%** en ambos.
  ⚠️ Lecciones aprendidas: **(a)** el `hop_length` de 512 (default de librosa) da el BPM **bajo** en
  temas rápidos → hay que usar **256**; **(b)** la mediana de intervalos no alcanza → se agrega el
  **refinamiento por peine** (busca el tempo/fase que mejor alinea los onsets en TODO el audio);
  **(c)** en stems de batería+bajo la **tonalidad sale mal** (el croma se sesga hacia el bajo):
  analizar el **tema completo**; **(d)** songbpm/Spotify puede errar la tonalidad (decía E mayor
  para *Boogie with Stu*, que en realidad es A). Flags nuevos: `--sin-tempo`, `--tempo-rapido`.
- **Digitaciones de acordes ampliadas** — 24/Sep: la tabla de `acordes_html.py` pasó de **44 a 69**
  voicings, y se agregó **resolución de equivalentes enarmónicos**: el diccionario está escrito con
  sostenidos pero Chordino devuelve bemoles, así que `Ab` (= `G#`) **nunca** encontraba diagrama.
  También se agregaron las calidades **m7b5** y **dim7** a `CALIDADES` (antes caían al fallback de
  tríada mayor y describían mal las notas).
  **Validado con un verificador** que deriva las notas de cada cifrado pisado y las compara con la
  fórmula del acorde: **69/69 correctas, 0 errores**. Ese verificador quedó en el repo como
  `scripts/validar_digitaciones.py` (corrélo al agregar voicings). Cobertura sobre los análisis
  existentes: de 19 apariciones sin diagrama a **3** (**98.7 %**).
- **Canciones procesadas**:
  - `Down by the Seaside`: 4 stems (htdemucs) + 6 stems (htdemucs_6s) + loop + mezclas + análisis (84 segmentos)
  - `Boogie with Stu`: 6 stems (htdemucs_6s) + análisis por stem (6) + análisis de la mezcla (43 segmentos)
- **Docs**: `.clinerules` (140 líneas), `AGENTES.md` (463), `README.md` (532),
  `PENDIENTES.md` (173) + backups `.bak_pre_spleeter` de los 3
  (versión anterior al cambio de estructura).
- **Repo en GitHub** (24/Sep): `https://github.com/flacogabrielc/split_music` — **público**, rama `main`.
  **23 archivos / 576 KB** (scripts + docs) y 9 commits (hoy **10**). `venv/`, `mp3/`, `output/` y `separated/`
  quedaron en `.gitignore`. Remote por **SSH**. El repo nació con un `Initial commit` de GitHub
  (README placeholder de 2 líneas) y la divergencia se resolvió con **rebase** → historial lineal,
  **sin `--force`**. Verificado: se clona en otra PC por HTTPS **sin credenciales**.
- **`requirements.txt`**: 72 paquetes del venv + la receta de instalación escrita adentro
  (resuelve la trampa de `Requires-Python: <3.12` de chord-extractor).
- **Limpieza + decisiones cerradas** (24/Sep): se borraron los artefactos de prueba de `output/`
  (`prueba_30s/` + los `test_*.wav` y `prueba_30s_*.wav`: **~156 MB liberados**) y del repo
  (`git rm Readme.txt`, que era un volcado crudo de terminal; la versión corregida es
  `COMANDOS_MANUALES.txt` y git conserva el original en el historial). La sección 11 del `README`
  (que documentaba esos archivos) se eliminó y la 12 pasó a ser la 11.
  Decisiones cerradas **sin cambios**: los derivados siguen en `output/<cancion>/<modelo>/` (mantiene
  la trazabilidad de qué modelo produjo cada stem) y `separated/` sigue recreándose con `mkdir -p`.
- **Análisis de `output/` regenerados** (24/Sep): los **8 informes** (2 mixes + 6 stems) ahora tienen
  `_tempo.{txt,json}` y muestran BPM/tonalidad + los diagramas nuevos, **sin re-extraer acordes**.
  Dato real que vale anotar: en el stem de **batería** el BPM salió **66.56** (la mitad de 133.21) —
  es el caso típico de pulso ambiguo sin armonía; conviene mirar `bpm_doble` en el `_tempo.txt`.
- **Looper: BPM automático** (24/Sep): `loop.sh` acepta ahora 2 formas de llamada
  (`<archivo> <bpm> <compases>` y `<archivo> <compases>`) y usa el **BPM detectado** cuando no se lo
  pasan. Lee `output/<cancion>/analisis/<cancion>_tempo.txt` — el del **mix**, no el del stem, porque
  en un stem de batería el pulso sale a la mitad —, lo **redondea** al entero, informa el exacto y la
  tonalidad, y **avisa sin autocorregir** si cae fuera de 75-170 bpm (caso real: 66.56 → sugiere
  133.12). Nuevo flag `--bpm <n>` y errores claros (BPM pasado dos veces, falta de análisis, canción
  no deducible). **7 pruebas** cubriendo compatibilidad hacia atrás, modo automático, `--bpm` y los 3
  caminos de error.
- **Looper: el inicio se ajusta al tiempo, sin tocar el audio** (24/Sep): `loop.sh` mueve el `--start`
  al beat más cercano (nuevo `scripts/_beats.py`, helper interno que lee `<cancion>_tempo.json`) y lo
  informa en ms: `--start 32.5` → **32.4151** (−85 ms). `--sin-cuantizar` mantiene el corte exacto.
  Si el beat más cercano está fuera de la grilla (intro sin pulsos) no lo mueve y avisa el motivo.
  **El audio no se procesa**: verificado comparando el md5 del PCM decodificado del loop contra un
  corte directo de `ffmpeg` → **idénticos**. Se midió también que los cambios de acorde NO sirven para
  inferir el downbeat (máx. 31% de alineación) y que el tempo de la toma respira (92.3 a 95.7 BPM),
  así que no se promete "compás 1" ni se estira el audio.

## 🧰 Diagnóstico del ENTORNO (25/Sep) — pendientes nuevos

Medido, no copiado del doc: ese día se hizo **lectura + un benchmark en `/tmp`** (ya borrado), o sea que
**nada del proyecto se modificó**. Resumen: el entorno **funciona**, pero quedaron **9 cosas mejorables**
y **varias afirmaciones de los docs que hoy son falsas**.

| # | Problema verificado (con la evidencia medida) | Arreglo propuesto |
|---|---|---|
| **E1** | El workspace de VS Code apunta a `~/agent proyect` (**carpeta vacía**) y no a `~/proyectos/spleeter`: `.clinerules` y `AGENTES.md` **no se cargan solos** y la búsqueda de archivos del agente devuelve **0 resultados** | abrir la carpeta correcta + `.vscode/settings.json` con `files.exclude`/`search.exclude` de `venv/` y `output/` |
| **E2** | **3,2 GB de CUDA inutilizable**: `torch.cuda.is_available()=False` pero hay `torch 2.14.0+cu130` + 16 paquetes `nvidia-*` (`cu13` 1,7 GB, `cudnn` 922 MB, `nccl` 242 MB) = **54 %** de los 5,9 GB del `venv/` | recrear el `venv/` con el wheel CPU (`--index-url https://download.pytorch.org/whl/cpu`) → ~2,5 GB |
| **E3** | El locale `es_AR` rompe los comandos ad-hoc **en silencio**: `printf '1.5\n' \| awk '{print $1+1}'` da **2** (con `LC_ALL=C` da 2.5). Los scripts están a salvo (`_comun.sh:8`) | regla en `.clinerules`: todo `awk`/`bc`/`printf` numérico con prefijo `LC_ALL=C` |
| **E4** | **Ninguna prueba automatizada ni CI**: no existe `tests/` ni `.github/` y `pytest` no está instalado (las "7 pruebas" del Looper se corren a mano) | `scripts/smoke.sh` end-to-end con audio sintético (`ffmpeg -f lavfi` → sin copyright) |
| **E5** | El comando de instalación del README §2.1 **falla tal cual está**: `pip install -r requirements.txt` arrastra `chord-extractor==0.1.3` (`Requires-Python: <3.12`) | `./venv/bin/pip install --ignore-requires-python -r requirements.txt`, o partir el requirements en dos |
| **E6** | **Doc drift** (6 puntos): README §11 dice "**4 roles**" y `AGENTES.md` tiene **5** (falta el Analista); §11 lista el BPM automático como TODO (hecho el 24/Sep); §10 dice "~1× el tiempo real" y el log real da **2,27×**; §2.1 dice "torch CPU **sin CUDA**" (falso, ver E2); §2.1 dice 488 KB vs 576 KB; `analizar.sh:71-74` prefiere un `venv-analisis/` que no existe ni hace falta | pasada de "verdad de docs" |
| **E7** | Log de Demucs = **8 KB de barras de progreso** por canción (demucs 4.1.0 fuerza `progress=True` en `demucs/separate.py:129`: no hay flag para apagarlas) + **3 logs huérfanos** de los tests `prueba_30s` borrados el 24/Sep | filtrar los `\r` al escribir el log + borrar los huérfanos |
| **E8** | Warning de HF Hub + ida a la red **en cada corrida** aunque los modelos ya estén bajados (`~/.cache/huggingface/hub/models--adefossez--HTDemucs{,-6s}`, 133 MB, cargan en **<2 s**). Hoy solo se documenta `HF_TOKEN` (README §8) | documentar/soportar `HF_HUB_OFFLINE=1` |
| **E9** | Ruido en el repo: 3 `.bak_pre_spleeter` **trackeados** (68 KB; git ya los tiene en el historial) + `backup_codigo_docs_*.tar.gz` (56 KB) en la raíz → de 10 archivos en la raíz, 3 son backups | `git rm` de los `.bak` (⚠️ pedir OK antes, como manda `.clinerules`) |

### Verificado y OK (para NO volver a medirlo)

- **ABI sana**: `numpy 2.5.3` + `numba 0.67` + `librosa 1.0.0` → `njit` compila y `beat_track` ejecuta;
  `pip check` sin conflictos.
- **Modelos**: `htdemucs` y `htdemucs_6s` cargan de caché en **<2 s**; smoke completo del entorno **5,3 s**.
- **Hilos (lo medí antes de "optimizarlo")**: audio sintético de 30 s / 6 stems, 2 corridas por config →
  `OMP_NUM_THREADS=8` = 18,1 s y 19,3 s (media **18,7**) vs `=4` = 19,6 s y 20,6 s (media **20,1**).
  Con 4 núcleos/8 hilos, **8 hilos rinde ~7 % mejor**: la config actual (`_comun.sh` usa `nproc`) es la
  correcta y **no hay oversubscription que corregir**.
- `requirements.txt` **pinneado y sin drift** (72 `==` = 72 paquetes del venv). Demucs real:
  **2,27× tiempo real** (234 s de audio en 103 s).

### Packs de entorno (en este orden)

- **A — Higiene (30 min, riesgo nulo):** E1 + E3 + E6 + E7 (huérfanos) + E9 (con OK) + actualizar docs.
- **B — Venv liviano (15 min, riesgo bajo):** E2 (recupera **3,4 GB**); después re-verificar la cadena.
- **C — `scripts/smoke.sh` (40 min, riesgo nulo):** E4 — el que evita que un cambio rompa la cadena.
- **D — Robustez (20 min, riesgo nulo):** E5 + E7 (filtro del log) + E8.

⚠️ Lo que se toque del entorno se documenta en `README`/`.clinerules` en la misma pasada.

## 🎼 Recursos para improvisar + verificación de tonalidad (pedido 25/Sep)

**Requerimiento del usuario:** al detectar la tonalidad, darle **recursos para improvisar** — escalas,
patrones, licks y voicings para tocar arriba de la pista (pentatónicas mayor/menor, escala de blues, menor
natural/armónica/melódica, los 7 modos y los **acordes diatónicos por grado** con su diagrama de guitarra).
Ideal: **detectar el género** (*"esta canción es un blues"* → pentatónicas + blues + mixolidia + licks de
blues). Si el género no se puede detectar solo, **que lo declare el usuario**.

### Las 4 piezas y su dificultad (evaluado el 25/Sep)

| # | Pieza | Cómo se hace | Deps nuevas | Certeza |
|---|---|---|---|---|
| A | **Escalas, modos y grados** | Teoría pura sobre `tonica`+`modo` del `_tempo.json`; + acordes diatónicos por grado (I..VII) con su función | **0** | **Total** (aritmética de semitonos) |
| B | **Voicings** | Generarlos por algoritmo (12 tonalidades × familias × juegos de cuerdas) y **validarlos con `validar_digitaciones.py`** (hoy 69/69 OK) | **0** | **Total** (verificable) |
| C | **Patterns y licks** | Es **contenido**, no tecnología: biblioteca curada por género en JSON editable; se valida que cada nota caiga en la escala declarada | **0** | Alta (es curaduría: el oído decide) |
| D | **Género** | (1) **lo declara el usuario** [fuente de verdad] · (2) **heurística** con datos ya calculados (BPM, swing, vocabulario armónico, modo, stems), marcada *orientativo* · (3) clasificador real (MTG-Jamendo / CLAP) | 0 / 0 / **pesada** | Total / **Baja** / Alta |

- ⚠️ **Lo que NO se promete**: transcribir licks del audio (eso es transcripción; Omnizart ya se descartó por
  arrastrar TensorFlow ~600 MB) ni adivinar el género de un stem instrumental. Un clasificador real va
  **en contra del Pack B** (~300 MB–1 GB de pesos) → paso aparte y opcional.
- Todo se apoya en lo que ya existe: `_tempo.json` (`tonica`, `modo`, `confianza`, `ambigua` y **5
  candidatos**), `_acordes.txt` (la secuencia real) y `CALIDADES`/`NOTAS`/`BEMOLES`/`svg_diagrama()` de
  `acordes_html.py`. **Es una capa de solo lectura**: no hay que volver a pasar Demucs ni Chordino.

### ¿A quién le preguntamos la tonalidad? (medido el 25/Sep, consultas de red)

| Fuente | Estado verificado | ¿Trae tonalidad? |
|---|---|---|
| **AcousticBrainz** (MTG-UPF + MusicBrainz, motor Essentia) | ✅ **Anda** (HTTP 200). Gratis, **CC0**, **sin API key**; **dejó de recibir datos en 2022** | ✅ `tonal.key_key`+`key_scale`, `tonal.chords_key`+`chords_scale`, `rhythm.bpm` (+ género y mood) |
| GetSongBPM / songbpm.com | ❌ **403 de Cloudflare** (ni la doc se puede pedir desde un script) | (sí, pero inaccesible) |
| Spotify `/v1/audio-features` (daba `key`+`mode`) | ❌ **bloqueado para apps nuevas desde el 27/nov/2024** | — |
| MusicBrainz (la base) | ✅ pero **no guarda tonalidad** | ❌ |
| Tag `TKEY` de los mp3 | ❌ no lo traen (sí `genre=Rock` → pista gratis de género) | ❌ |
| Essentia / madmom / skey (local) | ❌ **sin wheel para Python 3.12** (essentia solo cp314; madmom abandonado en 2018) | — |
| Plugins de Vamp | ❌ el `venv/` solo trae Chordino (`nnls-chroma.so`) | ❌ |

**La prueba con las 2 canciones (y el hallazgo que cambia el diseño):**

| Voz | Down by the Seaside | Boogie with Stu |
|---|---|---|
| `chroma_cqt` / `stft` / `cens` + Krumhansl | C / C / C | Am / Am / A |
| Acordes (Chordino, ponderado por duración) | F (2º C; **termina en C**) | D (2º **A**, que dura **43,5 %**) |
| AcousticBrainz | F mayor / **C mayor** | **F menor / C menor** |

- **Down by the Seaside** → consenso **C mayor** ✅ (AcousticBrainz acierta su `chords_key` y erra su `key_key`).
- **Boogie with Stu** → **A mayor vs A menor** se decide por **0,002–0,007** en los cromas y por **0,0597**
  en el pipeline actual (umbral `ambigua` = 0,05 → **pasó raspando**); en cambio **los acordes lo zanjan
  ~4,7 a 1** (`A` 43,5 % de la duración vs `Am` 9,2 %). AcousticBrainz dice F menor/C menor: **no coincide
  con ninguna de las 4 voces locales**.
- ⚠️ **Lección**: la **tónica** se detecta bien; el **modo (mayor/menor)** es la parte frágil — y el modo es
  justo lo que define la escala (A mayor pentatónica = A B C# E F#; A menor = A C D E G).
- ⚠️ Los 3 cromas **no son voces independientes** (mismos perfiles de Krumhansl, solo cambia el croma):
  miden *estabilidad*, no confirman. La voz verdaderamente independiente son **los acordes**.

**Roles acordados (quién decide qué):**

| Qué | Voz que manda | Corrobora |
|---|---|---|
| Tónica | **voto de acordes** (raíz ponderada por duración) | los 2–3 cromas |
| Modo (mayor/menor) | **la tercera del acorde de tónica** (Chordino) | — |
| Estabilidad / confianza | acuerdo entre voces + `margen`/`ambigua` | — |
| 2ª opinión externa | **AcousticBrainz**, solo si **discrepa** | — |
| Última palabra | **el usuario** (oído / `--tonalidad` manual; la elección se guarda) | — |

- **Nunca corrige en silencio**: si una voz discrepa, se muestra como **"segunda opinión"** (pedido explícito).
- **Am vs C son relativas**: mismas 7 notas y **la pentatónica mayor de C = la menor de A** → para
  escalas/pentatónicas da igual; el modo lo desempatan los acordes.
- Implementación: **no hay `curl` en la máquina** → usar `urllib` de Python. Flag **apagado por defecto**
  (el pipeline sigue 100 % offline, coherente con E8/`HF_HUB_OFFLINE`), **cachear en `_tempo.json`** y
  emparejar por **MBID exacto** (hay **15** "Boogie with Stu" con 3 tonalidades distintas, y **2 de 3**
  "Down by the Seaside" dieron **404**). Si AcousticBrainz cierra algún día, el panel interno sigue
  andando → **no es dependencia dura**.

### Arquitectura y fases (propuesto, nada implementado todavía)

```
scripts/analizar_bpm.py      EDIT   + 2 cromas extra (stft/cens) y el voto de acordes → "panel" de tonalidad
scripts/recursos.py          NUEVO  motor de teoría: escalas, grados, diatónicos, relativas/paralelas
scripts/generos.json         NUEVO  biblioteca editable: género → escalas + licks + voicings
scripts/validar_recursos.py  NUEVO  valida que cada lick/voicing caiga en su escala declarada
scripts/acordes_html.py      EDIT   + svg_escala()/svg_pattern() + sección "Recursos para improvisar"
scripts/analizar.sh          EDIT   + --genero, --recursos, --verificar-clave
AGENTES.md / .clinerules     EDIT   rol nuevo (ej. *Coach* / *Improvisador*) o extensión del Analista
```

- **F1** panel de tonalidad + motor de escalas/grados + sección en el informe HTML · **F2** género declarado
  + heurística · **F3** biblioteca de licks/patterns · **F4** clasificador real (opcional y aparte) ·
  **F5** todo esto es **insumo natural de la interfaz gráfica**.
- **Decisiones abiertas**: qué expone primero, y si el panel de género/recursos vive en el informe HTML,
  en la UI, o en los dos.

## ⏳ Pendientes (orden acordado el 25/Sep)

**Primero va el 🧰 Entorno** (packs A→D de la sección de arriba).

1. **🖥️ Interfaz gráfica** — pedida el **25/Sep**. **RECOMENDADO el 25/Sep: WEB LOCAL** (falta el OK).
   - **Por qué web local** (`http.server` de la stdlib, o `Flask` dentro del `venv/` + navegador):
     **(a)** reusa `acordes_html.py` y los informes que ya existen → la UI es *extender* lo que ya hay;
     **(b)** los scripts ya son CLI con flags estables → el backend solo los invoca con `subprocess`
     y muestra el log en vivo (clave: Demucs tarda minutos y hay que ver el progreso);
     **(c)** **el navegador te da el reproductor gratis** (`<audio>`): comparar stems, loop A/B y el
     **"escuchar la escala sobre la pista"**, que es justo con lo que se desempata el modo por oído;
     **(d)** **cero dependencias nuevas** con la stdlib (Flask son ~6 paquetes chicos);
     **(e)** no contradice el **Pack B** (el `venv/` va a adelgazar, no a engordar).
   - **Contra**: hay que armar el backend y los formularios, y manejar los **jobs en background**
     (cola + logs: `separar.sh` no puede bloquear la request). **Seguridad**: escuchar **solo en
     `127.0.0.1`** (nunca `0.0.0.0`), porque el servidor ejecuta comandos.
   - **Sensación de "app"**: un `.desktop` que hace `xdg-open http://127.0.0.1:<puerto>` → app sin Qt/Electron.
   - **Desktop (`PySide6`/Qt)**: descartado *por ahora*: ~150 MB de Qt + dependencias, y va **en contra**
     del objetivo del Pack B. Electron/Tauri suman Node/Rust. Queda como opción solo si aparece una
     necesidad que el navegador no cubra (acceso directo a archivos, ASIO, etc.).
   - **Qué expone primero** (propuesto): **F1 solo lectura** → listar canciones/stems, abrir los informes
     HTML y **reproducir** los stems; después acciones (separar / mezclar / limpiar / loop) con log en vivo.
   - Falta también: **rol nuevo en `AGENTES.md`** (ej. *Interfaz*). Las mejoras del HTML (punto 2) son
     insumo directo de la UI → conviene decidirlas juntas.
2. **Mejoras del HTML** charladas: filtro por instrumento, comparar stems lado a lado, barras por
   compás. (Las métricas de BPM/tonalidad y las digitaciones ya se agregaron el 24/Sep.)
   ⚠️ Dato técnico ya relevado: `acordes_html.py` toma **un** `.txt` (arg `--out`), así que "filtro por
   instrumento" y "comparar stems" piden un **modo multi-stem** (varios `.txt` en un informe) y
   regenerar los 8 informes **sin volver a extraer acordes con Chordino**.
3. **Analista: estructura del tema** (intro / verso / estribillo) — es lo que le queda al rol después
   de BPM y tonalidad. Se haría con `librosa.segment` (auto-similitud) sobre el croma ya calculado.
4. **Descripción del repo en GitHub** (opcional, 30 s en la web): el tagline
   *"Un separador de pistas y creador de partituras y acordes"* quedó solo en el commit inicial
   `ad87b8d`; el `README.md` actual arranca distinto. Se puede pegar en *Settings → Description*.
5. **🎼 Recursos para improvisar + panel de tonalidad** → ver la sección **🎼** (requerimiento del 25/Sep):
   escalas/modos/grados, voicings generados y validados, licks por género y **panel de tonalidad** con
   AcousticBrainz como 2ª opinión (nunca corrige en silencio). Es el insumo natural de la interfaz (punto 1).
6. **📱 Android (APK)** — pedido el **25/Sep** (*"¿es posible luego ver de exportar todo y llevarlo a un
   APK?"*). **Respuesta: sí, pero como CLIENTE LIVIANO, no como procesador.**
   - ⛔ **Lo pesado no puede vivir en el teléfono**: Demucs en CPU ya tarda **2,27× el tiempo real en la
     PC** (en un celular serían decenas de minutos por tema) y `chord-extractor`/Chordino es un plugin
     **C++ de Vamp sin build para Android**. Tampoco `librosa`+`numba` (JIT de LLVM: no corre en Android).
   - ✅ **Camino recomendado (barato)**: la APK **envuelve la MISMA UI web** del punto 1 y apunta al
     servidor de la PC (`http://<IP-de-la-PC>:8765`). `scripts/servidor.py` **se reusa tal cual**; la APK
     es un **WebView** (Capacitor o WebView pelado, ~1 día) instalada por sideload (sin Play Store).
   - 🆓 **Paso 0 gratis**: antes de la APK, **PWA** = `manifest.json` + service worker → *"Agregar a la
     pantalla de inicio"* ya da experiencia de app, sin compilar ni firmar nada.
   - 🎨 **Y sí, también se puede una APK "de verdad" (Flutter / Kotlin)** — es **otra cosa** que envolver la
     web, y se verificó el 25/Sep en pub.dev:
     - **Flutter** compila a **ARM nativo** (no es un navegador): genera un **APK real** (~15-25 MB), con
       ícono, instalable por sideload. ⚠️ **No ejecuta el Python**: la app **consume** el servidor de la PC
       → el backend (punto 1) es **requisito de TODAS las opciones**; si arrancamos por el backend, elegir
       cliente después no cuesta nada y no se tira nada.
     - **Lo que gana** (paquetes confirmados hoy): `flutter_svg` **2.3.0** (mantenido por flutter.dev) tiene
       **`SvgPicture.string()`** → los **diagramas SVG que ya genera `svg_diagrama()` se dibujan directo en
       la app**; `just_audio` **0.10.6** trae **`setClip(inicio, fin)`** (loop A/B exacto para practicar),
       **varios players a la vez** (comparar stems) y **`setSpeed`** (practicar más lento); y sobre todo
       **modo OFFLINE real**: bajar los stems en Opus + los informes y ensayar **sin la PC**.
     - **Lo que cuesta**: **duplica la UI** (salvo que se use `webview_flutter` **4.14.1**, de flutter.dev,
       para embeber el informe HTML dentro de la app) + SDK de Flutter (~1-2 GB) + Dart + ~1-2 semanas.
     - **Esfuerzo comparado**: **PWA ~2 h · APK-WebView ~1 día · Flutter ~1-2 semanas**.
   - 🥇 **RECOMENDADO el 25/Sep: KOTLIN (Jetpack Compose), no Flutter.** Contexto real: **Android Studio ya
     está instalado** y **ya hicieron una app Kotlin** (la del fixture del Mundial); el target es **solo
     Android**; y es una app **de audio**.
     - **No se paga el costo de entrada**: Flutter = SDK nuevo (~1 GB) + **aprender Dart** + rehacer la app.
       Con Kotlin se sigue sobre lo que ya saben.
     - **La ventaja de Flutter (multiplataforma) no aplica acá**: el target es Android, e iOS necesita Mac +
       cuenta paga (estamos en Linux). Y si algún día se quiere **app de escritorio**, **Compose
       Multiplatform** (JetBrains **v2.4.20**; Android/desktop/iOS **stable**, web beta — verificado hoy)
       **reusa la misma UI de Compose** → Kotlin tampoco encierra en Android.
     - **El audio ES el producto**: `androidx.media3` (ExoPlayer) da `ClippingMediaSource` (con `Builder` y
       `setStart/EndPositionUs`) para el **loop A/B**, el **modo repetir** para loopearlo, velocidad
       (`PlaybackParameters`) y **varias instancias** para comparar stems, + `MediaSession`
       (fondo/notificación). Los paquetes de Flutter (`just_audio`) son **wrappers de estas mismas APIs**.
       (Nota: `ClippingMediaSource` es `@UnstableApi` → `@OptIn(UnstableApi::class)`; es lo normal en ExoPlayer.)
     - **Offline y archivos, de fábrica**: WorkManager (bajar stems en Opus) + Room/DataStore (cachear
       análisis/recursos) + Storage Access Framework.
     - **Diagramas**: en Compose se dibujan con **Canvas** (~50 líneas: líneas, círculos, texto) y quedan
       **interactivos** (tocar la nota, animar el mástil); el informe HTML se embebe con `AndroidView`+WebView.
     - **Camino incremental desde la app del fixture**: **(1)** WebView + network security config + token →
       APK en **~1 día** mostrando la UI web; **(2)** crecer a nativo por partes: media3 (loop/velocidad),
       offline (Opus + Room), Canvas (diagramas). **Envolver la web no es un callejón sin salida: es el F1 barato.**
     - **Dónde Flutter sí sería mejor** (para ser justos): si se quisiera iOS, o una sola base
       celu+escritorio+web, o si no se supiera Kotlin/Android. **Ninguna aplica hoy.**
   - 🍎 **¿Y si después se quiere iOS / subirla al market?** — preguntado el 25/Sep (tiene una **Mac Intel
     "de las últimas"**). **Respuesta: NO existe un "exportar" (no hay botón), pero es una de las rutas MÁS
     BARATAS que hay**, y con **KMP se hace sin reescribir**:
     - ⛔ **La Mac es obligatoria**: los docs de Kotlin/Native lo dicen textual — *"Building final binaries
       for Apple targets **on Linux and Windows is also not possible**"*.
     - ✅ **Kotlin Multiplatform**: un mismo proyecto con targets `androidTarget` + `iosArm64`. Se comparte
       la lógica (~100%: Ktor, modelos, kotlinx.serialization, estado, cache) y —con **Compose
       Multiplatform**, iOS **stable**— **la UI (~90%)**. `iosArm64` (dispositivo real) es **Tier 1**.
     - ❗ **Lo que NO se comparte: el AUDIO.** `media3`/ExoPlayer es **solo Android** → en iOS va
       **AVFoundation** (`AVPlayer`/`AVAudioEngine` para los stems, `AVAudioUnitTimePitch` para velocidad
       sin cambiar el tono), con `expect/actual` (`expect fun crearReproductor()` + 2 implementaciones).
       **Es la única parte que se escribe dos veces** (y el módulo de audio es chico).
     - ⚠️ **Los 2 asteriscos de la Mac Intel** (verificado el 25/Sep en las tablas de Apple y de Kotlin):
       **(1)** La App Store **exige Xcode 26+** para subir un app iOS (App Store Connect Help: *"iOS app …
       built using Xcode 26 or later"*), y **Xcode 26.x pide macOS Tahoe 26.2+** (Xcode 27, Tahoe 26.6+).
       → **Numeración** (aclarado el 25/Sep): macOS saltó **15 Sequoia → 26 Tahoe → 27 Golden Gate**
         (numeración por año, igual que iOS 26/27). Ojo: **Tahoe SÍ corre en Intel** (plataformas
         soportadas: ARM64 + **x86-64**) → es la **última** con Intel, no la primera sin.
       → **Cómo saber en 30 s si tu Mac llega**: menú Apple → *Acerca de esta Mac* (modelo/año) y
         *Ajustes → General → Actualización de software*: **si te ofrece Tahoe, llegás**. Los Intel que
         entraron en Tahoe son los **últimos de cada línea** (MacBook Pro 16" 2019, MBP 13" 2020 de 4 puertos
         TB3, iMac 2020, Mac Pro 2019) → **verificar el modelo exacto**. Un MBP 2018/2019, un Mac mini 2018
         o un iMac 2019 **se quedan en Sequoia 15**.
       → **Si te quedás en Sequoia 15: NO alcanza para PUBLICAR** (no existe Xcode 26 para Sequoia), pero
         **SÍ para programar** (Xcode 16 local: compila, corre simulador y hasta instala en tu propio iPhone).
       → **📌 MODELO CONFIRMADO (25/Sep)**: **MacBook Pro (13-inch, 2019, Four Thunderbolt 3 ports)** —
         **i7 quad 2.8 GHz + 16 GB LPDDR3** (ese i7 de 2.8 sólo existió en ese modelo; el 2018 era 2.7 y el
         2020 de 4 puertos es 10ª gen 2.3). Identificador: `MacBookPro15,2` (confirmar con `sysctl hw.model`).
         **Está corriendo macOS 15.8 Sequoia = SU TECHO**, y eso cierra el tema: **NO está en la lista de
         Tahoe** (el único 13" que Apple dejó es el **2020** de 4 puertos; Tahoe se limitó a **iMac 2020,
         MBP 16" 2019, MBP 13" 2020 4TB3 y Mac Pro 2019** — ni MacBook Air ni Mac mini Intel entraron).
         **CONCLUSIÓN CERRADA**:
         · **Xcode máximo = 16.x** (no hay Xcode 26 ni 27 para Sequoia) → **NO puede subir a App Store ni
           TestFlight desde esa Mac**. Para publicar: **Xcode Cloud** (u$s99/año, 25 h/mes incluidas) o una
           **Mac nueva** (un **Mac mini M1 usado** es lo más barato).
         · **SÍ puede programar iOS**: Xcode 16 compila Kotlin/Native + CMP, corre el simulador (`iosX64`,
           Tier 3) e **instala en su propio iPhone** (Apple ID gratis = 7 días; membresía = 1 año / 100
           dispositivos). Y Xcode 16 alcanza para **configurar Xcode Cloud** (o se hace desde la web).
         · **Su Mac sirve perfecto para el target real de hoy: Android** (Studio + Compose + Gradle con 16 GB).
         · **🎮 DESARROLLO Y PRUEBAS = 100% LOCAL Y GRATIS** (aclarado el 25/Sep, porque se había entendido
           lo contrario: *"¿no se puede usar un emulador? ¿se desarrolla a ciegas?"*). **NO se desarrolla a
           ciegas**: **Android** → emulador de Android Studio + **teléfono real por USB** (lo mejor para
           probar latencia de audio); **iOS** → **el simulador de iOS viene incluido con Xcode 16** y corre
           en Sequoia, más su **propio iPhone** con Apple ID gratis. Y el **simulador de Android** ya lo
           tienen andando de la app del fixture.
         · 💰 **La plata NO es para desarrollar, es SÓLO para PUBLICAR**: la membresía Apple de **u$s99/año**
           es la **misma** que hace falta para subir algo a la App Store con **cualquier** Mac (nueva o
           vieja) → **no es un costo extra "de la nube"**, y encima **incluye** las 25 h de Xcode Cloud.
           Google Play: **u$s25 una sola vez**. Todo el resto del ciclo (programar, probar, instalar en los
           propios teléfonos) es **gratis**.
       → **La salida real si no llegás: Xcode Cloud** (verificado): **incluido en la membresía** (u$s99/año)
         con **25 h de cómputo por mes**, compila **en las máquinas de Apple con el Xcode más nuevo**, se
         maneja desde Xcode o desde la web de App Store Connect e integra **TestFlight**. O sea: **Mac vieja
         para programar + Xcode Cloud para compilar y subir**. (Alternativa si sobra plata: un **Mac mini M1
         usado**.) La ventana sigue siendo de **~1-2 años**: cuando Apple exija Xcode 28 (macOS 27+ = solo
         Apple silicon), se terminó.
       **(2)** **El simulador en Intel** usa `iosX64`, que Kotlin tiene en **Tier 3** (*"not in active
       development… may come with breaking issues. Use them with caution"*), y sus hermanos x86_64
       (`macosX64`, `watchosX64`, `tvosX64`) **ya están deprecados desde Kotlin 2.3.20**.
     - 💰 **Subir al market**: Apple **u$s99/año** (obligatorio, incluso si es gratis) vs Google Play
       **u$s25 una sola vez** (y en cuentas personales nuevas, prueba cerrada con testers antes de producción).
     - ⚠️ **Riesgo de review si el objetivo es "marketearla"**: una app que **solo funciona contra tu PC**
       puede ser rechazada por **§4.2 "Minimum Functionality"**. Lo que la salva es el **modo OFFLINE** real
       (contenido y análisis en el teléfono) → otra razón para priorizarlo.
     - ⚠️ **Nunca empaquetar el audio** (Led Zeppelin) en la APK/IPA: la app reproduce lo que sube el
       usuario, **no distribuye música**.
     - ✅ **Decisión de HOY para no cerrar la puerta (cuesta ~1 h)**: **(1)** la lógica pura en un **módulo
       Kotlin sin imports de Android** (`:core`); **(2)** el **audio detrás de una interfaz**
       (`Reproductor`) con la implementación media3 aparte; **(3)** **no arrancar con Compose Multiplatform**
       el día 1 (JetBrains lo documenta como adopción "gradual"). Así, el día que haya Mac+iOS, es
       **agregar un target**, no un rewrite.
   - ⚠️ **Trampa técnica que aplica a las 3 opciones** (docs de Android, verificado hoy): Android **bloquea el
     HTTP sin HTTPS** ("cleartext") por defecto en **`targetSdk` 28+** → como el servidor es
     `http://192.168.x.x:8765`, hay que habilitarlo con **`android:usesCleartextTraffic`** o (mejor) una
     **Network Security Config que permita cleartext solo a la IP local**. El doc aclara que **WebView
     también lo respeta** (target API 26+): sin esto **no carga ni la web ni Flutter**. Es el error #1 de
     este tipo de apps. Sumar: permiso **`INTERNET`**, **token** en la URL (el server ejecuta comandos) y
     un **QR** con la IP+token para no hardcodear la IP.
   - ⚠️ **Seguridad al abrir a la red**: para que el celular llegue, el servidor debe escuchar en la
     **LAN** (no solo `127.0.0.1`) → **token obligatorio**; y conviene un **modo solo-lectura** para el
     teléfono (listar, ver informes, reproducir) dejando las acciones solo desde la PC.
   - ⚠️ **Los stems son WAV grandes**: para el celular conviene exportar **MP3/Opus**, no los WAV crudos.
     Y **el audio sigue sin versionarse** (copyright): la APK se usa en tu red, no se publica.
   - 📦 **"Exportar todo" (`.zip` por canción)**: feature aparte, barata y útil, y **no depende de
     Android** → `scripts/exportar.sh "<cancion>"` que empaqueta informe HTML + análisis + loops
     (+recursos) en un `.zip` para llevarse o mandar.
   - ⛔ **Descartado**: procesar en el teléfono (Demucs/Chordino) y **servidor en la nube** (costo de CPU;
     el proyecto es local y privado).
   - **Orden**: va **después** de la UI (es cliente de ella) → **F6**.

7. **☁️ Motor en la nube: ¿cuánto cuesta? (preguntado el 25/Sep)** — *"para publicar la app no voy a dejar
   el PC corriendo: es riesgo y se fríe con 4 usuarios"*. **Respuesta: el cómputo es BARATO (centavos por
   canción); lo caro/crítico es lo LEGAL y la disponibilidad.** Base de cálculo = **su propio benchmark**:
   Demucs a **2,27× tiempo real** con 8 hilos (234 s de audio en 103 s) ≈ **824 vCPU-s por canción de 4 min**
   (≈14 vCPU-min).
   - **Serverless GPU — Modal** (verificado el 25/Sep): **T4 u$s0.000164/s**, L4 u$s0.000222/s, A10
     u$s0.000306/s, A100-40GB u$s0.000583/s · CPU u$s0.0000131/(core físico = 2 vCPU)/s · RAM
     u$s0.00000222/GiB/s · **no se paga el idle** y el plan **Starter trae u$s30/mes de cómputo gratis**.
     Una canción en GPU (con el modelo cargado) ≈ **20-40 s** → **~u$s0,005/canción** →
     **4 usuarios ≈ 1.200 canciones/mes ≈ u$s6 → u$s0 con el crédito gratis**.
   - **Serverless CPU — Cloud Run** (verificado): free tier **240.000 vCPU-s + 450.000 GiB-s por mes** →
     **≈ 290 canciones/mes GRATIS** (824 vCPU-s c/u); después, centavos. Escala a cero, factura por 100 ms.
   - **Stems — Cloudflare R2** (verificado): **egress GRATIS** (clave: los stems son grandes), **10 GB-mes
     gratis**, u$s0,015/GB-mes. 1.200 canciones en MP3 (≈36 MB c/u) = 43 GB → **~u$s0,50/mes**; borrando a
     los 7 días, casi $0.
   - **VPS 24/7 tipo Hetzner (~8 vCPU)**: precio plano del orden de **u$s25-30/mes** (no verificado en esta
     consulta) → **más caro que serverless** a este volumen, pero simple y previsible.
   - ❌ **GitHub Actions NO sirve para esto**: es para CI/CD del repo (sus términos lo prohíben como backend
     de una app), no da endpoint HTTP persistente ni escala a cero.
   - ⚠️ **El costo NO es el problema; el problema es LEGAL**: si la app pública sube la canción de un usuario
     y le devuelve los stems, **se está alojando y redistribuyendo obra derivada con copyright** (más la
     política de privacidad y el formulario *Data safety* que exige Google Play). **Eso** puede tumbar la
     publicación, no los u$s5.
   - **Ruta recomendada por fases**: **(0)** 4 amigos → PC + **Cloudflare Tunnel + Access** (gratis, sin abrir
     puertos) o Tailscale, u$s0 · **(1)** app pública **sin Demucs**, todo on-device (u$s0/mes y sin riesgo
     legal) · **(2)** separación en la nube con serverless GPU + R2 (u$s0-6/mes para ese volumen) ·
     **(3)** escala: cobrar créditos por uso.
   - ⚠️ **Ancho de banda**: servir 4 stems WAV (~160 MB) desde una conexión de casa es lento (a 10 Mbps de
     subida ≈ 2 min) → exportar **Opus/MP3** (16-36 MB) lo baja a 15-30 s.

8. **📈 Estrategia: ¿"venderle la app a Spotify"? (preguntado el 25/Sep)** — idea del usuario: armar un PoC
   prolijo (APK + web corriendo en su PC) y ofrecérselo a Spotify *"porque ellos ya tienen resuelta la parte
   legal"*. **Opinión sincera: el demo SÍ, la puerta elegida NO.**
   - ✅ **El demo es el paso correcto**: es barato, valida la UX y **es el mejor currículum posible**.
     ⚠️ Detalle: el teléfono **no resuelve el `localhost` de la PC** → hay que apuntar a la **IP de la LAN**
     (`http://192.168.x.x:8765`) + network security config + token. Medir lo que importa: que **3 de 4
     músicos la usen 2 veces por semana sin que se lo pidas** (un "¡está bueno!" de amigos no es señal).
   - ⚠️ **La competencia ya existe y es enorme — el dato que más pesa**: **Moises** — **+80 M de artistas**,
     separación en **27 stems**, *Chord Finder*, *Speed Changer*, transcripción de letras, web + desktop +
     iOS + Android, **free tier** + suscripción, iPad App del Año y premios de Apple/Microsoft, usado en
     Berklee. Y **Logic Pro 11** trae **Stem Splitter** de fábrica. → **La separación de stems es un
     commodity**: ahí no está el valor propio.
   - 🎯 **El nicho real y abierto es el "coach de improvisación"**: Moises te da los stems y los acordes;
     **nadie te dice** *"esto es un blues en A → estas pentatónicas, esta escala de blues, estos licks,
     estos voicings, y practicá con este loop A/B"*. Ese cruce (análisis → recursos por grado + género →
     práctica) **no lo vende nadie** y es justo lo que el proyecto tiene a medio construir.
   - ⛔ **Por qué Spotify es la puerta equivocada (no por ambicioso: por mal target)**: **(a)** a las grandes
     no se les vende una idea, se les **compra una empresa con usuarios/tecnología**; **(b)** **la legalidad
     NO se transfiere**: sus licencias son para **streaming dentro de su app**, no para que un tercero
     entregue **stems de obra con copyright** — es justo el derecho que no pueden ceder; **(c)** la
     **Developer Policy** (vigente **15/may/2025**, verificada) es restrictiva con el contenido
     (*Respect Content and Creators*, *Some prohibited applications*) y limita los *Audio Preview Clips* a
     promover/enlazar, no a un servicio propio; **(d)** si les interesara, lo construyen **adentro de su app
     con su audio licenciado** (van hacia ahí con herramientas de artista/IA).
   - ✅ **Lo que SÍ abre puertas, en orden**: **(1)** que músicos reales la usen y la reusen; **(2)**
     publicar en Play (u$s25) con el diseño **legal-safe** (on-device, archivos del usuario) y medir; **(3)**
     **el repo ya es público** → pulido + video demo = portfolio para que **te contraten** en
     Zound/Moises/Apple/Spotify (el camino realista a "trabajar en esto"); **(4)** monetizar al nicho
     directo: **profesores, estudiantes y bandas de covers** (compra única o u$s3-5/mes; las academias pagan
     por asiento); **(5)** recién entonces hablar con quien **sí** tiene licencias (sellos, editoriales,
     academias).
   - ⛔ **No hacer**: un servicio de separación en la nube (Moises + Logic + alternativas gratis + riesgo
     legal), perseguir un acuerdo con Spotify **antes** de tener usuarios, y pagarle a alguien para
     "representar la idea".
   - 🔒 **El plan de negocio completo vive en `PLAN_NEGOCIOS.local.md`** — archivo **LOCAL y PRIVADO**: está
     en `.gitignore` (`*.local.md`) y **no se sube** (el repo es público). Ahí están el mapa competitivo, los
     segmentos S1-S5, precios, fases con go/no-go, métricas y los próximos 5 pasos.
9. **📣 Publicar el proyecto (sirve a los 3 carriles a la vez)** — los **4 artefactos**: **(a)** `README.md`
   **en inglés** con capturas; **(b)** **video demo de 90 s**; **(c)** **post técnico** con el hallazgo del
   **modo** (*el croma acierta la tónica pero falla el modo; lo resuelve la armonía*); **(d)** la app en
   **Play**. Es el mismo trabajo que desbloquea producto, negocio y carrera (ver `PLAN_NEGOCIOS.local.md`).

## 🔗 Repositorio (GitHub)

- **URL**: https://github.com/flacogabrielc/split_music — público, rama `main`, upstream configurado.
- **Remote**: `origin` = `git@github.com:flacogabrielc/split_music.git` (**SSH**, clave
  `~/.ssh/id_ed25519` sin passphrase, agregada en GitHub como *musicapp*).
- **Identidad local del repo**: `flacogabrielc <flacogabrielc@users.noreply.github.com>`.
- **Subir cambios**: `git add -A && git commit -m "..." && git push` (desde `~/proyectos/spleeter`).
- **Traer cambios**: `git pull` (el repo local es el de trabajo; la otra PC solo clona/lee).
- **Clonar en otra PC**: `git clone https://github.com/flacogabrielc/split_music.git` →
  **no pide credenciales** (es público). Después recrear el entorno con la receta del
  `README.md` sección **2.1**.
- **No se versiona** (`.gitignore`): `venv/`, `venv-analisis/`, `mp3/`, `output/`, `separated/`,
  `__pycache__/`, `*.tar.gz`. ⚠️ El repo es **público**: nunca subir `mp3/` (audio con copyright).

## 🧭 Cómo retomar (comandos listos)

```bash
cd ~/proyectos/spleeter

# acordes de una canción (por nombre: lo busca en mp3/ y subcarpetas)
./scripts/analizar.sh "Down by the Seaside.mp3"

# ver el informe HTML
xdg-open "output/Down by the Seaside/analisis/Down by the Seaside_acordes.html"

# mezclar / filtrar / loopear usando los stems nuevos
./scripts/mezclar.sh "output/Boogie with Stu/spleeter/htdemucs_6s" drums bass --out base_ritmica
./scripts/limpiar.sh "output/Down by the Seaside/spleeter/htdemucs/bass.wav" lowpass 220 --out bass_limpio

# loop: BPM detectado solo, y el inicio se ajusta al tiempo más cercano
./scripts/loop.sh "output/Down by the Seaside/htdemucs/base_ritmica.wav" 8 --start 32.5
#   -> Tempo 92 bpm (detectado) | inicio 32.4151 s (ajustado desde 32.5, -85 ms)

# separar una canción nueva (Demucs → staging → output/<cancion>/spleeter/)
./scripts/separar.sh "Boogie with Stu.mp3" htdemucs_6s

# flujo completo
./scripts/procesar.sh "Down by the Seaside.mp3" htdemucs --bpm 110 --start 32.5
```

## 🔑 Datos clave del entorno (para no re-descubrir)

- `venv/` = **Python 3.12.3** + demucs 4.1.0 + torch 2.14 (CPU, sin CUDA) + huggingface_hub
  + **chord-extractor 0.1.3** + vamp 1.1.0 + librosa 1.0.0 + soundfile 0.14.0.
- **Demucs va a ~2× tiempo real** (4 pistas y 6 pistas similar). Modelos ya descargados (cache HF).
- `chord-extractor` se instaló **forzando el pin de Python**:
  `pip install --ignore-requires-python --no-build-isolation chord-extractor`
  (su metadata declara `<3.12`; funciona igual). Snapshot previo: `freeze_antes_chordextractor.txt`.
  El plugin Chordino y el Vamp SDK **vienen empaquetados** → no requiere apt ni sudo.
- **`N` en los acordes** = sin acorde detectado (silencio/percusión). El último `N` suele ser un
  marcador con timestamp **posterior al final** del archivo (artefacto de Chordino).
- Los scripts activan el venv solos; `analizar.sh` prefiere `venv-analisis/` si algún día existe.
- Género de las canciones procesadas: *Led Zeppelin* (`mp3/`, fuente original intacta).
- **Git**: remote por SSH a `flacogabrielc/split_music` (ver sección *Repositorio*). El repo arrancó
  con el `Initial commit` de GitHub (README placeholder de 2 líneas), rebaseado encima **sin
  `--force`**; hoy son **10 commits lineales** (Initial + proyecto + docs + Analista + digitaciones +
  verificador + limpieza + Looper BPM + Looper inicio + punto de retomada). `requirements.txt` documenta la instalación y
  el repo queda sincronizado (`main` ↔ `origin/main`).
- ⚠️ El repo es **público**: lo que se commitea queda visible. `mp3/` y `output/` están en `.gitignore`
  justamente por el copyright del audio.
- ⚠️ **Locale**: usá `LC_ALL=C`/`LC_NUMERIC=C` en los comandos que usen `awk` (con `es_*` los decimales
  van con coma y rompen las comparaciones). Los scripts ya lo fijan por su cuenta en `_comun.sh`.
- **BPM/tonalidad**: `librosa` ya está en `venv/` (no hace falta `venv-analisis/`). El BPM se afina con
  un peine sobre todo el audio y la tonalidad con Krumhansl (trae `confianza`/`ambigua`).
