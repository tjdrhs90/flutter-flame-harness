---
name: flame-harness-contract
description: Phase 4 — propose verifiable completion criteria and mandatory hard gates; reach AGREED (1-pass default, multi-round negotiation in --strict).
argument-hint: ""
allowed-tools: [Agent, Read, Write, Edit, Bash]
---

# flame-harness-contract

Phase 4 of the flutter-flame-harness pipeline. Reads the PRD and design doc, proposes verifiable
completion criteria (Mandatory Hard Gates + Functional Criteria), and marks the contract AGREED
before handing off to the generator.

All file schemas (`config.md`, `state.md`, `contract.md`) are defined in
`docs/harness-protocol.md` — refer to that document as the single source of truth. Do not
redefine schemas here.

---

## Input

### 1. Read `docs/harness/config.md`

Extract:

| Key | Use |
|---|---|
| `app_name` | Contract title header |
| `app_slug` | Used to identify the game |
| `strict_mode` | If `true`, run `--strict` negotiation; if `false` (or absent), run default 1-pass |

### 2. Read the latest PRD

Find the most recent file matching `docs/harness/plans/*-prd.md` (sort by filename descending,
take the first). Abort with a clear message if none exists.

### 3. Read the design doc

Find the most recent file matching `docs/harness/plans/*-design.md` (sort by filename
descending, take the first). Abort if none exists.

---

## Mandatory Hard Gates

These 8 criteria are non-negotiable and must appear verbatim in every `contract.md`. A FAIL on
any one results in an immediate FAIL verdict, regardless of other passing criteria.

> **Source:** `docs/harness-protocol.md` §3 — Mandatory Hard Gates block. Always cite; never
> restate differently.

1. `flutter analyze` returns zero issues.
2. `flutter test` — all tests pass.
3. No TODO, stub, or placeholder in game logic (grep-checkable).
4. All tuning constants centralized in `game_config.dart` — no magic numbers in gameplay code.
5. Game content (enemies / levels / waves) is defined as data, not hardcoded.
6. Localization complete for all configured locales — `default_language`, plus English when `default_language` ≠ `en` — no missing l10n keys.
7. Core loop works end to end: start → play → win/lose → restart.
8. Runs on a simulator/emulator with zero crashes and zero console errors.

Copy these 8 lines verbatim into the `## Mandatory Hard Gates` section of `contract.md`. Do not
paraphrase, reorder, or omit any gate.

## Platform-Robustness Gates

In addition to the 8 core gates above, every contract includes a `## Platform-Robustness Gates`
section requiring the patterns in `docs/game-gotchas.md` (cite it). These are mandatory:

- **R1 Audio safe**: all audio calls in try/catch (missing asset never crashes); frequent SFX use an
  `AudioPool` (not per-call `FlameAudio.play()`); BGM stops on game-over, app-background, and teardown.
- **R2 Haptics safe** (if the game uses haptics): a `Haptics` helper with platform guard + throttle +
  `enabled` toggle + try/catch; gameplay never calls `HapticFeedback.*` raw.
- **R3 Lifecycle**: app host implements `WidgetsBindingObserver`; on background → `pauseEngine()` +
  BGM pause; resume reverses; teardown cleans up audio/timers.
- **R4 Performance**: no per-frame `world.children.whereType<...>()` in a hot path (cache once per
  frame); `Paint`/shaders not recreated per frame.
- **R5 App branding**: a custom icon + splash are generated (not the default Flutter art), the icon
  is opaque (no alpha), and the localized app display name (`CFBundleDisplayName`/`android:label`) is
  set to `app_name` — not "Runner"/the slug.
- **R6 Native config**: orientation locked **natively** to `config.orientation` (the unused
  orientation removed — no launch rotate); iPhone-only (`TARGETED_DEVICE_FAMILY = 1`, no iPad);
  `ITSAppUsesNonExemptEncryption = false`; root back-button = SnackBar double-press-to-exit;
  bundle id **byte-identical** across iOS (`PRODUCT_BUNDLE_IDENTIFIER`) and Android (`applicationId`)
  == `config.bundle_id` (lowercase, no `_`/`-`).
- **R7 Assets & CI**: the game ships with audio (synthesized or sourced) + visuals (code-drawn or
  cleaned sprites) and **no missing-asset references** (every `pubspec.yaml` asset exists); a
  `.github/workflows` CI (analyze + test) is present.
- **R8 Store graphics**: Android Play listing has the required **hi-res icon (512×512)** and
  **feature graphic (1024×500)** placed for `supply` (`metadata/android/<locale>/images/icon.png` +
  `featureGraphic.png`); iOS has localized screenshots.
- **R9 Durable save**: persistence survives reinstall **and** device transfer (not `shared_preferences`
  alone) — a `SaveRepository` mirrors the save blob to iOS Keychain (`flutter_secure_storage`,
  `first_unlock`) + Android Block Store (`play_services_block_store`) + a `shared_preferences` cache,
  reading durable-first and writing all tiers in try/catch; `PreferencesService` routes through it.
- **R10 Accessibility & safety baseline**: no effect flashes faster than 3×/second (photosensitive
  safety); OS Reduce Motion (`MediaQuery.disableAnimations`) is read and damps screen-shake/particles/
  flashing; menu/overlay buttons are ≥48×48 dp with `Semantics` labels (icon-only buttons especially);
  in-game HUD keeps `withNoTextScaling`. (Full in-game screen-reader support is out of scope.)
- **R11 Test depth**: beyond `flutter test` merely passing, the game ships **≥3 system unit tests**
  (score/spawn/difficulty/economy — real logic), **≥1 widget test** (a menu/overlay renders + a button
  taps), and **≥1 integration test** (core loop: boot → play → game-over). Mirrors the shipped games;
  prevents a green `flutter test` that actually covers nothing.

---

## Functional Criteria

Per-game acceptance criteria derived from the PRD. Each criterion must be verifiable by one of:

- **Command** — a shell command whose exit code or output proves the criterion (e.g.,
  `grep -r "TODO" lib/` returns no matches).
- **Screenshot** — a labelled screenshot that visually confirms the criterion.
- **Code path** — a named file + method that implements the behaviour, plus a test that exercises it.

### Writing Functional Criteria

Read the PRD sections carefully:

| PRD section | What to extract |
|---|---|
| Core Loop | One criterion per loop step (each step must be observable) |
| Game Mechanics | One criterion per mechanic; specify measurable threshold |
| Win/Lose Conditions | Explicit pass/fail states |
| Content Metrics | Count targets (e.g. "≥ 3 enemy types defined in data files") |
| Progression & Economy | Score increments, reward triggers |

Criteria that are NOT verifiable (e.g. "the game is fun") must be rewritten as observable checks
or removed. Every criterion that references a timing threshold must cite a concrete number (e.g.
"responds within 100 ms" not "responds quickly").

Aim for 5–10 Functional Criteria per game. More is not better — specificity is.

### Anti-stub rule

Before marking AGREED, run:

```bash
grep -rn "TODO\|stub\|placeholder\|스텁\|미구현" lib/ --include="*.dart"
```

If this command returns any output, the contract must NOT be marked AGREED. Remove or resolve
every stub before proceeding.

---

## Negotiation

### Default mode (1-pass)

When `strict_mode` is `false` or absent:

1. Generator reads the PRD and design doc.
2. Generator writes `docs/harness/contract.md` with:
   - The 8 Mandatory Hard Gates verbatim (from `docs/harness-protocol.md` §3).
   - 5–10 Functional Criteria derived from the PRD.
3. Generator self-reviews each criterion for verifiability.
4. Generator marks the contract `## Status: AGREED` in the same pass.
5. Generator updates `state.md` and hands off to the generator phase.

### --strict mode (rigorous self-review)

When `strict_mode: true` in `config.md`, or when the skill is invoked with `--strict`:

1. Generator writes the initial `contract.md` (same as default, steps 1–3 above).
2. Generator performs a **second self-review pass** over every Functional Criterion, checking
   each one against all three of the following gates:
   - **Concrete verification method** — does the criterion name a specific shell command (with
     expected exit code or output), a labelled screenshot, or a named file + method + test?
     Vague language like "works correctly" or "looks good" must be rewritten with a measurable
     check.
   - **Concrete numbers** — every timing, count, or threshold must cite a real value (e.g.
     "responds within 100 ms", "≥ 3 enemy types", "score increments by 10 per obstacle").
     Relative terms ("quickly", "several", "enough") must be replaced.
   - **Full PRD coverage** — confirm that every core loop step, mechanic, win/lose condition,
     and content metric from the PRD has at least one corresponding Functional Criterion.
3. If any criterion fails the second-pass check, revise it in-place before proceeding.
4. Generator self-marks `## Status: AGREED` and proceeds (same `state.md` write as default mode).

> **Phase B note:** Phase B may reintroduce Evaluator-side contract negotiation with a
> Generator↔Evaluator round-trip; Phase A uses rigorous self-review only.

In both modes the contract file must contain `## Status: AGREED` before the generator phase
begins coding.

---

## Output

### 1. Write `docs/harness/contract.md`

Use the layout defined in `docs/harness-protocol.md` §3:

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
6. Localization complete for all configured locales — `default_language`, plus English when `default_language` ≠ `en` — no missing l10n keys.
7. Core loop works end to end: start → play → win/lose → restart.
8. Runs on a simulator/emulator with zero crashes and zero console errors.

## Functional Criteria (per game)

<!-- Generator adds game-specific acceptance criteria here. -->
<!-- Each criterion must be verifiable by command, screenshot, or code path. -->

## Status: AGREED
```

If `docs/harness/` does not exist, create it before writing.

### 2. Update `state.md`

Update `docs/harness/state.md` per the schema in `docs/harness-protocol.md` §2:

```yaml
status: running
current_phase: contract
next_role: generator
current_round: 1
updated_at: "<ISO-8601 UTC now>"
```

Leave all other keys unchanged. Use `Edit` for a targeted update.

Per `docs/harness-protocol.md` §7 (Phase Transition Table): the `contract → AGREED` event sets
`next_role: generator` and `current_round: 1`.

### 3. Append to `pipeline-log.md`

Append one row to `docs/harness/pipeline-log.md` per the schema in `docs/harness-protocol.md` §6:

```
| <ISO-8601 UTC now> | complete | contract | contract AGREED; <N> functional criteria; next: generator |
```

---

## Error handling

- If the PRD is missing, abort with a clear message and set `state.md` to `status: paused`,
  `pause_reason: manual_action`.
- If the design doc is missing, abort with a clear message and set `state.md` to
  `status: paused`, `pause_reason: manual_action`.
- If `config.md` cannot be read, abort immediately (do not write partial output).
- In `--strict` mode, the Generator self-marks AGREED after the rigorous second-pass review;
  there is no multi-round Evaluator loop in Phase A. `max_rounds` applies only to the
  generator→evaluator cycle (Phase 5–6), not to contract negotiation.
