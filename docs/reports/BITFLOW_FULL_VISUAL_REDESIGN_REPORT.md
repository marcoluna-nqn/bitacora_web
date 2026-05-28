# BitFlow Full Visual Redesign Report

Date: 2026-05-21

## Scope

BitFlow was moved toward the Luna Systems light premium product family while keeping the editor, DataGrid workflow, local persistence, and export paths functionally intact.

## Files changed

- `lib/main.dart`
- `lib/start_page_v2.dart`
- `lib/theme/bitflow_colors.dart`
- `lib/theme/gridnote_theme.dart`
- `lib/theme/app_theme.dart`
- `lib/ui/app_button.dart`
- `lib/ui/app_table.dart`

Pre-existing unrelated work was preserved and not staged as part of this redesign:

- `lib/features/editor/editor_state.dart`
- `lib/services/export_share_file_io.dart`
- `.claude/`
- `BITFLOW_VISUAL_AUDIT.md`
- `CLAUDE_DESIGN_PROMPT.md`
- `ORCHESTRATION_REPORT.md`
- `artifacts/`

## Design changes

- Added a dedicated BitFlow/Luna palette with cold light background `#F6F8FB`, white surfaces, soft borders, teal accent `#0E9F8E`, teal soft surface `#E2F4F1`, and shared status colors.
- Made the app default to light mode so public demo/review sessions open in the intended Luna Systems visual direction.
- Updated global app tokens to use the new palette for surfaces, muted surfaces, borders, status colors, shadows, and focus states.
- Recolored the Start/Home experience with a teal product tile, white rounded cards, cleaner icon tiles, soft shadows, and stronger SaaS hierarchy.
- Polished primary action cards so the main `Nuevo relevamiento` action reads as a modern teal CTA, while secondary actions remain white cards.
- Updated shared table styling for presentation tables with teal-muted headers.
- Kept destructive buttons readable by forcing white foreground text on the red destructive fill.

## DataGrid and editor checks

- Did not modify `grid_host.dart`, `smart_datasource.dart`, editor cell editing logic, persistence services, export services, or platform build files.
- Decoupled the Syncfusion/DataGrid table accent from the global teal accent by introducing a neutral `tableAccent` for DataTable selection/header skinning.
- Preserved the dense grid layout and editor toolbar behavior.
- Opened the real editor from the built web app using the visible `Nuevo relevamiento` flow.
- Confirmed the table renders, selected cell remains visible, toolbar buttons remain available, and horizontal width stays contained inside the grid/editor surface.
- Checked editor widths at 1920, 1280, and 1024 px with screenshots saved in the review folder.

## Export checks

- Opened the real `Exportar` dialog from the editor toolbar.
- Confirmed PDF, Excel, evidence toggle, generate, share, and package-with-evidence actions remain visible.
- Export implementation files were intentionally not changed.

## Validation commands and results

- `flutter pub get`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test`: passed, 173 tests.
- `flutter build web`: passed and built `build\web`.
- `flutter build windows`: skipped by configuration; Flutter reports `No Windows desktop project configured`.
- `flutter run -d windows`: not run because this repo has no Windows desktop project configured.

Notes:

- `flutter build web` emitted existing wasm dry-run warnings from web/JS dependencies such as `flutter_secure_storage_web` and `package:js`; the standard web build succeeded.
- Dependency commands report many newer packages incompatible with current constraints; no dependency versions were changed.

## Screenshots

Main review folder:

- `C:\demo comerciales\visual_redesign_review\bitflow_main_after.png`
- `C:\demo comerciales\visual_redesign_review\bitflow_table_after.png`
- `C:\demo comerciales\visual_redesign_review\bitflow_export_after.png`
- `C:\demo comerciales\visual_redesign_review\bitflow_redesign_contact_sheet.png`

Additional viewport evidence:

- `C:\demo comerciales\visual_redesign_review\bitflow_table_1920_check.png`
- `C:\demo comerciales\visual_redesign_review\bitflow_table_1280_check.png`
- `C:\demo comerciales\visual_redesign_review\bitflow_table_1024_check.png`

## Known risks

- Windows desktop could not be built or manually run because the repository does not contain a configured Windows desktop project.
- The editor grid still intentionally keeps a technical spreadsheet density; it is visually softened but not transformed into a low-density dashboard.
- The first-run/tutorial surfaces still appear for fresh profiles until dismissed, which is existing behavior.

## Intentionally not changed

- Data models.
- Persistence and local store logic.
- PDF/XLSX/export logic.
- Evidence/attachment services.
- Syncfusion DataGrid core behavior.
- Cell editing logic.
- Smart datasource behavior.
- Routing/navigation behavior, except for the visual-only default light-mode startup.
- Firebase/options/build/platform configuration.
