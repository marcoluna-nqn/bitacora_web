# BitFlow — Reporte del pase de refinamiento UX del editor

Fecha: 2026-05-22
Rama de trabajo: `ux/editor-fast-entry-evidence` (creada desde `feature/unified-luna-systems-design`)
Alcance: pase enfocado de UX + pulido visual. No es un rediseño completo.

---

## 1. Archivos cambiados

| Archivo | Cambio |
|---|---|
| `lib/features/editor/editor_state.dart` | Edición de un clic entre celdas + `Enter` mueve a la derecha (overlay editor). |
| `lib/features/editor/widgets/editor_app_bar.dart` | Grupo de evidencia visible en la toolbar (`_EvidenceActionGroup` / `_EvidenceButton`); "Modo GPS" movido al menú "Más". |
| `BITFLOW_EDITOR_UX_AUDIT.md` | Auditoría previa (nuevo). |
| `BITFLOW_EDITOR_UX_REFINEMENT_REPORT.md` | Este reporte (nuevo). |

Sin cambios en modelos, servicios, datasource, lógica de export ni persistencia.

> Nota: el árbol de trabajo ya tenía, **antes de este pase**, cambios sin commitear
> ajenos a esta tarea (mejora de "compartir en móvil con fallbacks" en
> `editor_state.dart` y `lib/services/export_share_file_io.dart`). Esos cambios se
> **dejaron fuera del commit** y siguen presentes sin commitear; este commit contiene
> únicamente el trabajo de UX del editor.

## 2. Edición de celda — antes / después

- **Antes:** con un editor abierto, hacía falta hacer **doble clic** para editar otra
  celda. El primer clic sólo lo absorbía la barrera del overlay (`GestureDetector` con
  `onTap`), que ganaba el *gesture arena* a la celda destino.
- **Después:** la barrera de cierre es ahora un `Listener` (`onPointerDown`) que **no**
  entra al *gesture arena*. Al bajar el puntero confirma el valor y cierra el editor,
  y el mismo clic llega al `InkWell` de la celda destino → **un solo clic** abre el
  editor de la nueva celda.
- Se identifica el puntero que cae dentro del editor (`editorPointerDownId`) para que la
  barrera no confirme cuando el usuario interactúa con el propio editor.
- Sin cambios en el commit/cancel de valores ni en la lógica de actualización de datos.

## 3. Navegación por teclado — antes / después

Durante la edición (overlay editor):

| Tecla | Antes | Después |
|---|---|---|
| `Tab` / `Shift+Tab` | Celda derecha / izquierda | Celda derecha / izquierda *(sin cambio)* |
| `Enter` | Celda **abajo** | Celda **derecha** (siguiente editable) |
| `Shift+Enter` | Celda **arriba** | Celda **izquierda** (anterior editable) |
| `Cmd/Ctrl+Enter` | Confirma y cierra | Confirma y cierra *(sin cambio)* |
| `Esc` | Cancela sin guardar | Cancela sin guardar *(sin cambio)* |
| Flechas | Mueven el cursor dentro del texto | Igual *(sin cambio)* |

- El valor **se confirma antes de moverse** (igual que antes).
- **Fin de fila:** al ir a la derecha desde la última columna, pasa a la **primera
  columna editable de la fila siguiente**; si no hay fila siguiente, se **crea una nueva
  fila** automáticamente (comportamiento conservado, útil para carga rápida).
- **Para bajar:** `Cmd/Ctrl+Enter` confirma y cierra, luego flechas; o clic directo en la
  celda destino (ahora de un solo clic).
- Fuera de edición, los atajos a nivel pantalla no cambiaron (flechas mueven selección;
  `Enter` navega hacia abajo entre celdas seleccionadas).

## 4. Acciones de evidencia / adjuntos — antes / después

- **Antes:** todas las acciones de evidencia estaban escondidas dentro de un único
  menú desplegable ("Evidencia", `PopupMenuButton`). Había que abrir el menú para
  descubrirlas.
- **Después:** grupo de evidencia **visible** en la toolbar (`_EvidenceActionGroup`):
  una tarjeta segmentada con etiqueta "Evidencia" y botones directos, cada uno con
  ícono + texto y tooltip:
  - **Cámara** (foto) — `P`
  - **Video**
  - **Audio** — `A`
  - **GPS** — `G`
  - **Adjuntos** (abre el panel de adjuntos)
  - **Archivo** (adjuntar documento)
- Todas son acciones **reales ya implementadas** (`editor_actions.dart`). No se agregaron
  botones falsos ni funcionalidad inventada.
- "Modo GPS" (un selector de configuración, baja frecuencia de uso) se movió al menú
  "Más" para no recargar el grupo; **no se eliminó**.
- **"Agregar observación":** BitFlow no tiene una acción de evidencia separada para
  "observación"; las observaciones se cargan como texto en cualquier columna de la
  planilla. No se creó un botón falso para esto. **Pendiente** si se desea una acción
  dedicada (no implementada hoy).
- En la grilla siguen disponibles los accesos previos: ícono de agregar foto en la
  columna "Fotos" y chips (F#, A, GPS) que abren el panel de adjuntos.

## 5. Refinamiento visual

Pase **conservador** (el rediseño Luna ya se había aplicado; se evitó churn de riesgo
sobre la grilla):

- Nuevo grupo de evidencia con estilo Luna premium: tarjeta segmentada con tinte teal
  suave, borde fino, etiqueta "Evidencia" en acento teal, divisor sutil y *hover* teal
  en cada botón. Da jerarquía visual al diferencial del producto.
- No se tocaron densidad de la grilla, encabezados, banda de índice ni el editor overlay,
  para no arriesgar comportamiento (regla "no romper la DataGrid").

## 6. Resultados de validación

Comandos ejecutados (tras los cambios):

| Paso | Resultado |
|---|---|
| `flutter clean` | OK |
| `flutter pub get` | OK |
| `flutter analyze` | **No issues found** (proyecto completo) |
| `flutter test` | **All tests passed** (173 tests) |
| `flutter build web --release --no-web-resources-cdn --pwa-strategy=none --base-href /bitacora_web/` | **✓ Built build\web** |

Verificación manual con build web servido localmente y Chromium (Playwright) en 1920,
1280 y 1024 px:

- Home y editor abren correctamente.
- La celda se edita con **un clic** (overlay editor abre directo).
- El grupo de evidencia es **visible** en la toolbar en los 3 anchos.
- La toolbar **envuelve** (Wrap) sin overflow horizontal de página en 1280 y 1024.
- La grilla mantiene su scroll horizontal dentro del contenedor.
- Sin RenderFlex overflow observado.
- Acciones de export ("Exportar", "Compartir") siguen presentes.

Nota sobre el build web: aparecen advertencias *Wasm dry run* de
`flutter_secure_storage_web` (`dart:html` / `dart:js`). Son **preexistentes**, ajenas a
este pase, y no afectan el build JS (`✓ Built build\web`).

## 7. Capturas

- `C:\demo comerciales\visual_redesign_review\bitflow_editor_ux_after.png` (1920×1080)
- `C:\demo comerciales\visual_redesign_review\bitflow_evidence_actions_after.png` (1280×860)
- `C:\demo comerciales\visual_redesign_review\bitflow_grid_navigation_after.png` (1024×768, editor de celda abierto)

## 8. Riesgos conocidos

- La edición de un clic depende del orden de *hit-testing* del overlay (editor sobre la
  barrera). Validado por análisis y por las pruebas existentes; conviene una prueba
  manual extra de "editar A1 → clic en B1 → editar" antes de publicar.
- El grupo de evidencia es ancho (~6 botones con etiqueta). En UI de escritorio (≥1024)
  entra y/o envuelve sin overflow; el editor de escritorio no se usa por debajo de ese
  ancho (ahí entra `_MobileCompactHeader`).
- `Enter` ya no baja durante la edición; es un cambio de hábito intencional. Documentado
  arriba (usar `Ctrl/Cmd+Enter` + flechas, o clic directo, para bajar).

## 9. Lo que NO se cambió (intencional)

- Modelos, servicios, datasource, lógica de export y persistencia.
- Comportamiento de commit/cancel de celdas y de la grilla personalizada.
- `smart_sheet.dart` / Syncfusion (no es el editor real).
- Densidad, encabezados y banda de índice de la grilla.
- Atajos de teclado a nivel pantalla (fuera de edición).
- Los cambios preexistentes de "compartir en móvil" quedaron sin commitear (ver §1).
