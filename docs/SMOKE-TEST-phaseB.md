# Phase B Smoke Test — Manual Deploy Dry-Run Procedure

This document is a step-by-step manual dry run of the full Phase B pipeline (AdMob → build →
screenshot → submit → retro). A human runs each `/flame-harness*` command in their own Claude
Code session after Phase A has completed with an evaluator PASS. This agent cannot execute those
commands on your behalf.

---

## Operational Prerequisites and Gotchas

Before attempting a Phase B run, ensure the following are in place. Skipping any of these will
cause a lane or upload to fail mid-run.

### (a) App Store Connect and Google Play Console app records must already exist

`fastlane certs`, `fastlane beta`, and `fastlane internal` all target an existing app record by
bundle ID. Neither fastlane nor this harness can create the app record for you — that step
requires a one-time manual action in each console:

- **iOS**: Sign in to [App Store Connect](https://appstoreconnect.apple.com) → My Apps → **+** →
  New App. Set the bundle ID to match `bundle_id` from `config.md` (format: `com.<company>.<slug>`).
- **Android**: Sign in to [Google Play Console](https://play.google.com/console) → All apps →
  **Create app**. Set the package name to the same `bundle_id` value.

If either record is missing, the upload lanes will exit with a 404 / "app not found" error.

### (b) Keystore SHA fingerprint must be enrolled in Play App Signing before the first AAB upload

Google Play enforces App Signing by Google Play for all new apps. When a keystore is generated
by `keytool` (as `flame-harness-build` does if no keystore is found in `credentials_dir`), you
must enroll the upload certificate's SHA fingerprint before the first `fastlane internal` run:

1. Extract the SHA-256 fingerprint from the keystore:
   ```bash
   keytool -list -v -keystore <game>/android/upload-keystore.jks \
     -alias upload -storepass <keystore-password> | grep SHA256
   ```
2. In Play Console → App → Setup → App integrity → App signing, upload the certificate or paste
   the fingerprint when prompted.

Without enrollment, the AAB upload will be rejected with a signing validation error.

### (c) `flutter drive` screenshot output location

`flutter drive` with `IntegrationTestWidgetsFlutterBinding.takeScreenshot` writes PNG files
to the **game project root** by default (i.e. `<projects-dir>/<app_slug>/`).
Before running `fastlane screenshots` or `fastlane images`, you must move the captured PNGs
into the fastlane-expected directory layout:

- iOS: `<game>/ios/fastlane/screenshots/ko/` and `<game>/ios/fastlane/screenshots/en-US/`
- Android: `<game>/android/fastlane/metadata/android/ko-KR/images/phoneScreenshots/` and
  `.../en-US/images/phoneScreenshots/`

Check the `flutter drive` output (stdout) for the exact path where PNGs land before moving them.
The integration test driver writes a line like:
```
Screenshot: 01_home → <projects-dir>/<slug>/01_home.png
```
Use those absolute paths in your `mv` commands.

---

## Starting Point

Phase B begins immediately after the evaluator issues a PASS verdict at the end of Phase A.
At that point `docs/harness/state.md` inside the game project will read:

```yaml
status: paused
current_phase: admob
next_role: admob
pause_reason: manual_action
```

(or `next_role: build` if `skip_admob: true` was set in `config.md`.)

To advance into Phase B, run `flame-harness-resume` in your Claude Code session:

```
/flame-harness-resume
```

The resume skill confirms `state.md`, sets `status: running`, increments `resume_attempts`, and
dispatches the skill named by `next_role` (`admob` or `build`).

---

## Phase B Checklist

Work through each skill in order. Verify the listed checkpoints before proceeding to the next
phase.

---

### Phase 7 — AdMob (`flame-harness-admob`)

**Trigger:** orchestrator dispatches this skill when `next_role: admob`. It can also be invoked
directly as `/flame-harness-admob`.

**Skip path:** if `config.md` has `skip_admob: true`, the skill immediately sets
`next_role: build`, logs `skip_admob=true`, and exits. Skip to Phase 8 in that case.

**Interactive steps:**

1. The skill reads the PRD and decides rewarded-ad placements (revive/continue, double-coins, etc.).
2. It asks you for your AdMob **iOS App ID** and **Android App ID** via `AskUserQuestion`:
   - Open [https://admob.google.com](https://admob.google.com), add your iOS and Android apps if
     not already added, and paste both IDs (format `ca-app-pub-XXXX~YYYY`).
   - Type `defer` to pause and continue later.
3. For each rewarded placement, it asks you to create a rewarded ad unit in the AdMob console and
   paste back the iOS and Android unit IDs (format `ca-app-pub-XXXX/NNNN`).
4. The skill injects `google_mobile_ads`, ATT permission, UMP consent flow, `AdIds`, and
   `RewardedAdHelper` into the game's source.

**Verify after completion:**

- [ ] `docs/harness/config.md` `admob:` block is fully populated (app IDs + ad unit IDs).
- [ ] `<game>/lib/admob/` contains `att_helper.dart`, `consent_helper.dart`, `ad_ids.dart`,
  `rewarded_ad_helper.dart`.
- [ ] `<game>/ios/Runner/Info.plist` has `NSUserTrackingUsageDescription` and
  `GADApplicationIdentifier`.
- [ ] `<game>/android/app/src/main/AndroidManifest.xml` has `com.google.android.gms.ads.APPLICATION_ID`.
- [ ] `flutter analyze` returns 0 issues in the game directory.
- [ ] `docs/harness/state.md`:
  ```yaml
  status: running
  current_phase: admob
  next_role: build
  ```
- [ ] `docs/harness/pipeline-log.md` has a `complete` row for `admob`.

---

### Phase 8 — Build (`flame-harness-build`)

**Trigger:** orchestrator dispatches when `next_role: build`.

**What the skill does:**

1. Reads `config.md` for `bundle_id`, `credentials_dir`, `ios.asc_key_id`, `android.key_alias`.
2. Copies signing credentials from `credentials_dir` into the game:
   - `AuthKey_<asc_key_id>.p8` → `<game>/ios/fastlane/`
   - `play-store-key.json` → `<game>/android/fastlane/`
   - `upload-keystore.jks` → `<game>/android/` (or generates a new keystore with `keytool`).
3. Generates fastlane `Appfile` and `Fastfile` for iOS and Android by substituting placeholders
   in `templates/fastlane/` (`__APP_ID__`, `__PACKAGE__`, `__IPA_NAME__`, `__PROFILE_NAME__`).
4. Runs the fastlane build and upload sequence:
   ```bash
   cd <game>/ios
   fastlane certs          # download/renew distribution cert + provisioning profile
   fastlane beta           # build signed IPA + upload to TestFlight

   cd <game>
   flutter build appbundle --release
   cd android
   fastlane internal       # upload AAB to Play Store internal track
   ```

**Verify after completion:**

- [ ] `<game>/ios/fastlane/Appfile` and `<game>/ios/fastlane/Fastfile` contain no unresolved
  `__PLACEHOLDER__` strings.
- [ ] `<game>/android/fastlane/Appfile` and `<game>/android/fastlane/Fastfile` likewise clean.
- [ ] IPA appears in TestFlight: App Store Connect → your app → TestFlight → Builds.
- [ ] AAB appears in Play Console: your app → Testing → Internal testing → Releases.
- [ ] `docs/harness/handoff/build-result.md` exists with IPA path, AAB path, and build numbers.
- [ ] `docs/harness/state.md`:
  ```yaml
  status: running
  current_phase: build
  next_role: screenshot
  ```
- [ ] `docs/harness/pipeline-log.md` has a `complete` row for `build`.

---

### Phase 9 — Screenshot (`flame-harness-screenshot`)

**Trigger:** orchestrator dispatches when `next_role: screenshot`.

**What the skill does:**

1. Copies `templates/screenshots_test.dart.template` to `<game>/integration_test/screenshots_test.dart`
   and adapts the `// TODO(generator):` markers for the game's actual screens and locale controller.
2. Ensures `<game>/test_driver/integration_test.dart` (standard boilerplate) exists.
3. Runs `flutter drive` twice per platform (once for `SCREENSHOT_LOCALE=ko`, once for `en`), with
   `--dart-define=screenshots=true` to suppress all ad overlays.
4. Writes ASO metadata: `keywords.txt`, `name.txt`, `subtitle.txt`, `description.txt`,
   `promotional_text.txt`, `release_notes.txt` for iOS; `title.txt`, `short_description.txt`,
   `full_description.txt`, `changelogs/<version-code>.txt` for Android — in both `ko` and `en`.
5. Moves PNGs to the fastlane-expected paths and runs:
   ```bash
   cd <game>/ios
   fastlane screenshots    # upload screenshots + metadata to App Store Connect

   cd <game>/android
   fastlane images         # upload screenshots + metadata to Google Play
   ```

**Verify after completion:**

- [ ] PNGs present in `<game>/store-assets/ios/{ko,en-US}/` and
  `<game>/store-assets/android/{ko-KR,en-US}/`.
- [ ] At least 4 PNG files per locale per platform (home, gameplay, game-over, secondary screen).
- [ ] iOS ASO metadata files exist under `<game>/ios/fastlane/metadata/{ko,en-US}/`.
- [ ] Android ASO metadata files exist under `<game>/android/fastlane/metadata/android/{ko-KR,en-US}/`.
- [ ] App Store Connect → your app → App Information shows updated screenshots and metadata.
- [ ] Play Console → your app → Store listing shows updated screenshots and short description.
- [ ] `docs/harness/state.md`:
  ```yaml
  status: running
  current_phase: screenshot
  next_role: submit
  ```
- [ ] `docs/harness/pipeline-log.md` has a `complete` row for `screenshot`.

---

### Phase 10 — Submit (`flame-harness-submit`)

**Trigger:** orchestrator dispatches when `next_role: submit`.

**What the skill does:**

1. Uploads text metadata and categories via fastlane:
   ```bash
   cd <game>/ios
   fastlane metadata     # push all locale text files to App Store Connect
   fastlane categories   # set primary + secondary App Store category

   cd <game>/android
   fastlane metadata     # push locale text to Google Play
   fastlane release_notes  # push changelogs
   ```
2. Writes `state.md` with `status: paused`, `next_role: retro`, `pause_reason: manual_action`.
3. Prints exact manual steps for the developer.

**Manual steps (user-run):**

**iOS — Submit for Review:**
1. Open [App Store Connect](https://appstoreconnect.apple.com) and navigate to your app.
2. Select the version uploaded by Phase 8.
3. Verify the build, screenshots, and metadata are correct and complete.
4. Click **"Submit for Review"** (심사 제출).
5. Answer Apple's pre-submission questionnaires (export compliance, content rights, IDFA / ATT).
6. Confirm. The app status will change to "Waiting for Review".

**Android — Production promotion:**
1. Open [Google Play Console](https://play.google.com/console) and navigate to your app.
2. Go to **Testing → Internal testing** and locate the release uploaded by Phase 8.
3. Complete the following questionnaires if not already done (the Google Play API cannot set these
   programmatically):
   - **Content Rating** — complete the IARC questionnaire.
   - **Data Safety** — declare what data the app collects and how it is used.
   - **Target Audience** — confirm the app is not directed at children (if applicable).
4. Click **"Promote release → Production"**.
5. Set the rollout percentage (100% recommended for a new app).
6. Click **"Review release"** then **"Start rollout to production"**.

Once both submissions are confirmed, run:

```
/flame-harness-resume
```

**Verify after the pause:**

- [ ] `docs/harness/state.md`:
  ```yaml
  status: paused
  current_phase: submit
  next_role: retro
  pause_reason: manual_action
  ```
- [ ] `docs/harness/pipeline-log.md` has a `pause` row with event `metadata-done`.
- [ ] App Store Connect shows status "Waiting for Review".
- [ ] Play Console shows the release promoted to production (or in rollout).

**Verify after `/flame-harness-resume`:**

- [ ] `docs/harness/state.md`:
  ```yaml
  status: running
  current_phase: retro      # resume sets current_phase before dispatching retro
  next_role: retro
  pause_reason: ""
  resume_attempts: <N+1>
  ```
- [ ] `docs/harness/pipeline-log.md` has a `resume` row.

---

### Phase 11 — Retro (`flame-harness-retro`)

**Trigger:** `flame-harness-resume` dispatches this skill after the submit pause is cleared.

**What the skill does:**

1. Reads all harness artifacts: `config.md`, `state.md`, `contract.md`, all
   `handoff/round-N-gen.md`, all `feedback/round-N-qa.md`, `build-log.md`, `pipeline-log.md`,
   and `git log --oneline`.
2. Scores the 9 harness-design principles on a 1–5 scale with cited evidence.
3. Writes `docs/harness/retro.md` (9-principles scorecard + Keep / Improve / Try section).
4. Sets `state.md` to `status: completed`.

**Verify after completion:**

- [ ] `docs/harness/retro.md` exists and contains:
  - `## 9 Principles Scorecard` table with scores 1–5 for all 9 principles.
  - `## Verification` table for every contract criterion.
  - `## Keep / Improve / Try` section.
- [ ] `docs/harness/state.md`:
  ```yaml
  status: completed
  current_phase: retro
  pause_reason: ""
  ```
- [ ] `docs/harness/pipeline-log.md` has a `complete` row for `retro` with `status=completed`.
- [ ] No further skill dispatch occurs. The pipeline ends.

---

## State Transition Reference

The table below shows every expected `state.md` snapshot during Phase B, matching the protocol
transition table in `docs/harness-protocol.md` §7.

| After step | `current_phase` | `next_role` | `status` | `pause_reason` |
|---|---|---|---|---|
| Phase A evaluator PASS | `admob` | `admob` | `paused` | `manual_action` |
| `/flame-harness-resume` (into admob) | `admob` | `admob` | `running` | `""` |
| AdMob complete | `admob` | `build` | `running` | `""` |
| Build complete | `build` | `screenshot` | `running` | `""` |
| Screenshot complete | `screenshot` | `submit` | `running` | `""` |
| Submit metadata-done | `submit` | `retro` | `paused` | `manual_action` |
| `/flame-harness-resume` (into retro) | `retro` | `retro` | `running` | `""` |
| Retro complete | `retro` | `retro` | `completed` | `""` |

For the `skip_admob: true` path, replace the evaluator PASS row with:

| Phase A evaluator PASS (`skip_admob`) | `build` | `build` | `paused` | `manual_action` |
|---|---|---|---|---|

---

## Rate-Limit Pause (can occur at any Phase B phase)

If Claude Code hits a rate limit mid-pipeline during any Phase B skill, the `stop-failure-handler.sh`
hook fires and writes `status: paused`, `pause_reason: rate_limit` to `state.md`.

- [ ] `state.md` shows `status: paused` and `pause_reason: rate_limit`.
- Resume with:
  ```
  /flame-harness-resume
  ```
- [ ] After resume, `resume_attempts` incremented by 1 in `state.md`.
- [ ] `status` returns to `running` and `pause_reason` cleared to `""`.
- [ ] The skill that was interrupted re-dispatches from the start of its current phase.

---

## Recording Divergence

If the pipeline behaves differently from this document, note each divergence here:

| Step | Expected | Actual | Disposition |
|---|---|---|---|
| _(fill in as you run)_ | | | |

---

## Smoke Test Sign-Off

| Item | Result |
|---|---|
| `validate.sh` | PASS / FAIL |
| `validate-fastlane.sh` | PASS / FAIL |
| `test-hook.sh` (3/3) | PASS / FAIL |
| Plugin installed (14 skills visible) | YES / NO |
| Phase A evaluator PASS + state transition to `admob` | YES / NO |
| AdMob: app IDs collected, code injected, `flutter analyze` 0 errors | YES / NO |
| Build: IPA on TestFlight, AAB on internal track | YES / NO |
| Screenshot: KO+EN PNGs in store-assets + uploaded | YES / NO |
| Submit: fastlane metadata lanes pass, pipeline pauses | YES / NO |
| Manual: iOS "Submit for Review" + Android production promotion | YES / NO |
| Resume: dispatches retro, `resume_attempts` incremented | YES / NO |
| Retro: `retro.md` written, `status: completed` | YES / NO |
| No secrets in git (`git ls-files \| grep -Ei 'jks\|\.p8\|\.p12'` → empty) | YES / NO |

**Tester:** _______________
**Date:** _______________
**Overall result:** PASS / FAIL
