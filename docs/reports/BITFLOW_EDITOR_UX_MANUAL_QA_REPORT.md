# BitFlow — Reporte de QA manual del editor (UX)

Fecha: 2026-05-22
Rama: `ux/editor-fast-entry-evidence`
Commit verificado: `bddb1c9` — "Improve BitFlow editor UX and evidence actions"
Objetivo: verificar los cambios de UX del editor **antes de push/deploy**.

---

## Resultado global: ✅ APROBADO

Todas las verificaciones solicitadas pasaron. Sin bloqueantes para revisión final.

---

## 1. Checks automáticos

| Check | Comando | Resultado |
|---|---|---|
| Análisis estático | `flutter analyze` | ✅ **No issues found** (proyecto completo) |
| Pruebas | `flutter test` | ✅ **All tests passed** — 173 pruebas |
| Build web | `flutter build web --release --no-web-resources-cdn --pwa-strategy=none --base-href /bitacora_web/` | ✅ **✓ Built build\web** |

Nota: el build web emite advertencias *Wasm dry run* de `flutter_secure_storage_web`
(`dart:html` / `dart:js`). Son **preexistentes** y ajenas a esta rama; no afectan el
build JS (`✓ Built`).

## 2. QA interactivo (build web servido localmente, Chromium)

Sesión guiada en el editor (planilla nueva en blanco). Capturas en
`artifacts/qa_editor_ux/`.

| # | Verificación | Resultado | Evidencia |
|---|---|---|---|
| 1 | Editar A1 con mouse | ✅ Un solo clic abre el editor de celda | `01_a1_editor_open.png` |
| 2 | Clic en B1 mientras se edita A1 | ✅ Confirma A1 (`A1VAL`) y abre B1 **en un solo clic** | `03_clicked_b1.png` |
| 3 | Escribir valor + `Enter` | ✅ Confirma B1 (`B1VAL`) y se mueve a la **derecha** (C1) | `04_enter_right.png` |
| 4 | `Shift+Enter` | ✅ Confirma C1 (`C1VAL`) y se mueve a la **izquierda** (B1) | `05_shift_enter_left.png` |
| 5 | `Tab` / `Shift+Tab` | ✅ `Tab` → C1; `Shift+Tab` → B1 | `06_tab_right.png`, `07_shift_tab_left.png` |
| 6 | Fin de fila envuelve a la fila siguiente | ✅ 22×`Tab` desde B1 → llega a fila 2 (`Celda J2`), sin crash, valores intactos | `08_row_wrap.png` |
| 7 | Los valores confirman correctamente | ✅ `A1VAL`/`B1VAL`/`C1VAL` persisten tras navegar, `Esc` y reselección | `09_after_escape.png`, `10_adjuntos_panel.png` |
| 8 | Toolbar de evidencia visible | ✅ Cámara · Video · Audio · GPS · Adjuntos · Archivo, visibles en 1920/1280/1024 | `00`, `11`, `12` |
| 9 | Botones de evidencia que existen funcionan | ✅ "Adjuntos" disparó la acción real (feedback "Sin evidencias en A1.") | `10_adjuntos_panel.png` |
| 10 | Sin botones falsos | ✅ Las 6 acciones llaman funciones reales implementadas (`editor_actions.dart`) | — |
| 11 | Sin overflow horizontal de página | ✅ `scrollWidth == innerWidth` en 1920, 1280 y 1024 | medición JS |
| 12 | Sin RenderFlex overflow | ✅ Sin contenido recortado/encimado; ver §3 | capturas + tests |
| 13 | Editor usable en 1920 / 1280 / 1024 | ✅ Toolbar envuelve limpiamente; grilla con scroll horizontal interno | `11`, `12`, `13` |
| 14 | Acciones de export visibles | ✅ Botón "Exportar" presente en los 3 anchos | `00`, `11`, `12` |

### Detalle de la edición de un clic (verificación clave)
Antes de este pase hacía falta **doble clic** para pasar de una celda a otra mientras se
editaba. La captura `03_clicked_b1.png` confirma la corrección: con el editor de A1
abierto, **un solo clic** en B1 confirma `A1VAL` en A1 y abre el editor de B1
simultáneamente. El chip de selección de la toolbar pasa de "Celda A1" a "Celda B1".

### Detalle navegación de teclado
- `Enter` mueve a la **derecha** (no hacia abajo) — entrada horizontal rápida tipo planilla.
- `Shift+Enter` mueve a la **izquierda**.
- `Tab` / `Shift+Tab` mantienen derecha / izquierda.
- En el extremo de fila, `Tab` envuelve a la **primera celda editable de la fila
  siguiente** (se observó el salto de fila 1 → fila 2, columna J). Si no existe fila
  siguiente se crea una nueva (comportamiento por diseño, no se forzó en esta QA porque
  la fila destino ya existía).
- El valor **se confirma antes de moverse** en todos los casos.

### Detalle evidencias
- El grupo "Evidencia" es visible directamente en la toolbar (ya no es un menú oculto).
- Se probó interactivamente **"Adjuntos"**: ejecutó la acción real y dio feedback
  ("Sin evidencias en A1."). No es un botón falso.
- Cámara, Video, Audio, GPS y Archivo abren *pickers*/permisos del sistema operativo, por
  lo que no se dispararon mediante automatización (colgarían el navegador headless). Se
  confirmó por código que están cableados a funciones reales y ya implementadas
  (`_runPhotoForSelection`, `_runVideoForSelection`, `_runAudioForSelection`,
  `_runFileForSelection`, `_runGpsForSelection` en `editor_actions.dart`). **No hay
  botones falsos.**

## 3. Notas sobre detección de overflow

- **Overflow de página:** medido por JavaScript (`document.body.scrollWidth` vs
  `window.innerWidth`) en los 3 anchos → **iguales**, sin overflow de página. La grilla
  conserva su scroll horizontal **dentro** de su contenedor (correcto).
- **RenderFlex overflow:** un build `--release` de Flutter Web **no dibuja** las franjas
  amarillas/negras ni imprime errores de overflow, por lo que no es detectable visualmente
  con total certeza en release. Mitigación: `flutter test` (173 pruebas, incluidas
  pruebas de layout del editor y de escalas de texto grandes) **pasó** — un RenderFlex
  overflow lanza excepción en modo test y habría hecho fallar esas pruebas. Las capturas
  en los 3 anchos tampoco muestran contenido recortado ni encimado. Recomendación: una
  verificación adicional rápida en un *run* `debug` si se quiere certeza visual del 100 %.

## 4. Estado del árbol de trabajo

- QA realizada sobre la rama `ux/editor-fast-entry-evidence` en el commit `bddb1c9`.
- El árbol de trabajo conserva cambios **sin commitear, preexistentes y ajenos** a este
  pase (`lib/features/editor/editor_state.dart` hunk de "compartir en móvil" y
  `lib/services/export_share_file_io.dart`). **No se tocaron** y **no se incluyen** en
  ningún commit de esta QA. Esos cambios pertenecen a la ruta de *share* en móvil y no
  afectan ninguna superficie verificada aquí (edición de celda, navegación por teclado,
  toolbar de evidencia — todo UI de escritorio/grilla).

## 5. Conclusión

Los cambios de UX del editor del commit `bddb1c9` funcionan según lo previsto:

- Edición de celda de **un solo clic** (incluido el cambio de celda durante la edición).
- `Enter` mueve a la **derecha**; `Shift+Enter` a la izquierda; `Tab`/`Shift+Tab` ok;
  envoltura de fila segura; los valores se confirman correctamente.
- Toolbar de evidencia **visible y funcional**, sin botones falsos.
- Sin overflow horizontal de página; usable en 1920/1280/1024; export visible.
- `analyze`, `test` y `build web` en verde.

**Listo para revisión.** No se hizo push ni deploy.
