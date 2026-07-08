# Game Gotchas — required robustness patterns

Hard-won fixes from shipped Flutter/Flame games. The **generator must emit** these patterns, the
**contract must require** them, and the **evaluator must verify** them — so a generated game does
not silently regress on problems already solved. Cite this file (DRY); skills do not restate it.

Universal rule: **every platform call (audio, haptics, ads, persistence, method channels) is wrapped
in try/catch, logs via `debugPrint`, and never rethrows.** Missing assets/features degrade
gracefully (silent audio, no-op haptic, fallback rectangle) — the game stays playable.

---

## Audio

- **Frequent SFX → `AudioPool`, not `FlameAudio.play()`.** `FlameAudio.play()` allocates a new
  native player per call (platform-channel + allocation), causing frame stutter during bursts
  (coins, fire, hits). Pre-warm an `AudioPool` per frequent SFX in `onLoad()` (1–3 players) and call
  `pool.start()`. Rare one-offs (game-over, power-up) may still use `FlameAudio.play()`.
- **Throttle rapid repeats** (~70 ms): keep `Map<String,double> _lastPlayed`; skip a key if it fired
  within the window. Collapses a burst into a steady click.
- **Graceful fallback**: wrap pool creation and every play in try/catch; if an asset is missing, mark
  the pool null and skip playback. Never crash on a bad/typo'd audio path (fails hard in release).
- **BGM lifecycle**: start BGM only in the `playing` state (not menus/pause). Call
  `FlameAudio.bgm.stop()` on game-over, on app-background, and in `onRemove()`/`onDetach()` — BGM
  from a previous run must not leak into menu or after quit.
- **Volume caps**: define per-channel caps (e.g. BGM ≤ 0.2, SFX ≤ 0.7); the user slider is a fraction
  of the cap, so 100% = a safe level, not ear-splitting.
- **iOS audio format**: iOS does not reliably play OGG. Convert OGG/MP3 → 22 kHz mono 16-bit WAV
  (`ffmpeg -i in.ogg -ac 1 -ar 22050 -sample_fmt s16 out.wav`) and bundle WAV.

## Haptics

- **Provide a `Haptics` system** (`lib/systems/haptics.dart`); never call `HapticFeedback.*` raw from
  gameplay. The system must:
  - **Platform-guard**: no-op unless `!kIsWeb && (Platform.isIOS || Platform.isAndroid)`.
  - **Throttle** (~60 ms global minimum gap) — bursts otherwise machine-gun the vibration motor.
  - **`enabled` toggle** (persisted in prefs) so users can turn it off.
  - **try/catch** every call (emulators / unsupported devices throw).
- **iOS optimization (optional, for haptic-heavy games)**: a native MethodChannel in
  `AppDelegate.swift` holding prepared `UIImpactFeedbackGenerator` instances (light/medium/heavy)
  avoids the 5–10 ms main-thread stall of creating a generator per event. Baseline Dart
  `HapticFeedback` + throttle is sufficient for most games; document this as an upgrade.

## App lifecycle / pause-resume / cold start

- **Background = pause**: the app host widget implements `WidgetsBindingObserver`; on
  `AppLifecycleState.paused`/`inactive` call `game.pauseEngine()` + BGM pause; on `resumed` reverse.
  Prevents battery drain, background BGM, and missed pauses.
- **Teardown cleanup**: in `onDetach()`/`dispose()` stop audio, dispose pools, cancel timers/streams.
  Never re-access game/engine state during teardown.
- **Stale input on resume**: gate input on a `_canInput` flag (false during pause) so a tap on the
  pause overlay doesn't fire into gameplay on resume.
- **Cold-start order**: call `super.onLoad()` first; don't touch peers before the component tree is
  mounted. Android `MainActivity` must init the FlameGame before `super.onCreate()` to avoid a
  NullPointerException on cold start.
- **Startup sequence in `main()`**: `WidgetsFlutterBinding.ensureInitialized()` →
  `await SharedPreferences.getInstance()` (so sync prefs reads work) → ATT (after first frame /
  foreground) → UMP consent → `MobileAds.initialize()` → preload audio → `runApp()`. Ads must not be
  requested before consent completes.
- **ATT prompt must actually appear (App Store 2.1)**: the ATT dialog only presents while the app is
  active/foregrounded. Requesting in `main()` before the first frame silently no-ops on the latest
  iOS → "NSUserTrackingUsageDescription present but the alert never appears" rejection. Required
  pattern: **wait until `WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed`** (poll
  up to ~4s), then a **~400 ms settle delay**, then request **only when `notDetermined`** — from a
  post-frame callback, awaited **before** ads init. Localize the prompt text for **every** configured
  locale (per-locale `<locale>.lproj/InfoPlist.strings`) — see *Store rejections* → "Permission
  strings not localized".
- **Android hardware back button**: wrap the app in `PopScope` — back closes an open overlay, else
  (in-game) pauses, else (on the **root/menu**) shows a Flutter `SnackBar` ("press back again to
  exit") and only exits on a second back within ~2 s. Never let a single back kill the app mid-run.
- **Lock to one orientation natively** — decide portrait *or* landscape and lock it in
  `Info.plist` `UISupportedInterfaceOrientations` (remove the `~ipad` variant) + Android
  `android:screenOrientation`. `SystemChrome.setPreferredOrientations` alone still lets the app open
  in the wrong orientation and rotate (a visible launch flash); removing the unused orientation
  natively prevents it.
- **Reset all run state on a new run** — clear score/effects/spawns/timers so nothing leaks from the
  previous run into the next (a common source of "weird state on retry").

## Input & UI

- **iOS edge-gesture conflict**: full-screen drag/joystick games trigger the iOS system swipe. Defer
  it with `SystemChrome.setEnabledSystemUIMode` / `preferredScreenEdgesDeferringSystemGestures` so a
  player's swipe near the edge doesn't pull down Control Center or trigger back.
- **SafeArea + responsive HUD**: wrap every overlay/HUD in `SafeArea`; cap bar/dialog widths with
  `LayoutBuilder`/max-width so notches and landscape don't clip or stretch the UI.
- **Block input during splash/transitions** so a stray tap doesn't fall through into gameplay.

## Accessibility & safety (arcade-appropriate baseline — gate R10)

Full screen-reader/AAA a11y is out of scope for a visual arcade game, but a small baseline is cheap,
genuinely useful, and two items are **safety/compliance**, not nicety:

- **No flashing faster than 3 flashes/second** (photosensitive-seizure safety — WCAG 2.3.1; app
  stores flag it). Full-screen strobes/rapid inversions are the risk; keep any flash effect ≤3 Hz.
- **Respect OS "Reduce Motion"** — read `MediaQuery.of(context).disableAnimations` (iOS Reduce Motion
  / Android Remove Animations). When true, damp or skip screen-shake, big particle bursts, and any
  flashing. Route it through one flag (e.g. `GameConfig`/a settings service) so effects check it.
- **Tap targets ≥ 48×48 dp** for menu/overlay buttons (Play/Pause/Restart/Settings) — comfortable and
  the platform minimum.
- **Text contrast ≥ 4.5:1** against its background (already required in the design-tokens spec).
- **`Semantics` labels on menu/overlay buttons** so the menus are screen-reader navigable (label the
  few control buttons; gameplay itself need not be labelled). Icon-only buttons especially.
- Keep pinning `MediaQuery.withNoTextScaling` for the in-game HUD (prevents OS font-scaling from
  breaking tight/pixel-font layouts) — that is intentional and separate from the above.

## Performance

- **No per-frame `whereType` in hot paths**: computing `world.children.whereType<X>()` per component
  per frame is O(n²) and GC-heavy. Compute active lists once per frame in the game root's
  `update(dt)` and have components read the cache.
- **Cache `Paint`/shaders**: reuse `static final Paint` (with gradient/blur preset); don't recreate
  `Paint`/`createShader`/`MaskFilter.blur` per frame. Swap color on a reused Paint instead.
- **Don't rebuild static text every frame**: cache `TextPaint`; rebuild HUD text only when the value
  changes.

## Build / platform

- **Bundle id identical on both platforms** — iOS `PRODUCT_BUNDLE_IDENTIFIER` (all build configs) ==
  Android `applicationId` + `namespace` == `config.bundle_id`, byte-for-byte (lowercase `[a-z0-9.]`,
  no `_`/`-`/uppercase). `flutter create` derives the id from the project name and can leave
  underscores/case or diverge between platforms — set it explicitly on both. AdMob + store records
  use this exact string.
- **Android `minSdk = 23`** — `google_mobile_ads` requires API 23+; lower fails at startup.
- **iOS `Podfile` platform**: bump `platform :ios, '<x>'` to the highest plugin requirement, or
  `pod install` fails.
- **`Info.plist`**: `NSUserTrackingUsageDescription` (ATT) and `SKAdNetworkItems` (Google's list) are
  required for an ads build to pass App Store review.
- **iOS `PrivacyInfo.xcprivacy` (iOS 17+)**: ship a Privacy Manifest and register it in the Xcode
  project, or App Store Connect rejects the upload. Declare reasons for any required-reason APIs
  (UserDefaults, file timestamps, etc.).
- **Android core library desugaring**: enable `coreLibraryDesugaring` in
  `android/app/build.gradle.kts` (some plugins, e.g. notifications, require it) or the build fails.
- **Localized app display name**: set the store/home-screen name per locale — iOS
  `<locale>.lproj/InfoPlist.strings` (`CFBundleDisplayName`), Android per-locale `strings.xml`.
- **Icon + splash + in-app logo from one shared painter** for visual consistency; the native splash
  `color` must match the in-app splash background (else a color blink on launch). iOS icon must be
  opaque (no alpha); `flutter_launcher_icons: remove_alpha_ios: true`.
- **Android adaptive icon ≠ iOS icon — don't reuse the full-bleed image.** The adaptive-icon canvas
  is 108dp but the launcher mask shows only ≤72dp, and just the centre ~66dp circle is guaranteed
  unclipped. A full-bleed iOS icon dropped in as the `adaptive_icon_foreground` gets cropped/"zoomed"
  by the mask. Ship a **separate padded foreground** (`icon-fg.png`, motif inside the safe zone,
  ~25% margin) over a solid `adaptive_icon_background` colour — not the `image_path` art. Also ship a
  **monochrome layer** (`adaptive_icon_monochrome`, white-on-transparent silhouette) for Android 13+
  themed icons; Google Play increasingly expects one and Android 16 auto-tints non-compliant icons,
  so an icon without it looks off among themed icons.
- **Asset paths lowercase**: Android/Linux are case-sensitive; keep `assets/**` names lowercase and
  declare directories (trailing slash) in `pubspec.yaml`.
- **Always ship with assets (no manual sourcing required)**: audio defaults to **code-synthesized**
  WAV (`tool/build_audio.dart`) so the game is never silent; visuals default to **code-drawn**
  (`CustomPainter`/Flame shapes). Sourced sprites (CC0/AI) are optional and get their background
  flood-filled to alpha (`tool/strip_bg.dart`). Every asset referenced in code/`pubspec.yaml` must
  exist — a dangling reference is a runtime crash/blank.
- **Ship CI from day one**: `.github/workflows/ci.yml` running `flutter analyze --no-fatal-infos` +
  `flutter test` on push/PR.

## Ads (init coordination — see also the admob skill)

- **Gate the ad SDK to mobile only**: don't init `MobileAds`/load ads on web/desktop; guard on
  `!kIsWeb && (Platform.isIOS || Platform.isAndroid)`, or you get silent no-ops/errors.
- **Coordinate the ad manager with `MobileAds.initialize()`** — don't request an ad before init
  completes (silent no-ops). Test IDs in debug, real IDs (from config) on release.

## Store screenshots

- **Screenshot mode flag** (`--dart-define=screenshots=true`): disables ads, the ATT prompt, and
  audio during capture so frames are clean.
- **Android: convert the Flutter surface to an image once** (not per shot) or multi-shot capture
  fails after the first frame.

## Persistence

- **Coins/score persist immediately**: on earn (or at run end, synchronously before any async save)
  write to prefs, so a crash mid-run doesn't lose progress.
- **Migrate legacy keys** once (e.g. old int `high_score` → new JSON profile) then delete the old key.

## Store rejections (App Review) — real ones already hit

These caused real App Store / Play rejections and were fixed; prevent them up front.

- **2.1 — ATT prompt never appears** (most common here): see the ATT pattern under *Lifecycle*
  (wait-for-resumed + settle + notDetermined, post-frame, before ads). For the review reply, attach
  a **screen recording on a physical device** showing a fresh install → the ATT prompt appearing
  before any tracking → the following flow, and put it in App Review Information → Notes.
- **Permission strings not localized** (real, repeat rejection): if the app declares multiple App
  Store localizations, every `NS*UsageDescription` (especially `NSUserTrackingUsageDescription`)
  must be translated per locale, or a reviewer in another language sees a foreign-language prompt.
  The base `Info.plist` string is only the development-language fallback — add each translation to
  `ios/Runner/<locale>.lproj/InfoPlist.strings` (same files as the localized `CFBundleDisplayName`),
  for **every** configured locale (`default_language` + English when `default_language ≠ en`). The
  admob skill owns this when it injects ATT; verify at submit.
- **App icon / screenshots with an alpha channel are rejected** — flatten to opaque RGB (no
  transparency) for the iOS icon and all store screenshots.
- **Play listing requires a hi-res icon (512×512) + feature graphic (1024×500)** — generate both
  (opaque) from the shared painter and place at `android/fastlane/metadata/android/<locale>/images/
  icon.png` + `featureGraphic.png` so `supply` uploads them; without them the Play listing can't be
  published. (App Store needs no feature graphic.)
- **ASC rejects duplicate build numbers** — bump the build number on every upload (don't reuse `1`).
- **Export compliance prompt every upload** — set `ITSAppUsesNonExemptEncryption = false` in
  `Info.plist` if the app uses no non-exempt encryption, to skip the prompt on future builds.
- **AdMob "Publisher data not found" / no ads** — the ad unit's publisher prefix must match the
  AdMob app, and the bundle id / package name must exactly match what's registered in AdMob
  (propagation can take minutes–hours).
- **4.1 / 4.3 Copycats** — avoid silhouettes/palettes that read as a clone of a famous title
  (e.g. classic-green pipes + side-scroll = Flappy clone flag); add a distinct visual/mechanic hook.
- **Don't auto-prompt for notifications** before there's a user-understood reason (Apple/Play
  discourage cold permission prompts).
- **Store-listing + App-Review info must be filled** (from `config.md` developer block): privacy
  policy URL, support + marketing URLs, copyright, and App Review contact (first/last name, phone,
  email). iOS: write `ios/fastlane/metadata/{copyright.txt,<locale>/support_url.txt,marketing_url.txt,
  privacy_url.txt,review_information/*}` so `deliver` uploads them. Android: contact email/website
  have no `supply` field → set via the Publisher API (`set_contact_details.rb`); privacy URL + Data
  Safety are manual in the console. Missing review-contact info delays/blocks review.
- **4.2 Minimum Functionality** — don't ship a thin app. Have enough content (e.g. a meaningful
  number of levels/modes) plus an in-game tutorial and per-mechanic first-appearance tips, or risk a
  "minimal app" rejection.
- **2.3.10 — no other-platform mentions in metadata** — App Store rejects a description that says
  "Android …". Keep store-specific copy (App Store edition vs Play edition).
- **ASCII-safe description** — App Store Connect's linter rejects decorative Unicode (box-drawing
  chars ▌ — × etc.); use plain ASCII headers/punctuation.
- **iPhone-only target** (`TARGETED_DEVICE_FAMILY = 1`) avoids the iPad screenshot requirement for a
  phone-only game (and remove `~ipad` orientation keys).
- **AdMob "Made for kids" = No** in the AdMob app config (unless truly child-directed), or ads won't
  serve.
- **iOS App Privacy label (App Store Connect)** — a Connect form, **separate from**
  `PrivacyInfo.xcprivacy`. An empty/absent label blocks release. For an offline game + AdMob: declare
  **Identifiers → Third-Party Advertising** and mark it under **Tracking** (must match the ATT
  prompt). With `skip_admob: true` → **Data Not Collected**.
- **Play Data Safety** — must match the iOS label: "Collects **Device or other IDs**" for
  **Advertising**, shared with Google, encrypted in transit; nothing else (no location/contacts/PII).
  With `skip_admob: true` → "No data collected". Mismatched declarations across stores draw review
  scrutiny.
- **COPPA / child-directed consistency** — if a game is directed at under-13, Play **Target
  Audience**, AdMob **"Made for kids"** + `tagForChildDirectedTreatment(true)` must all agree;
  personalized ads must be off. Default every game to **not** child-directed unless the concept
  clearly targets kids (misdeclaring is an FTC-enforcement risk, not just a rejection).

---

## Long-tail (full commit-history audit)

Lower-frequency but real, from a full read of all repos' commits + docs.

**Lifecycle / crash**
- **`LateInitializationError` on early backgrounding** — `didChangeAppLifecycleState` (or a reused
  component's `launch()`) touches a `late` field before `onLoad` ran. Guard handlers with
  `if (!game.isLoaded) return;` and prefer nullable fields initialised in `onLoad`.
- **`OpacityEffect` only works on `OpacityProvider`** — applying it to a plain `TextComponent`
  throws; animate opacity manually in `update()`.
- **Snapshot before mutating during iteration** — a hit that kills an enemy which spawns children
  mid-loop → concurrent-modification crash. Iterate a `.toList()` snapshot.

**Performance (heavy/bullet-hell games)**
- **Avoid per-frame allocations**: reuse `Vector2` via `setValues`, reuse `static final Paint`, set
  `paint.filterQuality = FilterQuality.none`, and `canvas.drawRect` for solid fills instead of
  per-tile sprite loops.
- **No per-frame `MaskFilter.blur`/`saveLayer`** — replace glows/shadows with flat translucent fills,
  layered solid discs, or hard offset shadows; offer a "high FX" toggle (default off on weak devices).
- **Cap per-frame spawns** — mass-kill VFX / floating text / bullets must be capped per frame and
  pooled (retire oldest past a ceiling); cull off-screen render and throttle off-screen AI.

**Input & UI**
- **Low-latency action input**: use a raw `Listener` (`onPointerDown/Move/Up`), classify swipes
  mid-gesture (fire on threshold, latch once per gesture), fire taps on pointer-up; gate on an
  `_inputActive` flag so taps don't leak to overlays. `GestureDetector`'s arena adds latency.
- **Wrap Flame overlays in a (transparent) `Material`** — `InkWell`/ripple in a Flame overlay asserts
  "No Material widget" in debug and shows no ripple; a transparent `Material` parent fixes it.
- **`MediaQuery.withNoTextScaling`** for pixel-font / tight landscape layouts so OS font-scaling
  doesn't break the HUD.

**Ads / consent**
- **5 s timeouts on UMP** (`requestConsentInfoUpdate` + `loadAndShowConsentFormIfRequired`) — a flaky
  simulator network otherwise hangs forever (no callback).
- **The UMP form needs a GDPR message created in the AdMob console** (per app, per platform) — code
  alone won't present a form.

**Build / platform**
- **iOS Podfile static linkage** — `use_frameworks! :linkage => :static` + `use_modular_headers!`
  fixes the recurring "Failed to verify code signature (0xe8008014)" with AdMob / secure-storage pods
  and avoids per-install `flutter clean`.
- **Run `pod install`** after adding/changing any iOS plugin, or the iOS build fails.

**Persistence**
- **Batch high-frequency writes** — don't `SharedPreferences.setInt` per kill/event (blocks I/O);
  mutate memory + set a dirty flag, flush at game-over / teardown. (Critical currency like coins
  still persists immediately/synchronously at run end.)
- **Version the save schema** (`save_v1` key + per-field migration defaults) so new fields don't
  corrupt old saves.
- **Durable save (default ON, gate R9)** — `shared_preferences` alone is *not enough*: iOS drops it
  on app delete, so progress is lost on reinstall/new device. Route persistence through a
  `SaveRepository` that mirrors one JSON blob to **iOS Keychain** (`flutter_secure_storage`,
  `first_unlock`) + **Android Block Store** (`play_services_block_store`) + a `shared_preferences`
  cache (also the Android Auto Backup payload); read durable-first, write all tiers, every call in
  try/catch. This is last-write-wins restore on a fresh install/device, **not** real-time cloud sync.

**Physics (Forge2D games only)**
- **Forge2D units are meters, not pixels** — size bodies in ~0.5–2 m and let the camera zoom convert;
  never mix pixel sizes into physics.
- **Speed-gate impulses & remove spawn overlaps** — springs/bumpers fire only above a contact-velocity
  threshold (else resting bodies launch at spawn); strip overlapping bodies at level-gen (Box2D
  explodes overlaps).
