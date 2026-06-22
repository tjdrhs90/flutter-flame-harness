---
name: flame-harness
description: Orchestrator — bootstrap a Flutter/Flame game pipeline (idea→playable game) and dispatch each phase skill. Use when starting or continuing a flame-harness run.
argument-hint: "[game idea] [--strict] [--rounds N] [--skip-research] [--skip-admob] [--resume]"
allowed-tools: [Agent, Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, Skill]
---

# flame-harness Orchestrator

This skill bootstraps and drives the full Flutter/Flame game pipeline from idea to playable game.
All file schemas (`config.md`, `state.md`, `contract.md`, log tables) and the phase transition table
are defined in `docs/harness-protocol.md` — refer to that document as the single source of truth.
Do not redefine schemas here.

---

## Argument Parsing

Parse the invocation arguments before doing anything else.

| Argument | Config key (in `config.md`) | Default |
|---|---|---|
| `[game idea]` | `app_idea` | optional — if omitted, research generates & recommends ideas from scratch |
| `--strict` | `strict_mode: true` | `false` |
| `--rounds N` | `max_rounds: N` | `3` |
| `--skip-research` | `skip_research: true` | `false` |
| `--skip-admob` | `skip_admob: true` | `false` |
| `--resume` | (delegates to resume handler; see Resume section) | — |

**Guard:** if `--skip-research` is set AND no idea is given, abort immediately with:
`flame-harness: --skip-research needs a game idea (nothing to build without research or an idea).`

Key-to-file mapping follows the `config.md` schema in `docs/harness-protocol.md` Section 1.

- `--strict` → set `strict_mode: true` in `config.md`
- `--rounds N` → set `max_rounds: N` in `config.md`
- `--skip-research` → set `skip_research: true` in `config.md`. On first run `next_role` is still
  `research` (NOT `plan`): the research skill honors `skip_research` by skipping market discovery and
  idea generation, but it still runs the App Store 4.3 clone-avoidance check on the provided idea and
  writes the research spec — so the clone check is never silently skipped.
- `--skip-admob` → set `skip_admob: true` in `config.md`
- `--resume` → skip bootstrap entirely, delegate straight to `flame-harness-resume` (see Resume)

---

## Bootstrap (First Run)

Bootstrap runs only when `docs/harness/state.md` does not yet exist.

### 1. Create directory tree

```
docs/harness/
docs/harness/handoff/
docs/harness/feedback/
docs/harness/specs/
docs/harness/plans/
```

### 2. Write `docs/harness/config.md`

Read `/Users/ssg/AndroidStudioProjects/credentials/store-metadata.md` to extract the
`developer`, `ios`, and `android` credential blocks, then write `docs/harness/config.md`
with the full schema from `docs/harness-protocol.md` Section 1.

Populate the game-specific keys from the parsed arguments:

- `app_idea` — from the positional argument; if no positional argument was given, write `app_idea: ""` (blank is valid — research will generate and recommend concepts). Do NOT abort on an empty idea.
- `app_name` — derive a short display name from the idea (ask the user if ambiguous); if NO idea was given, write `app_name: ""` — the plan phase sets the name after research confirms the concept.
- `app_slug` — kebab-case of `app_name`; write `app_slug: ""` if `app_name` is blank.
- `bundle_id` — `com.gonigon.<id>` where `<id>` is `app_slug` with hyphens/underscores removed (bundle-id segments must be `[a-z0-9]+`; hyphens/underscores break signing). Blank if `app_slug` is blank.
- `strict_mode`, `max_rounds`, `skip_research`, `skip_admob` — from flags (defaults per table above)
- `developer`, `ios`, `android` — from `credentials/store-metadata.md`
- `credentials_dir` — `/Users/ssg/AndroidStudioProjects/credentials`

Do NOT hard-code credential values; always read them from `credentials_dir`.

### 3. Write `docs/harness/state.md`

Write `state.md` per the schema in `docs/harness-protocol.md` §2. Initial values: `status: running`, `current_phase: (init)`, `current_round: 1`, `next_role: research` (always `research` on first run — the research skill handles `skip_research` internally, still running the clone check and writing the spec), `pause_reason: ""`, `resume_attempts: 0`, and `created_at`/`updated_at` set to the current ISO-8601 UTC timestamp.

### 4. Append INIT row to `docs/harness/pipeline-log.md`

Create `pipeline-log.md` if absent and append:

```
| <ISO-8601 UTC now> | start | bootstrap | config.md written |
```

Follow the `pipeline-log.md` schema in `docs/harness-protocol.md` Section 6.

---

## Dispatch Loop

After bootstrap (or when resuming without `--resume` flag), enter the dispatch loop.

### Reading `next_role`

Read `docs/harness/state.md` and extract `next_role` and `status`.

- If `status: completed` — print a completion summary and exit.
- If `status: paused` — print the `pause_reason` and any pending manual steps, then instruct the user to run with `--resume`. Do not continue automatically.

### Dispatch

For any `next_role` value in the known set, invoke the corresponding phase skill:

```
Skill("flame-harness-<next_role>")
```

Valid `next_role` values and their skills (per transition table in `docs/harness-protocol.md`
Section 7):

| next_role | Skill invoked |
|---|---|
| `research` | `flame-harness-research` |
| `plan` | `flame-harness-plan` |
| `design` | `flame-harness-design` |
| `contract` | `flame-harness-contract` |
| `generator` | `flame-harness-generator` |
| `evaluator` | `flame-harness-evaluator` |
| `admob` | `flame-harness-admob` |
| `build` | `flame-harness-build` |
| `screenshot` | `flame-harness-screenshot` |
| `submit` | `flame-harness-submit` |
| `retro` | `flame-harness-retro` |

Each phase skill is responsible for updating `state.md` (including setting `next_role` to the
next phase) before returning, following the transition rules in `docs/harness-protocol.md` Section 7.

After each skill returns, re-read `state.md` and verify that either `updated_at` changed or
`next_role` advanced compared to the values before dispatch. If neither changed, abort immediately
with: "orchestrator: phase skill `<role>` returned without updating state.md — halting to avoid a
redispatch loop."

When `status: paused` (e.g. after `submit` sets `pause_reason: manual_action`), print the pending
manual steps from `state.md` and instruct the user to complete them, then run with `--resume`.
Do not continue automatically.

Then repeat the dispatch check. Continue until:
- `status: completed` (set by `retro` — print a completion summary and exit)
- `status: paused` (print pause_reason and instruct user to run with `--resume`, then exit)

---

## Resume

If `--resume` is passed as an argument, first verify that `docs/harness/state.md` exists. If it
does not exist, abort with: "Nothing to resume — no state.md found. Run without --resume to start
a new pipeline."

Otherwise, skip all bootstrap and dispatch logic and delegate immediately to the resume skill:

```
Skill("flame-harness-resume")
```

`flame-harness-resume` is responsible for reading `state.md`, incrementing `resume_attempts`,
restoring `status: running`, and re-entering the dispatch loop.

Do not attempt to read or modify `state.md` before delegating to the resume skill.

---

## Error Handling

- If `docs/harness/config.md` is missing on a non-first run, abort with a clear error message.
- If an invoked phase skill exits with an error or sets `status: paused` with
  `pause_reason: error`, stop the loop and report the failure to the user.
- If `next_role` contains a value not in the known set (research, plan, design, contract, generator, evaluator, admob, build, screenshot, submit, retro), abort with an "unknown next_role" error so the user can investigate `state.md`.
