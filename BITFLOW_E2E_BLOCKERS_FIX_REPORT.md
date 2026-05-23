# BitFlow E2E Blockers Fix Report

Date: 2026-05-23
Branch: feature/unified-luna-systems-design

## Summary

BitFlow was moved from the E2E QA NO-GO blockers toward CONDITIONAL GO by fixing the two paid-pilot critical paths:

- Printable grid input no longer triggers bare evidence shortcuts. One-click cell editing preserves the first typed character, including `A`.
- Package export no longer creates dangling evidence references. Attachment bytes are included in the ZIP when available, and missing binaries are blocked with a clear ZIP-specific error.
- Public/client-facing release builds no longer show the confusing demo-login notice by default, and release export metadata no longer falls back to `dev`/`0.0.0` when build defines are absent.

No Caja Clara files, Luna landing files, deploys, pushes, or force-pushes were performed.

## Fixes Made

### 1. Grid printable input vs evidence shortcuts

Changed `lib/features/editor/actions/editor_shortcuts.dart` so bare `A`, `P`, and `G` no longer trigger Audio, Photo, or GPS actions. Those actions remain available through toolbar buttons and modifier shortcuts:

- Photo: `Ctrl/Cmd+P`
- GPS: `Ctrl/Cmd+G`
- Audio: `Ctrl/Cmd+Shift+A`

Updated command palette shortcut labels in `lib/features/editor/actions/editor_actions.dart`.

### 2. Package ZIP evidence binaries

Added `lib/services/package_archive_builder.dart` to centralize package ZIP creation. The builder:

- Adds `export.xlsx`.
- Adds every referenced attachment binary at its manifest path.
- Adds `manifest.json` and `sheet.json`.
- Throws `MissingPackageAssetException` before producing a misleading ZIP if any referenced asset has no readable bytes.

Updated `lib/features/editor/editor_state.dart` so package export uses that builder and reports a ZIP-specific missing-attachment message.

Fixed web attachment readback in `lib/services/web_blob_store_web.dart` by keeping original `Uint8List` bytes in the in-session memory cache after IndexedDB/cache saves. This is what made immediate package export able to include a newly attached file binary.

### 3. Public demo/dev state

Added `RuntimeFlags.showDemoNotice`, defaulting to false, and gated the demo-login notice behind it. Release build metadata now falls back to `release` instead of `dev` for empty build defines.

## Regression Tests Added

- `test/editor_live_cell_editing_feedback_test.dart`
  - Clicking a cell and typing `ABC` preserves `ABC`.
  - Bare `A` does not open Audio/microphone flow while editing.
  - Enter, Shift+Enter, Tab, and Shift+Tab navigation still work.

- `test/package_archive_builder_test.dart`
  - Package archive includes referenced attachment binaries.
  - Manifest asset path matches a real ZIP entry.
  - Dangling evidence references throw `MissingPackageAssetException`.

## Validation Commands

Commands run:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test test\editor_live_cell_editing_feedback_test.dart --reporter expanded
flutter test test\editor_export_active_drafts_test.dart --reporter expanded
flutter test test\package_archive_builder_test.dart --reporter expanded
flutter test --reporter expanded
flutter build web --release --no-web-resources-cdn --pwa-strategy=none --base-href /bitacora_web/
```

Final validation status:

- `flutter analyze`: PASS
- focused regression tests: PASS
- full `flutter test`: PASS, 179 tests
- release web build: PASS

Build note: Flutter emitted existing Wasm dry-run incompatibility warnings from `flutter_secure_storage_web`/`dart:html` dependencies. The requested JS web release build still completed successfully.

## Manual Browser QA

Local release build was served under `/bitacora_web/` and tested with Playwright/Chromium.

Results:

- App loaded with no console/page errors.
- Home did not show the previous confusing demo-login notice.
- Editor opened from new sheet flow.
- Evidence toolbar remained visible: Camera, Video, Audio, GPS, Attachments, File.
- One-click cell edit then typing `ABC` showed `ABC`; no microphone permission flow opened.
- Enter/Shift+Enter/Tab/Shift+Tab navigation was exercised and remained stable.
- Sample file attachment succeeded and displayed in the grid.
- Standalone XLSX export downloaded and opened with `openpyxl`.
- Package ZIP export downloaded.
- ZIP inspection confirmed:
  - `export.xlsx` exists.
  - `manifest.json` exists.
  - `sheet.json` exists.
  - `attachments/files/B1_p1_sample_photo.png` exists.
  - Manifest asset path exactly matches the ZIP entry.
  - Attachment binary size is 68 bytes, matching the uploaded sample.
- 390px viewport check reported no document horizontal overflow (`scrollWidth == innerWidth == 390`).

Manual artifacts generated under `artifacts/`:

- `artifacts/bitflow_fix_abc.png`
- `artifacts/bitflow_fix_navigation.png`
- `artifacts/bitflow_fix_final_attachment.png`
- `artifacts/bitflow_fix_final_package_result.png`
- `artifacts/bitflow_fix_mobile_390.png`
- `artifacts/bitflow_fix_manual_export.xlsx`
- `artifacts/bitflow_fix_manual_package.zip`

These artifacts were not staged for commit.

## Export Verification Details

Package ZIP:

```text
ZIP: artifacts/bitflow_fix_manual_package.zip
Entries:
- export.xlsx
- attachments/files/B1_p1_sample_photo.png
- manifest.json
- sheet.json
Manifest asset path: attachments/files/B1_p1_sample_photo.png
ZIP asset present: yes
ZIP asset bytes: 68
Manifest appVersion/buildId: release/release
```

Standalone XLSX:

```text
XLSX: artifacts/bitflow_fix_manual_export.xlsx
Sheets:
- Relevamiento 2026-05-23 18 15
- Adjuntos
- Caratula
- Resumen
- _BITFLOW_META
Contains edited value ABC: yes
Contains sample_photo evidence text: yes
```

## Remaining Limitations

- Browser file picker automation was possible in Playwright, but native OS picker UI itself was not visually driven; Playwright supplied the test file directly.
- This was a local release-build verification. No public GitHub Pages deploy was performed.
- No Caja Clara or Luna Systems landing validation was rerun as part of this fix task.

## Commercial Verdict

BitFlow status after fixes: CONDITIONAL GO for paid pilot.

Remaining pilot condition: run one final QA pass on the actual deployed public URL after deployment, because this task intentionally did not deploy.
