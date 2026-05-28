# BitFlow — Auditoría visual para rediseño "Luna Systems light premium"

> Estado: **AUDITORÍA — sin cambios de código.** No se editó ningún archivo de la app.
> Fecha: 2026-05-21
> Objetivo: dejar la app lista para parecerse al render de referencia de Luna Systems
> (fondo claro, tarjetas blancas, esquinas redondeadas, sombras suaves, acento **teal**,
> look SaaS/B2B moderno, dashboard limpio, tablas prolijas).
>
> **Restricciones críticas del encargo (respetadas en esta auditoría):**
> - NO tocar el comportamiento del DataGrid.
> - NO tocar exportaciones.
> - NO tocar services / models / persistencia.
> - NO romper desktop / web / Windows.
> - Solo recomendaciones seguras de tema / layout.

---

## 1. Resumen ejecutivo

BitFlow (paquete interno `bitacora_web`, marca "Bit Flow" / "Gridnote") es una app
Flutter **grande y madura** (web + Windows + Android/iOS). A diferencia de Caja Clara,
tiene **dos sistemas de diseño conviviendo**:

1. **`lib/theme/gridnote_theme.dart`** — el tema real efectivo. Construye el `ThemeData`
   completo (estilo "Apple premium": píldoras, cards suaves, tipografía Cupertino/Roboto).
   Aquí vive el **acento**, que hoy es **monocromático casi-negro** (`#0D0D0F`).
2. **`lib/ui/`** — un design-system más nuevo y limpio (`AppTokens`, `AppCard`, `AppShell`,
   `AppButton`, `AppTable`, `SectionHeader`, etc.) que **deriva** sus colores del `ThemeData`
   anterior vía `AppTheme.fromTheme()`.

La pantalla de inicio (`start_page_v2.dart`), la lista de planillas (`sheets_screen.dart`)
y partes del editor ya usan `lib/ui/`. **No hay "look admin viejo"**: ya es light, con
tarjetas blancas, radios grandes y sombras suaves.

El cambio conceptual es el **acento**: hoy **monocromo (negro/gris)**; la referencia pide
**teal**. Como casi todo el acento se resuelve desde `accentMono` en `gridnote_theme.dart`,
el recolor es **muy contenido** — pero hay que hacerlo **sin tocar la grilla del editor**.

- **Esfuerzo estimado:** bajo-medio (1 archivo de tema crítico + ajustes puntuales).
- **Riesgo global:** bajo **si se respeta la zona prohibida del editor/DataGrid**.
- **Bloqueo principal:** el acento también alimenta el estilo de la grilla
  (`GridnoteTableStyle`); hay que decidir si la grilla se recolorea o se deja monocroma.

---

## 2. Arquitectura de tema (cómo fluye el color)

```
gridnote_theme.dart  →  GridnoteTheme.build(light)
   ├─ accentMono (#0D0D0F light / #F3F3F3 dark)   ← ACENTO (a cambiar por teal)
   ├─ scaffoldLight #F5F5F7 / cardLight #FFFFFF   ← ya light premium
   ├─ ThemeData completo (botones píldora, cards, inputs, navbar…)
   └─ GridnoteTableStyle.from(theme)              ← estilo de grilla del editor
        ↓
app_theme.dart  →  AppTheme.material(light) = GridnoteTheme.build(light).material
   └─ AppTheme.fromTheme(theme)  →  AppColors / AppRadii / AppShadows / AppSpacing
        ↓
ui_theme.dart  →  UiTheme.light()/dark()  (usado por main.dart MaterialApp)
        ↓
app_tokens.dart  →  context.tokens  (consumido por lib/ui/* y start_page_v2, sheets_screen)
```

Punto clave: en `AppTheme.fromTheme()`, `accent = neutralInk` (negro/gris). Es **derivado**,
no un color de marca propio. Para teal hay que **introducir un color de acento explícito**.

---

## 3. Mapa de archivos visuales

### 3.1 Tema (núcleo)

| Archivo | Rol | Riesgo |
|---|---|---|
| `lib/theme/gridnote_theme.dart` | **Tema real.** Define `accentMono`, scaffold, card, divider, todo el `ThemeData` y `GridnoteTableStyle`. | **MEDIO** — punto de entrada del recolor; afecta también la grilla (ver §6). |
| `lib/theme/app_theme.dart` | Capa de tokens (`AppColors`, `AppRadii`, `AppShadows`). `accent` hoy = tinta neutra. | **BAJO** — ideal para introducir el teal de marca como token explícito. |
| `lib/theme/bitflow_colors.dart` | **Archivo vacío.** Candidato natural para alojar las constantes de marca teal. | **NULO** — está vacío. |
| `lib/ui/ui_theme.dart` | `UiTheme.light()/dark()` — wrapper fino sobre `AppTheme.material`. | **NULO** — no requiere cambios. |
| `lib/ui/app_tokens.dart` | Expone `context.tokens`. | **NULO** — no requiere cambios. |

### 3.2 Design-system `lib/ui/` (componentes seguros de pulir)

| Archivo | Rol | Riesgo |
|---|---|---|
| `lib/ui/app_card.dart` | Tarjeta base (hover, sombras, borde, radio). | **BAJO** |
| `lib/ui/app_shell.dart` | `AppShell` + `AppTopBar` (encabezado de pantalla en tarjeta). | **BAJO** |
| `lib/ui/app_button.dart` | Botones; **usa `0xFF0D0D0F` hardcodeado** para el acento. | **BAJO/MEDIO** — tiene un color literal a revisar. |
| `lib/ui/app_table.dart` | Tabla de presentación de `lib/ui/` (NO es el DataGrid del editor). | **BAJO** — segura de pulir; ver §6 para distinguirla. |
| `lib/ui/section_header.dart`, `empty_state.dart`, `error_state.dart`, `loading_state.dart`, `app_text_field.dart`, `app_toast.dart`, `app_modal.dart`, `app_text_styles.dart`, `glass_surface.dart` | Componentes de presentación. | **BAJO** |

### 3.3 Pantallas / dashboard / navegación

| Archivo | Rol | Riesgo |
|---|---|---|
| `lib/start_page_v2.dart` | **Home / dashboard real** (`StartPage` extiende `StartPageV2`). Hero, acciones primarias, panel de planillas recientes. Usa `lib/ui/` + `context.tokens`. Tiene `0xFF0D0D0F` hardcodeado en `_ActionTile`. | **BAJO/MEDIO** |
| `lib/start_page.dart` | Alias delgado (`StartPage extends StartPageV2`). | **NULO** |
| `lib/screens/sheets_screen.dart` | Lista de planillas (Apple large-title, búsqueda, tarjetas `_SheetCard`). Usa `lib/ui/` + `Theme.of`. | **BAJO** |
| `lib/main.dart` | Root `MaterialApp.router`, boot splash, badges. Aplica `UiTheme.light()/dark()`. Tiene colores de pantalla de error hardcodeados (`#0B0D1A`). | **BAJO** — solo el splash/boot, no rutas. |
| `lib/screens/landing_screen.dart` | Landing in-app (usa `lib/ui/`). | **BAJO** |
| `lib/screens/about/legal/privacy/terms/login_screen.dart` | Pantallas estáticas (usan `lib/ui/`). | **BAJO** |
| `lib/widgets/app_background_shell.dart` | Fondo decorativo de la app. | **BAJO** — revisar que no choque con el teal. |
| `lib/widgets/command_palette.dart` | Paleta de comandos (usa `lib/ui/`). | **BAJO** |

### 3.4 Editor y grilla — **ZONA SENSIBLE**

| Archivo | Rol | Riesgo |
|---|---|---|
| `lib/features/editor/editor_screen.dart` | Pantalla del editor de planillas. Es un archivo "monolito" con ~20 `part` (controller, state, dialogs, actions, grid_host, app_bar…). | **ALTO — no tocar** salvo cambios triviales de color en el app_bar, y solo con aprobación. |
| `lib/features/editor/widgets/grid_host.dart` | **El DataGrid real**: `_GridView`, métricas de fila, render de celdas, scroll, selección. | **MUY ALTO — NO TOCAR.** Cae bajo "no tocar comportamiento del DataGrid". |
| `lib/widgets/smart_datasource.dart`, `lib/smart_sheet/smart_sheet.dart` | Consumen `GridnoteTableStyle` / `accentMono`. | **ALTO — no tocar.** Vinculados a la grilla. |
| `lib/features/editor/widgets/editor_app_bar.dart`, `save_status_chip.dart` | Chrome del editor (barra superior, chip de guardado). | **MEDIO** — recolor posible pero solo con aprobación; son `part` del monolito. |
| `lib/features/editor/dialogs/export_dialogs.dart` y servicios `export_*` | Exportaciones. | **NO TOCAR** (restricción explícita). |

---

## 4. Punto de partida vs. referencia Luna Systems

| Aspecto | Hoy (BitFlow) | Referencia Luna Systems | Acción |
|---|---|---|---|
| Fondo | `#F5F5F7` gris claro frío | Gris muy claro frío | ✅ Ya alineado |
| Tarjetas | Blancas, radio 22-26, borde fino, sombra limpia | Blancas, radios grandes, sombra suave | ✅ Ya alineado |
| Acento | **Monocromo casi-negro** `#0D0D0F` | **Teal** (`#1FB6A6`/`#0FA9A0` aprox.) | Cambiar `accentMono` → teal |
| Botones | Píldora (StadiumBorder) | SaaS modernos (radio medio o píldora) | ✅ OK; opcional ajustar radio |
| Tipografía | Cupertino → Roboto local, pesos altos | Sans moderna | ✅ Ya alineado |
| Tablas | Grilla del editor monocroma; `AppTable` de `lib/ui/` neutra | Tablas prolatas con header claro | Header/acento de selección a teal (con cuidado) |

**Conclusión:** la estructura ya es "premium light". El trabajo es **recolor a teal**,
concentrado en el acento, **evitando la grilla del editor**.

---

## 5. Archivos que necesitarían cambios visuales (propuesta segura)

| # | Archivo | Cambio propuesto | Riesgo |
|---|---|---|---|
| 1 | `lib/theme/bitflow_colors.dart` | Crear las constantes de marca teal aquí (archivo hoy vacío). Fuente única de verdad del acento. | **NULO** |
| 2 | `lib/theme/gridnote_theme.dart` | Cambiar `accentMono` (light) de `#0D0D0F` al teal de marca. Esto propaga acento a botones, navbar, inputs focus, chips, switches. **Decidir aparte qué pasa con `GridnoteTableStyle` / `dataTableTheme`** (ver §6). | **MEDIO** |
| 3 | `lib/theme/app_theme.dart` | En `fromTheme()`, dejar de derivar `accent = neutralInk` y usar el teal explícito; revisar `statusBg`, `focusRing`, `accentMuted`. | **BAJO** |
| 4 | `lib/ui/app_button.dart` | Reemplazar el literal `0xFF0D0D0F` por el token de acento. | **BAJO** |
| 5 | `lib/start_page_v2.dart` | Reemplazar el literal `0xFF0D0D0F` de `_ActionTile` por el token; verificar contraste del ícono "accent" sobre teal. | **BAJO** |
| 6 | `lib/ui/app_card.dart`, `app_shell.dart` | Solo verificación/afinado de sombras y radios si se quiere acercar al render. | **BAJO** |
| 7 | `lib/widgets/app_background_shell.dart` | Verificar que el fondo decorativo no choque con el teal. | **BAJO** |

> **Importante:** la app tiene **modo claro y oscuro**. Todo cambio de acento debe definir
> el par light/dark (`accentMono` ya distingue ambos). El render de referencia es light;
> mantener el dark coherente sin romperlo.

---

## 6. Decisión clave: la grilla del editor

`accentMono` alimenta **dos cosas**:
1. El acento general de la UI (botones, navbar, inputs, chips) — **seguro de recolorear**.
2. `GridnoteTableStyle` y `dataTableTheme` dentro de `gridnote_theme.dart` —
   define `headingRowColor`, color de fila seleccionada/hover de la grilla del editor.

El encargo dice **"no tocar el comportamiento del DataGrid"**. Cambiar `accentMono`
**no cambia comportamiento**, pero **sí cambia el color de selección/hover de la grilla**.

**Recomendación segura (opción A — preferida):**
Al recolorear, **desacoplar la grilla del acento**: dejar `dataTableTheme` y
`GridnoteTableStyle.from()` con un gris/tinta neutro fijo (su look actual), y aplicar el
teal **solo** al acento de UI general. Así la grilla queda **visualmente intacta** y se
cumple la restricción al 100%.

**Opción B (requiere aprobación explícita):** permitir que el highlight de selección de
la grilla pase a teal. Es solo color (no comportamiento), pero toca la zona sensible;
no se hará sin OK expreso.

---

## 7. Orden de implementación recomendado

1. **Paso 1 — Marca** (`bitflow_colors.dart`): definir constantes teal (light + dark). Compilar.
2. **Paso 2 — Acento de UI** (`gridnote_theme.dart` + `app_theme.dart`): aplicar teal al
   acento general **manteniendo `dataTableTheme`/`GridnoteTableStyle` neutros** (opción A).
3. **Paso 3 — Literales** (`app_button.dart`, `start_page_v2.dart`): reemplazar `0xFF0D0D0F`.
4. **Paso 4 — Verificación de pantallas** light y dark: home, sheets, landing, estáticas.
5. **Paso 5 — Afinado opcional** de sombras/radios en `lib/ui/` para acercar al render.
6. **Paso 6 — QA multiplataforma**: web (Chrome), Windows desktop, layout angosto/ancho.

El editor (`editor_screen.dart`, `grid_host.dart`) **queda fuera de todos los pasos**.

---

## 8. Archivos riesgosos / NO tocar

- **`lib/features/editor/widgets/grid_host.dart`** — DataGrid. **PROHIBIDO.**
- **`lib/features/editor/editor_screen.dart`** y sus `part` — monolito del editor. No tocar.
- **`lib/widgets/smart_datasource.dart`, `lib/smart_sheet/smart_sheet.dart`** — ligados a la grilla.
- **Todo `lib/services/`** — persistencia, sync, engine, exportaciones, auth, Firebase. **Cero cambios.**
- **`lib/services/export_*`, `lib/spreadsheet_agent/export/`, `editor/dialogs/export_dialogs.dart`** — exportaciones. **Prohibido.**
- **`lib/models/`, `lib/core/`, `lib/attachments/`, `lib/workers/`, `lib/platform/`, `lib/web/`** — lógica/plataforma. No tocar.
- **`lib/firebase_options.dart`, `lib/main.dart` (rutas/boot logic)** — no tocar lógica; el splash es solo cosmético y de bajo valor.

---

## 9. Comandos de validación

Ejecutar desde `C:\Users\marco\dev\bitflow_p18`:

```powershell
flutter analyze                       # estático: 0 errores nuevos
flutter test                          # suite de tests (incluye watchdog/editor)
flutter run -d chrome                 # verificación visual web (target principal)
flutter run -d windows                # verificación visual Windows desktop
flutter build web --release           # build web release (pre-entrega)
flutter build windows --release       # build Windows release (pre-entrega)
```

Checklist visual manual (light **y** dark):
- [ ] Home (`start_page_v2`): hero, acciones primarias, panel de recientes — teal coherente.
- [ ] Lista de planillas (`sheets_screen`): app bar, búsqueda, tarjetas `_SheetCard`.
- [ ] Botones primarios/secundarios/ghost: contraste de texto sobre teal.
- [ ] Inputs: borde de foco en teal, legible.
- [ ] NavigationBar / chips / switches: estado seleccionado en teal.
- [ ] **Editor: la grilla se ve idéntica a antes** (selección/hover sin cambios — opción A).
- [ ] Modo oscuro: el teal se ve correcto, sin perder contraste.
- [ ] Windows desktop: scrollbars, hover de mouse, transiciones OK.

---

## 10. Estrategia de rollback

- **Pre-requisito:** confirmar el estado de git de `bitflow_p18`. Si es repo:
  trabajar en rama `redesign/luna-teal`; rollback = `git checkout .` / `git reset --hard`.
  Si NO es repo: `git init` + commit inicial **o** copia de respaldo de `lib/theme/` y `lib/ui/`.
- El cambio es **puramente de color y reversible**: revertir `gridnote_theme.dart`,
  `app_theme.dart`, `bitflow_colors.dart` y los 2 literales devuelve la app al estado actual.
- Cero migraciones de datos, cero cambios de persistencia, cero cambios de servicios.
- Con la **opción A** (grilla desacoplada del acento), el editor no se ve afectado en absoluto,
  lo que hace el rollback aún más acotado.

---

## 11. Próximo paso

**Esperando aprobación explícita** para implementar el rediseño.
Decisión pendiente para el aprobador: **opción A** (grilla intacta, recomendada) vs.
**opción B** (highlight de grilla en teal). Sugerido aprobar **Paso 1 + Paso 2 con opción A**
como prueba visual de bajo riesgo antes de continuar.
