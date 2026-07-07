---
name: flame-harness-submit
description: Phase 10 — upload store text metadata + categories via fastlane, then pause with exact manual steps for the final iOS review submission and Android production promotion.
argument-hint: ""
allowed-tools: [Read, Write, Edit, Bash, AskUserQuestion]
---

# flame-harness-submit

Phase 10 of the flutter-flame-harness pipeline. Uploads store text metadata and app categories via
fastlane for both iOS and Android, then pauses the pipeline with exact manual steps for the final
review submission / production promotion that cannot be automated.

All file schemas (`config.md`, `state.md`, `pipeline-log.md`) and the phase transition table are
defined in `docs/harness-protocol.md` — that document is the single source of truth (§1 for
`config.md`; §2 for `state.md` keys and `pause_reason` values; §6 for `pipeline-log.md` schema;
§7 for the `submit → metadata-done → paused` transition and the `(paused) → resume → retro`
transition). Do not redefine schemas here.

**Boundary:** Text metadata upload is automated. The final "Submit for Review" tap on iOS and the
"Promote to production" action on Android are **manual** — the Apple and Google APIs do not permit
fully automated submission without human confirmation after the review build is staged.

**Prerequisites:** Phase 9 (`flame-harness-screenshot`) completed; screenshots and ASO metadata
already uploaded; `state.md` shows `next_role: submit`.

---

## Input — Read Inputs

Before any action, load:

1. `docs/harness/config.md` — extract `app_slug`, `bundle_id`, `app_name`, and `default_language`
   (per protocol §1).
2. `docs/harness/state.md` — confirm `next_role: submit` (per protocol §2).

Derive the game project root for `<app_slug>` from `config.md` / the harness working directory (the games live under the same parent as the harness, e.g. `…/AndroidStudioProjects/<app_slug>/`).

---

## Phase 0 — Generate store-info files from config

Before uploading, write the store-listing + App-Review files from the `developer` block in
`config.md` (sourced from `credentials/store-metadata.md`) so they actually get uploaded — these are
otherwise empty and the listing/review info would be missing.

**iOS (deliver picks these up automatically):**
- `ios/fastlane/metadata/copyright.txt` ← `developer.copyright`
- per locale (`ko`, `en-US`): `support_url.txt` ← `developer.homepage`, `marketing_url.txt` ←
  `developer.homepage`, `privacy_url.txt` ← `developer.privacy`
- `ios/fastlane/metadata/review_information/`: `first_name.txt`, `last_name.txt`, `phone_number.txt`,
  `email_address.txt` ← `developer.*`; `notes.txt` ← reviewer notes (e.g. the ATT screen-recording
  note for an ads build).

**Android (contact email + website have no `supply` field — set via the Publisher API):**
- copy `templates/set_contact_details.rb.template` → `android/fastlane/set_contact_details.rb`,
  fill `__PACKAGE__`=`bundle_id`, `__EMAIL__`=`developer.email`, `__WEBSITE__`=`developer.homepage`,
  and run `cd android && ruby fastlane/set_contact_details.rb`.
- The **privacy policy URL** and Data Safety / Content Rating / Target Audience are set in the manual
  step below (Play console).

## Phase 1 — Metadata Upload

Run the fastlane metadata and categories lanes for both platforms. These lanes push text metadata
(localized titles, descriptions, release notes) and app category assignments to the stores without
uploading a binary.

### iOS metadata upload

```bash
cd <game>/ios
fastlane metadata
fastlane categories
```

- `fastlane metadata` pushes all locale text files under `ios/fastlane/metadata/` to App Store
  Connect via `deliver` (titles, subtitles, descriptions, keywords, promotional text,
  release notes).
- `fastlane categories` sets the primary and secondary App Store category. The `categories` lane
  must already exist in the generated `ios/fastlane/Fastfile` (written by Phase 8
  `flame-harness-build`).

### Android metadata upload

```bash
cd <game>/android
fastlane metadata
fastlane release_notes
```

- `fastlane metadata` pushes all locale text files under `android/fastlane/metadata/android/` to
  Google Play (titles, short descriptions, full descriptions) via `upload_to_play_store` with
  `skip_upload_apk: true` and `skip_upload_aab: true`.
- `fastlane release_notes` pushes the `changelogs/<version-code>.txt` files for the current
  release.

If any fastlane lane exits non-zero, do NOT proceed to the pause step. Instead write
`docs/harness/state.md` with `status: paused`, `pause_reason: manual_action`, and
`next_role: submit` (retry), then explain the error and stop.

---

## Phase 2 — Manual Steps + Pause

After both upload sequences complete successfully, the pipeline must pause so the developer can
perform the final submission actions that cannot be automated.

**Pre-submit rejection checklist** (print this with the manual steps — these are the rejections
already hit; see `docs/game-gotchas.md` → Store rejections):
- **ATT (2.1):** attach a **screen recording from a physical device** to App Review Information →
  Notes, showing fresh-install → ATT prompt appears before any tracking → following flow. (The app
  must use the wait-for-resumed ATT pattern, or the prompt won't show on the latest iOS.)
- **Localized permission strings:** every configured App Store locale's
  `ios/Runner/<locale>.lproj/InfoPlist.strings` must carry a `NSUserTrackingUsageDescription` (and
  any other `NS*UsageDescription` the app declares) — a permission string left in only one language
  is a repeat localization rejection (the reviewer sees a foreign-language prompt). Verify:
  `for d in ios/Runner/*.lproj; do grep -q NSUserTrackingUsageDescription "$d/InfoPlist.strings" || echo "MISSING: $d"; done`
  (no output = OK). Wording must match the App Privacy / tracking declaration.
- **No alpha** in the iOS icon or any screenshot.
- **Build number** incremented (ASC rejects duplicates).
- **Export compliance** set (`ITSAppUsesNonExemptEncryption=false`) so no per-upload prompt.
- **iOS App Privacy (nutrition label):** in App Store Connect → App Privacy, declare data types
  accurately (this is **separate from** `PrivacyInfo.xcprivacy`, which is a bundled manifest — the
  label is a Connect form). A missing/empty label blocks release. Use the **Data-collection profile**
  below.
- **Privacy:** `PrivacyInfo.xcprivacy` present in the bundle; tracking matches the ATT prompt.
- **Android:** privacy policy URL set (`developer.privacy`); Content Rating (IARC), Data Safety, and
  Target Audience questionnaires completed with the **Data-collection profile** below. (Contact
  email/website were set in Phase 0 via the API script.)
- **COPPA / kids:** if the game is **child-directed** (see the profile), AdMob must be "Made for kids"
  with `tagForChildDirectedTreatment`, and Play Target Audience must include children — keep all three
  consistent or expect a rejection / FTC exposure.

### Pre-pause state write

Per `docs/harness-protocol.md` §7 (`submit → metadata-done` event row) and §7 rule 3 (when
`status` is `paused`, `pause_reason` must be non-empty), write `docs/harness/state.md` atomically
with **exactly** these field changes (leave `created_at`, `current_round`, `resume_attempts`
unchanged):

```yaml
status: paused
current_phase: submit
next_role: retro
pause_reason: manual_action
updated_at: "<ISO-8601 UTC now>"
```

**Important:** `next_role: retro` is set at pause time because a paused state stores the role to
run *after* resume. `flame-harness-resume` reads `next_role` directly from `state.md` (it does
NOT set `next_role` itself) and dispatches `Skill("flame-harness-<next_role>")`. Setting
`next_role: retro` here is what causes resume to advance to retro rather than re-dispatching
submit (see Resume Contract below).

### Append to pipeline-log.md

Append one row to `docs/harness/pipeline-log.md` per the schema in `docs/harness-protocol.md` §6,
using the transition event name `metadata-done` (matches protocol §7):

```
| <ISO-8601 UTC now> | pause | submit | metadata-done: iOS metadata+categories uploaded, Android metadata+release_notes uploaded; awaiting manual Submit for Review (iOS) and production promotion (Android) |
```

### Print exact manual steps

After writing state, print the following instructions verbatim for the developer:

---

**PIPELINE PAUSED — MANUAL SUBMISSION REQUIRED**

Fastlane has uploaded all text metadata and categories. You must now complete the final
submission steps manually, as the Apple and Google APIs do not support fully automated review
submission.

**iOS — Submit for Review**

1. Open [App Store Connect](https://appstoreconnect.apple.com) and navigate to your app.
2. Select the version that was uploaded by `flame-harness-build` (Phase 8).
3. Verify that the build, all screenshots, and all metadata are correct and complete.
4. Click **"Submit for Review"** (심사 제출).
5. Answer any pre-submission questionnaires Apple presents (export compliance, content rights,
   advertising identifier / IDFA).
6. Confirm submission. The app status will change to "Waiting for Review".

**Android — Promote to Production**

1. Open [Google Play Console](https://play.google.com/console) and navigate to your app.
2. Go to **Testing → Internal testing** and locate the internal-track release uploaded by
   `flame-harness-build` (Phase 8).
3. Complete the following questionnaires if not already done (the Google Play API cannot set
   these programmatically):
   - **Content Rating** — complete the IARC questionnaire.
   - **Data Safety** — declare what data your app collects and how it is used.
   - **Target Audience** — confirm the app is not directed at children (if applicable).
4. Once all questionnaires are complete, click **"Promote release → Production"**.
5. Set the rollout percentage (100% recommended for a new app).
6. Click **"Review release"** then **"Start rollout to production"**.

**Data-collection profile** — the privacy questionnaires on both stores ask the same underlying
question. For a typical offline Flame game with AdMob (and no login/analytics/PII), fill them with:

| Question | Answer |
|---|---|
| Collects data? | **Yes** — only if AdMob is enabled (`skip_admob: false`); otherwise **No**. |
| Data type | **Identifiers** — advertising ID / device ID (AdMob). No name, email, location, contacts, photos, health, financial, or messages. |
| Purpose | **Third-party advertising** (and, if ATT-authorized, measurement). |
| Linked to identity? | No (no account/login). |
| Used for tracking? | Yes if ATT-authorized (advertising ID → cross-app). Declare this on iOS App Privacy → "Tracking". |
| Shared with third parties? | Yes — the AdMob SDK (Google). |
| Encrypted in transit? | Yes. |
| User can request deletion? | Not applicable (no server-side user data). |

- **iOS App Privacy:** declare **Identifiers → Third-Party Advertising**, and mark it under
  **Tracking** (matches the ATT prompt). If `skip_admob: true`, declare **Data Not Collected**.
- **Play Data Safety:** "Collects **Device or other IDs**" for **Advertising**, shared with Google,
  encrypted in transit; nothing else. If `skip_admob: true`, "No data collected".
- **COPPA / Target Audience:** default = **not directed at children**. Only if the concept is
  child-directed, set Play Target Audience to include under-13 **and** AdMob "Made for kids" +
  `tagForChildDirectedTreatment(true)` — all three must agree.

When you have completed all of the above steps on both platforms, run:

```
/flame-harness-resume
```

`flame-harness-resume` will confirm you are done, clear the pause, and launch
`flame-harness-retro` (the pipeline was already set to `next_role: retro` at pause time).

---

## Resume Contract

This section documents the expected behaviour of `flame-harness-resume` when it encounters the
pause written by this skill. It is informational — `flame-harness-resume` is the authoritative
implementation (see its SKILL.md).

Per `docs/harness-protocol.md` §7:

- The pause event is `metadata-done`; it sets `status: paused` with `pause_reason: manual_action`.
- The resume event transitions `(paused) → resume → retro`.
- When the user confirms all manual steps are complete, `flame-harness-resume` will:
  1. Clear `pause_reason` to `""` (per §7 rule 8).
  2. Set `status: running` atomically (per §7 rules 1 and 2). **`flame-harness-resume` does NOT
     set `next_role`** — it reads whatever `next_role` is already in `state.md`. Because this
     skill wrote `next_role: retro` at pause time, resume dispatches `retro`.
  3. Increment `resume_attempts` (per §7 rule 4).
  4. Append a `resume` row to `pipeline-log.md` (per §6).
  5. Read `next_role` (= `retro`) from the updated `state.md` and dispatch
     `Skill("flame-harness-retro")`.

The retro phase (`next_role: retro`) is the final phase; when it completes it sets
`status: completed` (per §7 `retro → complete` row).
