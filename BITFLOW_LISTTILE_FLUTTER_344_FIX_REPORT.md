# BitFlow — Fix Flutter 3.44 ListTile-in-DecoratedBox widget tests

**Branch:** `fix/listtile-decoratedbox-flutter-344`
**Base:** `feature/unified-luna-systems-design`
**Fecha:** 2026-05-22

## 1. Contexto

PR #54 (`fix/gridnote-theme-flutter-344`) dejó el paso **Analyze** de CI en
verde. Con el análisis pasando, el paso **Test** corrió por primera vez en
Flutter 3.44 y reveló **9 fallas de widget tests**, todas con la misma causa.
Es un problema **preexistente**, no introducido por PR #54: estaba enmascarado
porque CI nunca pasaba del paso de análisis.

Esta rama parte de `fix/gridnote-theme-flutter-344` (incluye el fix del
analizador) para que el paso Test de CI pueda ejecutarse y validar este fix.

## 2. Causa raíz

Flutter 3.44 agregó una **nueva aserción de debug en `ListTile`**:

> `ListTile background color or ink splashes may be invisible. The ListTile is
> wrapped in a DecoratedBox that has a background color. Because ListTile
> paints its background and ink splashes on the nearest Material ancestor,
> this DecoratedBox will hide those.`
>
> `To fix this, wrap the ListTile in its own Material widget, or remove the
> background color from the intermediate DecoratedBox.`

La aserción falla cuando un `ListTile` (o subclase: `RadioListTile`,
`SwitchListTile`) tiene, entre él y su `Material` ancestro más cercano, un
`DecoratedBox`/`Container` con color de fondo.

BitFlow tiene ese patrón en dos lugares compartidos:

| Patrón | Archivo | Detalle |
|---|---|---|
| `AppCard` | `lib/ui/app_card.dart` | `AnimatedContainer` con `BoxDecoration(color)` y **sin** `Material` interno. Usado por `AppModal` (`showAppModal`) y por la pantalla **Acerca de**. |
| Hoja Smart Paste | `lib/features/editor/editor_state.dart` | `_showSmartPasteOptionsSheet`: `Container` con `BoxDecoration(color: pal.menuBg)` dentro de un `showModalBottomSheet` con fondo transparente. |

## 3. Tests afectados (9)

| Test file | Test | Widget de origen |
|---|---|---|
| `editor_smart_paste_preview_undo_test.dart` | smart paste detects table and opens preview sheet | Hoja Smart Paste (`RadioListTile`) |
| `editor_smart_paste_preview_undo_test.dart` | smart paste apply shows undo and undo reverts changes | Hoja Smart Paste (`Radio`/`SwitchListTile`) |
| `editor_template_gallery_widget_test.dart` | template gallery applies Inventario template | `AppModal` → `AppCard` (`ListTile`) |
| `about_menu_version_test.dart` | open About from menu and render version row | Pantalla Acerca de → `AppCard` (`ListTile`) |
| `editor_field_workflow_widget_test.dart` | field export copy is human and evidence-focused | `AppModal` export → `AppCard` (`SwitchListTile`) |
| `legal_pages_smoke_test.dart` | About, Privacy and Terms screens build | Pantalla Acerca de → `AppCard` (`ListTile`) |
| `legal_pages_smoke_test.dart` | About screen opens licenses page | Pantalla Acerca de → `AppCard` (`ListTile`) |
| `start_menu_routes_smoke_test.dart` | Start menu routes About/Privacy/Terms/Diagnostics/Licenses | Pantalla Acerca de → `AppCard` (`ListTile`) |
| `start_menu_routes_smoke_test.dart` | Sheets menu routes About/Privacy/Terms/Diagnostics/Licenses | Pantalla Acerca de → `AppCard` (`ListTile`) |

7 fallas convergen en `AppCard`; 2 en la hoja Smart Paste.

## 4. Fix aplicado

Se aplica la solución **recomendada por la propia aserción de Flutter**:
envolver el contenido en un `Material` propio **dentro** del `DecoratedBox`. Se
usa `MaterialType.transparency` (sin color, sin elevación, sin shape) para que
el `ListTile` tenga un `Material` ancestro pero el resultado visual sea
**idéntico**.

### 4.1 `lib/ui/app_card.dart` (fix central)

Se envuelve `widget.child` del `AnimatedContainer` en
`Material(type: MaterialType.transparency, ...)`. Como `AppCard` es el
componente compartido detrás de `AppModal`/`showAppModal` y de la pantalla
Acerca de, este único cambio cubre **7 de las 9 fallas**.

```diff
   boxShadow: widget.shadows ??
         (_hovered && interactive ? t.shadows.card : t.shadows.soft),
   ),
-  child: widget.child,
+  child: Material(
+    type: MaterialType.transparency,
+    child: widget.child,
+  ),
 ),
```

### 4.2 `lib/features/editor/editor_state.dart` (hoja Smart Paste)

La hoja Smart Paste es un `showModalBottomSheet` *ad hoc* con su propio
`Container` decorado; no pasa por `AppCard`. Se envuelve el `Column` interno en
el mismo `Material` transparente. Cubre las **2 fallas restantes**
(`RadioListTile`/`SwitchListTile`). La hoja Smart Paste es un widget del editor,
por lo que el cambio cae dentro del alcance permitido; **no** se tocó la
DataGrid, ni la lógica de pegado/parseo, ni el comportamiento.

## 5. Validación

### Local (Flutter 3.35.6)

> Nota: la aserción es nueva en 3.44, por lo que en 3.35.6 las 9 fallas no se
> reproducen. La validación local confirma que el fix **no introduce
> regresiones**; la corrección de la aserción la valida CI en 3.44.

| Paso | Resultado |
|---|---|
| `flutter clean` / `flutter pub get` | ✅ OK |
| `flutter analyze` | ✅ No issues found |
| `flutter test` | ✅ All tests passed (**173**) |
| `flutter build web --release --no-web-resources-cdn --pwa-strategy=none --base-href /bitacora_web/` | ✅ ✓ Built build\web |

### CI esperado (Flutter 3.44)

- Analyze: verde (fix de PR #54, incluido en esta rama).
- Test: las 9 fallas `ListTile`/`DecoratedBox` quedan resueltas → 173 verde.
- Build web: ejecuta tras Test verde.

## 6. Sin regresión visual ni funcional

- `MaterialType.transparency` no pinta nada (ni color, ni sombra, ni clip): la
  apariencia de las tarjetas, modales y la hoja Smart Paste es **idéntica**.
- En el `AppCard` interactivo, el `Material`+`InkWell` externos (splash de la
  tarjeta) se conservan; el `Material` transparente nuevo sólo da contexto a los
  `ListTile` hijos.
- **DataGrid**: sin cambios. **Export**: sin cambios de lógica. **Servicios /
  modelos / persistencia**: sin tocar. **Lógica de negocio**: sin cambios.

## 7. Alcance / cumplimiento de reglas

- ✅ Sólo 2 archivos modificados: `lib/ui/app_card.dart` y
  `lib/features/editor/editor_state.dart` (sólo la hoja Smart Paste, un widget
  del editor).
- ✅ Diff mínimo (16 líneas, +2 wrappers `Material` transparentes).
- ✅ No se redibujó la UI; apariencia idéntica.
- ✅ No se tocó la DataGrid, export, servicios, modelos ni persistencia.
- ✅ Los archivos *dirty* ajenos (`editor_state.dart` cambios de share,
  `export_share_file_io.dart`) se reservaron con `git stash` y **no** se
  incluyeron en el commit.
- ✅ No se hizo deploy. No se tocó `main`.

## 8. Pendiente

- Revisar este PR (no mergear sin revisión).
- Merge ordenado: PR #54 (analizador) primero o esta rama directamente, ya que
  incluye ambos fixes sobre `feature/unified-luna-systems-design`.
