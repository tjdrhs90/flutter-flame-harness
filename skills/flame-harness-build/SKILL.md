---
name: flame-harness-build
description: Phase 8 — bootstrap signing credentials, generate fastlane config from templates, and build + upload signed IPA (TestFlight) and AAB (internal track).
argument-hint: ""
allowed-tools: [Read, Write, Edit, Bash, Glob]
---

# flame-harness-build

Phase 8 of the flutter-flame-harness pipeline. Bootstraps signing credentials into the generated
game, generates fastlane config from the Task 3 templates, then builds and uploads a signed IPA
to TestFlight and a signed AAB to the Play Store internal track.

All file schemas (`config.md`, `state.md`, `pipeline-log.md`) and the phase transition table are
defined in `docs/harness-protocol.md` — that document is the single source of truth (§1 for
`config.md` including `credentials_dir`, `ios`, and `android` blocks; §2 for `state.md`; §6 for
log schemas; §7 for the `build → screenshot` transition and the `status: running` rule). Do not
redefine schemas here.

**Prerequisites:** An App Store Connect app record and a Google Play Console app must already exist
(created once manually). The upload lanes will fail without them. Fastlane and Ruby must be
installed on the developer's macOS machine (Xcode and the flutter CLI are assumed present).

---

## Input — Read Inputs

Before any action, load:

1. `docs/harness/config.md` — extract `app_slug`, `bundle_id`, `app_name`, and `credentials_dir`
   (per protocol §1). Also read `ios.asc_key_id` and `android.key_alias`.
2. `docs/harness/state.md` — confirm `next_role: build` (per protocol §2).

Derive the game root path: `/Users/ssg/AndroidStudioProjects/<app_slug>/`.

---

## Phase 1 — Credential Bootstrap

Copy signing credentials from the shared `credentials_dir` (per protocol §1 — skills must not
hard-code credential paths; always read `credentials_dir` from `config.md`) into the game's
platform directories.

### iOS credentials

```bash
mkdir -p <game>/ios/fastlane/certs
cp <credentials_dir>/AuthKey_339MZ7CUZ5.p8 <game>/ios/fastlane/
```

The `.p8` filename encodes the ASC key ID from `config.md` `ios.asc_key_id`. The `certs/`
directory holds the downloaded distribution certificate and provisioning profile (written by
`fastlane certs`).

### Android credentials

```bash
mkdir -p <game>/android/fastlane
cp <credentials_dir>/play-store-key.json <game>/android/fastlane/
```

### Android keystore

Check whether `<credentials_dir>/upload-keystore.jks` exists.

- **If it exists:** copy it.

  ```bash
  cp <credentials_dir>/upload-keystore.jks <game>/android/upload-keystore.jks
  ```

- **If it is missing:** generate a new keystore with `keytool`. Use the alias and password
  defined in `config.md` `android.key_alias` (default: `upload`). Store and key passwords are
  both `111111`.

  ```bash
  keytool -genkey -v \
    -keystore <game>/android/upload-keystore.jks \
    -alias upload \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass 111111 -keypass 111111 \
    -dname "CN=Gonigon, OU=Dev, O=Gonigon, L=Seoul, S=Seoul, C=KR"
  ```

### android/key.properties

Write `<game>/android/key.properties` by substituting the `templates/key.properties.template`
values (placeholders are already concrete — the template uses literal values matching the keystore
generated above):

```
storePassword=111111
keyPassword=111111
keyAlias=upload
storeFile=upload-keystore.jks
```

The `storeFile` path is relative to the `android/` directory, which is where Gradle reads it.

---

## Phase 2 — Fastlane Config Generation

Generate fastlane `Appfile` and `Fastfile` for both platforms by substituting the following
placeholders in the templates located at `templates/fastlane/`:

| Placeholder | Value |
|---|---|
| `__APP_ID__` | `bundle_id` from `config.md` |
| `__PACKAGE__` | `bundle_id` from `config.md` |
| `__IPA_NAME__` | `<app_name>.ipa` (spaces allowed; use the value of `app_name` verbatim) |
| `__PROFILE_NAME__` | `<bundle_id> AppStore` (e.g. `com.gonigon.mygame AppStore`) |

Note: `__PROFILE_NAME__` is used both as the Xcode code-signing profile name and as the
`.mobileprovision` filename (with `.mobileprovision` appended by fastlane). Spaces are acceptable.

### iOS fastlane

```bash
mkdir -p <game>/ios/fastlane/certs
# Write Appfile
sed -e 's/__APP_ID__/<bundle_id>/g' \
    templates/fastlane/ios-Appfile.template \
    > <game>/ios/fastlane/Appfile
# Write Fastfile
sed -e 's/__APP_ID__/<bundle_id>/g' \
    -e 's/__IPA_NAME__/<app_name>.ipa/g' \
    -e 's/__PROFILE_NAME__/<bundle_id> AppStore/g' \
    templates/fastlane/ios-Fastfile.template \
    > <game>/ios/fastlane/Fastfile
```

### Android fastlane

```bash
mkdir -p <game>/android/fastlane
# Write Appfile
sed -e 's/__PACKAGE__/<bundle_id>/g' \
    templates/fastlane/android-Appfile.template \
    > <game>/android/fastlane/Appfile
# Write Fastfile
sed -e 's/__PACKAGE__/<bundle_id>/g' \
    templates/fastlane/android-Fastfile.template \
    > <game>/android/fastlane/Fastfile
```

After substitution, verify with `grep '__' <game>/ios/fastlane/Appfile <game>/ios/fastlane/Fastfile <game>/android/fastlane/Appfile <game>/android/fastlane/Fastfile` — output must be empty (no unresolved placeholders).

---

## Phase 3 — Build and Upload

Run all build commands from the game root (`/Users/ssg/AndroidStudioProjects/<app_slug>/`).

### Pre-build platform requirements

Before building, ensure the platform items in `docs/game-gotchas.md` (Build/platform) are in place —
these are submit-blockers if missing: iOS `PrivacyInfo.xcprivacy` registered (iOS 17+), Android
`minSdk = 23` + core-library desugaring, iOS `Podfile` platform bumped, `Info.plist`
ATT + `SKAdNetworkItems`.

### iOS — Signed IPA → TestFlight

```bash
cd <game>/ios
fastlane certs          # downloads/renews distribution cert + provisioning profile into certs/
fastlane beta           # builds the signed IPA and uploads it to TestFlight
```

`fastlane beta` calls `get_provisioning_profile`, `update_code_signing_settings`, `build_app`,
and `upload_to_testflight` (defined in the generated Fastfile). The lane sets
`skip_waiting_for_build_processing: true` so it does not block waiting for Apple's processing.

### Android — Signed AAB → internal track

```bash
cd <game>
flutter build appbundle --release   # produces build/app/outputs/bundle/release/app-release.aab

cd android
fastlane internal                   # uploads AAB to the Play Store internal track
```

`fastlane internal` calls `upload_to_play_store` with `track: "internal"` and the relative AAB
path `../build/app/outputs/bundle/release/app-release.aab` (defined in the generated Fastfile).

### Build failure handling

- If `fastlane certs` fails with a certificate error, check that the Apple Distribution
  certificate is valid in Keychain Access, then re-run.
- If `fastlane beta` fails with a profile not found error, ensure the app record exists in App
  Store Connect (prerequisite above) and re-run `fastlane certs` first.
- If `flutter build appbundle --release` fails, run `flutter analyze` to identify compilation
  errors and fix them before retrying.
- If `fastlane internal` fails with a `401` or credential error, verify that
  `android/fastlane/play-store-key.json` was copied correctly and that the service account has
  the Release Manager role in Play Console.

---

## Output — Write Handoff and State

### handoff/build-result.md

Write `docs/harness/handoff/build-result.md` with the following layout:

```markdown
# Build Result — <app_name>

## IPA

- Path: `<game>/ios/build/<app_name>.ipa`
- Upload: TestFlight — uploaded successfully (build number: <N>)

## AAB

- Path: `<game>/build/app/outputs/bundle/release/app-release.aab`
- Upload: Play Store internal track — uploaded successfully (version code: <N>)

## Build Number

- iOS build number: <N>
- Android version code: <N>
```

Fill `<N>` with the actual build number / version code reported by fastlane output.

### state.md

Write `docs/harness/state.md` atomically (per protocol §7 `build → screenshot` transition and
§7 rule 2 — set `status: running` in the same write as `next_role`):

```yaml
status: running
current_phase: build
next_role: screenshot
updated_at: "<ISO-8601 UTC now>"
```

Leave `current_round`, `created_at`, `resume_attempts`, and `pause_reason` unchanged.

### pipeline-log.md

Append one row to `docs/harness/pipeline-log.md` (per protocol §6):

```
| <ISO-8601 UTC now> | complete | build | IPA uploaded to TestFlight; AAB uploaded to internal track; next: screenshot |
```

---

## Error Handling and Pausing

If either upload fails and cannot be resolved immediately, write `docs/harness/state.md` with:

```yaml
status: paused
current_phase: build
next_role: build
pause_reason: manual_action
updated_at: "<ISO-8601 UTC now>"
```

Then explain what manual action is required. The harness will resume when the user runs
`flame-harness-resume` (per protocol §7 pause/resume rules).
