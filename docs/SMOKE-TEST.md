# Phase A Smoke Test — Manual Procedure

This document is a step-by-step manual dry run of the full Phase A pipeline using a deliberately
tiny game idea. A human runs each `/flame-harness*` command in their own Claude Code session.
This agent cannot execute those commands on your behalf.

**Test game:** `--skip-research "tap to flap, single obstacle"`

---

## Prerequisites

1. Claude Code is installed and running.
2. The plugin is installed in your session:

   ```
   /plugin marketplace add <projects-dir>/flutter-flame-harness
   /plugin install flutter-flame-harness
   ```

   **Verify:** running `/flame-harness --help` (or `/flame-harness` with no arguments) should
   show the argument-hint. The skill list should contain these 9 entries:
   `flame-harness`, `flame-harness-research`, `flame-harness-plan`, `flame-harness-design`,
   `flame-harness-contract`, `flame-harness-generator`, `flame-harness-evaluator`,
   `flame-harness-status`, `flame-harness-resume`.

3. Flutter SDK is on your `PATH` (`flutter doctor` passes for at least one target).
4. The credentials store file exists:
   `<projects-dir>/credentials/store-metadata.md`
   (the orchestrator reads `developer`, `ios`, and `android` blocks from it).

---

## Step 1 — Validate the plugin

Run from the repo root (terminal, not Claude Code):

```bash
bash scripts/validate.sh && bash scripts/test-hook.sh
```

**Expected output:**

```
validate: OK
PASS: no-state silent exit 0
PASS: paused set
PASS: reason set
```

A failure here means a skill file or hook is broken — fix before continuing.

---

## Step 2 — Launch the pipeline

In your Claude Code session, run:

```
/flame-harness --skip-research "tap to flap, single obstacle"
```

**Variation — no-idea run:** run `/flame-harness` with no arguments and confirm that the research
phase presents 2-3 concept recommendations via AskUserQuestion and waits for your pick before
proceeding (the pipeline must not auto-select a concept).

The orchestrator bootstraps `docs/harness/` inside the new game project directory, writes
`config.md` and `state.md`, then dispatches each phase in order.

---

## Phase-by-Phase Checklist

Work through each phase in sequence. After each phase completes, verify the items listed.

### Phase 0 — Bootstrap

After the orchestrator starts (before any phase skill runs):

- [ ] `docs/harness/` directory tree exists:
  ```
  docs/harness/
  docs/harness/handoff/
  docs/harness/feedback/
  docs/harness/specs/
  docs/harness/plans/
  ```
- [ ] `docs/harness/config.md` is valid YAML and contains:
  - `app_idea: "tap to flap, single obstacle"`
  - `app_slug:` a non-empty kebab-case string
  - `bundle_id: "com.<company>.<slug>"` — the slug must match `app_slug`
  - `skip_research: true`
  - `developer:`, `ios:`, `android:` blocks populated from `store-metadata.md`
- [ ] `docs/harness/state.md` is valid YAML with:
  - `status: running`
  - `current_phase: plan`  ← because `--skip-research` was passed
  - `current_round: 1`
  - `next_role: plan`
  - `pause_reason: ""`
  - `created_at:` set to the current UTC time
  - `updated_at:` same or later

**Expected `state.md` at this point:**
```yaml
status: running
current_phase: plan
current_round: 1
next_role: plan
pause_reason: ""
created_at: "<ISO-8601 timestamp>"
updated_at: "<ISO-8601 timestamp>"
resume_attempts: 0
```

---

### Phase 1 — Plan (`flame-harness-plan`)

- [ ] `docs/harness/plans/prd.md` (or equivalent PRD file) exists.
- [ ] PRD contains `app_slug:` entry.
- [ ] PRD contains `bundle_id: com.<company>.<slug>`.
- [ ] PRD contains a scope guard section (no features beyond single-obstacle flap).
- [ ] PRD contains a `lib/` directory structure map.
- [ ] `docs/harness/pipeline-log.md` contains a `complete` row for the `plan` phase.
- [ ] `state.md` updated:
  - `current_phase: design`
  - `next_role: design`
  - `status: running`

---

### Phase 2 — Design (`flame-harness-design`)

- [ ] `docs/harness/specs/design-tokens.md` (or equivalent) exists and contains:
  - Color palette
  - Typography settings
  - At least one asset/audio plan entry
- [ ] `docs/harness/pipeline-log.md` has a `complete` row for `design`.
- [ ] `state.md` updated:
  - `current_phase: contract`
  - `next_role: contract`
  - `status: running`

---

### Phase 3 — Contract (`flame-harness-contract`)

The generator and evaluator negotiate completion criteria. This phase ends only when both
sides agree to the contract.

- [ ] `docs/harness/contract.md` exists.
- [ ] `contract.md` contains `## Status: AGREED`.
- [ ] `contract.md` contains all **8 mandatory hard gates** (in the `## Mandatory Hard Gates`
  section):
  1. `flutter analyze` returns zero issues.
  2. `flutter test` — all tests pass.
  3. No TODO, stub, or placeholder in game logic.
  4. All tuning constants centralized in `game_config.dart`.
  5. Game content defined as data, not hardcoded.
  6. KO + EN localization complete.
  7. Core loop works end to end: start → play → win/lose → restart.
  8. Runs on a simulator/emulator with zero crashes and zero console errors.
- [ ] `contract.md` contains at least one game-specific functional criterion under
  `## Functional Criteria`.
- [ ] `docs/harness/pipeline-log.md` has a `complete` row for `contract`.
- [ ] `state.md` updated:
  - `current_phase: generator`
  - `next_role: generator`
  - `current_round: 1`
  - `status: running`

---

### Phase 4 — Generator (`flame-harness-generator`)

The generator builds the Flutter/Flame project in three sub-phases: scaffold → API wiring →
UI polish.

- [ ] Flutter project directory exists at `<projects-dir>/<slug>/`.
- [ ] `flutter create` was run (check for `pubspec.yaml` in the project root).
- [ ] Sub-phase A (scaffold): project compiles — `flutter analyze` reports 0 errors.
- [ ] Sub-phase B (API/game logic): `flutter test` passes.
- [ ] Sub-phase C (UI polish): no TODO/stub/placeholder in any `lib/` file
  (`grep -r "TODO\|stub\|placeholder" <slug>/lib/` returns empty).
- [ ] `docs/harness/handoff/round-1-gen.md` exists and contains:
  - `## What Was Built`
  - `## Contract Self-Assessment` table
  - `## Test Results` with `flutter analyze` and `flutter test` output
- [ ] `docs/harness/build-log.md` has a row for round 1.
- [ ] `docs/harness/pipeline-log.md` has a `handoff` row for `generator`.
- [ ] `state.md` updated:
  - `current_phase: evaluator`
  - `next_role: evaluator`
  - `status: running`

---

### Phase 5 — Evaluator (`flame-harness-evaluator`)

The evaluator runs the game on a device/emulator, takes screenshots, and writes a verdict.

**If PASS:**

- [ ] `docs/harness/feedback/round-1-qa.md` exists with `**PASS**` verdict.
- [ ] Evidence table contains `flutter analyze`, `flutter test`, and at least one cold-start
  entry.
- [ ] Screenshots exist in `docs/harness/screenshots/` (or referenced paths exist).
- [ ] Pipeline halts at the Phase B boundary with a handoff message:
  - The orchestrator prints something like:
    `"Phase A complete. Phase B (admob) is out of scope for this run. Handoff ready."`
  - `state.md` updated:
    - `status: paused` (or `completed` if `skip_admob: true`)
    - `current_phase: admob`
    - `next_role: admob`
    - `pause_reason: manual_action`
- [ ] `docs/harness/pipeline-log.md` has a `PASS` row for `evaluator`.

**If FAIL (round increment path):**

- [ ] `docs/harness/feedback/round-1-qa.md` exists with `**FAIL**` verdict.
- [ ] `## Failed Criteria` section lists each failing criterion with a specific, reproducible fix.
- [ ] `state.md` updated:
  - `current_phase: generator`
  - `next_role: generator`
  - `current_round: 2`  ← incremented
  - `status: running`
- [ ] `docs/harness/pipeline-log.md` has a `FAIL` row for `evaluator`.
- [ ] The orchestrator automatically re-dispatches `flame-harness-generator` for round 2.
- Repeat the generator/evaluator checklist above for round 2, substituting `round-2-*` file names.

---

## State Transition Reference

The table below shows every expected `state.md` snapshot (against the protocol in
`docs/harness-protocol.md` Section 7).

| After step | `current_phase` | `next_role` | `current_round` | `status` |
|---|---|---|---|---|
| Bootstrap (`--skip-research`) | `plan` | `plan` | `1` | `running` |
| Plan complete | `design` | `design` | `1` | `running` |
| Design complete | `contract` | `contract` | `1` | `running` |
| Contract AGREED | `generator` | `generator` | `1` | `running` |
| Generator handoff | `evaluator` | `evaluator` | `1` | `running` |
| Evaluator PASS | `admob` | `admob` | `1` | `paused` |
| Evaluator FAIL | `generator` | `generator` | `2` | `running` |
| Rate-limit event (any phase) | `<current>` | `<current>` | unchanged | `paused` |

---

## What to Check After a Rate-Limit Pause

If Claude Code hits a rate limit mid-pipeline, the `stop-failure-handler.sh` hook fires.

- [ ] `state.md` has `status: paused` and `pause_reason: rate_limit`.
- Resume with:
  ```
  /flame-harness --resume
  ```
- [ ] After resume, `resume_attempts` incremented by 1 in `state.md`.
- [ ] `status` returns to `running` and `pause_reason` cleared to `""`.

---

## Phase B Boundary — Expected Halt

At the end of a successful evaluator PASS, Phase A is complete. The orchestrator **must not**
proceed to AdMob, build, screenshot, or submit phases (Phase B). Expected behavior:

- A clear handoff message is printed in the Claude Code session.
- `state.md` `current_phase` is set to `admob`.
- `state.md` `status` is `paused` with `pause_reason: manual_action`
  (unless `--skip-admob` was passed, in which case `status: completed`).
- No AdMob-related files are created.

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
| `test-hook.sh` | PASS / FAIL |
| Plugin installed (9 skills visible) | YES / NO |
| Bootstrap creates config.md + state.md | YES / NO |
| Plan: PRD has app_slug + com.<company>.\<slug\> | YES / NO |
| Design: tokens doc created | YES / NO |
| Contract: `## Status: AGREED` + all 8 hard gates | YES / NO |
| Generator: flutter analyze 0 errors | YES / NO |
| Generator: flutter test 0 failures | YES / NO |
| Evaluator: launches game + screenshots | YES / NO |
| Evaluator verdict written (PASS or FAIL) | YES / NO |
| FAIL path: round increments + generator re-dispatched | YES / NO |
| Phase B boundary halt (admob) | YES / NO |
| No secrets in git (`git ls-files \| grep -Ei 'jks\|\.p8\|\.p12'` → empty) | YES / NO |

**Tester:** _______________  
**Date:** _______________  
**Overall result:** PASS / FAIL
