# BitFlow — Fix de CI: `gridnote_theme.dart` (compatibilidad Flutter 3.44)

Fecha: 2026-05-22
Rama: `fix/gridnote-theme-flutter-344` (desde `feature/unified-luna-systems-design`)

---

## Problema

El check `verify` de CI estaba en rojo por **13 errores del analizador** en
`lib/theme/gridnote_theme.dart` (líneas 163–168):

- `invalid_constant`
- `undefined_method` — "The method 'CupertinoPageTransitionsBuilder' isn't defined..."
- `non_constant_map_value` — "The values in a const map literal must be constant"

Preexistentes en la rama base (vienen del commit `868f660` "Apply Luna UI visual
redesign"); **no** los causó el PR #53.

## Causa raíz

CI corre **Flutter 3.44.0**; el entorno local corre **Flutter 3.35.6**.

Desde Flutter 3.44, el constructor de `CupertinoPageTransitionsBuilder` **dejó de ser
`const`**. El archivo declaraba el mapa de transiciones como literal constante:

```dart
const pageTransitions = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    ...
  },
);
```

Al no ser `const` el constructor, el literal `const` ya no es válido en 3.44 → 13
errores (uno `invalid_constant` + 2 por cada una de las 6 entradas del mapa). En 3.35.6
el constructor aún era `const`, por eso el análisis local no lo detectaba.

## Fix aplicado

Cambio mínimo (1 palabra) en `lib/theme/gridnote_theme.dart`:

```diff
- const pageTransitions = PageTransitionsTheme(
+ final pageTransitions = PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
```

`final` en lugar de `const`: el mapa pasa a ser no-constante, por lo que invocar el
constructor (sea `const` o no) es válido. Es compatible **hacia atrás** (funciona en
3.35.6 y en 3.44) y **hacia adelante**.

`pageTransitions` sólo se usa en `pageTransitionsTheme: pageTransitions` dentro de
`final material = ThemeData(...)` — un contexto no-constante — así que pasar de `const` a
`final` no afecta a ningún otro uso.

Sin cambios en comportamiento de la app: las transiciones siguen siendo las mismas.

## Validación local

| Paso | Resultado |
|---|---|
| `flutter clean` | OK |
| `flutter pub get` | OK |
| `flutter analyze` | ✅ No issues found |
| `dart scripts/analyze_budget.dart` (CI-equivalente, `ANALYZE_BASELINE=0`) | ✅ Total issues: 0 — "Analyze budget check passed" |
| `flutter test` | ✅ All tests passed (173) |
| `flutter build web --release --no-web-resources-cdn --pwa-strategy=none --base-href /bitacora_web/` | ✅ ✓ Built build\web |

Nota: el entorno local es Flutter 3.35.6, donde el archivo ya analizaba limpio antes y
después del cambio. La verificación definitiva en Flutter 3.44 es el propio check `verify`
de CI sobre el PR de esta rama; el fix está construido para ser correcto en ambas
versiones.

## Alcance / cumplimiento de reglas

- ✅ Sólo se modificó `lib/theme/gridnote_theme.dart` (1 línea efectiva).
- ✅ No se tocaron los cambios de UX del editor.
- ✅ No se tocó la DataGrid, exports, servicios, modelos ni persistencia.
- ✅ No se tocaron los archivos *dirty* ajenos (`editor_state.dart`,
  `export_share_file_io.dart`).
- ✅ No se hizo deploy. No se tocó `main`.
