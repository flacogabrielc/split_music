# 📌 ESTADO Y PENDIENTES — spleeter

> **Archivo de continuidad.** Cline no tiene memoria entre sesiones: lo que "recuerda" es lo que
> está escrito acá. Para retomar, pedile:
> *"leé `~/proyectos/spleeter/PENDIENTES.md` y seguimos"*
> (o abrí la carpeta `~/proyectos/spleeter` como workspace, así se cargan `.clinerules` y `AGENTES.md` solos).

**Última actualización:** 24/Sep/2026 (madrugada)

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
- **Docs**: `.clinerules` (95 líneas), `AGENTES.md` (420), `README.md` (465) + backups
  `.bak_pre_spleeter` de los 3 (versión anterior al cambio de estructura).

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
6. **Sugerencia**: `git init` + `.gitignore` (ignorando `venv/`, `mp3/`, `output/`) para tener
   historial real de scripts y docs. Lo armo si querés.
7. **`Readme.txt` reapareció** (24/Sep 01:27, 102 líneas): es tu nota **original**, con los
   `--stems` que corregimos. Probablemente el editor la tenía abierta y la guardó después del
   renombre. Hoy conviven:
   - `Readme.txt` → versión vieja (con los `--stems` inexistentes)
   - `COMANDOS_MANUALES.txt` → versión corregida
   Decidí: borrar el viejo, fusionar, o dejarlo como histórico. **No lo toqué** (es tuyo).
8. **`separated/`** existe de nuevo pero **vacía**: la recrea `procesar.sh` con `mkdir -p`
   (es el staging documentado de Demucs). No molesta; si querés se elimina esa línea.

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
