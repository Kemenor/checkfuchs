# Mac session: finish the iOS release setup for Checkfuchs

Read this first, then work through the steps in order. Everything Android is
done (listing uploaded, first build on Play internal testing). This file is
the iOS half. Delete it when the iOS pipeline has shipped its first TestFlight
build from CI.

## Context

- Repo: `Kemenor/checkfuchs`, branch `main`. Bundle id **`ch.fuchsnest.checkfuchs`**.
  Version `1.0.0+1` in `pubspec.yaml`.
- Sibling `Kemenor/knabberfuchs` has the identical pipeline already working on
  iOS — when in doubt, diff against it. Same Apple developer account and team
  (team id `2Q964MD3G2`, see knabberfuchs `ios/ExportOptions.plist`).
- CI: `.github/workflows/ios.yml` (workflow_dispatch → TestFlight; `v*` tag →
  TestFlight + submit for review) and `ios-release.yml` (resubmit an existing
  build). Both currently **fail at the signing step** until steps 2–4 below
  are done. That is expected.
- fastlane lanes for iOS live in `fastlane/Fastfile` (`ios beta / listing /
  screenshots / release / validate`); the App Store metadata is already
  written under `fastlane/metadata/ios/{en-US,de-DE,fr-FR,it}` (name,
  subtitle, description, keywords, promo text, release notes, URLs). Screenshot
  slots under `fastlane/screenshots/<locale>/` are empty.
- Flutter runs natively on the Mac (no distrobox). `flutter --version` should
  match `.fvmrc` (3.44.4); install via fvm if not.

## 1. App Store Connect record

- App Store Connect → My Apps → **+** → New App: iOS, name **Checkfuchs**,
  primary language English (U.S.), bundle id `ch.fuchsnest.checkfuchs`
  (register it first under Certificates, Identifiers & Profiles → Identifiers
  if it isn't listed), SKU `checkfuchs`.
- Capabilities needed on the identifier: none beyond the defaults
  (local notifications need no entitlement). Push is **not** used.
- Note the app's Apple ID (numeric) — the `ios release` lane and
  `ios-release.yml` may need it if the bundle id lookup fails.

## 2. Signing on the Mac (one-time)

1. `open ios/Runner.xcworkspace`. Runner target → Signing & Capabilities:
   team `2Q964MD3G2`, bundle id `ch.fuchsnest.checkfuchs`. Let automatic
   signing create the development profile so the app runs on a device once.
2. Create the **App Store** provisioning profile in the developer portal:
   Profiles → **+** → App Store Connect, app id `ch.fuchsnest.checkfuchs`,
   certificate = the existing **Apple Distribution** cert used for knabberfuchs
   (do not create a second distribution cert). Name it
   **`Checkfuchs App Store`**. Download the `.mobileprovision`.
3. Export the distribution certificate + private key as a `.p12` from Keychain
   Access (Apple Distribution: … → Export → set a password). If a `.p12` for
   knabberfuchs already exists in ProtonDrive, reuse it — same cert.
4. Create `ios/ExportOptions.plist` — copy knabberfuchs's and change the
   provisioning-profile entry:

   ```xml
   <key>provisioningProfiles</key>
   <dict>
     <key>ch.fuchsnest.checkfuchs</key>
     <string>Checkfuchs App Store</string>
   </dict>
   ```

   Keep `method=app-store`, `signingStyle=manual`,
   `signingCertificate=Apple Distribution`, `teamID=2Q964MD3G2`. Commit it
   (it holds no secrets).
5. Prove the signed build locally:

   ```sh
   flutter pub get
   flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
   ls build/ios/ipa/*.ipa
   ```

## 3. GitHub secrets (repo Kemenor/checkfuchs)

Names must match the header of `.github/workflows/ios.yml`:

```sh
gh secret set ASC_KEY_ID           --repo Kemenor/checkfuchs --body "<key id>"        # same as knabberfuchs
gh secret set ASC_ISSUER_ID        --repo Kemenor/checkfuchs --body "<issuer id>"     # same as knabberfuchs
base64 -i AuthKey_<id>.p8            | gh secret set ASC_API_KEY_P8_BASE64        --repo Kemenor/checkfuchs
base64 -i dist.p12                   | gh secret set IOS_DIST_CERT_P12_BASE64     --repo Kemenor/checkfuchs
gh secret set IOS_DIST_CERT_PASSWORD --repo Kemenor/checkfuchs --body "<p12 password>"
base64 -i "Checkfuchs App Store.mobileprovision" | gh secret set IOS_PROVISION_PROFILE_BASE64 --repo Kemenor/checkfuchs
openssl rand -hex 16 | gh secret set KEYCHAIN_PASSWORD --repo Kemenor/checkfuchs
```

The three `ASC_*` values are account-level: copy them from the knabberfuchs
repo's secrets (or ProtonDrive) — `gh secret list --repo Kemenor/knabberfuchs`
shows the names but not values, so take them from the backup.
Put the `.p8`, `.p12` and `.mobileprovision` in ProtonDrive under
`fuchs-secrets/checkfuchs/` next to the Android keystore (which is currently
only on the Linux laptop at `~/Documents/fuchs-secrets/checkfuchs/`).

## 4. First TestFlight build from CI

```sh
gh workflow run ios.yml --repo Kemenor/checkfuchs
gh run watch --repo Kemenor/checkfuchs
```

Expect: test job green → macOS job signs, builds the IPA, `fastlane ios beta`
uploads and waits for processing. Then in App Store Connect → TestFlight add
yourself as an internal tester and install.

Things that bit knabberfuchs the first time (check if the run fails):
- `ITSAppUsesNonExemptEncryption` must be in `ios/Runner/Info.plist` — already
  added (`false`).
- Xcode version on the runner: the workflow pins `macos-26`; if `flutter build
  ipa` complains about the deployment target, bump `IPHONEOS_DEPLOYMENT_TARGET`
  in `ios/Runner.xcodeproj` and `platform :ios` in `ios/Podfile` to 13.0+.

## 5. iOS screenshots + App Store listing

```sh
tool/screenshots.sh ios            # boots an iPhone Pro Max simulator, captures en/de/fr/it
fastlane ios validate              # metadata sanity
fastlane ios listing               # text → App Store Connect (staged)
fastlane ios screenshots           # fastlane/screenshots/* → App Store Connect
```

`tool/screenshots.sh ios` runs the same `integration_test/screenshots_test.dart`
harness as Android (8 scenes; demo suite seeded; language pinned). If the
simulator shows an iOS notification-permission dialog over the first shot,
the in-context prompt is misfiring on iOS — the harness never adds a reminder,
so there should be none; check `NotificationScheduler.requestPermission`.
Fastlane needs Ruby: `gem install fastlane -v 2.236.1`; the ASC API key for
local lanes goes to `fastlane/AuthKey_<id>.p8` (gitignored).

Commit the screenshots (`fastlane/screenshots/`) like the Android ones.

## 6. App Store Connect details to fill by hand

- App privacy: "Data not collected" for every category (nothing leaves the
  device). Privacy policy URL: `https://checkfuchs.fuchsnest.ch/privacy.html`.
- Age rating questionnaire: all "None".
- Category: Productivity (secondary: Lifestyle or Health & Fitness).
- Pricing: free, all territories.
- App Review notes: "Fully offline. No account. Reminders are local
  notifications; the permission is requested when the first reminder is set."

## 7. Then the real release

Both stores release from the **tag**: write the four Android changelogs
(`fastlane/metadata/android/<locale>/changelogs/<versionCode>.txt` — `1.txt`
exists) and the iOS `release_notes.txt` (exist), then

```sh
tool/cut_release.sh 1.0.0
```

That tags `v1.0.0`, and `android.yml` + `ios.yml` ship it. Until then, keep
testing via TestFlight and Play internal testing.

## Also on the list (not Mac-specific)

- Android keystore + passwords: copy `~/Documents/fuchs-secrets/` from the
  Linux laptop to ProtonDrive once it syncs.
- Play Console: finish content rating / data safety / target audience if any
  are still open, then promote the internal build to closed testing when happy.
