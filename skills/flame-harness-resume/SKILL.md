---
name: flame-harness-resume
description: Resume a paused flame-harness run based on pause_reason (rate_limit waits; manual_action confirms with user; error reports).
argument-hint: ""
allowed-tools: [Read, Write, Edit, Bash, AskUserQuestion, Skill]
---

# flame-harness-resume

Resume handler for the flutter-flame-harness pipeline. Reads `state.md`, branches on
`pause_reason`, and re-dispatches the next phase skill when ready to continue.

All file schemas (`state.md`, `pipeline-log.md`) and state transition rules (including the
requirement that `pause_reason` is cleared to `""` when `status` is restored to `running`) are
defined in `docs/harness-protocol.md` — refer to §2 (state.md schema) and §7 (state transition
rules) as the single source of truth. Do not redefine schemas here.

---

## Input

Read `docs/harness/state.md` per the schema in `docs/harness-protocol.md` §2. If `state.md`
does not exist, abort with:

```
flame-harness-resume: nothing to resume — docs/harness/state.md not found.
Run /flame-harness <idea> to start a new pipeline.
```

Extract:

- `status` — expected `paused`; if `running` or `completed`, print a note and exit (nothing to resume).
- `pause_reason` — `rate_limit` | `manual_action` | `error`
- `next_role` — role to dispatch after resuming
- `resume_attempts` — integer; will be incremented on successful resume
- `current_phase`, `updated_at` — for logging

If `status` is `running`:

```
flame-harness-resume: pipeline is already running (status: running, next_role: <next_role>).
No resume needed.
```

If `status` is `completed`:

```
flame-harness-resume: pipeline is already completed. Nothing to resume.
```

---

## Branch on pause_reason

### rate_limit

`pause_reason: rate_limit` means the pipeline hit an API rate limit and paused automatically.

**Procedure:**

1. Print:
   ```
   Pipeline paused due to rate limit (rate_limit).
   Checking whether the rate-limit window has passed...
   ```
2. Read `updated_at` from `state.md`. Calculate elapsed time since that timestamp using Bash
   (`date` command). If elapsed time is less than 60 seconds, print a warning:
   ```
   Warning: only <N> seconds have elapsed since the pause. The rate-limit window may not
   have passed yet. Proceeding anyway — if another rate limit is hit, the pipeline will
   pause again.
   ```
3. Proceed to **Resume execution** below.

### manual_action

`pause_reason: manual_action` means the pipeline requires a manual step from the user before
it can continue (e.g. **playing/approving the built game at the post-QA review gate**, completing
App Store / Play Console submission steps, uploading a keystore, or configuring a device). The
specific action is recorded in the `pause` event row of `pipeline-log.md`.

**Procedure:**

1. Read `docs/harness/pipeline-log.md` per `docs/harness-protocol.md` §6. Find the most recent
   `pause` event row to extract the details string describing what manual action was needed.
   If the log is unavailable, use a generic prompt.

2. Use **AskUserQuestion** to confirm the user has completed the required steps:
   ```
   The pipeline was paused for a manual action.
   Last recorded reason: <details from pipeline-log, or "see docs/harness/pipeline-log.md">

   Have you completed the required steps? (yes / no / describe what's pending)
   ```

3. If the user answers `no` or describes pending work:
   - Print a summary of what they said.
   - Abort: do NOT resume. Exit with:
     ```
     flame-harness-resume: manual action not yet complete. Run /flame-harness-resume again
     when ready.
     ```

4. If the user answers `yes`:
   - Proceed to **Resume execution** below.

### error

`pause_reason: error` means the pipeline encountered an unrecoverable error in a phase skill.

**Procedure:**

1. Read `docs/harness/pipeline-log.md` per `docs/harness-protocol.md` §6. Find the most recent
   `error` event row to extract the error details.

2. Print a clear error report:
   ```
   Pipeline paused due to an error.
   Phase     : <current_phase>
   Next role : <next_role>
   Error     : <details from pipeline-log, or "see docs/harness/pipeline-log.md">

   You must investigate and fix the error before resuming.
   Common fixes:
     - If it is a Flutter/Dart compile error, fix the code and run `flutter analyze`.
     - If it is a missing file, create or restore it.
     - If it is a credential error, check docs/harness/config.md and the credentials_dir.
   ```

3. Use **AskUserQuestion**:
   ```
   Have you resolved the error and are ready to retry? (yes / no)
   ```

4. If the user answers `no`:
   - Abort: do NOT resume. Exit with:
     ```
     flame-harness-resume: error not yet resolved. Run /flame-harness-resume again when fixed.
     ```

5. If the user answers `yes`:
   - Proceed to **Resume execution** below.

### Unknown pause_reason

If `pause_reason` is empty or an unrecognised value, print:

```
flame-harness-resume: unexpected pause_reason "<value>" in state.md.
Expected one of: rate_limit, manual_action, error.
Please inspect docs/harness/state.md manually and correct it before resuming.
```

Then abort without modifying any files.

---

## Resume execution

Reached only after the appropriate branch above confirms it is safe to continue.

Per `docs/harness-protocol.md` §7 rule 4: when `status` is set back to `running`,
`resume_attempts` must be incremented, and per §7 rule 8: `pause_reason` must be cleared
to `""` by this skill.

### 1. Update state.md

Use **Edit** to update `docs/harness/state.md` with the following field changes (leave all other
keys unchanged):

```yaml
status: running
pause_reason: ""
resume_attempts: <previous_value + 1>
updated_at: "<ISO-8601 UTC now>"
```

Both `status: running` and `pause_reason: ""` must be written in the same Edit call (atomic per
`docs/harness-protocol.md` §7 rule 1).

### 2. Append to pipeline-log.md

Append one row to `docs/harness/pipeline-log.md` per the schema in `docs/harness-protocol.md` §6:

```
| <ISO-8601 UTC now> | resume | <current_phase> | resume_attempts=<new_value>; was paused for <pause_reason> |
```

### 3. Dispatch next_role

Read `next_role` from the (now-updated) `state.md` and dispatch:

```
Skill("flame-harness-<next_role>")
```

Valid `next_role` values are listed in the transition table in
`docs/harness-protocol.md` §7. `admob` is a normal dispatchable role and is handled like any
other `next_role` — dispatch `Skill("flame-harness-admob")` without any special boundary check.

If `next_role` is empty or unknown, abort with:

```
flame-harness-resume: cannot dispatch — next_role is "<value>".
Inspect docs/harness/state.md and set a valid next_role before retrying.
```

---

## Error handling

- If `state.md` becomes unreadable mid-execution (e.g. concurrent write), abort immediately
  and do not write partial state changes.
- Never dispatch `Skill(...)` before `state.md` has been successfully updated to
  `status: running` with `pause_reason: ""`. Dispatch is the last step.
