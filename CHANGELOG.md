# Changelog

All notable changes to flutter-flame-harness are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/), and versions follow [Semantic Versioning](https://semver.org/).

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
