# BitFlow Public Web Deploy Report

Date: 2026-05-22

## Public URL

Active public BitFlow URL:

`https://bitflowapp.github.io/bitacora_web/`

Cache-busted verification URL used after deploy:

`https://bitflowapp.github.io/bitacora_web/?deploy=cc6d817#/app`

Note: the README also mentioned `https://marcoluna-nqn.github.io/bitacora_web/`, but that URL returned 404 during this verification.

## Why Public Looked Old

The public page was still old because the GitHub Pages artifact was stale.

Before deploy:

- Local app source was at `970c031 Polish BitFlow Luna UI final pass`.
- Public/remote `gh-pages` was still `be8cd83 deploy: web release 2026-05-01 22:55:34`.
- The public page rendered the older black/monochrome BitFlow UI.
- The three Luna redesign source commits were not present on any fetched remote source branch.

The redesign existed locally, but the public Pages branch had not been refreshed from that redesigned build.

## Git State

Working branch:

`feature/unified-luna-systems-design`

Local HEAD:

`970c031 Polish BitFlow Luna UI final pass`

Requested redesign commits found locally:

- `868f660 Apply Luna UI visual redesign to BitFlow`
- `d35c415 Polish BitFlow grid selection for Luna UI`
- `970c031 Polish BitFlow Luna UI final pass`

Remote source status:

- `origin/main`: `e374fcf`
- `origin/gh-pages` before deploy: `be8cd83`
- No fetched remote source branch contained the three redesign commits.

Pre-existing dirty files in the main worktree were not included in the deploy:

- `M lib/features/editor/editor_state.dart`
- `M lib/services/export_share_file_io.dart`
- Existing untracked audit/artifact files.

To avoid including dirty local files, the build and deploy were performed from a clean temporary worktree:

`C:\Work\tmp\bitflow_clean_deploy_verify`

Clean source commit built:

`970c031`

## Source Verification

Confirmed Luna/teal redesign markers in the clean source:

- `lib/theme/bitflow_colors.dart`
  - `Color(0xFF0E9F8E)`
  - `Color(0xFFE2F4F1)`
- `BITFLOW_FULL_VISUAL_REDESIGN_REPORT.md`
  - documents Luna palette and BitFlow teal accent

## Build Command Used

From:

`C:\Work\tmp\bitflow_clean_deploy_verify`

Command:

```powershell
flutter clean
.\scripts\release_web.ps1 -BaseHref "/bitacora_web/"
```

The release script ran:

- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build web --release --no-web-resources-cdn --pwa-strategy=none --base-href /bitacora_web/`

Base href used:

`/bitacora_web/`

Build output:

`C:\Work\tmp\bitflow_clean_deploy_verify\build\web`

Fresh build hashes:

- `build\web\index.html`: `C65C7A1FEADF97CE6E72A757EC3C8EF525382C374ECD7B84395EE8481E895425`
- `build\web\main.dart.js`: `3C92AD349D88DF834A9BBBFE9E11896BEF8BBD68EB084B2FB9E7FF857CB9F9F2`

## Local Public-Base Validation

The fresh build was served locally under the same path shape as GitHub Pages:

`http://127.0.0.1:50919/bitacora_web/`

Validation result:

- Home/start screen showed Luna UI redesign.
- `Nuevo relevamiento` used the teal primary style.
- Editor/table opened.
- `+ Registro`, `Guardar`, `Exportar`, and other actions existed.
- Grid header/index band used subtle teal styling.
- Selected cell used teal-soft fill and teal border.
- No RenderFlex overflow was observed in browser console.
- No page-level horizontal overflow was detected.

Local validation screenshots:

- `C:\demo comerciales\visual_redesign_review\bitflow_public_ready_home.png`
- `C:\demo comerciales\visual_redesign_review\bitflow_public_ready_editor.png`
- `C:\demo comerciales\visual_redesign_review\bitflow_public_ready_table.png`

## Deploy Command Used

From the clean temporary worktree:

```powershell
.\scripts\deploy_gh_pages.ps1 -SkipBuild
```

Target:

- Remote: `origin`
- Branch: `gh-pages`
- Folder copied into deploy branch: `build\web`

Deployed commit:

`cc6d817 deploy: web release 2026-05-22 15:50:56`

Push result:

`be8cd83..cc6d817 HEAD -> gh-pages`

Files changed by deploy:

- Generated web artifact files on `gh-pages`.
- No source branch was pushed.
- No unrelated dirty source files were pushed.

## Public Verification After Deploy

After deploy, public CDN files matched the clean local build:

- Public `index.html`: `C65C7A1FEADF97CE6E72A757EC3C8EF525382C374ECD7B84395EE8481E895425`
- Public `main.dart.js`: `3C92AD349D88DF834A9BBBFE9E11896BEF8BBD68EB084B2FB9E7FF857CB9F9F2`

Public visual verification:

- Public home/start screen now shows the Luna light UI.
- Teal BitFlow accent is visible.
- Public `Nuevo relevamiento` primary action uses teal.
- Public editor/table opens with teal `+ Registro`.
- DataGrid has subtle teal header/index band and teal selected-cell styling.
- Export actions are visible.
- No old black/monochrome identity dominates the public UI.
- No RenderFlex overflow was observed.
- No page-level horizontal overflow was detected.

Public screenshots:

- `C:\demo comerciales\visual_redesign_review\bitflow_public_after_deploy_home.png`
- `C:\demo comerciales\visual_redesign_review\bitflow_public_after_deploy_editor.png`
- `C:\demo comerciales\visual_redesign_review\bitflow_public_after_deploy_table.png`

## Manual Review

Open:

`https://bitflowapp.github.io/bitacora_web/?deploy=cc6d817#/app`

If a browser still shows the old UI, use a hard refresh or clear the site service worker/cache for:

`https://bitflowapp.github.io/bitacora_web/`

The deploy build uses `--pwa-strategy=none`, so future refresh behavior should be less sticky than the older service-worker-backed build.

## Risks / Notes

- The Luna redesign source commits are still local-only source commits; this deploy pushed the generated `gh-pages` artifact, not the source branch.
- `version.json` still reports generic `dev` metadata because the local deploy script does not stamp version metadata.
- Flutter reported Wasm dry-run incompatibilities from existing web dependencies; the standard web build completed successfully.
