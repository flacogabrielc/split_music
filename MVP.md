# 🎯 MVP.md — alcance, mapa y seguimiento (demo v0)

> **Qué es:** el **tablero** del MVP para que nada se pierda. Se actualiza a medida que avanza.
> **Regla de oro:** todo lo que se empieza tiene su **ID de historia** (`E1-1`, `E5-2`…) y se marca acá.
> El **backlog detallado** (local, no se sube) está en `HISTORIAS.local.md`.

---

## 1. Alcance del demo v0 (lo que SÍ entra)

**Pantallas:** P1 (Mis canciones) · P3 (La canción) · P4 (Recursos, versión simple) · P5 (Practicar) ·
P6 mínimo (Conexión).

**Regla del MVP:** todo sale de **leer `output/`** → **cero cómputo nuevo**. Con las 2 canciones ya
procesadas alcanza para mostrar **el truco completo**: *abrir → ver análisis → ver recursos → loopear 8
compases → tocar encima*.

## 2. Lo que NO entra (para no inflarlo)

Subir/analizar canciones nuevos desde la UI · separar stems desde la UI · cuentas/login · nube ·
sincronización · pagos · notificaciones · multiusuario.

## 3. 🗂️ Mapa de archivos: dónde vive cada cosa (que no se pierda nada)

| Qué | Dónde | ¿Va al repo? |
|---|---|---|
| **UI web** (HTML/CSS/JS) | `scripts/ui/` | ✅ público |
| **Servidor local** | `scripts/servidor.py` + `scripts/servidor.sh` | ✅ público |
| Informe HTML (ya existe) | `scripts/acordes_html.py` | ✅ público |
| Motor de recursos (futuro) | `scripts/recursos.py` | ✅ público |
| Datos que consume la UI | `output/<cancion>/…` | ❌ ignorado (audio) |
| **Alcance + tablero del MVP** | **`MVP.md` (este archivo)** | ✅ público |
| Backlog de historias de usuario | `HISTORIAS.local.md` | 🔒 **local** |
| Estrategia, competencia, precios, carrera | `PLAN_NEGOCIOS.local.md` | 🔒 **local** |
| Estado del proyecto y próximo paso | `PENDIENTES.md` | ✅ público |

➡️ **El diseño no se duplica:** el **wireframe en HTML es la app** (vive en `scripts/ui/`, se abre en el
celular y no hay que "traducir" nada). Las ideas sueltas se piensan en **Excalidraw/Penpot** y se bajan a HTML.

## 4. ✅ Checklist por historia (se marca acá)

**Épica 1 — Conexión (P6)**
- [ ] `E1-1` Abrir la URL y que cargue sin instalar nada
- [ ] `E1-3` Ver si el servidor está conectado o caído (con cartel claro)
- [ ] `E1-2` QR con IP + token para emparejar el celular
- [ ] `E1-4` Mensaje útil si el server está apagado

**Épica 2 — Mis canciones (P1)**
- [ ] `E2-1` Tarjetas con tonalidad + BPM (leídas de `output/`)
- [ ] `E2-2` Badges de qué tiene cada canción (stems/análisis/loops)

**Épica 3 — La canción (P3)**
- [ ] `E3-1` Tonalidad y BPM
- [ ] `E3-3` Progresión con timestamps + diagramas
- [ ] `E3-2` Candidatos y confianza visibles
- [ ] `E3-6` Link al informe HTML completo

**Épica 4 — Recursos (P4)**
- [ ] `E4-1` Escala/modo de la tonalidad
- [ ] `E4-2` Pentatónicas + escala de blues
- [ ] `E4-3` Acordes diatónicos por grado con función
- [ ] `E4-7` Corregir la tonalidad a mano y que se recuerde

**Épica 5 — Practicar (P5)**
- [ ] `E5-1` Reproducir canción o stem
- [ ] `E5-2` Loop A/B **exacto al tempo** (no se desfasa al repetir)

## 5. Definición de "hecho"

Funciona en **web** y en **celular** (mismo diseño por WebView) · probado con **una canción real** ·
contempla **el estado de error** · el ID de la historia se marca acá.

## 6. Cómo se prueba (comandos)

```bash
# 1) levantar el servidor local (a construir)
./scripts/servidor.sh          # escucha SOLO en 127.0.0.1:8765 (o la IP de la LAN con token)
# 2) abrir en la PC y en el celular
xdg-open http://127.0.0.1:8765
# 3) la UI lee esto (ya existe):
ls "output/Down by the Seaside/analisis/"
```
