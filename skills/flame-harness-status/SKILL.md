---
name: flame-harness-status
description: Show the current flame-harness pipeline state — phase, round, scores — read-only.
argument-hint: ""
allowed-tools: [Read, Bash, Glob]
---

# flame-harness-status

Read-only status reporter for the flutter-flame-harness pipeline. Reads `state.md`,
`build-log.md`, and `pipeline-log.md` and prints a summary of the current pipeline state.

All file schemas (`state.md`, `build-log.md`, `pipeline-log.md`) are defined in
`docs/harness-protocol.md` — refer to that document as the single source of truth.
Do not redefine schemas here.

**This skill is strictly read-only. It must never modify state.md or any other harness file.**

---

## Input

Locate `docs/harness/state.md` relative to the current project root (the directory that contains
`docs/harness/`). If `state.md` does not exist, print:

```
flame-harness-status: no active pipeline found (docs/harness/state.md missing).
Run /flame-harness <idea> to start a new pipeline.
```

Then exit without error.

---

## Procedure

### 1. Read state.md

Read `docs/harness/state.md` and extract the following fields per the schema in
`docs/harness-protocol.md` §2:

- `status` — `running` | `paused` | `completed`
- `current_phase` — name of the currently executing phase
- `current_round` — integer round counter
- `next_role` — skill role that runs next
- `pause_reason` — `""` | `rate_limit` | `manual_action` | `error`
- `updated_at` — ISO-8601 timestamp of last write
- `resume_attempts` — integer

### 2. Read build-log.md (if present)

Read `docs/harness/build-log.md` per the schema in `docs/harness-protocol.md` §6. Extract the
latest row to obtain the most recent QA score (`PASS` | `FAIL` | `PARTIAL`) and the round number
it corresponds to. If the file is absent or has no data rows, set `latest_score` to `—`.

### 3. Read pipeline-log.md (if present)

Read `docs/harness/pipeline-log.md` per the schema in `docs/harness-protocol.md` §6. Extract the
last 3 rows to give a recent event summary. If the file is absent or empty, skip.

### 4. Print status report

Print the following formatted report (adapt spacing for readability):

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 flame-harness pipeline status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Status        : <status>
  Current phase : <current_phase>
  Round         : <current_round>
  Next role     : <next_role>
  Latest QA     : <latest_score>
  Last updated  : <updated_at>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If `status` is `paused`, append:

```
  ⚠  Paused — reason: <pause_reason>
  Resume attempts: <resume_attempts>
  Run /flame-harness --resume (or /flame-harness-resume) to continue.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If `status` is `completed`, append:

```
  Pipeline completed successfully.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If there are recent pipeline-log rows, append:

```
Recent events:
  <time>  <event>  <phase>  <details>
  <time>  <event>  <phase>  <details>
  <time>  <event>  <phase>  <details>
```

---

## Constraints

- **Read-only**: this skill must never call `Write`, `Edit`, or any Bash command that modifies a
  file. It reads `state.md`, `build-log.md`, and `pipeline-log.md` only.
- Do not modify `state.md` under any circumstances, including error paths.
- If any file is unreadable, skip it silently and note "(unavailable)" in the report.
