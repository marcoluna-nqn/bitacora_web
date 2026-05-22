# BitFlow — Fix de CI: `gridnote_theme.dart` (compatibilidad Flutter 3.44)

Fecha: 2026-05-22
Rama: `fix/gridnote-theme-flutter-344` (desde `feature/unified-luna-systems-design`)
PR: #54 → `feature/unified-luna-systems-design` (abierto, **sin mergear**)

---

## Resultado

✅ **Errores del analizador en `gridnote_theme.dart` corregidos.** El paso
"Analyze budget (baseline 0)" de CI pasa en verde.

⚠️ **CI `verify` aún no está 100 % verde**: al destrabarse el análisis, el paso
"Test" reveló **9 fallas preexistentes** de Flutter 3.44 ajenas a este fix
(ver §5). Se documentan para tratarlas por separado.

## 1. Problema

El check `verify` de CI estaba en rojo por errores del analizador en
`lib/theme/gridnote_theme.dart`, en el mapa `pageTransitions` que usa
`CupertinoPageTransitionsBuilder`.

Preexistente en la rama base (viene del commit `868f660` "Apply Luna UI visual
redesign"); **no** lo causó el PR #53.

## 2. Causa raíz

CI corre **Flutter 3.44.0**; el entorno local corre **Flutter 3.35.6**.

En **Flutter 3.44**, `CupertinoPageTransitionsBuilder` se **movió de
`package:flutter/material.dart` a `package:flutter/cupertino.dart`** (breaking
change "Page transition builders reorganization", PR flutter/flutter#179776).

El archivo sólo importaba `material.dart`, por lo que en 3.44 el símbolo quedó
**sin resolver** (`undefined_method`) y, en consecuencia, el mapa `const` también
fallaba (`non_constant_map_value`, `invalid_constant`). En Flutter 3.35.6 el
símbolo seguía en `material.dart`, por eso el análisis local no lo detectaba.

## 3. Fix aplicado

Cambios mínimos, sólo en `lib/theme/gridnote_theme.dart`:

1. **Import de `cupertino.dart`** para obtener `CupertinoPageTransitionsBuilder`
   en Flutter ≥ 3.44:

   ```diff
   + import 'package:flutter/cupertino.dart'; // ignore: unnecessary_import
     import 'package:flutter/material.dart';
   ```

   En Flutter < 3.44 el símbolo aún está en `material.dart`, por lo que ahí el
   import se ve como redundante; se añade `// ignore: unnecessary_import` para
   que el archivo analice limpio en **ambas versiones**. (`unnecessary_ignore`
   no está habilitado en `analysis_options.yaml`, así que el comentario es
   inocuo en 3.44, donde el import sí es necesario.)

2. **`const pageTransitions` → `final pageTransitions`**: evita depender de que
   el constructor de `CupertinoPageTransitionsBuilder` sea `const` entre
   versiones de Flutter. `pageTransitions` sólo se usa dentro de
   `final material = ThemeData(...)` (contexto no-constante).

Sin cambios de comportamiento: las transiciones de página siguen iguales.

Commits: `1c1e060` (const→final) y `8415ecc` (import cupertino + reporte).

## 4. Validación

### Local (Flutter 3.35.6)

| Paso | Resultado |
|---|---|
| `flutter clean` / `flutter pub get` | OK |
| `flutter analyze` | ✅ No issues found |
| `dart scripts/analyze_budget.dart` (CI-equiv, `ANALYZE_BASELINE=0`) | ✅ 0 issues — "Analyze budget check passed" |
| `flutter test` | ✅ All tests passed (173) |
| `flutter build web --release ...` | ✅ ✓ Built build\web |

### CI (Flutter 3.44.0, PR #54 — run 26313328750)

| Paso | Resultado |
|---|---|
| Setup Flutter / pub get | ✅ |
| **Analyze budget (baseline 0)** | ✅ **verde** (el fix de este PR) |
| Test | ❌ 164 pasan, **9 fallan** (ver §5) |
| Build web | — (no se ejecutó, Test falló antes) |

## 5. Hallazgo separado: 9 fallas de test en Flutter 3.44 (fuera de alcance)

Al pasar el análisis, el paso Test corrió por primera vez en 3.44 y reveló 9
fallas, **todas con la misma causa**:

> `ListTile background color or ink splashes may be invisible. The ListTile is
> wrapped in a DecoratedBox that has a background color.`

Flutter 3.44 **agregó una nueva aserción de debug en `ListTile`** que falla
cuando un `ListTile` está dentro de un `Container`/`DecoratedBox` con color de
fondo. BitFlow tiene ese patrón en widgets compartidos de menús/hojas, así que
9 tests de widget fallan (smart-paste preview, galería de plantillas, menú
Acerca de, field workflow, etc.).

Características de este hallazgo:

- **Preexistente** en el código; estaba enmascarado porque CI nunca pasaba del
  paso de análisis.
- **No lo causó este PR** — un ajuste del tema de transiciones no puede afectar
  el anidamiento de `ListTile`.
- **No está en `gridnote_theme.dart`** — está en otros widgets (p. ej. la hoja
  inferior de `_pickStatusForCell` en `editor_state.dart`).
- Corregirlo exige editar archivos **fuera del alcance** de esta tarea (incluido
  `editor_state.dart`, que las reglas vigentes prohíben tocar).

**Recomendación:** tratar las 9 fallas de `ListTile`/`DecoratedBox` en una tarea
aparte (envolver cada `ListTile` afectado en su propio `Material`, o quitar el
color del contenedor intermedio). Este PR #54 se mantiene acotado al fix del
analizador.

## 6. Alcance / cumplimiento de reglas

- ✅ Sólo se modificó `lib/theme/gridnote_theme.dart`.
- ✅ No se tocaron los cambios de UX del editor, la DataGrid, exports,
  servicios, modelos ni persistencia.
- ✅ No se tocaron los archivos *dirty* ajenos (`editor_state.dart`,
  `export_share_file_io.dart`).
- ✅ No se hizo deploy. No se tocó `main`. PR #54 **sin mergear**.

## 7. Pendiente

- Revisar PR #54 (fix del analizador; no mergear sin revisión).
- Tarea separada: corregir las 9 fallas de test `ListTile`-en-`DecoratedBox`
  para dejar CI `verify` 100 % en verde.
