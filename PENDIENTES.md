# 📌 ESTADO Y PENDIENTES — spleeter

> **Archivo de continuidad.** Cline no tiene memoria entre sesiones: lo que "recuerda" es lo que
> está escrito acá. Para retomar, pedile:
> *"leé `~/proyectos/spleeter/PENDIENTES.md` y seguimos"*
> (o abrí la carpeta `~/proyectos/spleeter` como workspace, así se cargan `.clinerules` y `AGENTES.md` solos).

**Última actualización:** 24/Sep/2026 — se sumó el **repositorio en GitHub** (ver *Repositorio*)

---

## ✅ Hecho y verificado

- **Estructura consolidada por canción**: `output/<cancion>/{spleeter/<modelo>, <modelo>, loops, analisis}`
  (+ `output/_sueltos/` y `output/logs/`). `separated/` quedó como *staging temporal* de Demucs.
- **Scripts** (9): `separar.sh`, `mezclar.sh`, `limpiar.sh`, `loop.sh`, `procesar.sh`,
  `analizar.sh` + `analizar.py` + `acordes_html.py` + `_comun.sh`.
- **Roles documentados** en `AGENTES.md`: Separador, Mezclador, Masterizador, Looper, **Analista**.
- **Rol Analista operativo**: chord-extractor 0.1.3 (Chordino) → `.txt` + `.json` + `.html`
  (informe con **diagramas SVG**, línea de tiempo proporcional y tabla de cambios).
- **Canciones procesadas**:
  - `Down by the Seaside`: 4 stems (htdemucs) + 6 stems (htdemucs_6s) + loop + mezclas + análisis (84 segmentos)
  - `Boogie with Stu`: 6 stems (htdemucs_6s) + análisis por stem (6) + análisis de la mezcla (43 segmentos)
- **Docs**: `.clinerules` (110 líneas), `AGENTES.md` (420), `README.md` (495),
  `PENDIENTES.md` (115) + backups `.bak_pre_spleeter` de los 3
  (versión anterior al cambio de estructura).
- **Repo en GitHub** (24/Sep): `https://github.com/flacogabrielc/split_music` — **público**, rama `main`.
  21 archivos / 488 KB (scripts + docs). `venv/`, `mp3/`, `output/` y `separated/` quedaron en `.gitignore`.
  Remote por **SSH**. El repo nació con un `Initial commit` de GitHub (README placeholder) y la
  divergencia se resolvió con **rebase** → historial lineal, **sin `--force`**.
  Verificado: se clona en otra PC por HTTPS **sin credenciales**.
- **`requirements.txt`**: 72 paquetes del venv + la receta de instalación escrita adentro
  (resuelve la trampa de `Requires-Python: <3.12` de chord-extractor).

## ⏳ Pendientes (en orden sugerido)

1. **BPM y tonalidad para el rol Analista** — es lo ÚNICO que le falta al rol.
   - `chord-extractor` no los da. Opciones evaluadas:
     - **librosa** (`beat_track` + `chroma_cqt` + Krumhansl/acordes): validado en `/tmp/musica-venv`
       con audio sintético → 6/6 en tonalidad (Krumhansl + acordes + regla de tónica) y BPM ±1-3.
       **Falta probarlo con las canciones reales** y decidir si va en `venv/` o en `venv-analisis/`.
     - **Omnizart**: DESCARTADO por ahora (solo sdist → compilar, TensorFlow ~600 MB, `vamp`/`pyfluidsynth`).
   - ⚠️ Lección: el locale `es_*` rompe `awk` (decimales con coma) → usar `LC_ALL=C`/`LC_NUMERIC=C`.
2. **Más digitaciones** en la tabla de `acordes_html.py` (~40 hoy): faltan `F6` y voicings alternativos.
3. **Mejoras del HTML** charladas: filtro por instrumento, comparar stems lado a lado, barras por compás.
4. **Decisión abierta**: los derivados van a `output/<cancion>/<modelo>/` (actual) —
   ¿o preferís `output/<cancion>/mezclas/`?
5. **Limpieza opcional**: `rm -rf output/prueba_30s` (artefacto de mis pruebas) y
   los `test_*.wav` / `prueba_30s_*.wav` de la raíz de `output/` (tuyos, para borrar vos).
6. **`Readme.txt` reapareció** (24/Sep 01:27, 102 líneas): es tu nota **original**, con los
   `--stems` que corregimos. Probablemente el editor la tenía abierta y la guardó después del
   renombre. Hoy conviven:
   - `Readme.txt` → versión vieja (con los `--stems` inexistentes)
   - `COMANDOS_MANUALES.txt` → versión corregida
   Decidí: borrar el viejo, fusionar, o dejarlo como histórico. **No lo toqué** (es tuyo).
7. **`separated/`** existe de nuevo pero **vacía**: la recrea `procesar.sh` con `mkdir -p`
   (es el staging documentado de Demucs). No molesta; si querés se elimina esa línea.
8. **Descripción del repo en GitHub** (opcional, 30 s en la web): el tagline
   *"Un separador de pistas y creador de partituras y acordes"* quedó solo en el commit inicial
   `ad87b8d`; el `README.md` actual arranca distinto. Se puede pegar en *Settings → Description*.

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
./scripts/loop.sh "output/Down by the Seaside/htdemucs/base_ritmica.wav" 110 8 --start 32.5

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
  con el `Initial commit` de GitHub (README placeholder de 2 líneas) y el commit local se rebaseó
  encima → 2 commits lineales, sin `--force`. `requirements.txt` documenta la instalación.
- ⚠️ El repo es **público**: lo que se commitea queda visible. `mp3/` y `output/` están en `.gitignore`
  justamente por el copyright del audio.
