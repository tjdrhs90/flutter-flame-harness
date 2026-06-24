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
  post-frame callback, awaited **before** ads init. Localize the prompt text (per-locale
  `InfoPlist.strings`).
- **Android hardware back button**: wrap the app in `PopScope` — back closes an open overlay, else
  pauses, else double-tap-to-exit (don't let a single back kill the app mid-run).
- **Reset all run state on a new run** — clear score/effects/spawns/timers so nothing leaks from the
  previous run into the next (a common source of "weird state on retry").

## Input & UI

- **iOS edge-gesture conflict**: full-screen drag/joystick games trigger the iOS system swipe. Defer
  it with `SystemChrome.setEnabledSystemUIMode` / `preferredScreenEdgesDeferringSystemGestures` so a
  player's swipe near the edge doesn't pull down Control Center or trigger back.
- **SafeArea + responsive HUD**: wrap every overlay/HUD in `SafeArea`; cap bar/dialog widths with
  `LayoutBuilder`/max-width so notches and landscape don't clip or stretch the UI.
- **Block input during splash/transitions** so a stray tap doesn't fall through into gameplay.

## Performance

- **No per-frame `whereType` in hot paths**: computing `world.children.whereType<X>()` per component
  per frame is O(n²) and GC-heavy. Compute active lists once per frame in the game root's
  `update(dt)` and have components read the cache.
- **Cache `Paint`/shaders**: reuse `static final Paint` (with gradient/blur preset); don't recreate
  `Paint`/`createShader`/`MaskFilter.blur` per frame. Swap color on a reused Paint instead.
- **Don't rebuild static text every frame**: cache `TextPaint`; rebuild HUD text only when the value
  changes.

## Build / platform

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
- **Asset paths lowercase**: Android/Linux are case-sensitive; keep `assets/**` names lowercase and
  declare directories (trailing slash) in `pubspec.yaml`.

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
- **App icon / screenshots with an alpha channel are rejected** — flatten to opaque RGB (no
  transparency) for the iOS icon and all store screenshots.
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
