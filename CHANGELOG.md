# Changelog

All notable changes to flutter-flame-harness are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/), and versions follow [Semantic Versioning](https://semver.org/).

## [0.21.0] — 2026-08-25

### Added
- **App Store Connect submission over the API is documented, and the old claim that it cannot be
  automated is corrected.** `POST /v1/appStoreVersionSubmissions` has been deprecated —
  it answers `403 "Allowed operation is: DELETE"` — and the working flow is three calls:
  `reviewSubmissions` → `reviewSubmissionItems` → `PATCH { submitted: true }`. The submit skill now
  carries that flow as a reference section. The pipeline still pauses before the final submission,
  but now says so as a deliberate checkpoint rather than an API limitation.
- **Resubmitting after a rejection.** A rejected version stays attached to the submission that
  rejected it, so adding it to a new one fails with `STATE_ERROR.ITEM_PART_OF_ANOTHER_SUBMISSION`;
  every item under a submission in state `UNRESOLVED_ISSUES` has to be detached with
  `{ removed: true }` first. And a rejection is edited in place — `REJECTED`,
  `DEVELOPER_REJECTED`, `METADATA_REJECTED`, `INVALID_BINARY` are all editable states, so a new
  version record is both unnecessary and rejected as a duplicate version string.
- **Age rating: the declarations Apple added in 2026.** `userGeneratedContent`, `messagingAndChat`,
  `ageAssurance`, `gunsOrOtherWeapons`, `advertising`, `healthOrWellnessTopics`, `parentalControls`.
  An app record that only answered the old questionnaire cannot enter review. Any AdMob build must
  answer `advertising` = Yes — banners count — or Apple's automated analysis bounces it before a
  human looks. `ageRatingDeclarations` is write-only over the API (`GET` → `403`), so this is not
  auditable programmatically; the checklist says to open the Connect UI.
- **Play Console declarations come from the merged manifest.** A dependency's own
  `AndroidManifest.xml` is merged into the bundle, so a permission nobody typed becomes a
  declaration to file under App content → Needs attention. `FOREGROUND_SERVICE_*` requires a form
  with a mandatory demo video showing the feature working while the app is backgrounded, and past
  the compliance deadline it blocks updates while the live listing stays up. Deleting your own
  `<uses-permission>` line does nothing when the dependency declares it.
- **Metadata locks at release, not at submission** — `whatsNew`, store URLs, and review notes stay
  editable through `WAITING_FOR_REVIEW` and `IN_REVIEW`, and start returning `409` at
  `READY_FOR_SALE`.
- **Resolution Center has no API.** The rejection text cannot be read and cannot be replied to;
  `appStoreReviewDetail.notes` is the only reviewer-facing field that can be written, so a fix
  explanation belongs there **before** the resubmission rather than after it.
- **`TARGETED_DEVICE_FAMILY` has to match reality** — declaring iPad (`"1,2"`, a template default)
  obliges the game to support every iPad orientation, and a portrait-only phone game shipped that
  way is rejected under 4.0.
- **A released version string cannot take another build** (*"Invalid Pre-Release Train … closed for
  new build submissions"*); bump the name in `pubspec.yaml` and leave `+N`, the Android
  `versionCode`, on its own schedule.
- **Build-machine gotchas:** a build script that `git checkout`s a generated-but-tracked file
  (`project.pbxproj`) silently reverts deliberate source edits, so the repo and the shipped binary
  disagree with no error anywhere — copy and `mv` back instead; editing a shell script while it runs
  corrupts the running shell's byte offsets; simultaneous iOS + Android release builds OOM a 16 GB
  machine; and a portfolio sweep should take its app list from `GET /v1/apps`, not from directory
  layout, which misses every project that builds iOS from its own tree.

## [0.20.0] — 2026-07-28

### Fixed
- **Screenshot capture wrote nothing at all:** the screenshot skill's test-driver boilerplate was
  `Future<void> main() => integrationDriver();`, but `integrationDriver` has **no default screenshot
  writer** — its native path is guarded by `onScreenshot != null`, so every `takeScreenshot` byte was
  silently discarded and no PNG was ever produced. The skill now supplies an `onScreenshot` callback
  that writes to `$SCREENSHOT_DIR` (default `build/screenshots`), the Phase 2 locale loop gives each
  locale its own staging directory, and Phase 4 copies from there into the fastlane paths with a
  per-locale file count printed. The old claim that `flutter drive` "writes PNG files to `<game>/`"
  was wrong and is gone. Verified: the callback type-checks against the real `ScreenshotCallback`
  typedef (`dart analyze`, no issues).
- **`sips -s format png` was recommended to strip alpha, and it does not:** it re-encodes and keeps
  the channel, so the "flatten before upload" step left the App Store alpha rejection in place — the
  exact rejection the guidance exists to prevent. (The evaluator's `sips -g hasAlpha` *detector* was
  correct all along; only the fix was wrong.) Replaced with two verified recipes —
  `magick … -alpha remove -alpha off`, or a JPEG round-trip using macOS built-ins — both confirmed to
  turn `hasAlpha: yes` into `hasAlpha: no` on a real RGBA PNG.
- **ASO keyword length was measured in bytes, wasting two thirds of the field:** the skill told you to
  check `keywords.txt` with `echo -n … | wc -c`, which counts **bytes**; one Hangul syllable is 3
  bytes in UTF-8, so a valid 97-character Korean string measures 247 and looks 2.5× over the 100-char
  cap. Following it truncates Korean keywords to ~33 characters. Now counts characters (and notes
  that a here-string `<<<` adds a newline and inflates the count by 1). Both worked examples were
  also mislabelled — "exactly 97 chars" was 53 and "exactly 96 chars" was 87, i.e. both violated the
  skill's own 95–100 rule; replaced with strings measured at 97 (KO) and 99 (EN).
- `validate.sh` now guards all three against regression, and `game-gotchas.md` records them. Each
  guard was confirmed to actually fail when the corresponding guidance is removed.

## [0.19.0] — 2026-07-28

### Fixed
- **Every iOS store screenshot uploaded twice, and `deliver` reported success:** `deliver` judges
  "already uploaded?" by comparing App Store Connect's `sourceFileChecksum` to the local file's MD5.
  When that comparison doesn't match, its post-upload verification concludes *every* local file is
  missing and retries — and the retry keeps the screenshots that already landed while re-uploading
  the whole set, so each image is stored twice. Once a set holds 10 images `deliver`'s own "nothing
  missing" guard passes, so it prints *Successfully uploaded all screenshots* and exits 0 on the
  doubled set (a 5-shot locale doubles to exactly 10 with no error). `overwrite_screenshots: true`
  does not prevent it — that only clears the sets *before* the first round. The iOS Fastfile template
  now carries `prune_duplicate_screenshots!`, which keys on **file name** instead of checksum: it
  keeps one screenshot per name (preferring a `COMPLETE` one), drops failed/incomplete leftovers,
  restores filename order, and checks the per-locale count against the local PNGs. The `screenshots`
  lane runs it strictly after upload so a doubled set now *fails* the lane, and a new
  `screenshots_prune` lane runs it standalone to clean an app that already carries duplicates.
  `screenshots_path` is pinned so the upload and the check read the same directory. The screenshot
  skill also empties each locale directory before copying captures in (`deliver` uploads every PNG it
  finds, and a stale file would skew the count check), and documents why the cleanup step must not be
  removed; `game-gotchas.md` records the behaviour and `validate.sh` asserts the skill covers it.
  Verified by extracting the helper from the template and running it against stubs across 5
  scenarios / 14 assertions — including the reported symptom (ko + en-US each doubled to 10),
  `COMPLETE`-preferring survivor choice, `FAILED` orphan removal, a locale with no local directory,
  and strict-vs-report modes — plus `fastlane lanes` to confirm both lanes register.

## [0.18.1] — 2026-07-08

### Changed
- **Concrete `SKAdNetworkItems` guidance:** the admob skill now spells out that `SKAdNetworkItems` is
  a *required manual* Info.plist step (the SDK doesn't inject it), gives the minimal Google ID
  (`cstr6suwn9.skadnetwork`), and links Google's authoritative lists (quick-start + 3p SKAdNetwork
  IDs) with a note to copy the current full list at build time. Mirrored in `game-gotchas.md`.

## [0.18.0] — 2026-07-08

### Fixed
- **Android adaptive icon looked cropped/"zoomed" (iOS icon reused full-bleed):** the generator only
  wired `image_path`, and `gen_icon.dart` produced a single full-bleed icon — so on Android the
  launcher mask (108dp canvas, ~66dp safe zone) cropped it. `gen_icon.dart` now also emits a
  **padded adaptive foreground** (`icon-fg.png`, motif kept inside the safe zone) and a **monochrome
  themed-icon layer** (`icon-mono.png`, white-on-transparent), and the `flutter_launcher_icons`
  config wires `adaptive_icon_foreground`/`adaptive_icon_background`/`adaptive_icon_monochrome`.
  Covers the Android 13+/Play themed-icon expectation. Documented in `game-gotchas.md`; evaluator R5
  and `validate.sh` assert it. Verified by running the icon generator (all layers emitted; foreground
  padded, monochrome = opaque-white centre + transparent corners).

## [0.17.0] — 2026-07-07

### Fixed
- **Localized ATT / permission strings (repeat App Store rejection):** the admob skill hard-coded
  `NSUserTrackingUsageDescription` in a single language in the base `Info.plist` and never localized
  it — so a non-Korean listing showed a foreign-language prompt (real, recurring rejection). Now the
  base string is written in `default_language` and the ATT reason is added to every configured
  locale's `ios/Runner/<locale>.lproj/InfoPlist.strings`. `submit`'s pre-submit checklist verifies
  every locale carries the string, `game-gotchas.md` documents it as a distinct rejection, and
  `validate.sh` asserts both.

## [0.16.0] — 2026-07-03

### Added
- **Accessibility & safety baseline (gate R10):** no >3 Hz flashing (photosensitive safety), respect
  OS Reduce Motion (`MediaQuery.disableAnimations`), ≥48dp tap targets + `Semantics` labels on
  menu/overlay buttons. Full in-game screen-reader support remains out of scope (arcade games).
- **Test depth (gate R11):** generator now scaffolds real tests (system unit + widget + integration)
  from new templates; requires ≥3 system unit + ≥1 widget + ≥1 integration test. Default-mode QA
  checks it (was `--strict`-only). Adds the `integration_test` dev dependency.
- **Store-compliance completeness:** submit skill now includes a concrete iOS App Privacy label +
  Play Data Safety data-collection profile and COPPA/child-directed consistency guidance.
- **Resilience:** `flutter create` idempotency guard (safe re-run/resume) + per-sub-phase
  `checkpoint` in `state.md` so resume skips completed sub-phases; store-upload non-idempotency note.

## [0.15.0] — 2026-06-30

### Added
- Generated games now get a complete `.gitignore` (the full `templates/gitignore.template` appended
  onto `flutter create`'s standard one), a `README.md`, and a `LICENSE` (MIT).
- Plugin-repo CI (`.github/workflows/validate.yml`) runs all three validators on push/PR.
- Contributor infra: issue + PR templates, `CONTRIBUTING.md`, `SECURITY.md`, this `CHANGELOG.md`.

### Changed
- `pubspec.lock` is explicitly committed in generated games (reproducible builds).

## [0.14.0] — 2026-06-30

### Security
- De-personalized the harness: replaced all hard-coded developer/contact/company/signing values with
  placeholders. (No key material was ever committed — `.p8`/`.jks`/JSON keys are gitignored.)

### Added
- Bootstrap sources developer/signing info from the user's own `store-metadata.md`, asking
  interactively when absent (never a sample identity or hard-coded company).
- Generator `git init`s each generated game and makes atomic Conventional commits at every gate.

## [0.13.1] — 2026-06-30

### Fixed
- `default_language` falls back to the OS locale (`AppleLanguages`/`$LANG`) when there's no
  conversational signal, so a bare `/flame-harness` bootstraps in the user's language, not English.

## [0.13.0] — 2026-06-29

### Added
- Durable, device-transfer-surviving save (gate R9, default on): iOS Keychain + Android Block Store +
  `shared_preferences`, via a `SaveRepository`.

## [0.12.0] — 2026-06-25

### Added
- Required Google Play listing graphics (gate R8): 512×512 hi-res icon + 1024×500 feature graphic.

## [0.11.0] — 2026-06-25

### Added
- Store-info upload: iOS App Review contact + copyright + support/marketing/privacy URLs, Android
  contact details — sourced from the developer block in config.
