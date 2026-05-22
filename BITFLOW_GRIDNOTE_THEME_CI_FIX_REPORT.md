# BitFlow — Fix de CI: `gridnote_theme.dart` (compatibilidad Flutter 3.44)

Fecha: 2026-05-22
Rama: `fix/gridnote-theme-flutter-344` (desde `feature/unified-luna-systems-design`)

---

## Problema

El check `verify` de CI estaba en rojo por errores del analizador en
`lib/theme/gridnote_theme.dart`, en el mapa `pageTransitions` que usa
`CupertinoPageTransitionsBuilder`.

Preexistente en la rama base (viene del commit `868f660` "Apply Luna UI visual
redesign"); **no** lo causó el PR #53.

## Causa raíz

CI corre **Flutter 3.44.0**; el entorno local corre **Flutter 3.35.6**.

En **Flutter 3.44**, `CupertinoPageTransitionsBuilder` se **movió de
`package:flutter/material.dart` a `package:flutter/cupertino.dart`**
(breaking change "Page transition builders reorganization", PR flutter/flutter#179776).

El archivo sólo importaba `material.dart`, por lo que en 3.44 el símbolo quedó
**sin resolver**. El analizador lo reportó como `undefined_method` y, en
consecuencia, el mapa `const` también fallaba (`non_constant_map_value`,
`invalid_constant`). En Flutter 3.35.6 el símbolo seguía en `material.dart`, por
eso el análisis local no detectaba el problema.

## Fix aplicado

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
   inocuo en 3.44 donde el import sí es necesario.)

2. **`const pageTransitions` → `final pageTransitions`**: evita depender de que
   el constructor de `CupertinoPageTransitionsBuilder` sea `const` entre
   versiones de Flutter. `pageTransitions` sólo se usa dentro de
   `final material = ThemeData(...)` (contexto no-constante), así que el cambio
   no afecta a ningún otro uso.

Sin cambios de comportamiento: las transiciones de página siguen siendo las
mismas (estilo iOS en todas las plataformas).

## Validación local (Flutter 3.35.6)

| Paso | Resultado |
|---|---|
| `flutter clean` | OK |
| `flutter pub get` | OK |
| `flutter analyze` | ✅ No issues found |
| `dart scripts/analyze_budget.dart` (CI-equivalente, `ANALYZE_BASELINE=0`) | ✅ Total issues: 0 — "Analyze budget check passed" |
| `flutter test` | ✅ All tests passed (173) |
| `flutter build web --release --no-web-resources-cdn --pwa-strategy=none --base-href /bitacora_web/` | ✅ ✓ Built build\web |

Nota: el entorno local es Flutter 3.35.6. La verificación definitiva en Flutter
3.44 es el check `verify` de CI sobre el PR de esta rama (PR #54). El fix está
construido para ser correcto y analizar limpio en **ambas** versiones.

## Alcance / cumplimiento de reglas

- ✅ Sólo se modificó `lib/theme/gridnote_theme.dart`.
- ✅ No se tocaron los cambios de UX del editor.
- ✅ No se tocó la DataGrid, exports, servicios, modelos ni persistencia.
- ✅ No se tocaron los archivos *dirty* ajenos (`editor_state.dart`,
  `export_share_file_io.dart`).
- ✅ No se hizo deploy. No se tocó `main`.
