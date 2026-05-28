# BitFlow E2E Blockers Deploy Report

Date: 2026-05-23
Published fix commit: `9ba070f Fix BitFlow E2E pilot blockers`
Deploy target: `gh-pages`
Live URL verified: `https://bitflowapp.github.io/bitacora_web/?deploy=e2e-blockers-9ba070f#/app`

## Source Safety

- Confirmed `9ba070f` exists.
- Confirmed commit contents are limited to the intended BitFlow E2E blocker fixes and `BITFLOW_E2E_BLOCKERS_FIX_REPORT.md`.
- Created a detached clean publish worktree at:
  `C:\Users\marco\dev\bitflow_p18_publish_9ba070f`
- The dirty main checkout was not used for build or deploy.
- Did not include:
  - `lib/features/editor/editor_models.dart` whitespace-only change
  - `.claude/`
  - prior untracked report files
  - `artifacts/`
- Did not touch Caja Clara.
- Did not touch Luna Systems landing.
- Did not push source branches.
- Did not force push.

## Validation

Ran from the clean publish worktree at `9ba070f`:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn --pwa-strategy=none --base-href /bitacora_web/
```

Results:

- `flutter clean`: PASS
- `flutter pub get`: PASS
- `flutter analyze`: PASS, no issues found
- `flutter test`: PASS, 179 tests
- `flutter build web`: PASS, built `build\web`

Build note: Flutter reported existing Wasm dry-run incompatibility warnings from web dependencies. The requested release JS web build completed successfully.

## Deploy

Command:

```powershell
.\scripts\deploy_gh_pages.ps1 -SkipBuild
```

First deploy attempt was rejected by Git as non-fast-forward. No force push was used. I fetched the current `origin/gh-pages` tip explicitly and reran the deploy.

Successful publish:

```text
gh-pages: cb80523..2b1ab29
deploy commit: 2b1ab29 deploy: web release 2026-05-23 22:55:44
```

## Live Verification

Verified with Playwright/Chromium against:

`https://bitflowapp.github.io/bitacora_web/?deploy=e2e-blockers-9ba070f#/app`

Checks:

- App loads: PASS
- No demo/dev login notice: PASS
- Editor opens: PASS
- Click cell once and type `ABC`: PASS
- `ABC` appears, not `BC`: PASS
- Bare `A` does not trigger Audio/microphone permission: PASS
- Enter moves right: PASS
- Shift+Enter moves left: PASS
- Tab / Shift+Tab work: PASS
- Evidence toolbar remains visible: PASS
- Attach sample image/file: PASS
- Export XLSX: PASS
- Export ZIP/package: PASS
- Inspect ZIP contents: PASS
- Attachment binary exists in ZIP and manifest path matches: PASS
- No dangling evidence references: PASS
- No console errors: PASS
- No horizontal overflow at 1920, 1280, 1024, 390: PASS

Viewport overflow results:

```text
1920: innerWidth=1920 scrollWidth=1920 bodyScrollWidth=1920
1280: innerWidth=1280 scrollWidth=1280 bodyScrollWidth=1280
1024: innerWidth=1024 scrollWidth=1024 bodyScrollWidth=1024
390:  innerWidth=390  scrollWidth=390  bodyScrollWidth=390
```

## Export Verification

Live XLSX:

```text
Path: D:\Work\tmp\bitflow_e2e_deploy_verify\live_bitflow_export.xlsx
Suggested filename: BitFlow_2026-05-23_Relevamiento_2026_05_23_22_57.xlsx
Size: 8043 bytes
Sheets:
- Relevamiento 2026-05-23 22 57
- Adjuntos
- Caratula
- Resumen
- _BITFLOW_META
Contains ABC: yes
Contains sample_photo evidence text: yes
```

Live ZIP:

```text
Path: D:\Work\tmp\bitflow_e2e_deploy_verify\live_bitflow_package.zip
Suggested filename: BitFlow-package_20260523_2257.bitflow.zip
Size: 7728 bytes
Entries:
- export.xlsx
- attachments/files/B1_p1_sample_photo.png
- manifest.json
- sheet.json
Manifest asset path: attachments/files/B1_p1_sample_photo.png
ZIP asset present: yes
ZIP asset bytes: 68
Dangling evidence references: none
```

Live verification artifacts:

```text
D:\Work\tmp\bitflow_e2e_deploy_verify\live_1920.png
D:\Work\tmp\bitflow_e2e_deploy_verify\live_1280.png
D:\Work\tmp\bitflow_e2e_deploy_verify\live_1024.png
D:\Work\tmp\bitflow_e2e_deploy_verify\live_390.png
D:\Work\tmp\bitflow_e2e_deploy_verify\live_home.png
D:\Work\tmp\bitflow_e2e_deploy_verify\live_editor.png
D:\Work\tmp\bitflow_e2e_deploy_verify\live_abc.png
D:\Work\tmp\bitflow_e2e_deploy_verify\live_navigation.png
D:\Work\tmp\bitflow_e2e_deploy_verify\live_attachment.png
D:\Work\tmp\bitflow_e2e_deploy_verify\live_export_result.png
D:\Work\tmp\bitflow_e2e_deploy_verify\live_verify_results.json
```

## Result

Public BitFlow GitHub Pages is updated with the E2E paid-pilot blocker fixes.

Commercial readiness after live verification: CONDITIONAL GO.

Condition: keep using the verified URL/build for pilot demos; do not redeploy from a dirty worktree.
