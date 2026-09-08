# Checkfuchs — project guide for Claude

Ad-free, no-subscription, **serverless** Android + iOS habit & to-do app
(Flutter/Dart). Local-first (drift/SQLite), Riverpod, Material 3, four locales
(en/de/fr/it). Model: `design-concept.md`. Plan & roadmap: `PLAN.md`. Look:
`DESIGN_SYSTEM.md` + HTML mockups in `examples/ui/`. Part of the fox family —
shared design system & base stack in `../fuchsbau`; `../knabberfuchs` is the
sibling this repo's release pipeline was copied from.

## Working in this repo

**Flutter is NOT on PATH — it runs inside a distrobox container named `flutter`.**
Wrap every flutter/dart command:

```bash
distrobox enter flutter -- bash -lc 'cd ~/Documents/fuchs/checkfuchs && flutter <cmd>'
```

- **Analyze / test:** `flutter analyze` · `flutter test` (tests in `test/`).
  CI (`ci.yml`) additionally enforces `dart format` and that the committed
  drift codegen (`lib/data/db/database.g.dart`) is fresh — after editing
  `lib/data/db/database.dart` run
  `dart run build_runner build --delete-conflicting-outputs`.
- **l10n:** edit `lib/l10n/app_en.arb` (template, with `@key` blocks), then
  mirror the key into `app_de/fr/it.arb`. The generated
  `lib/l10n/app_localizations*.dart` are **gitignored** — run `flutter gen-l10n`
  after a fresh clone or analyze/test fail with ~70 undefined errors. Config:
  `l10n.yaml`. No hardcoded user-facing strings (the English-only DEBUG
  section in Settings is the one sanctioned exception).
- **Emulator (Linux):** launch it from the **host**, not the container, and
  with `-gpu host` — software rendering segfaults the host renderer:
  ```bash
  export ANDROID_HOME=$HOME/Android/Sdk ANDROID_AVD_HOME=$HOME/.config/.android/avd
  $ANDROID_HOME/emulator/emulator -avd pixel_api36 -gpu host -no-snapshot-load -no-boot-anim -no-audio
  ```
  adb is not on PATH: `~/Android/Sdk/platform-tools/adb`. Debug menu in the
  app: long-press the name in Settings › About (Load demo suite, Reset to
  intro, …).
- **App icon:** `flutter_launcher_icons` config in `pubspec.yaml`
  (`assets/icon/`, same recipe as knabberfuchs, no monochrome layer on
  purpose). Regenerate with `dart run flutter_launcher_icons`.
- **Release flow (CI, the normal path):** write the four changelogs at
  `fastlane/metadata/android/<locale>/changelogs/<nextBuildNumber>.txt` and
  the iOS notes at `fastlane/metadata/ios/*/release_notes.txt`, then
  `tool/cut_release.sh x.y.z` — it verifies tree/changelogs/CI, bumps pubspec,
  tags `vX.Y.Z` and pushes. **The tag is the human gate**: it ships to
  production on both stores with no further approval. The tag triggers
  `.github/workflows/android.yml` (analyze+test gate → signed AAB → *completed*
  release on the Play `alpha` closed track **and production**) and `ios.yml`
  (analyze+test gate → TestFlight → submit for App Store review,
  **auto-releases on approval**).
  **Off-tag production pushes** (a build already uploaded, e.g. promoting an
  older closed-testing build): Android = `gh workflow run android.yml -f
  track=production -f promote_version_code=<N>` — never re-upload a
  versionCode; that run has no tag behind it, so it holds on the protected
  `play-production` environment until approved in the GitHub UI. iOS =
  `gh workflow run ios-release.yml -f version=x.y.z -f build_number=N`.
  Manual fallback:
  `flutter build appbundle --release` → `python3 tool/play_upload_aab.py <track>`
  (track(s) as positional args, e.g. `internal`; AAB path hardcoded in the
  script; `fastlane/play-store-key.json` lives in CI secrets + ProtonDrive,
  not on every machine). Store listing text: `fastlane/RELEASING.md`.
  The CI Flutter version is single-sourced in `.fvmrc` (all workflows read it
  via `flutter-version-file`).
  **Status (2026-09-08):** Play Console app record exists; the Android side
  is complete — upload keystore generated (local copy in
  `~/Documents/fuchs-secrets/checkfuchs/`, later ProtonDrive) and all five
  `ANDROID_*` / `PLAY_STORE_KEY_JSON_BASE64` secrets set; the store listing
  (text, screenshots, icon, feature graphics, 4 locales) is uploaded as a
  draft via `tool/play_publish.py --commit`. No build has been uploaded yet
  (first one: `gh workflow run android.yml -f track=alpha`). iOS: App Store
  Connect record, signing secrets and `ios/ExportOptions.plist` still to be
  created on the Mac. Store screenshots: `tool/screenshots.sh android` from
  the container against the host emulator.
- **Secrets:** keystore, `android/key.properties`, `fastlane/play-store-key.json`,
  `*.p8` / `*.p12` / `*.mobileprovision` are gitignored — never commit, print
  or paste them. Backups live in ProtonDrive; CI copies are base64 secrets.

## UI conventions (summary — full rules in `DESIGN_SYSTEM.md`)

- **Icons:** Material Symbols Rounded via `material_symbols_icons` —
  `Symbols.<name>_rounded`, never `Icons.*`.
- **Sheets:** `isScrollControlled: true` + `showDragHandle: true`, a
  `titleLarge` title, `SafeArea(top:false)` + `viewInsets.bottom + 16` padding,
  full-width `FilledButton` action at the bottom.
- **Buttons/dialogs:** `FilledButton` = primary/confirm, `TextButton` =
  cancel/dismiss; dialog order is **Cancel → Confirm**.
- **Lists on pushed screens:** explicit `padding:` must add
  `MediaQuery.paddingOf(context).bottom` (3-button navigation bars).
- **Theme:** `lib/core/theme.dart` delegates to the shared **fuchsbau** package
  (tangerine triad: primary orange, secondary indigo, tertiary emerald).
  Status colours: done emerald · skipped grey · missed faded taupe (struck) ·
  avoidance amber — **never red** (red is destruction-only).
- **Separation law:** Template owns generation, Task owns status, Lens/View
  are presentation only and never write status (`design-concept.md` §4.6).

**When you introduce a genuinely new UI pattern, update `DESIGN_SYSTEM.md`.**
