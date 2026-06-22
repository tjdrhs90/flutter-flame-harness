---
name: flame-harness
description: Orchestrator — bootstrap a Flutter/Flame game pipeline (idea→playable game) and dispatch each phase skill. Use when starting or continuing a flame-harness run.
argument-hint: "<game idea> [--strict] [--rounds N] [--skip-research] [--skip-admob] [--resume]"
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
| `<game idea>` | `app_idea` | — (required on first run) |
| `--strict` | `strict_mode: true` | `false` |
| `--rounds N` | `max_rounds: N` | `3` |
| `--skip-research` | `skip_research: true` | `false` |
| `--skip-admob` | `skip_admob: true` | `false` |
| `--resume` | (delegates to resume handler; see Resume section) | — |

Key-to-file mapping follows the `config.md` schema in `docs/harness-protocol.md` Section 1.

- `--strict` → set `strict_mode: true` in `config.md`
- `--rounds N` → set `max_rounds: N` in `config.md`
- `--skip-research` → set `skip_research: true` in `config.md`; on first run this also means
  `state.md` is written with `next_role: plan` instead of `next_role: research`
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

- `app_idea` — from the positional argument
- `app_name` — derive a short display name from the idea (ask the user if ambiguous)
- `app_slug` — kebab-case version of `app_name`
- `bundle_id` — `com.gonigon.<slug>`
- `strict_mode`, `max_rounds`, `skip_research`, `skip_admob` — from flags (defaults per table above)
- `developer`, `ios`, `android` — from `credentials/store-metadata.md`
- `credentials_dir` — `/Users/ssg/AndroidStudioProjects/credentials`

Do NOT hard-code credential values; always read them from `credentials_dir`.

### 3. Write `docs/harness/state.md`

Write initial state per the schema in `docs/harness-protocol.md` Section 2:

```yaml
status: running
current_phase: (init)
current_round: 1
next_role: research   # use "plan" if --skip-research was passed
pause_reason: ""
created_at: "<ISO-8601 UTC now>"
updated_at: "<ISO-8601 UTC now>"
resume_attempts: 0
```

If `--skip-research` was given, set `next_role: plan`.

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
- If `status: paused` — print the `pause_reason` and instruct the user to run with `--resume`.
  Do not continue automatically.

### Phase B boundary

The Phase B boundary is reached when `next_role` is `admob` (or `current_phase` transitions to
`admob` per the transition table in `docs/harness-protocol.md` Section 7).

When this boundary is hit, stop the loop and print:

```
Phase B (AdMob + submission) is not yet implemented.
The game pipeline has completed Phase A successfully.
To continue once Phase B skills are available, run:
  /flame-harness --resume
```

Then exit. Do NOT invoke `flame-harness-admob`.

### Dispatch

For any other `next_role` value, invoke the corresponding phase skill:

```
Skill("flame-harness-<next_role>")
```

Valid Phase A `next_role` values and their skills (per transition table in `docs/harness-protocol.md`
Section 7):

| next_role | Skill invoked |
|---|---|
| `research` | `flame-harness-research` |
| `plan` | `flame-harness-plan` |
| `design` | `flame-harness-design` |
| `contract` | `flame-harness-contract` |
| `generator` | `flame-harness-generator` |
| `evaluator` | `flame-harness-evaluator` |

Each phase skill is responsible for updating `state.md` (including setting `next_role` to the
next phase) before returning, following the transition rules in `docs/harness-protocol.md` Section 7.

After each skill returns, re-read `state.md` and repeat the dispatch check. Continue until:
- `status: completed`
- `status: paused`
- `next_role: admob` (Phase B boundary)

---

## Resume

If `--resume` is passed as an argument, skip all bootstrap and dispatch logic and delegate
immediately to the resume skill:

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
- If `next_role` contains a value not in the known Phase A set and is not `admob`, abort with
  an "unknown next_role" error so the user can investigate `state.md`.
