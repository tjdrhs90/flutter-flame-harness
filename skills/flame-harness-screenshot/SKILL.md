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

Ensure `<game>/test_driver/integration_test.dart` exists. **`integrationDriver()` has no default
screenshot writer** — its native path is guarded by `onScreenshot != null`, so without the callback
below every `takeScreenshot` byte is silently discarded and no file is ever written. Pass one:

```dart
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (
    String name,
    List<int> bytes, [
    Map<String, Object?>? args,
  ]) async {
    // The driver runs on the host, so Platform.environment works here (inside
    // the test it would not — that side uses String.fromEnvironment).
    final dir = Platform.environment['SCREENSHOT_DIR'] ?? 'build/screenshots';
    final file = File('$dir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return true;
  },
);
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
flattened to opaque RGB. Check with `sips -g hasAlpha <file>` (must report `hasAlpha: no`).

**`sips -s format png` does NOT strip alpha** — it re-encodes and keeps the channel, so it silently
leaves the rejection in place. Use one of these instead:

```bash
# Preferred — lossless, needs ImageMagick
magick in.png -background white -alpha remove -alpha off out.png

# macOS built-ins only — round-trip through JPEG (lossy, fine for screenshots)
sips -s format jpeg in.png --out tmp.jpg && sips -s format png tmp.jpg --out out.png

sips -g hasAlpha out.png   # verify: hasAlpha: no
```

See `docs/game-gotchas.md` → Store rejections.

```dart
// In the ad helper (example):
const bool isScreenshotMode =
    bool.fromEnvironment('screenshots', defaultValue: false);
```

### Locale loop — KO and EN

Run the capture twice, once per locale (`ko` and `en`), using `--dart-define=SCREENSHOT_LOCALE=`:

`SCREENSHOT_DIR` is read by the `onScreenshot` callback above — give each locale its own directory
so the two runs can't overwrite each other:

```bash
DEVICE_ID="<ios-simulator-id>"
GAME="<absolute-path-to-game-root>"

# KO screenshots — iOS
SCREENSHOT_DIR=build/screenshots/ios/ko flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart \
  -d "$DEVICE_ID" \
  --dart-define=SCREENSHOT_LOCALE=ko \
  --dart-define=screenshots=true

# EN screenshots — iOS
SCREENSHOT_DIR=build/screenshots/ios/en-US flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart \
  -d "$DEVICE_ID" \
  --dart-define=SCREENSHOT_LOCALE=en \
  --dart-define=screenshots=true
```

Repeat for the Android phone emulator with its device ID, using
`build/screenshots/android/<ko-KR|en-US>`.

### Screenshot output directory

The PNGs land in `$SCREENSHOT_DIR` (default `build/screenshots`), named after the `takeScreenshot`
argument — e.g. `build/screenshots/ios/ko/01_home.png`. Nothing is written to the game root. Phase 4
copies these into the fastlane-expected paths.

After each run, confirm the files actually exist before moving on — an empty directory means the
`onScreenshot` callback is missing or the capture failed:

```bash
ls -1 build/screenshots/ios/ko/*.png | wc -l   # must match the number of shot() calls
```

---

## Phase 3 — ASO Metadata

Populate all ASO metadata for both `ko` and `en` locales.

### iOS keywords.txt

Write `<game>/ios/fastlane/metadata/<locale>/keywords.txt` for each locale. The field holds at most
**100 characters** including commas; aim for **95–100** so none of it is wasted.

Example KO keywords (97 characters):
```
러너,점프,캐주얼,무한달리기,아케이드,코인,스킨,피하기,반응속도,귀여운캐릭터,하이스코어,빠른게임,한손조작,중독성,심플,오프라인,시간순삭,랭킹,도전,연타,순발력,두뇌게임,틈틈이
```

Example EN keywords (99 characters):
```
runner,jump,casual,endless,arcade,coin,skins,dodge,reflex,cute,highscore,fast,retro,fun,offline,tap
```

Verify the length before writing. **Count characters, not bytes** — `wc -c` counts bytes, and one
Hangul syllable is 3 bytes in UTF-8, so the KO example above measures 247 with `wc -c`. Using `wc -c`
makes a valid Korean string look 2.5× over the limit and costs you two thirds of the field:

```bash
# a here-string (<<<) would append a newline and inflate the count by 1 — use printf '%s'
printf '%s' "your,keyword,string" | python3 -c 'import sys;print(len(sys.stdin.read()))'

# check what was actually written (trailing newline stripped)
python3 -c 'import sys;print(len(open(sys.argv[1],encoding="utf-8").read().strip()))' \
  <game>/ios/fastlane/metadata/ko/keywords.txt
```

Both must report **95–100**.

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

Create the directories, and **empty them before copying** — `deliver` and `supply` upload every
PNG they find, so a leftover file from an earlier run or the other locale silently ships:

```bash
cd <game>

# "<staging dir>:<fastlane dir>" — staging dirs are the SCREENSHOT_DIR values from Phase 2
for pair in \
  "build/screenshots/ios/ko:ios/fastlane/screenshots/ko" \
  "build/screenshots/ios/en-US:ios/fastlane/screenshots/en-US" \
  "build/screenshots/android/ko-KR:android/fastlane/metadata/android/ko-KR/images/phoneScreenshots" \
  "build/screenshots/android/en-US:android/fastlane/metadata/android/en-US/images/phoneScreenshots"; do
  src="${pair%%:*}"; dst="${pair#*:}"
  mkdir -p "$dst"
  rm -f "$dst"/*.png            # drop leftovers from an earlier run / the other locale
  cp "$src"/*.png "$dst"/
  echo "$dst: $(ls -1 "$dst"/*.png | wc -l) file(s)"
done
```

Every locale must report the **same** non-zero count. A zero means capture produced nothing (see
Phase 2's `onScreenshot` note).

### iOS — fastlane screenshots lane

Run from the iOS fastlane directory to upload the locale screenshot directories to App Store
Connect (screenshots only — text metadata goes up in Phase 10):

```bash
cd <game>/ios
fastlane screenshots
```

The lane calls `upload_to_app_store` with `skip_binary_upload: true`, then runs a **duplicate
cleanup and count check** and fails if App Store Connect does not end up with exactly the local
number of screenshots per locale. A successful run ends with
`Screenshots verified — no duplicates`.

**Do not remove that cleanup step.** `deliver` decides "is this screenshot already uploaded?" by
comparing App Store Connect's `sourceFileChecksum` against the local file's MD5. When that
comparison does not match, its post-upload verification concludes every local file is missing and
retries — and the retry keeps the already-uploaded screenshots while re-uploading the whole set, so
each image lands **twice**. Once a set holds 10 images its own "nothing missing" guard passes, so
`deliver` prints *Successfully uploaded all screenshots* and exits 0 with a doubled set.
`overwrite_screenshots: true` does not prevent this — it only clears the sets before the first
round.

If an app already carries duplicates from an earlier upload, clean it without re-uploading:

```bash
cd <game>/ios
fastlane screenshots_prune   # deletes duplicates + broken assets, reports per-locale counts
```

Confirm the result against the live API — the per-locale counts must equal the local PNG counts:

```bash
fastlane verify   # VER[ko] … screenshots=N / VER[en-US] … screenshots=N
```

Ensure the generated `<game>/ios/fastlane/Fastfile` contains both the `screenshots` and
`screenshots_prune` lanes.

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
