---
name: flame-harness-evaluator
description: Phase 6 — skeptical QA. Run the game, watch it, then judge against the contract. Default = functional check; --strict adds quality and edge-case passes.
argument-hint: ""
allowed-tools: [Agent, Read, Write, Edit, Bash, Glob, Grep]
---

# flame-harness-evaluator

Phase 6 of the flutter-flame-harness pipeline. Skeptical QA gate that decides PASS or FAIL
against the negotiated contract. Default mode runs the functional check (6.1) only; `--strict`
adds quality scoring (6.2) and an agent-team edge-case sweep (6.3).

All file schemas (`config.md`, `state.md`, `handoff/round-N-gen.md`, `feedback/round-N-qa.md`,
`build-log.md`) and the phase transition table are defined in `docs/harness-protocol.md` — that
document is the single source of truth (§1 for `config.md`; §2 for `state.md`; §3 for
`contract.md`; §4 for handoff layout; §5 for feedback layout; §6 for log schemas; §7 for the
`evaluator → admob / evaluator → build / evaluator → generator` transitions). Do not redefine schemas here.

---

## Critical Rule

**"Run the code, see the app, then judge." Never PASS on code review alone. Execute commands,
launch the game on a simulator, play the core loop, capture and study screenshots. Stub detected
= automatic FAIL, no exceptions.**

---

## Setup — Read Inputs

Before any check, load:

1. `docs/harness/state.md` — extract `current_round` (integer ≥ 1) and confirm
   `next_role: evaluator`.
2. `docs/harness/config.md` — extract `app_slug`, `strict_mode` (bool), `max_rounds` (int).
3. `docs/harness/contract.md` — parse `## Mandatory Hard Gates` and `## Functional Criteria`.
   Confirm `## Status: AGREED` is present; if missing, abort with:
   `flame-harness-evaluator: contract not AGREED — run flame-harness-contract first`.
4. `docs/harness/handoff/round-<N>-gen.md` (where N = `current_round`) per protocol §4.
   If the file is missing, abort with:
   `flame-harness-evaluator: handoff for round <N> not found — generator must run first`.

---

## 6.1 Functional Check (default — always runs)

Run every step in order. A failure on any **Mandatory Hard Gate** from `contract.md` is an
immediate FAIL — do not continue checking remaining criteria.

### Step 1 — Static analysis

```bash
cd /Users/ssg/AndroidStudioProjects/<app_slug>
flutter analyze
```

Required result: **0 issues**. If any issues are reported, record each with file, line, and
message. This is a Mandatory Hard Gate.

### Step 2 — Tests

```bash
cd /Users/ssg/AndroidStudioProjects/<app_slug>
flutter test
```

Required result: **0 failures**. Capture the full output. This is a Mandatory Hard Gate.

### Step 3 — Stub / TODO grep

```bash
grep -rn "TODO\|stub\|placeholder\|스텁\|미구현" \
  /Users/ssg/AndroidStudioProjects/<app_slug>/lib/ --include="*.dart"
```

Any match is an **automatic FAIL**. No exceptions (per `docs/harness-protocol.md` §3 Hard
Gate 3). Record each match with file path, line number, and the matched text.

### Step 4 — game_config.dart centralization

```bash
grep -rn "[0-9]\{3,\}\.\?[0-9]*" \
  /Users/ssg/AndroidStudioProjects/<app_slug>/lib/game/ --include="*.dart" \
  | grep -v "game_config.dart"
```

Magic numbers (3+ digits) in game logic files other than `game_config.dart` are a Hard Gate
failure (per protocol §3 Hard Gate 4). Exclude intentional non-tuning constants (e.g., HTTP
status codes) if clearly justified in a comment; document any exclusion in the feedback file.

### Step 5 — l10n completeness

```bash
cd /Users/ssg/AndroidStudioProjects/<app_slug>
flutter gen-l10n
```

Then confirm that every configured `lib/l10n/app_<locale>.arb` (the project's `default_language`,
plus `app_en.arb` when `default_language` ≠ `en`) contains identical key sets:

```bash
python3 -c "
import glob, json
arbs = glob.glob('lib/l10n/app_*.arb')
keysets = {f: set(json.load(open(f))) for f in arbs}
allkeys = set().union(*keysets.values()) if keysets else set()
bad = {f: sorted(allkeys - ks) for f, ks in keysets.items() if allkeys - ks}
if len(arbs) < 1: print('NO ARB FILES'); exit(1)
if bad: print('MISSING KEYS:', bad); exit(1)
print('l10n OK', list(keysets))
"
```

Missing keys in either locale are a Hard Gate failure (protocol §3 Hard Gate 6).

### Step 5a — Platform-robustness gates

Verify the `## Platform-Robustness Gates` (R1–R4) from `contract.md` / `docs/game-gotchas.md`:

```bash
# R1 audio: frequent SFX pooled + audio calls guarded; BGM stop on teardown
grep -rn "AudioPool" lib/ || echo "WARN: no AudioPool — frequent SFX may stutter"
grep -rn "FlameAudio\|AudioPool\|\.bgm" lib/ | grep -i "try\|catch" >/dev/null || echo "CHECK: audio not in try/catch"
grep -rn "bgm.stop\|\.stop()" lib/ || echo "CHECK: BGM stop on teardown/background"
# R2 haptics (if used)
ls lib/systems/haptics.dart 2>/dev/null && grep -nE "kIsWeb|isIOS|isAndroid|enabled|Stopwatch|elapsed" lib/systems/haptics.dart
# R3 lifecycle
grep -rn "WidgetsBindingObserver\|didChangeAppLifecycleState\|pauseEngine" lib/ || echo "FAIL: no lifecycle pause"
# R4 performance: no per-frame whereType in update hot paths
grep -rn "whereType" lib/ | grep -i "update" && echo "CHECK: whereType inside update — verify it's cached, not per-frame"
```

Judge results against `docs/game-gotchas.md`: missing lifecycle pause (R3) or unguarded audio that
can crash on a missing asset (R1) is a FAIL. A per-frame `whereType` in a hot `update` path, or
raw `HapticFeedback.*` in gameplay without the guarded helper, is a FAIL when the game relies on it.
Also confirm the game does **not crash when an audio/image asset is missing** (it should degrade).

### Step 6 — Contract criteria evidence

For each criterion in `contract.md` §§ "Mandatory Hard Gates" and "Functional Criteria", record
a row in the feedback evidence table showing the command run, the result, and any screenshot or
log path. Do not mark a criterion DONE without running a command that directly verifies it.

### Step 7 — Launch on simulator and play core loop

**This step is mandatory. A PASS verdict is not valid without completing it.**

Boot the iOS simulator (or Android emulator if iOS is unavailable):

```bash
open -a Simulator
xcrun simctl boot "iPhone 16" 2>/dev/null || true
```

Install and launch the game:

```bash
cd /Users/ssg/AndroidStudioProjects/<app_slug>
flutter run -d "iPhone 16" --no-pub
```

While the game is running:

0. Create the screenshots directory if it does not already exist:
   ```bash
   mkdir -p /Users/ssg/AndroidStudioProjects/<app_slug>/docs/harness/screenshots
   ```
1. Navigate to the main menu. Capture a screenshot:
   ```bash
   xcrun simctl io booted screenshot \
     /Users/ssg/AndroidStudioProjects/<app_slug>/docs/harness/screenshots/round-<N>-ios-menu.png
   ```
2. Start a game session. Play through the core loop (start → play → win/lose → restart).
3. Capture a screenshot of the gameplay state:
   ```bash
   xcrun simctl io booted screenshot \
     /Users/ssg/AndroidStudioProjects/<app_slug>/docs/harness/screenshots/round-<N>-ios-play.png
   ```
4. Reach a game-over or win condition. Capture the result screen:
   ```bash
   xcrun simctl io booted screenshot \
     /Users/ssg/AndroidStudioProjects/<app_slug>/docs/harness/screenshots/round-<N>-ios-end.png
   ```
5. Study each screenshot carefully. Check for: blank/white screens, visual glitches, missing
   sprites, overlapping UI elements, wrong language, or any rendering error.
6. Confirm the game runs without crashes and without console errors.

Any crash, blank screen, or console error is a Hard Gate failure (protocol §3 Hard Gates 7–8).

---

## 6.2 Quality Scoring (`--strict` only)

Run this section only when `strict_mode: true` in `config.md` or `--strict` is passed.

Score the game on four axes, each 0–10:

| Axis | What to assess |
|---|---|
| **Game feel / juice** | Responsiveness, animations, feedback on actions, audio cues |
| **Originality** | Freshness relative to competitors identified in the research phase |
| **Craft** | Code quality, absence of jank, visual polish, consistent design tokens |
| **Functionality** | All contract criteria met, no edge-case breakage observed |

Also assess:

- **Interaction states**: Does the game handle loading, error, and empty states gracefully?
- **Responsiveness**: Does the game render correctly on the target device sizes?

Scoring threshold:

- Default (`strict_mode: false`): weighted average ≥ **7 / 10** to advise PASS (advisory only).
- Strict profile (`strict_mode: true`): weighted average ≥ **8 / 10** required for PASS.

Weight: Game feel 30 %, Originality 20 %, Craft 25 %, Functionality 25 %.

Record the score for each axis and the weighted total in the feedback file. If the weighted
total is below threshold, the verdict is FAIL regardless of 6.1 results, and each axis below
7 must have at least one specific, reproducible fix listed.

---

## 6.3 Edge-Case Sweep (`--strict` only)

Run this section only when `strict_mode: true` in `config.md` or `--strict` is passed.

Spawn six specialist agents in parallel via the `Agent` tool. All six must report PASS for the
overall verdict to be PASS. A single FAIL from any agent is a FAIL verdict.

| Agent role | Brief |
|---|---|
| **gameplay-edge** | Find gameplay edge cases: score overflow, negative health, unreachable states, off-screen entities, simultaneous collision resolution. |
| **balance** | Assess difficulty curve: is the game winnable? is it too easy in the first 30 s? does difficulty ramp feel fair? |
| **lifecycle/crash** | Simulate app backgrounding (home button), screen rotation, incoming call interruption; confirm resume works and no crash. |
| **performance** | Run `flutter run --profile`, check frame rendering in DevTools; flag sustained drops below 30 fps. |
| **test-generator** | Identify the three highest-risk untested paths and write widget/unit tests for them; confirm they pass. |
| **adversarial-reviewer** | Adversarially review the generated code looking for security issues, credential leaks, or App Store policy violations. |

Each agent must return a structured PASS/FAIL verdict with evidence. Collect all six verdicts
before proceeding to Judgment.

---

## Judgment

After completing all applicable sections (6.1, and 6.2 + 6.3 if `--strict`), write the verdict.

### Determine verdict

- **PASS** if and only if:
  - All 6.1 Mandatory Hard Gates pass AND all 6.1 Functional Criteria verified with evidence.
  - If `--strict`: 6.2 weighted score ≥ threshold AND all six 6.3 agents report PASS.
- **FAIL** if any Hard Gate fails, any functional criterion lacks evidence, or (when `--strict`)
  6.2 score is below threshold or any 6.3 agent reports FAIL.

### max_rounds check

Before writing the verdict, check: if `current_round == max_rounds`, force the judgment. Do
not return FAIL regardless of results — write the verdict on the current state, record the
forced-advance note in the feedback file, and proceed to PASS transitions (per protocol §7
`evaluator → max_rounds → admob / build`, applying the same `skip_admob` branch as PASS).

### Write feedback/round-N-qa.md

Create `docs/harness/feedback/round-<N>-qa.md` following the layout in
`docs/harness-protocol.md` §5. Fill:

- `## Verdict` — **PASS** or **FAIL** (bold).
- `## Evidence` — one row per criterion checked; include screenshot paths for simulator checks.
- `## Failed Criteria` — for each FAIL, a specific reproducible fix. If PASS, write "none".

Never leave placeholder text. Every criterion must have a real command output or screenshot path
as evidence.

### Update state.md (PASS)

On PASS (or forced advance at max_rounds), the game has been built and has passed QA — but before
any deploy work (admob/build/screenshot/submit), there is a **human-approval gate** by default so
the user can actually play and approve the game.

First read `skip_admob` and `auto_deploy` from `docs/harness/config.md`, and decide `next_role`:
- if `skip_admob: true` → `next_role: build`
- otherwise → `next_role: admob`

Then branch on `auto_deploy`:

**Default (`auto_deploy: false`) — PAUSE for human review.**
Write `state.md` with `status: paused`, `pause_reason: manual_action`, and the `next_role`
decided above (per protocol §7 rule 2). Append a `pipeline-log.md` row and PRINT a review
checklist for the user:

> 게임 빌드 + QA 통과. **배포 전 직접 확인하세요:** `cd <app_slug> && flutter run` 으로 플레이하고,
> `docs/harness/screenshots/` 의 QA 스크린샷과 `docs/harness/feedback/round-<N>-qa.md` 를 확인.
> 만족하면 `/flame-harness --resume` 로 배포(admob→build→screenshot→submit)를 진행합니다.

```yaml
status: paused
current_phase: evaluator
next_role: admob   # or "build" if skip_admob: true
pause_reason: manual_action
updated_at: "<ISO-8601 UTC now>"
```

The orchestrator halts on `status: paused`; on `--resume`, `flame-harness-resume` confirms the
user approved and dispatches the stored `next_role`.

**`auto_deploy: true` — no pause, continue straight to deploy.**
Write `status: running` with the same `next_role` so the orchestrator auto-continues:

```yaml
status: running
current_phase: evaluator
next_role: admob   # or "build" if skip_admob: true
updated_at: "<ISO-8601 UTC now>"
```

Leave `current_round`, `created_at`, and `resume_attempts` unchanged. (In the `auto_deploy: false`
case you set `pause_reason: manual_action`; in the `auto_deploy: true` case leave `pause_reason`
unchanged.)

### Update state.md (FAIL)

On FAIL (and `current_round < max_rounds`), update `docs/harness/state.md` per protocol §2 and
the `evaluator → generator` transition in §7. Increment `current_round` and set
`status: running` atomically (protocol §7 rule 2):

```yaml
status: running
current_phase: evaluator
next_role: generator
current_round: <N+1>
updated_at: "<ISO-8601 UTC now>"
```

Leave `created_at`, `resume_attempts`, and `pause_reason` unchanged.

### Append to build-log.md

Append one row to `docs/harness/build-log.md` per protocol §6:

```
| <N> | evaluator | PASS/FAIL | <duration> | <one-line summary> |
```

### Append to pipeline-log.md

Append one row to `docs/harness/pipeline-log.md` per protocol §6:

```
| <ISO-8601 UTC now> | PASS/FAIL | evaluator | round <N>; next: admob|build/generator |
```

When the PASS path pauses for the human-review gate (default, `auto_deploy: false`), additionally
append a `pause` event row so `flame-harness-resume` can show the user what they are approving:

```
| <ISO-8601 UTC now> | pause | evaluator | manual_action: play/approve the built game before deploy; next: admob|build |
```

---

## Error Handling

- If `contract.md` is missing or has no `## Status: AGREED`, abort immediately.
- If `handoff/round-<N>-gen.md` is missing, abort with a clear message; do not set a FAIL
  verdict — the generator has not run yet.
- If the simulator cannot be booted (hardware CI), document the failure, skip Step 7, and set
  the verdict to FAIL with fix: "boot a simulator and complete Step 7."
- If any agent in 6.3 returns an error (not FAIL, but a tool error), retry once, then count it
  as FAIL with note "agent error — retry required."
