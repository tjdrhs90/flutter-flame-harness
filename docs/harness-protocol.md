# Harness Protocol Reference

This file is the single source of truth for all file schemas, state keys, and the phase transition
state machine used by every phase skill (Tasks 3–10). Skills cite this document rather than
redefining schemas (DRY principle).

---

## 1. `config.md` Schema

Each game's `docs/harness/config.md` must be valid YAML containing the following keys:

```yaml
app_idea: ""  # blank => research generates & recommends concepts; populated after research confirms choice
app_name: "<display name>"
app_slug: "<kebab-case identifier>"
bundle_id: "com.gonigon.<slug>"
default_language: ko
strict_mode: true          # if false, QA verdicts are advisory only
max_rounds: 3              # default; generator/evaluator loop limit
skip_research: false       # set true to skip Phase A research skill
skip_admob: false          # set true to skip AdMob integration phase

developer:
  company: gonigon
  email: tjdrhs90@gmail.com
  privacy: https://tjdrhs90.github.io/privacy/
  homepage: https://tjdrhs90.github.io
  copyright: "Copyright 2026. Gonigon all rights reserved."

ios:
  team_id: 8DHJJJ66LY
  asc_key_id: 339MZ7CUZ5
  asc_issuer_id: f9a69502-1e93-4fd1-9f53-5eb4db1b637a
  asc_private_key_path: "<absolute path to AuthKey_<asc_key_id>.p8>"

android:
  keystore_path: "<absolute path to upload.jks>"
  key_alias: upload

credentials_dir: /Users/ssg/AndroidStudioProjects/credentials

admob:
  enabled: true          # false when skip_admob
  ios_app_id: ""         # ca-app-pub-XXXX~YYYY
  android_app_id: ""     # ca-app-pub-XXXX~ZZZZ
  ad_units: []           # list of { key, ios_id, android_id, format }
```

### Key Notes

- `bundle_id` must always follow the pattern `com.gonigon.<slug>`.
- `credentials_dir` is the shared directory for all credential files (keystores, p8 keys, etc.).
- Skills must not hard-code credential paths; they must read `credentials_dir` from `config.md`.
- `max_rounds` controls how many generator→evaluator cycles are allowed before a forced judgment.

---

## 2. `state.md` Schema

Each game's `docs/harness/state.md` tracks live execution state. It must be valid YAML.

```yaml
status: running          # running | paused | completed
current_phase: research  # name of the phase currently executing
current_round: 1         # integer; increments each generator→evaluator cycle
next_role: evaluator     # role that runs next (skill name without suffix)
pause_reason: ""         # "" | rate_limit | manual_action | error
created_at: "2026-06-22T00:00:00Z"   # ISO-8601; set by bootstrap, never changed
updated_at: "2026-06-22T00:00:00Z"   # ISO-8601; updated by every skill on write
resume_attempts: 0       # integer; incremented each time the harness resumes after a pause
```

### Key Definitions

| Key | Type | Allowed Values | Written By |
|---|---|---|---|
| `status` | enum | `running` \| `paused` \| `completed` | every skill |
| `current_phase` | string | phase name (see transition table) | every skill |
| `current_round` | integer | ≥ 1 | generator, evaluator |
| `next_role` | string | skill role name | every skill |
| `pause_reason` | enum | `""` \| `rate_limit` \| `manual_action` \| `error` | every skill |
| `created_at` | ISO-8601 string | — | bootstrap only |
| `updated_at` | ISO-8601 string | — | every skill on write |
| `resume_attempts` | integer | ≥ 0 | resume handler |

**Note:** Timestamps are written by skills at runtime, not by scripts.

---

## 3. `contract.md` Layout

`docs/harness/contract.md` is negotiated between Generator and Evaluator before coding begins.

```markdown
# Contract — <app_name>

## Mandatory Hard Gates

These criteria are non-negotiable. A FAIL on any one of these results in an immediate FAIL verdict,
regardless of other passing criteria.

1. `flutter analyze` returns zero issues.
2. `flutter test` — all tests pass.
3. No TODO, stub, or placeholder in game logic (grep-checkable).
4. All tuning constants centralized in `game_config.dart` — no magic numbers in gameplay code.
5. Game content (enemies / levels / waves) is defined as data, not hardcoded.
6. KO + EN localization complete — no missing l10n keys.
7. Core loop works end to end: start → play → win/lose → restart.
8. Runs on a simulator/emulator with zero crashes and zero console errors.

## Functional Criteria (per game)

<!-- Generator adds game-specific acceptance criteria here before submitting for AGREED. -->
<!-- Example:
- Player can tap to jump and the character responds within 100 ms.
- Score increments by 1 per obstacle cleared.
- Game over screen shows final score and a restart button.
-->

## Status: AGREED
```

---

## 4. `handoff/round-N-gen.md` Layout

After each generator round, the generator writes `docs/harness/handoff/round-<N>-gen.md`.

```markdown
# Generator Handoff — Round <N>

## What Was Built / Fixed

<!-- Bullet list of features implemented or bugs fixed in this round. -->

## Contract Self-Assessment

| Criterion | Status | Notes |
|---|---|---|
| flutter analyze zero errors | DONE / PARTIAL / FAIL | … |
| flutter test zero failures | DONE / PARTIAL / FAIL | … |
| Cold-start (iOS + Android) | DONE / PARTIAL / FAIL | … |
| Flame ≥ 30 fps | DONE / PARTIAL / FAIL | … |
| No hardcoded credentials | DONE / PARTIAL / FAIL | … |
| Bundle ID correct | DONE / PARTIAL / FAIL | … |
| Assets declared in pubspec | DONE / PARTIAL / FAIL | … |
| AdMob IDs from config | DONE / PARTIAL / FAIL | … |
| <game-specific criterion> | DONE / PARTIAL / FAIL | … |

## Test Results

```
flutter analyze output (truncated to last 20 lines)
```

```
flutter test output (truncated to last 20 lines)
```

## Environment Detection

- Flutter version: <output of `flutter --version`>
- Dart version: <from above>
- Device/emulator used for smoke test: <name>

## Known Issues

<!-- List any known issues, limitations, or deferred items. State "none" if clean. -->
```

---

## 5. `feedback/round-N-qa.md` Layout

After each evaluator round, the evaluator writes `docs/harness/feedback/round-<N>-qa.md`.

```markdown
# QA Feedback — Round <N>

## Verdict

**PASS** / **FAIL**

## Evidence

Commands run and outputs (or screenshot paths):

| Command | Result | Screenshot / Log Path |
|---|---|---|
| `flutter analyze` | 0 errors | — |
| `flutter test` | 0 failures | — |
| Cold-start iOS | OK / CRASH | screenshots/round-<N>-ios-start.png |
| Cold-start Android | OK / CRASH | screenshots/round-<N>-android-start.png |
| FPS check | ≥ 30 fps | — |
| <game-specific check> | … | … |

## Failed Criteria

<!-- If verdict is FAIL, list each failing criterion with a specific, reproducible fix. -->
<!-- Example:
- **flutter analyze error**: `lib/game.dart:42` — unused import `dart:html`. Fix: remove the import.
- **Cold-start crash (Android)**: NullPointerException in `MainActivity.onCreate`. Fix: initialize FlameGame before `super.onCreate()`.
-->

<!-- If verdict is PASS, write "none". -->
```

---

## 6. Log Table Schemas

### `build-log.md`

`docs/harness/build-log.md` accumulates one row per generator round.

```markdown
# Build Log

| Round | Phase | Score | Duration | Notes |
|---|---|---|---|---|
| 1 | generator | PASS | 12 m | Initial scaffold |
| 2 | generator | FAIL | 8 m | Flame fps regression |
```

Column definitions:

| Column | Content |
|---|---|
| Round | Integer round number |
| Phase | Skill that produced the row (`generator` \| `evaluator`) |
| Score | `PASS` \| `FAIL` \| `PARTIAL` |
| Duration | Wall-clock time (human-readable, e.g. `5 m`) |
| Notes | One-line summary of the most significant change or failure |

### `pipeline-log.md`

`docs/harness/pipeline-log.md` appends one row per significant harness event.

```markdown
# Pipeline Log

| Time | Event | Phase | Details |
|---|---|---|---|
| 2026-06-22T10:00Z | start | bootstrap | config.md written |
| 2026-06-22T10:05Z | complete | research | 3 competitors analysed |
| 2026-06-22T10:30Z | pause | generator | rate_limit hit |
```

Column definitions:

| Column | Content |
|---|---|
| Time | ISO-8601 timestamp (UTC) |
| Event | `start` \| `complete` \| `pause` \| `resume` \| `error` \| `handoff` \| `PASS` \| `FAIL` |
| Phase | Current phase name at the time of the event |
| Details | Free-text one-liner |

---

## 7. Phase Transition Table

The state machine governing `current_phase`, `next_role`, and `status` transitions:

| current_phase | event | → next_role / next_phase |
|---|---|---|
| (init) | bootstrap | research (or plan if --skip-research) |
| research | complete | plan |
| plan | complete | design |
| design | complete | contract |
| contract | AGREED | generator (current_round=1) |
| generator | handoff | evaluator |
| evaluator | PASS | admob (or `build` if `skip_admob: true`) |
| evaluator | FAIL | generator (current_round+1) |
| evaluator | max_rounds | forced judgment, then admob |
| admob      | complete       | build                                    |
| build      | complete       | screenshot                               |
| screenshot | complete       | submit                                   |
| submit     | metadata-done  | status=paused, pause_reason=manual_action|
| (paused)   | resume         | retro                                    |
| retro      | complete       | status=completed                         |
| any | rate_limit | status=paused, pause_reason=rate_limit |

### State Transition Rules

1. A skill must update `state.md` atomically before exiting (write then rename/overwrite).
2. When a phase skill completes successfully and advances the pipeline, it sets `status: running` together with `current_phase` and `next_role` in the same `state.md` update. Only the rate-limit hook, an error, or a pause sets `status: paused`.
3. When `status` is set to `paused`, `pause_reason` must be one of `rate_limit`, `manual_action`, or `error` (never empty).
4. When `status` is set to `running` after a pause, `resume_attempts` must be incremented.
5. `current_round` starts at 1 when the contract is AGREED and increments each time the evaluator returns FAIL (i.e., at the start of each new generator round).
6. When `current_round` exceeds `max_rounds` the evaluator triggers the `max_rounds` event, writes a forced judgment, and transitions to `admob`.
7. `completed` status is set only after the final phase (`retro`) exits cleanly.
8. `pause_reason` is set only by the rate-limit hook / error path, and is cleared (set to `""`) by `flame-harness-resume` when it returns `status` to `running`. Forward-flow phase skills do not need to touch `pause_reason`.
9. If `config.md` `skip_admob: true`, the evaluator's PASS sets `next_role: build` (admob is skipped).
