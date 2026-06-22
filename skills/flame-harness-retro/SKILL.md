---
name: flame-harness-retro
description: Phase 11 — score the completed pipeline against Anthropic's 9 harness principles plus game quality, and write the retrospective.
argument-hint: ""
allowed-tools: [Read, Write, Bash, Glob, Grep]
---

# flame-harness-retro

Phase 11 (final) of the flutter-flame-harness pipeline. Scores the completed pipeline against
Anthropic's 9 harness-design principles and game quality criteria, then writes the retrospective
report and sets the pipeline to `completed`.

All file schemas (`config.md`, `state.md`, `build-log.md`, `pipeline-log.md`) and the phase
transition table are defined in `docs/harness-protocol.md` — that document is the single source of
truth (§1 `config.md`; §2 `state.md` keys; §3 `contract.md` layout; §4 handoff layout; §5 feedback
layout; §6 log schemas; §7 `retro → complete → status=completed` transition). Do not redefine
schemas here.

**Boundary:** This is the terminal phase. After writing `docs/harness/retro.md` and updating
`state.md`, no further skill dispatch occurs. The pipeline ends.

**Prerequisites:** `flame-harness-resume` dispatched this skill with `next_role: retro`; `state.md`
shows `current_phase: retro`.

---

## Inputs — Read All Harness Artifacts

Before scoring, load all available evidence:

1. `docs/harness/config.md` — extract `app_slug`, `app_name`, `max_rounds`, `strict_mode`,
   `skip_research`, `skip_admob` (per protocol §1).
2. `docs/harness/state.md` — confirm `current_phase: retro`; read `current_round`,
   `resume_attempts` (per protocol §2).
3. `docs/harness/contract.md` — review the negotiated Hard Gates and Functional Criteria, and the
   final `Status: AGREED` line (per protocol §3).
4. `docs/harness/handoff/` — read all `round-N-gen.md` files; note what was built / fixed per
   round, and any self-assessment failures (per protocol §4).
5. `docs/harness/feedback/` — read all `round-N-qa.md` files; note PASS/FAIL verdicts, evidence
   commands run, and specific failed criteria (per protocol §5).
6. `docs/harness/build-log.md` — read the full build log table (per protocol §6).
7. `docs/harness/pipeline-log.md` — read the full pipeline event log (per protocol §6).
8. Git log: run `git log --oneline` to count commits and identify rework patterns.

---

## 9 Principles Scoring

Score each of the 9 harness-design principles on a **1–5 scale** with evidence drawn from the
harness artifacts loaded above. Cite specific files, round numbers, or log entries as evidence.

### Principle 1 — Generator-Evaluator Separation

> Generator builds; Evaluator judges. Roles must never conflate — the Generator does not approve its
> own work, and the Evaluator does not write code.

**Evidence to check:** handoff files authored by generator; feedback files authored by evaluator;
no code edits in QA feedback files; no self-PASS verdicts in handoff files.

**Score guidance:**
- 5 — All handoffs were authored by the Generator; all QA by the Evaluator; zero role crossover.
- 3 — One instance of the Evaluator proposing a code fix inline rather than filing a failed
  criterion.
- 1 — Evaluator wrote code or Generator issued its own PASS.

The generator-evaluator separation principle is the most fundamental harness invariant. A breach
here invalidates all downstream verdicts.

### Principle 2 — Evaluator Skepticism

> Evaluator must run the game and observe actual behaviour before issuing any verdict; code-review-
> only PASS is prohibited.

**Evidence to check:** `feedback/round-N-qa.md` Evidence tables — were `flutter analyze`,
`flutter test`, cold-start iOS, cold-start Android, and FPS check all run? Were screenshots
captured? Did any feedback file issue PASS without running the game?

**Score guidance:**
- 5 — Every QA round shows a complete Evidence table with run commands + actual outputs / screenshot
  paths; no PASS issued without running the game.
- 3 — One round shows a partial Evidence table (e.g., FPS check omitted).
- 1 — At least one PASS was issued based on code review alone.

### Principle 3 — Contract Negotiation Quality

> The contract is negotiated (not dictated) before coding begins. Hard Gates are non-negotiable;
> Functional Criteria are game-specific and agreed bilaterally.

**Evidence to check:** `contract.md` — are all 8 Mandatory Hard Gates present (per protocol §3)?
Were Functional Criteria added and marked AGREED? Was there back-and-forth before AGREED, or was
the contract accepted without review?

**Score guidance:**
- 5 — All 8 Hard Gates present; game-specific Functional Criteria added; AGREED status set after
  bilateral review.
- 3 — Hard Gates present but Functional Criteria were thin or generic.
- 1 — Contract accepted without review or Hard Gates were missing.

### Principle 4 — File-Based Handoff

> Every inter-phase communication travels through a named file in `docs/harness/`. No out-of-band
> instructions in chat messages or inline code comments.

**Evidence to check:** `handoff/round-N-gen.md` and `feedback/round-N-qa.md` exist for every round
in `build-log.md`; pipeline-log events reference file writes; no phase-to-phase communication
happened only in chat.

**Score guidance:**
- 5 — Every handoff and feedback round has a corresponding file; build-log and pipeline-log are
  complete.
- 3 — One round's handoff or feedback file is missing or incomplete.
- 1 — Multiple rounds have no corresponding file.

### Principle 5 — No-Sprints / Single-Build

> The Generator completes the full game in one continuous build session per round. No iterative
> sprint cycles within a round; no partial deliveries labelled "Phase 1 of N".

**Evidence to check:** handoff files — does each `round-N-gen.md` claim a complete, runnable game?
Build-log round count — how many generator rounds were needed? Were any partial deliveries noted?

**Score guidance:**
- 5 — Each generator round delivered a complete, runnable game; no partial deliveries.
- 3 — One round ended with a partial delivery that required a follow-up round for completion rather
  than a genuine fix.
- 1 — Multiple partial deliveries across rounds; sprint-like behaviour observed.

### Principle 6 — Screenshot-and-Study

> Evaluator takes screenshots of the running game and studies them before scoring gameplay criteria.
> Visual evidence is mandatory for any visual or UX criterion.

**Evidence to check:** `feedback/round-N-qa.md` Evidence tables — do screenshot path columns
reference actual files under `screenshots/`? Were iOS and Android cold-start screenshots both
captured?

**Score guidance:**
- 5 — Screenshots captured for every QA round on both platforms; screenshot paths recorded in
  Evidence tables.
- 3 — Screenshots captured on one platform only, or paths recorded but files not verified to exist.
- 1 — No screenshots taken; visual criteria scored without visual evidence.

### Principle 7 — Simplicity

> Prefer the simplest implementation that satisfies the contract. No premature abstraction, no
> gold-plating, no features beyond the agreed scope.

**Evidence to check:** `contract.md` Functional Criteria vs. `handoff/` What Was Built sections —
did the Generator add features not in the contract? Did build-log show rework caused by over-
engineered code? Code complexity in handoff self-assessments.

**Score guidance:**
- 5 — Implementation matched contract scope exactly; no unrequested features added; no rework
  attributed to over-engineering.
- 3 — One or two minor additions beyond scope; or one rework round caused by over-abstraction.
- 1 — Significant scope creep or rework attributed to complexity.

### Principle 8 — Cost-Quality Tradeoff

> Use the cheapest model/tool capable of the task. Reserve expensive calls for decisions that
> require judgment; use cheap calls for grep/read/format tasks.

**Evidence to check:** pipeline-log — did any phase use expensive LLM calls for trivial file
transforms? Were research, design, and contract phases appropriately scoped? Did the evaluator use
`flutter analyze` and `flutter test` (cheap, deterministic) rather than LLM-only review?

**Score guidance:**
- 5 — Deterministic tools (analyze, test, screenshot) used for objective checks; LLM judgment
  reserved for qualitative criteria; no expensive calls for grep/format tasks.
- 3 — One or two instances of LLM judgment used where a deterministic check would suffice.
- 1 — LLM used for tasks that could be fully automated with CLI tools.

### Principle 9 — Test Deduplication

> Tests verify contract criteria exactly once. No duplicate assertions across unit tests, widget
> tests, and integration tests. Tests must be additive, not redundant.

**Evidence to check:** `handoff/round-N-gen.md` Test Results sections — are tests clearly
categorised (unit / widget / integration)? Do later-round handoffs add new tests for new criteria
rather than duplicating existing ones? Does `flutter test` output show a growing, non-redundant
test suite?

**Score guidance:**
- 5 — Tests organised by layer; each contract criterion covered by exactly one test layer; no
  duplication between unit and widget or widget and integration tests.
- 3 — Some overlap between test layers, but overall suite covers contract criteria without major
  gaps.
- 1 — Significant duplication across test layers, or contract criteria untested.

---

## Game Quality Review

Assess the delivered game across three axes using evidence from QA feedback, screenshots, and the
build-log.

### Keep

List what worked well in this pipeline run:

- Criteria that passed on the first generator round (no rework needed).
- Phases that produced complete, well-formed output files on the first attempt.
- Contract Hard Gates that were never violated across any round.
- Any phase where the Generator's self-assessment precisely matched the Evaluator's verdict.

### Improve

List what should be improved in the next pipeline run:

- Rounds that required rework — identify the root cause (ambiguous contract criterion, incomplete
  generator self-check, evaluator skipped a command).
- Any `PARTIAL` scores in `build-log.md` — what caused them?
- Phases where file output was missing or malformed (compared to protocol §4 / §5 / §6 schemas).
- Any principle scored 3 or below — explain why and what to change.

### Try

List new approaches to trial in the next pipeline run:

- Contract additions that could prevent the most common rework patterns observed.
- Additional deterministic checks (e.g., FPS measurement script, bundle size gate) that could
  replace LLM judgment.
- Structural changes to handoff or feedback schemas that would surface issues earlier.
- Changes to `max_rounds` or `strict_mode` settings based on observed pipeline behaviour.

---

## Output

### Write `docs/harness/retro.md`

Create or overwrite `docs/harness/retro.md` with the following structure:

```markdown
# Retrospective — <app_name>

> Pipeline completed: <ISO-8601 UTC timestamp>
> Rounds: <current_round> / <max_rounds>
> Resume attempts: <resume_attempts>

## 9 Principles Scorecard

| # | Principle | Score (1–5) | Evidence |
|---|---|---|---|
| 1 | Generator-Evaluator separation | N | <one-line evidence citation> |
| 2 | Evaluator skepticism | N | <one-line evidence citation> |
| 3 | Contract negotiation quality | N | <one-line evidence citation> |
| 4 | File-based handoff | N | <one-line evidence citation> |
| 5 | No-sprints / single-build | N | <one-line evidence citation> |
| 6 | Screenshot-and-study | N | <one-line evidence citation> |
| 7 | Simplicity | N | <one-line evidence citation> |
| 8 | Cost-quality tradeoff | N | <one-line evidence citation> |
| 9 | Test deduplication | N | <one-line evidence citation> |

**Overall:** <average score, rounded to one decimal> / 5

## Verification

| Contract Criterion | Final Status | Round Passed |
|---|---|---|
| flutter analyze zero errors | PASS / FAIL | N |
| flutter test zero failures | PASS / FAIL | N |
| Cold-start iOS | PASS / FAIL | N |
| Cold-start Android | PASS / FAIL | N |
| <game-specific criterion> | PASS / FAIL | N |

## Keep / Improve / Try

### Keep
- <bullet>

### Improve
- <bullet>

### Try
- <bullet>
```

### Update `state.md` — Set `completed`

Per `docs/harness-protocol.md` §7 (`retro → complete → status=completed`) and §7 rule 7
(`completed` status is set only after the final phase `retro` exits cleanly), write
`docs/harness/state.md` atomically with **exactly** these field changes (leave `created_at`,
`current_round`, `resume_attempts`, `next_role` unchanged):

```yaml
status: completed
current_phase: retro
pause_reason: ""
updated_at: "<ISO-8601 UTC now>"
```

No `next_role` advance is needed — `completed` is the terminal state. Do not dispatch any further
skill. Do not set `pause_reason` (leave as `""`).

### Append to `pipeline-log.md`

Append one row to `docs/harness/pipeline-log.md` per the schema in `docs/harness-protocol.md` §6:

```
| <ISO-8601 UTC now> | complete | retro | retro.md written; status=completed; overall score <N>/5 |
```

---

## Terminal Notice

After writing `retro.md`, updating `state.md` to `status: completed`, and appending to
`pipeline-log.md`, print the following summary for the developer and stop — do not dispatch any
further skill:

---

**PIPELINE COMPLETE**

`docs/harness/retro.md` has been written.
`state.md` status is now `completed`.

Overall harness score: **<N> / 5**

Review `docs/harness/retro.md` for the full 9-principles scorecard, verification table, and
Keep / Improve / Try action items for the next pipeline run.
