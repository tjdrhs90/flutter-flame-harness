---
name: flame-harness-admob
description: Phase 7 — analyze the game, decide a rewarded-ad strategy, guide manual AdMob ad-unit creation, and inject google_mobile_ads + ATT/UMP consent code.
argument-hint: ""
allowed-tools: [Agent, Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion]
---

# flame-harness-admob

Phase 7 of the flutter-flame-harness pipeline. Analyzes the game's loop, decides where rewarded
ads fit naturally, guides the user through manual ad-unit creation in the AdMob console, then
injects `google_mobile_ads`, iOS ATT, and UMP consent code.

All file schemas (`config.md`, `state.md`, `pipeline-log.md`) and the phase transition table are
defined in `docs/harness-protocol.md` — that document is the single source of truth (§1 for
`config.md` including the `admob:` block; §2 for `state.md`; §6 for log schemas; §7 for the
`admob → build` transition and the `skip_admob` branch rule). Do not redefine schemas here.

---

## Input — Read Inputs

Before any action, load:

1. `docs/harness/config.md` — extract `app_slug`, `app_name`, and `skip_admob` (bool).
2. `docs/harness/state.md` — confirm `next_role: admob`.
3. PRD at `docs/harness/prd.md` — read the game loop, monetization intent, and any explicit
   ad placement requests.

---

## Skip Flag — skip_admob Handling

Check `skip_admob` from `docs/harness/config.md` immediately after loading inputs.

If `skip_admob: true`:

1. Write `docs/harness/config.md` with `admob.enabled: false` (per protocol §1 `admob:` block).
2. Write `docs/harness/state.md` with:

   ```yaml
   status: running
   current_phase: admob
   next_role: build
   updated_at: "<ISO-8601 UTC now>"
   ```

3. Append to `docs/harness/pipeline-log.md` (per protocol §6):

   ```
   | <ISO-8601 UTC now> | complete | admob | skip_admob=true; AdMob skipped; next: build |
   ```

4. Exit immediately. Do not ask questions, do not inject code.

---

## Strategy — Rewarded Ad Placement

Read the PRD and game loop carefully. The goal is rewarded ads that feel like a natural reward
mechanic, not an interruption.

### Rewarded Ad Placement Principles

- **Revive / continue**: Offer a rewarded ad when the player dies or fails — "Watch an ad to
  continue?". This is the highest-converting rewarded placement for Flame games.
- **Double coins / bonus**: After a session ends, offer a rewarded ad to double the score or
  coins earned.
- **Extra life / shield**: Mid-game offer for an extra life when health is critical.
- **Unlock hint / skip**: In puzzle games, offer a rewarded ad to reveal a hint or skip a level.

Choose placements that match the PRD's described game loop. Document the chosen placements
explicitly — a fresh Claude running `flame-harness-generator` must know exactly where to add the
`RewardedAdHelper.show()` call.

### No Intrusive Interstitials

Do **not** add interstitial ads unless the PRD explicitly requests them. Interstitials between
levels or at session start hurt retention and risk App Store policy violations. Rewarded ads are
opt-in and always preferred.

### Banner Ads (conditional)

Add a banner ad only if the PRD explicitly requests one. If a banner is used, apply the SafeArea
banner gap pattern: wrap the game canvas in a `Column` with a `SafeArea`-padded `BannerAdWidget`
at the bottom so the ad never overlaps game content.

---

## Manual Unit Creation — AdMob Console

Google's API cannot create AdMob ad units programmatically. The user must create them manually
in the AdMob console. Follow these steps:

### Step 1 — Collect App IDs

Use `AskUserQuestion` to ask the user:

> "Please open the AdMob console (https://admob.google.com) and:
> 1. Add your iOS app → copy the **iOS App ID** (format: `ca-app-pub-XXXX~YYYY`).
> 2. Add your Android app → copy the **Android App ID** (format: `ca-app-pub-XXXX~ZZZZ`).
>
> Paste both IDs here. If you haven't done this yet, type 'defer' and I'll pause."

If the user types `defer` or says they haven't done it yet, write `docs/harness/state.md` with:

```yaml
status: paused
current_phase: admob
next_role: admob
pause_reason: manual_action
updated_at: "<ISO-8601 UTC now>"
```

Then stop. The harness will resume when the user runs `flame-harness-resume`.

### Step 2 — Collect Ad Unit IDs

For each rewarded placement identified in the Strategy section, use `AskUserQuestion` to ask the
user to create a rewarded ad unit in the AdMob console and paste back both the iOS and Android
unit IDs. Example for a "revive" unit:

> "In the AdMob console, under your app → Ad units → Add ad unit → Rewarded:
> - Unit name: `<app_slug>_rewarded_revive`
> - Copy the **iOS unit ID** (format: `ca-app-pub-XXXX/IIII`) and the
>   **Android unit ID** (format: `ca-app-pub-XXXX/AAAA`).
>
> Paste both here. Type 'defer' to pause."

Again apply the same `pause_reason: manual_action` pause if the user defers.

### Step 3 — Write config.md admob block

Once all IDs are collected, write the `admob:` block in `docs/harness/config.md`
(per protocol §1):

```yaml
admob:
  enabled: true
  ios_app_id: "ca-app-pub-XXXX~YYYY"
  android_app_id: "ca-app-pub-XXXX~ZZZZ"
  ad_units:
    - key: rewarded_revive
      ios_id: "ca-app-pub-XXXX/IIII"
      android_id: "ca-app-pub-XXXX/AAAA"
      format: rewarded
    # add one entry per placement
```

---

## Code Injection

After collecting IDs, inject the integration code into the Flutter project at
`<projects-dir>/<app_slug>/`.

### 1. pubspec.yaml — Add Dependencies

```yaml
dependencies:
  google_mobile_ads: ^5.1.0
  app_tracking_transparency: ^2.0.6
```

Run `flutter pub get` after editing.

### 2. iOS ATT Permission — Info.plist (localize for EVERY configured locale)

Read `default_language` from `docs/harness/config.md`. The configured App Store localizations are
`default_language` **plus English when `default_language ≠ en`** — the same set as the l10n Hard
Gate. The ATT prompt string must exist in **every** one of them, or you get a repeat rejection:
a reviewer (or user) in another locale sees a foreign-language permission prompt.

**Base string** — add `NSUserTrackingUsageDescription` to `ios/Runner/Info.plist` in the app's
`default_language` (this is the development-region fallback — NOT hard-coded to any one language):

```xml
<key>NSUserTrackingUsageDescription</key>
<string><ATT reason, written in default_language></string>
```

**Localize it per locale.** The generator already created a `ios/Runner/<locale>.lproj/InfoPlist.strings`
for each configured locale (for `CFBundleDisplayName`, generator §5c.9) and registered them in the
Xcode project. **Add the ATT key to each of those files** — reuse them; create+register any missing
one:

`ios/Runner/en.lproj/InfoPlist.strings`:
```
"NSUserTrackingUsageDescription" = "We use this to personalize ads and improve the app.";
```
`ios/Runner/ko.lproj/InfoPlist.strings`:
```
"NSUserTrackingUsageDescription" = "광고를 개인화하고 앱 개선을 위해 사용합니다.";
```
For any other configured locale, add the same key with a natural translation. Keep the wording
truthful to what the app does and consistent with the App Privacy / tracking declaration.

> The base `Info.plist` value is the fallback; the matching `<locale>.lproj/InfoPlist.strings`
> entry overrides it per language. **Verify before build:** every configured locale's
> `InfoPlist.strings` contains a `NSUserTrackingUsageDescription` line —
> `for d in ios/Runner/*.lproj; do grep -q NSUserTrackingUsageDescription "$d/InfoPlist.strings" || echo "MISSING ATT string: $d"; done`.

Add the iOS AdMob App ID:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXX~YYYY</string>
```

Also add an **`SKAdNetworkItems`** array to `Info.plist` — **required manual step** (the SDK does not
inject it). Without it iOS install attribution breaks, and it's an expected config for an ads app at
App Store review. At minimum include Google's own ID:

```xml
<key>SKAdNetworkItems</key>
<array>
  <dict><key>SKAdNetworkIdentifier</key><string>cstr6suwn9.skadnetwork</string></dict>
  <!-- + third-party buyer IDs (see below) -->
</array>
```

AdMob's exchange serves third-party demand even without mediation, so copy the **full current list**
from Google's docs — it changes over time, so fetch the latest at build time rather than hard-coding
an old copy:
- Quick-start Info.plist snippet: <https://developers.google.com/admob/ios/quick-start>
- Full third-party SKAdNetwork IDs: <https://developers.google.com/admob/ios/3p-skadnetworks>

(See `docs/game-gotchas.md` → Build/platform.)

### 3. Android — AndroidManifest.xml + minSdk

Set `minSdk = 23` in `android/app/build.gradle.kts` — `google_mobile_ads` requires API 23+ and a
lower value crashes at startup (`docs/game-gotchas.md`). Then add to
`android/app/src/main/AndroidManifest.xml` inside `<application>`:

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXX~ZZZZ"/>
```

### 4. ATT Request — lib/admob/att_helper.dart

Create `lib/admob/att_helper.dart`:

```dart
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

/// Requests iOS App Tracking Transparency permission. No-op on Android.
///
/// CRITICAL — App Store Guideline 2.1: the ATT system dialog ONLY presents
/// while the app is active/foregrounded. On a fresh launch the app may not be
/// `resumed` yet, so requesting too early silently no-ops and the prompt never
/// appears — the exact cause of the "NSUserTrackingUsageDescription present but
/// the ATT alert never appears" 2.1 rejection on the latest iOS. So: wait until
/// resumed, add a small settle delay, and only request when notDetermined.
Future<void> requestATT() async {
  if (!Platform.isIOS) return;
  try {
    await _waitUntilResumed();
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
  } catch (e) {
    debugPrint('ATT request failed: $e');
  }
}

/// Wait (up to ~4s) for the app to reach the foreground/active state, which is
/// required for the ATT prompt to actually present.
Future<void> _waitUntilResumed() async {
  for (var i = 0; i < 40; i++) {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}
```

Call `requestATT()` from a **post-first-frame callback** (`WidgetsBinding.instance.addPostFrameCallback`), and **await it before** `loadConsentForm()` and `MobileAds.instance.initialize()` so the ATT decision precedes any ad/tracking request (see §5). Never call it synchronously in `main()` before the first frame — that is what triggers the 2.1 rejection.

### 5. UMP Consent Flow — lib/admob/consent_helper.dart

Create `lib/admob/consent_helper.dart`:

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Loads and (if required) shows the UMP consent form.
/// Returns only after the consent callback fires — ads must NOT be
/// requested before this Future completes.
Future<void> loadConsentForm() async {
  final completer = Completer<void>();
  final params = ConsentRequestParameters();
  ConsentInformation.instance.requestConsentInfoUpdate(
    params,
    () async {
      if (await ConsentInformation.instance.isConsentFormAvailable()) {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
      }
      if (!completer.isCompleted) completer.complete();
    },
    (FormError error) {
      debugPrint('UMP consent error: ${error.message}');
      if (!completer.isCompleted) completer.complete(); // non-fatal, continue
    },
  );
  return completer.future;
}
```

> **Important:** ads must NOT be requested before `loadConsentForm()` completes.

Use this startup order in `main()`:

```dart
WidgetsFlutterBinding.ensureInitialized();
await requestATT();          // iOS only — no-op on Android
await loadConsentForm();     // waits for UMP consent decision
await MobileAds.instance.initialize();
// preload ads / runApp after this point
```

### 6. ID Switch — lib/admob/ad_ids.dart

Create `lib/admob/ad_ids.dart`. Use Google's official test IDs in debug builds to avoid
policy violations; switch to real IDs in release:

```dart
import 'dart:io';

const bool _isDebug = bool.fromEnvironment('dart.vm.product') == false;

class AdIds {
  // ── Rewarded: revive ────────────────────────────────────────────────────
  static String get rewardedRevive {
    if (_isDebug) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/1712485313'   // Google iOS test
          : 'ca-app-pub-3940256099942544/5224354917';  // Google Android test
    }
    return Platform.isIOS
        ? 'ca-app-pub-XXXX/IIII'   // from config.md admob.ad_units[rewarded_revive].ios_id
        : 'ca-app-pub-XXXX/AAAA';  // from config.md admob.ad_units[rewarded_revive].android_id
  }
  // Add one getter per ad unit.
}
```

Replace the placeholder strings with the IDs collected from the user.

### 7. Rewarded Helper — lib/admob/rewarded_ad_helper.dart

Create `lib/admob/rewarded_ad_helper.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Loads and shows a rewarded ad for a single placement.
/// Pass the ad unit ID from [AdIds] at construction time so the same
/// class can be reused for every placement (revive, bonus coins, etc.)
/// without subclassing.
///
/// Example:
///   final _reviveAd = RewardedAdHelper(AdIds.rewardedRevive);
///   final _bonusAd  = RewardedAdHelper(AdIds.rewardedBonus);
///
/// [onRewarded] is called when the user earns the reward.
/// [onDismissed] is called when the ad is dismissed (with or without reward).
class RewardedAdHelper {
  RewardedAdHelper(this.adUnitId);

  final String adUnitId;
  RewardedAd? _ad;

  Future<void> load() async {
    await RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _ad = ad,
        onAdFailedToLoad: (error) {
          debugPrint('RewardedAd failed to load: $error');
          _ad = null;
        },
      ),
    );
  }

  /// Returns true if an ad is ready.
  bool get isLoaded => _ad != null;

  /// Shows the ad. [onRewarded] fires when the user earns the reward.
  void show({
    required VoidCallback onRewarded,
    VoidCallback? onDismissed,
  }) {
    final ad = _ad;
    if (ad == null) {
      onDismissed?.call();
      return;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _ad = null;
        onDismissed?.call();
      },
    );
    ad.show(onUserEarnedReward: (_, __) => onRewarded());
  }

  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}
```

### 8. Game Integration

In the game-over or revive overlay (identified in the Strategy section), call:

```dart
if (_rewardedAdHelper.isLoaded) {
  _rewardedAdHelper.show(
    onRewarded: () {
      // Grant the reward: restore health, give extra life, double coins, etc.
    },
    onDismissed: () {
      // User skipped ad — proceed to normal game-over flow.
    },
  );
}
```

Pre-load the ad when the game session starts so it is ready when needed.
Instantiate one `RewardedAdHelper` per placement, passing the matching `AdIds` getter:

```dart
_reviveAdHelper = RewardedAdHelper(AdIds.rewardedRevive);
await _reviveAdHelper.load();
// Add one line per placement (e.g. RewardedAdHelper(AdIds.rewardedBonus))
```

---

## Output — Write State and Logs

After completing code injection and confirming `flutter analyze` returns 0 issues:

### Write config.md

Ensure `docs/harness/config.md` `admob:` block is complete and accurate (see Step 3 above under
Manual Unit Creation). Per protocol §1, the `enabled` field must be `true` when ads are injected.

### Write state.md

Write `docs/harness/state.md` atomically (per protocol §7 `admob → build` transition and §7
rule 2 — set `status: running` in the same write):

```yaml
status: running
current_phase: admob
next_role: build
updated_at: "<ISO-8601 UTC now>"
```

Leave `current_round`, `created_at`, `resume_attempts`, and `pause_reason` unchanged.

### Append to pipeline-log.md

Append one row to `docs/harness/pipeline-log.md` (per protocol §6):

```
| <ISO-8601 UTC now> | complete | admob | rewarded ad injected; ATT+UMP wired; next: build |
```

---

## Error Handling

- If `flutter analyze` fails after code injection, fix all issues before writing `state.md`.
- If the user cannot provide AdMob IDs (console access issue, approval pending), pause with
  `pause_reason: manual_action` and explain what is needed for resume.
- If `app_tracking_transparency` or `google_mobile_ads` pub.dev packages are unavailable,
  check the current package name with `flutter pub search google_mobile_ads` and update the
  version accordingly.
