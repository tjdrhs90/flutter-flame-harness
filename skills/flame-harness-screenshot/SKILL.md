---
name: flame-harness-screenshot
description: Phase 9 — capture store screenshots in the game's configured locales via integration_test (ads hidden), fill ASO keywords, and upload via fastlane.
argument-hint: ""
allowed-tools: [Read, Write, Edit, Bash, Glob]
---

# flame-harness-screenshot

Phase 9 of the flutter-flame-harness pipeline. Captures KO and EN store screenshots by driving the
game's `integration_test` harness on the required device sizes (ads hidden), fills ASO metadata
(keywords, localized titles, descriptions), and uploads the screenshots via fastlane.

All file schemas (`config.md`, `state.md`, `pipeline-log.md`) and the phase transition table are
defined in `docs/harness-protocol.md` — that document is the single source of truth (§1 for
`config.md` and `credentials_dir`; §2 for `state.md`; §6 for log schemas; §7 for the
`screenshot → submit` transition and the `status: running` rule). Do not redefine schemas here.

**Prerequisites:** The game has been built and uploaded (Phase 8 `flame-harness-build`). The iOS
simulator is a 6.7" iPhone model and the Android emulator is a phone-sized device. `flutter drive`
and fastlane must be installed on the developer's macOS machine.

---

## Input — Read Inputs

Before any action, load:

1. `docs/harness/config.md` — extract `app_slug`, `bundle_id`, `app_name`, and `default_language`
   (per protocol §1).
2. `docs/harness/state.md` — confirm `next_role: screenshot` (per protocol §2).

Derive the game root path: `<projects-dir>/<app_slug>/`.

---

## Phase 1 — Harness Setup

### Copy the integration_test template

Copy `templates/screenshots_test.dart.template` into the game's `integration_test/` directory:

```bash
mkdir -p <game>/integration_test
cp templates/screenshots_test.dart.template \
   <game>/integration_test/screenshots_test.dart
```

### Adapt the TODO markers

Open `<game>/integration_test/screenshots_test.dart` and replace every
`// TODO(generator):` comment block with the game's real screen-driving code:

- Replace `<__APP_SLUG__>` in the import with the actual package name (from `config.md` `app_slug`,
  converting hyphens to underscores).
- Seed mock SharedPreferences / Hive / Isar data to skip first-run tutorials and show a
  representative UI state (high score, coins, unlocked skins).
- Wire the locale controller to force the locale to the `SCREENSHOT_LOCALE` dart-define value so
  screenshots are language-deterministic regardless of the simulator's system locale.
- Replace the placeholder screen list with the game's actual key screens (home, gameplay,
  game-over/results, optional secondary screen), keeping zero-padded two-digit name prefixes so
  fastlane and App Store Connect receive them in order.

### Test driver

Ensure `<game>/test_driver/integration_test.dart` exists (standard Flutter integration_test
boilerplate):

```dart
import 'package:integration_test/integration_test_driver_extended.dart';
Future<void> main() => integrationDriver();
```

---

## Phase 2 — Capture

### Device sizes

| Platform | Required device |
|---|---|
| iOS | 6.7" iPhone simulator (e.g. iPhone 15 Pro Max) |
| Android | Phone emulator (e.g. Pixel 7, 1080 × 2400) |

Run `flutter devices` to identify the device ID. Use the `-d` flag to target the correct device.

### Ads hidden during capture

Pass `--dart-define=screenshots=true` to every `flutter drive` invocation. The game's ad helper
must check this flag and suppress all ad units (banner, interstitial, rewarded) during capture so
no ad overlays appear in store screenshots. Screenshot mode should also skip the ATT prompt and
mute audio (native prompts/sound break automated capture).

**No alpha channel** (App Store rejection): store screenshots — and the iOS app icon — must be
flattened to opaque RGB. Strip any transparency before upload (e.g. `sips -s format png` onto an
opaque background, or export without alpha). See `docs/game-gotchas.md` → Store rejections.

```dart
// In the ad helper (example):
const bool isScreenshotMode =
    bool.fromEnvironment('screenshots', defaultValue: false);
```

### Locale loop — KO and EN

Run the capture twice, once per locale (`ko` and `en`), using `--dart-define=SCREENSHOT_LOCALE=`:

```bash
DEVICE_ID="<ios-simulator-id>"
GAME="<absolute-path-to-game-root>"

# KO screenshots — iOS
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart \
  -d "$DEVICE_ID" \
  --dart-define=SCREENSHOT_LOCALE=ko \
  --dart-define=screenshots=true

# EN screenshots — iOS
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart \
  -d "$DEVICE_ID" \
  --dart-define=SCREENSHOT_LOCALE=en \
  --dart-define=screenshots=true
```

Repeat for the Android phone emulator with its device ID.

### Screenshot output directory

`flutter drive` with `IntegrationTestWidgetsFlutterBinding.takeScreenshot` writes PNG files
to `<game>/` by default. Move them into the fastlane-expected paths immediately after each run
(see Phase 3 — Upload for the target paths).

---

## Phase 3 — ASO Metadata

Populate all ASO metadata for both `ko` and `en` locales.

### iOS keywords.txt

Write `<game>/ios/fastlane/metadata/<locale>/keywords.txt` for each locale. The string must be
**95–100 characters** including commas (App Store Connect truncates at 100).

Example KO keywords (exactly 97 chars including commas):
```
러너,점프,캐주얼,무한달리기,아케이드,코인,스킨,피하기,반응속도,귀여운캐릭터,하이스코어,빠른게임
```

Example EN keywords (exactly 96 chars including commas):
```
runner,jump,casual,endless,arcade,coin,skins,dodge,reflex,cute,highscore,fast,retro,fun
```

Verify the length before writing:
```bash
echo -n "your,keyword,string" | wc -c   # must be 95–100
```

### iOS localized title and description

Write under `<game>/ios/fastlane/metadata/<locale>/`:

- `name.txt` — localized app display name (≤ 30 chars).
- `subtitle.txt` — localized subtitle (≤ 30 chars).
- `description.txt` — full App Store description (≤ 4000 chars, engaging, no keyword stuffing).
- `promotional_text.txt` — optional promotional text (≤ 170 chars).
- `release_notes.txt` — what's new in this version.

Write both `ko` and `en` variants.

### Android localized title and description

Write under `<game>/android/fastlane/metadata/android/<locale>/`:

- `title.txt` — localized app title (≤ 50 chars).
- `short_description.txt` — localized short description (≤ 80 chars).
- `full_description.txt` — localized full description (≤ 4000 chars).
- `changelogs/<version-code>.txt` — what's new.

Write both `ko` and `en` variants. Use locale codes `ko-KR` and `en-US` for the Android paths.

---

## Phase 4 — Upload

### Screenshot file placement

After capture, place PNG files in the fastlane-expected directory layout before running the
upload lanes:

**iOS** — one subdirectory per locale under the fastlane screenshots folder:

```
<game>/ios/fastlane/screenshots/ko/          ← KO PNGs
<game>/ios/fastlane/screenshots/en-US/       ← EN PNGs
```

**Android** — locale-scoped phone screenshot directories:

```
<game>/android/fastlane/metadata/android/ko-KR/images/phoneScreenshots/   ← KO PNGs
<game>/android/fastlane/metadata/android/en-US/images/phoneScreenshots/   ← EN PNGs
```

Create directories as needed:

```bash
mkdir -p <game>/ios/fastlane/screenshots/ko
mkdir -p <game>/ios/fastlane/screenshots/en-US
mkdir -p <game>/android/fastlane/metadata/android/ko-KR/images/phoneScreenshots
mkdir -p <game>/android/fastlane/metadata/android/en-US/images/phoneScreenshots
```

### iOS — fastlane screenshots lane

Run from the iOS fastlane directory to upload screenshots and metadata to App Store Connect:

```bash
cd <game>/ios
fastlane screenshots
```

The `screenshots` lane calls `deliver` (or `upload_to_app_store` with `skip_binary_upload: true`)
to push all locale screenshot directories and metadata files. Ensure the generated
`<game>/ios/fastlane/Fastfile` contains a `screenshots` lane.

### Android — Play listing graphics (required)

Google Play requires a **hi-res icon (512×512)** and a **feature graphic (1024×500)** in the listing,
in addition to phone screenshots — without them the listing cannot be published. These are produced
by `tool/gen_icon.dart` (§5c.9) at `assets/store/play_icon.png` + `assets/store/feature_graphic.png`.
Place them per locale where `supply` expects them:

```bash
for loc in ko-KR en-US; do
  d=<game>/android/fastlane/metadata/android/$loc/images
  mkdir -p "$d"
  cp <game>/assets/store/play_icon.png       "$d/icon.png"            # 512×512 hi-res icon
  cp <game>/assets/store/feature_graphic.png "$d/featureGraphic.png"  # 1024×500 feature graphic
done
```

(App Store needs no feature graphic — its icon is embedded in the build; only screenshots upload via
the iOS `screenshots` lane.)

### Android — fastlane images lane

Run from the Android fastlane directory to upload screenshots, the hi-res icon, and the feature
graphic to Google Play:

```bash
cd <game>/android
fastlane images
```

The `images` lane calls `upload_to_play_store` with `skip_upload_apk: true` and
`skip_upload_aab: true` so only metadata and images are pushed (no track needed for listing
graphics). Ensure the generated `<game>/android/fastlane/Fastfile` contains an `images` lane.

### Store assets archive

Copy the final PNGs into the game's `store-assets/` directory for reference:

```bash
mkdir -p <game>/store-assets/ios/ko <game>/store-assets/ios/en-US
mkdir -p <game>/store-assets/android/ko-KR <game>/store-assets/android/en-US
cp <game>/ios/fastlane/screenshots/ko/*.png       <game>/store-assets/ios/ko/
cp <game>/ios/fastlane/screenshots/en-US/*.png    <game>/store-assets/ios/en-US/
cp <game>/android/fastlane/metadata/android/ko-KR/images/phoneScreenshots/*.png \
   <game>/store-assets/android/ko-KR/
cp <game>/android/fastlane/metadata/android/en-US/images/phoneScreenshots/*.png \
   <game>/store-assets/android/en-US/
```

---

## Output — Write Handoff and State

### state.md

Write `docs/harness/state.md` atomically (per protocol §7 `screenshot → submit` transition and
§7 rule 2 — set `status: running` in the same write as `next_role`):

```yaml
status: running
current_phase: screenshot
next_role: submit
updated_at: "<ISO-8601 UTC now>"
```

Leave `current_round`, `created_at`, `resume_attempts`, and `pause_reason` unchanged.

### pipeline-log.md

Append one row to `docs/harness/pipeline-log.md` (per protocol §6):

```
| <ISO-8601 UTC now> | complete | screenshot | locale screenshots captured and uploaded; ASO metadata written; next: submit |
```

---

## Error Handling and Pausing

If screenshot capture or upload fails and cannot be resolved immediately, write
`docs/harness/state.md` with:

```yaml
status: paused
current_phase: screenshot
next_role: screenshot
pause_reason: manual_action
updated_at: "<ISO-8601 UTC now>"
```

Then explain what manual action is required. The harness will resume when the user runs
`flame-harness-resume` (per protocol §7 pause/resume rules).
