# BitFlow First-Character Cell Edit Fix Report

Date: 2026-05-23

## Summary

Fixed the desktop grid editor race where the first printable key could be lost after a single-click cell edit.

The bug happened during the short handoff between opening the overlay editor and the `TextField` becoming the focused `EditableText`. While the overlay existed, the main editor shortcut handler ignored printable keys instead of routing them to the pending cell editor.

## Files changed

- `lib/features/editor/actions/editor_shortcuts.dart`
- `test/editor_live_cell_editing_feedback_test.dart`

## Fix

When the cell editor overlay is open but focus has not yet landed on an `EditableText`, printable key-down events are now inserted directly into the active cell editor controller using the current selection. The cell editor then requests focus so subsequent typing continues normally.

This keeps the existing one-click editing, overlay commit, Enter, Shift+Enter, and Tab navigation paths intact.

## Regression coverage

Updated `test/editor_live_cell_editing_feedback_test.dart` with coverage for:

- First printable key during the overlay focus handoff is preserved.
- Click/edit/commit stores the typed value.
- Enter commits and moves right.
- Shift+Enter commits and moves left.

## Verification

Commands run:

- `flutter clean`
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build web --release --no-web-resources-cdn --pwa-strategy=none --base-href /bitacora_web/`

Results:

- `flutter analyze`: passed.
- `flutter test`: passed, 175 tests.
- Release web build: passed.

Manual local browser verification:

- Served `build/web` locally under `/bitacora_web/`.
- Opened the editor in Chrome.
- Clicked one cell once and immediately typed `ABC`.
- Confirmed `ABC` appeared, not `BC`.
- Pressed Enter, typed `DEF`, then Shift+Enter.
- Confirmed values persisted and navigation returned left.
- Evidence toolbar remained visible.
- Export actions remained visible.
- Checked 1920, 1280, 1024, and 390 widths with no document-level horizontal overflow.
- No page errors were captured.

Screenshot:

- `C:\demo comerciales\sales_readiness_qa\bitflow\bitflow_first_character_fix.png`

Additional verification artifact:

- `C:\demo comerciales\sales_readiness_qa\bitflow\bitflow_first_character_fix_local_verify.json`

## Deployment

No push or deploy was performed.
