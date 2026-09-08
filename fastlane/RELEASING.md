> **Note:** fastlane regenerates `fastlane/README.md` (a bare lane list) on
> every run, so the real release guide lives here in `RELEASING.md`. The
> day-to-day flow (cut a tag → CI ships) is in the repo's `CLAUDE.md`.

# Store metadata (fastlane)

Version-controlled Play Store + App Store listing for **Checkfuchs**
(`ch.fuchsnest.checkfuchs`), the same layout as knabberfuchs. Every lane
uploads as a **draft** — nothing goes live until you act in the Console, or
until a `v*` tag runs the CI release workflows.

## Layout

```
fastlane/
  Appfile                       package/bundle id + Play key path
  Fastfile                      lanes: android validate / listing / internal · ios beta / listing / screenshots / release / validate
  metadata/android/<locale>/
    title.txt                   ≤ 30 chars
    short_description.txt        ≤ 80 chars
    full_description.txt         ≤ 4000 chars
    changelogs/<build>.txt       release notes for that versionCode (≤ 500 chars)
    images/
      icon.png                   512×512  — required to publish
      featureGraphic.png         1024×500 — required to publish
      phoneScreenshots/          01_….png … (from tool/screenshots.sh)
  metadata/ios/<locale>/
    name.txt · subtitle.txt · description.txt · keywords.txt · release_notes.txt …
  screenshots/<locale>/         iOS screenshots (deliver layout)
```

Locales: Android `en-US` (default), `de-DE`, `fr-FR`, `it-IT`; iOS `en-US`,
`de-DE`, `fr-FR`, `it`.

## No-Ruby alternative: `tool/play_publish.py`

fastlane needs Ruby. `tool/play_publish.py` pushes the same Android metadata
tree via the Android Publisher API directly (Python only):

```sh
python3 -m pip install --user google-auth google-api-python-client
python3 tool/play_publish.py            # DRY RUN — validates, saves nothing
python3 tool/play_publish.py --commit   # saves the listing as a draft
```

## One-time setup

1. **Play service account key:** `fastlane/play-store-key.json` (gitignored;
   the CI copy is the `PLAY_STORE_KEY_JSON_BASE64` secret). One developer-account
   key serves all fox apps.
2. **App Store Connect API key:** `fastlane/AuthKey_<id>.p8` (gitignored; CI
   recreates it from `ASC_API_KEY_P8_BASE64`).
3. **Install fastlane:** `gem install fastlane -v 2.236.1` (needs Ruby).

## Lanes

```sh
fastlane android validate   # check Play metadata locally, no upload
fastlane android listing    # push text + screenshots as a draft (no binary)
fastlane android internal   # upload the release AAB to internal testing (draft)
fastlane ios validate       # check App Store metadata locally
fastlane ios listing        # push App Store text (staged, not submitted)
fastlane ios screenshots    # replace App Store screenshots with fastlane/screenshots
fastlane ios beta           # upload build/ios/ipa/*.ipa to TestFlight
fastlane ios release version:x.y.z build:N   # submit a TestFlight build for review
```
