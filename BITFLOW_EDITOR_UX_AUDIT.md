# BitFlow — Auditoría UX del editor / tabla

Fecha: 2026-05-22
Rama base: `feature/unified-luna-systems-design`
Alcance: pase enfocado de UX + pulido visual del editor. No es un rediseño completo.

---

## 1. Archivos inspeccionados

| Archivo | Rol |
|---|---|
| `lib/features/editor/editor_screen.dart` | Punto de entrada; agrupa todos los `part` del editor. |
| `lib/features/editor/editor_state.dart` (~22.5k líneas) | Estado del editor: edición de celda, overlay, navegación, evidencias. |
| `lib/features/editor/widgets/grid_host.dart` | Grilla **personalizada** (`_GridView`, `_DataCell`, `_HeaderCell`, `_RowIndexCell`). |
| `lib/features/editor/actions/editor_shortcuts.dart` | Atajos de teclado a nivel pantalla (cuando NO se está editando). |
| `lib/features/editor/actions/editor_actions.dart` | Acciones de evidencia: foto, video, audio, archivo, GPS, adjuntos. |
| `lib/features/editor/widgets/editor_app_bar.dart` | Cabecera/toolbar premium (`_PremiumAppleHeader`, `_ToolbarMenuButton`). |
| `lib/smart_sheet/smart_sheet.dart`, `lib/screens/xlsx_demo_screen.dart` | Usan Syncfusion `SfDataGrid`, pero son pantallas demo, **no** el editor principal. |

**Hallazgo clave:** el editor principal **no** usa Syncfusion `SfDataGrid`. La grilla es
una implementación propia a base de `InkWell` (`_DataCell`). La edición ocurre en un
**overlay flotante** (`_showOverlayEditor`) anclado a la celda con `CompositedTransformFollower`.

---

## 2. Comportamiento actual de edición

- `_DataCell` envuelve cada celda en un `InkWell` cuyo `onTap` llama `onEditRequested(r, c, w)`
  → `_beginEditCell(...)` → `_scheduleOverlayAtCell(...)` → `_showOverlayEditor(...)`.
- Con **una sola celda y ningún editor abierto**, un clic ya abre el editor (un clic).
- **Problema real (doble clic):** mientras hay un overlay abierto, `_showOverlayEditor`
  monta una barrera a pantalla completa:
  `Positioned.fill(child: GestureDetector(behavior: translucent, onTap: commitAndDismiss))`.
  Esa barrera entra al *gesture arena* y **gana el tap** sobre el `InkWell` de la celda
  destino. Resultado: el **primer clic** sobre otra celda sólo cierra el editor actual; hay
  que hacer un **segundo clic** para abrir el editor de la nueva celda. Eso es el
  "clic doble" que reporta Marco.
- Columna de fotos: el tap abre el flujo de fotos (`_handlePhotosCellTap`).
- Columnas con opciones de estado: el tap abre un `bottomSheet` de selección.

## 3. Comportamiento actual de teclado

**Fuera de edición** (`editor_shortcuts.dart`):
- Flechas → mueven selección.
- `Tab` / `Shift+Tab` → `_moveSelectionFast(vertical: false)` → mueve horizontal.
- `Enter` / `Shift+Enter` → `_moveSelectionFast(vertical: true)` → mueve **hacia abajo/arriba**.
- Carácter imprimible → abre el editor con ese carácter.

**Durante la edición** (overlay, `_showOverlayEditor` → `Focus.onKeyEvent`):
- `Esc` → cancela sin guardar.
- `Cmd/Ctrl+Enter` → confirma y cierra.
- `Tab` / `Shift+Tab` → confirma y va a la celda siguiente/anterior (**derecha/izquierda**).
- `Enter` / `Shift+Enter` → confirma y va a la celda de **abajo/arriba**.
- Flechas → se delegan al `TextField` (mueven el cursor dentro del texto). Correcto.

**Problema reportado:** al terminar de editar y pulsar `Enter`, el foco salta **abajo**.
Marco quiere entrada horizontal rápida tipo planilla: que `Enter` vaya a la **derecha**.

Navegación al final de fila: con `next`, si es la última columna pasa a la primera columna
de la fila siguiente; si no hay fila siguiente, `_insertRow` crea una.

## 4. Comportamiento actual de evidencias / adjuntos

- Acciones reales **ya implementadas** en `editor_actions.dart`:
  `_runPhotoForSelection`, `_runVideoForSelection`, `_runAudioForSelection`,
  `_runFileForSelection`, `_runGpsForSelection`, `_runOpenAttachmentsForSelection`.
  Todas operan sobre la celda seleccionada. **No hay botones falsos**.
- En la grilla: la última columna "Fotos" tiene un ícono de agregar foto; las celdas
  muestran chips (F#, A, GPS) que abren el panel de adjuntos al tocarlos.
- **Problema:** en la toolbar, todas las acciones de evidencia están escondidas dentro de
  un único `PopupMenuButton` ("Evidencia", `_ToolbarMenuButton`). Hay que abrir el menú
  para descubrir Cámara/Video/Audio/GPS/Adjuntos/Archivo. Contradice la propuesta de valor
  ("planillas técnicas con evidencias en campo") y la regla de "no esconder todo en un menú".
- Atajos existentes: `P` foto, `A` audio, `G` GPS (sin modificador).

## 5. Puntos visuales débiles

- La barra de evidencia es sólo una pastilla con menú desplegable → se siente "genérica".
- Las pastillas de la toolbar son todas iguales; no hay jerarquía visual del grupo de
  evidencia (que es el diferencial del producto).
- El editor overlay es funcional pero plano.

## 6. Archivos seguros para modificar

- `lib/features/editor/widgets/editor_app_bar.dart` — añadir grupo visible de evidencia.
- `lib/features/editor/editor_state.dart` → `_showOverlayEditor` (barrera + teclas Enter).
- Nuevo archivo de documentación / reporte.

## 7. Archivos / zonas a NO tocar (riesgo alto)

- Modelos, servicios y lógica de export (`services/`, `models/`).
- `_RowModel`, `_setCell`, `_commitDraftCell`, datasource y persistencia.
- `smart_sheet.dart` / Syncfusion (no es el editor real; no aporta).
- Lógica de `_overlayCommitAndNavigate` salvo el mapeo de teclas.

## 8. Plan de cambios (mínimo y reversible)

1. **Edición de un clic:** cambiar la barrera del overlay de `GestureDetector(onTap)` a
   `Listener(onPointerDown)`; así confirma al bajar el puntero y deja pasar el clic al
   `InkWell` de la celda destino → un solo clic abre el nuevo editor.
2. **Teclado:** en el overlay, `Enter` → celda derecha (`next`), `Shift+Enter` → izquierda
   (`prev`). `Tab`/`Shift+Tab` se mantienen. Para bajar: `Ctrl/Cmd+Enter` confirma y luego
   flechas, o clic directo.
3. **Evidencia visible:** reemplazar el `PopupMenuButton` "Evidencia" por un grupo
   segmentado visible (Cámara, Video, Audio, GPS, Archivo, Adjuntos) en la toolbar.
4. **Pulido visual:** estilo del grupo de evidencia y del overlay acorde a Luna premium.
