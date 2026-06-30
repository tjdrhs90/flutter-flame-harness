# flutter-flame-harness Phase A Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Phase A (MVP) core of the `flutter-flame-harness` Claude Code plugin — the skills that take a Flame game idea through research, planning, design, contract, and a Generator↔Evaluator build loop to a playable game passing `flutter analyze` + `flutter test`.

**Architecture:** A plugin of phase skills (`SKILL.md` prompt documents), each run with a context reset, communicating only through files in a per-game `docs/harness/` directory. An orchestrator skill reads `state.md.next_role` and dispatches the next phase skill. Adapts the proven `rn-launch-harness` machinery, retargeted from RN/Expo/backend-app to Flutter/Flame games.

**Tech Stack:** Markdown `SKILL.md` files (YAML frontmatter), Bash (hook + validation scripts), JSON (plugin/marketplace manifests). Target games use Dart 3.11+, Flame 1.37+, `flame_audio`, `google_mobile_ads`, `shared_preferences`.

## Global Constraints

- Plugin name `flutter-flame-harness`; skill prefix `flame-harness-*`.
- Plugin source repo: `<projects-dir>/flutter-flame-harness/` (already git-initialized).
- GitHub: public repo `tjdrhs90/flutter-flame-harness` via `gh` CLI (account `tjdrhs90`).
- Commits: Conventional Commits (`feat:`, `fix(scope):`, `docs:`, `chore:`, `refactor:`). **Never add AI-authorship trailers (no `Co-Authored-By`).**
- Commit author identity: `git -c user.name='<your-name>' -c user.email='<support-email>'` (repo is not a user-config git env).
- Central credential vault: `<projects-dir>/credentials/` (`AuthKey_<asc-key-id>.p8`, `play-store-key.json`, `upload-keystore.jks`, `store-metadata.md`).
- Per-game key copies live in `<game>/secrets/` (gitignored). `credentials/`, `secrets/`, `*.jks`, `*.p8`, `key.properties`, key `*.json` gitignored everywhere; never committed to the public plugin repo.
- iOS: Issuer `<asc-issuer-id>`, Key `<asc-key-id>`, Team `<apple-team-id>`. Bundle id `com.<company>.<slug>`.
- Android shared keystore: `upload-keystore.jks`, alias `upload`, store/key pw `<keystore-password>`.
- Scope = Phase A only (research → plan → design → contract → generator → evaluator + status/resume utils + orchestrator + hook). Phase B (admob/build/screenshot/submit/retro) is a later cycle.

---

## File Structure

| Path | Responsibility |
| --- | --- |
| `.claude-plugin/plugin.json` | Plugin manifest + `StopFailure` hook registration |
| `.claude-plugin/marketplace.json` | Local marketplace entry for install |
| `README.md` | Plugin overview, install, usage, phase map |
| `scripts/validate.sh` | Structural validation: JSON validity, skill frontmatter, referenced-file existence |
| `docs/harness-protocol.md` | Shared reference: `docs/harness/` file schemas + state-machine transition table (skills cite this) |
| `skills/flame-harness/SKILL.md` | Orchestrator: arg parse, init `config.md`/`state.md`, dispatch by `next_role` |
| `skills/flame-harness-research/SKILL.md` | Idea discovery + user query → research spec |
| `skills/flame-harness-plan/SKILL.md` | Korean game PRD + lib/ map + slug/bundle id |
| `skills/flame-harness-design/SKILL.md` | `design_tokens.dart` spec + art/visual concept + asset plan |
| `skills/flame-harness-contract/SKILL.md` | Negotiate verifiable completion criteria + hard gates |
| `skills/flame-harness-generator/SKILL.md` | 3 sub-phase build (core loop → systems → UI/content) |
| `skills/flame-harness-evaluator/SKILL.md` | Skeptical QA: run the game, then judge |
| `skills/flame-harness-status/SKILL.md` | Read-only state report |
| `skills/flame-harness-resume/SKILL.md` | Resume from paused state |
| `hooks/stop-failure-handler.sh` | Auto-pause + schedule resume on rate limit |
| `templates/gitignore.template` | Generated-game `.gitignore` |

Each `SKILL.md` reads only the `docs/harness/` files named in its Interfaces block, and writes only its declared outputs + `state.md`/`pipeline-log.md`. This keeps every skill independently understandable.

---

## Task 1: Plugin scaffold, manifests, validator, GitHub repo

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `.claude-plugin/marketplace.json`
- Create: `scripts/validate.sh`
- Create: `README.md`
- Modify: `.gitignore` (already exists from spec commit)

**Interfaces:**
- Produces: `scripts/validate.sh` — exit 0 if all manifests are valid JSON and every `skills/*/SKILL.md` has non-empty `name:` + `description:` frontmatter and every Markdown-linked sibling file exists; non-zero otherwise. Re-run as the verification step of every later task.

- [ ] **Step 1: Write the failing validator test**

Create `scripts/validate.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
err() { echo "FAIL: $1"; fail=1; }

# 1. Manifests are valid JSON
for f in "$ROOT/.claude-plugin/plugin.json" "$ROOT/.claude-plugin/marketplace.json"; do
  [ -f "$f" ] || { err "missing $f"; continue; }
  python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" 2>/dev/null || err "invalid JSON: $f"
done

# 2. Every skill has name+description frontmatter
while IFS= read -r skill; do
  head -20 "$skill" | grep -q '^name:[[:space:]]*[^[:space:]]' || err "no name: in $skill"
  head -20 "$skill" | grep -q '^description:[[:space:]]*[^[:space:]]' || err "no description: in $skill"
done < <(find "$ROOT/skills" -name SKILL.md 2>/dev/null)

[ "$fail" -eq 0 ] && echo "validate: OK" || exit 1
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash scripts/validate.sh`
Expected: FAIL (manifests do not exist yet) → exits non-zero with `FAIL: missing .../plugin.json`.

- [ ] **Step 3: Create `.claude-plugin/plugin.json`**

```json
{
  "name": "flutter-flame-harness",
  "version": "0.1.0",
  "description": "Idea-to-store harness for Flutter/Flame games: research, plan, design, contract, generator-evaluator build loop, and (later) deploy.",
  "author": { "name": "<your-name>", "email": "<support-email>" },
  "repository": "https://github.com/tjdrhs90/flutter-flame-harness",
  "hooks": {
    "StopFailure": [
      { "hooks": [ { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/stop-failure-handler.sh" } ] }
    ]
  }
}
```

- [ ] **Step 4: Create `.claude-plugin/marketplace.json`**

```json
{
  "name": "flutter-flame-harness",
  "owner": { "name": "tjdrhs90" },
  "plugins": [
    {
      "name": "flutter-flame-harness",
      "source": ".",
      "description": "Idea-to-store harness for Flutter/Flame games."
    }
  ]
}
```

- [ ] **Step 5: Create `README.md`**

Write a README with: one-paragraph overview; "Phase A (this release): research → plan → design → contract → generator ↔ evaluator → playable game"; "Phase B (planned): admob, build, screenshot, submit, retro"; install instructions (`/plugin marketplace add <projects-dir>/flutter-flame-harness` then `/plugin install flutter-flame-harness`); usage `/flame-harness <idea>` with flags `--strict`, `--rounds N`, `--skip-research`; a table of the Phase A skills; and a security note that credentials/secrets never enter the repo. Reference `docs/harness-protocol.md` for the file protocol.

- [ ] **Step 6: Make validator executable and run it**

Run: `chmod +x scripts/validate.sh && bash scripts/validate.sh`
Expected: PASS → prints `validate: OK` (no skills yet, so the skill loop is a no-op; manifests are valid).

- [ ] **Step 7: Commit**

```bash
git add .claude-plugin README.md scripts/validate.sh
git -c user.name='<your-name>' -c user.email='<support-email>' \
  commit -q -m "feat: scaffold plugin manifests, README, and validator"
```

- [ ] **Step 8: Create the public GitHub repo and push**

Run:
```bash
gh repo create tjdrhs90/flutter-flame-harness --public --source=. --remote=origin \
  --description "Idea-to-store harness for Flutter/Flame games" --push
gh repo view tjdrhs90/flutter-flame-harness --json visibility -q .visibility
```
Expected: prints `public`. Confirm `.gitignore` already excludes `credentials/`, `secrets/`, `*.jks`, `*.p8`, key `*.json` (verify with `git ls-files | grep -E 'jks|p8|key.json|secrets/' ` → empty output).

---

## Task 2: Harness protocol reference (file schemas + state machine)

**Files:**
- Create: `docs/harness-protocol.md`
- Modify: `scripts/validate.sh` (add a check that every `SKILL.md` referencing `docs/harness-protocol.md` resolves)

**Interfaces:**
- Produces: `docs/harness-protocol.md` defining, verbatim, the YAML keys of `config.md` and `state.md`, the markdown layout of `contract.md` / `handoff/round-N-gen.md` / `feedback/round-N-qa.md` / `build-log.md` / `pipeline-log.md`, and a **phase transition table**. Every phase skill (Tasks 3–10) cites this file rather than redefining schemas (DRY).

- [ ] **Step 1: Write the failing check**

Add to `scripts/validate.sh` before the final pass/fail line:

```bash
# 3. harness-protocol.md exists and defines required keys
PROTO="$ROOT/docs/harness-protocol.md"
[ -f "$PROTO" ] || err "missing docs/harness-protocol.md"
if [ -f "$PROTO" ]; then
  for key in current_phase current_round next_role status pause_reason; do
    grep -q "$key" "$PROTO" || err "harness-protocol.md missing state key: $key"
  done
fi
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash scripts/validate.sh`
Expected: FAIL → `FAIL: missing docs/harness-protocol.md`.

- [ ] **Step 3: Write `docs/harness-protocol.md`**

Include these sections with exact content:

1. **`config.md` schema** — YAML keys: `app_idea`, `app_name`, `app_slug`, `bundle_id` (=`com.<company>.<slug>`), `default_language: ko`, `strict_mode`, `max_rounds` (default 3), `skip_research`, `skip_admob`, a `developer:` block (company `<company>`, email `<support-email>`, privacy `<privacy-policy-url>`, homepage `<support-and-marketing-url>`, copyright `Copyright <year>. <company> all rights reserved.`), an `ios:` block (`team_id: <apple-team-id>`, `asc_key_id: <asc-key-id>`, `asc_issuer_id: <asc-issuer-id>`, `asc_private_key_path`), an `android:` block (`keystore_path`, `key_alias: upload`), and `credentials_dir: <projects-dir>/credentials`.
2. **`state.md` schema** — YAML keys: `status` (`running|paused|completed`), `current_phase`, `current_round`, `next_role`, `pause_reason` (`""|rate_limit|manual_action|error`), `created_at`, `updated_at`, `resume_attempts`. (Timestamps are written by skills, not by scripts.)
3. **`contract.md` layout** — header, "Mandatory Hard Gates" list (the §6.4 gates from the spec, copied verbatim), "Functional Criteria (per game)" list, trailing `## Status: AGREED`.
4. **`handoff/round-N-gen.md` layout** — sections: What Was Built/Fixed, Contract Self-Assessment (per-criterion DONE/PARTIAL), Test Results (`flutter analyze`, `flutter test`), Environment Detection, Known Issues.
5. **`feedback/round-N-qa.md` layout** — sections: Verdict (PASS/FAIL), Evidence (commands run + outputs + screenshot paths), Failed Criteria with specific reproducible fixes.
6. **`build-log.md`** and **`pipeline-log.md`** — the two markdown tables (`| Round | Phase | Score | Duration | Notes |` and `| Time | Event | Phase | Details |`).
7. **Phase transition table:**

```
| current_phase | event       | → next_role / next_phase            |
|---------------|-------------|-------------------------------------|
| (init)        | bootstrap   | research (or plan if --skip-research)|
| research      | complete    | plan                                |
| plan          | complete    | design                              |
| design        | complete    | contract                            |
| contract      | AGREED      | generator (current_round=1)         |
| generator     | handoff     | evaluator                           |
| evaluator     | PASS        | admob (Phase B boundary → pause/handoff) |
| evaluator     | FAIL        | generator (current_round+1)         |
| evaluator     | max_rounds  | forced judgment, then admob          |
| any           | rate_limit  | status=paused, pause_reason=rate_limit|
```

- [ ] **Step 4: Run validator to verify it passes**

Run: `bash scripts/validate.sh`
Expected: PASS → `validate: OK`.

- [ ] **Step 5: Commit**

```bash
git add docs/harness-protocol.md scripts/validate.sh
git -c user.name='<your-name>' -c user.email='<support-email>' \
  commit -q -m "feat: define harness file protocol and state machine"
```

---

## Task 3: Orchestrator skill `flame-harness`

**Files:**
- Create: `skills/flame-harness/SKILL.md`

**Interfaces:**
- Consumes: `docs/harness-protocol.md` (schemas), `state.md.next_role`.
- Produces: behavior that creates `docs/harness/config.md` + `docs/harness/state.md` on first run and dispatches `Skill("flame-harness-<next_role>")` thereafter.

- [ ] **Step 1: Add the skill-content check to the validator**

Add a generic per-skill section assertion helper to `scripts/validate.sh` (after the frontmatter loop):

```bash
# 4. Per-skill required-section assertions (set by REQ_<skillname> env in CI; here inline)
require_section() { # file, pattern, label
  grep -qi "$2" "$1" || err "$(basename "$(dirname "$1")") missing section: $3"
}
ORCH="$ROOT/skills/flame-harness/SKILL.md"
if [ -f "$ORCH" ]; then
  require_section "$ORCH" "next_role" "dispatch-by-next_role"
  require_section "$ORCH" "config.md" "config-init"
  require_section "$ORCH" "skip-research\|skip_research" "skip-research flag"
fi
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash scripts/validate.sh`
Expected: FAIL → `flame-harness missing section: dispatch-by-next_role`.

- [ ] **Step 3: Write `skills/flame-harness/SKILL.md`**

Frontmatter (verbatim):

```yaml
---
name: flame-harness
description: Orchestrator — bootstrap a Flutter/Flame game pipeline (idea→playable game) and dispatch each phase skill. Use when starting or continuing a flame-harness run.
argument-hint: "<game idea> [--strict] [--rounds N] [--skip-research] [--skip-admob] [--resume]"
allowed-tools: [Agent, Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, Skill]
---
```

Body must contain, as labeled sections:
- **Argument parsing** — map flags to `config.md` keys per `docs/harness-protocol.md`; `--skip-research` sets `skip_research: true`.
- **Bootstrap (first run)** — if `docs/harness/state.md` absent: create `docs/harness/{,handoff,feedback,specs,plans}`, write `config.md` (read `<projects-dir>/credentials/store-metadata.md` to fill developer/ios/android blocks), write `state.md` with `status: running`, `current_phase: (init)`, `next_role: research` (or `plan` if `--skip-research`). Append INIT to `pipeline-log.md`.
- **Dispatch loop** — read `state.md.next_role`; invoke `Skill("flame-harness-<next_role>")`; the phase skill updates `state.md` and returns; orchestrator re-reads and dispatches the next, following the transition table in `docs/harness-protocol.md`. Stop when `status: completed` or `current_phase` reaches the Phase B boundary (`admob`) — at that boundary, print a handoff message (Phase B not yet implemented).
- **Resume** — if `--resume`, delegate to `Skill("flame-harness-resume")`.
- Cite `docs/harness-protocol.md` for all schemas (do not restate them).

- [ ] **Step 4: Run validator to verify it passes**

Run: `bash scripts/validate.sh`
Expected: PASS → `validate: OK`.

- [ ] **Step 5: Commit**

```bash
git add skills/flame-harness/SKILL.md scripts/validate.sh
git -c user.name='<your-name>' -c user.email='<support-email>' \
  commit -q -m "feat(orchestrator): add flame-harness dispatch skill"
```

---

## Task 4: `flame-harness-research`

**Files:**
- Create: `skills/flame-harness-research/SKILL.md`

**Interfaces:**
- Consumes: `config.md.app_idea`, `config.md.skip_research`.
- Produces: `docs/harness/specs/<date>-research.md`; updates `config.md` (confirmed concept) and `state.md` (`current_phase: research`, `next_role: plan`).

- [ ] **Step 1: Add validator assertions**

Append to `scripts/validate.sh`:

```bash
RES="$ROOT/skills/flame-harness-research/SKILL.md"
if [ -f "$RES" ]; then
  require_section "$RES" "AskUserQuestion\|질의\|ask" "user query"
  require_section "$RES" "4\.3\|clone\|클론" "App Store 4.3 clone avoidance"
  require_section "$RES" "next_role" "state update"
fi
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash scripts/validate.sh`
Expected: FAIL → `flame-harness-research missing section: user query`.

- [ ] **Step 3: Write `skills/flame-harness-research/SKILL.md`**

Frontmatter:

```yaml
---
name: flame-harness-research
description: Phase 1 — discover Flame game concepts from store charts/competitors, propose 2-3 options, query the user, and record the chosen concept.
argument-hint: ""
allowed-tools: [Agent, Read, Write, Edit, WebFetch, WebSearch, AskUserQuestion, Bash]
---
```

Body sections: **Input** (read `config.md`; if `skip_research`, the user-supplied idea is the concept — skip discovery, still write the spec); **Discovery** (research Play/App Store game charts + competitors via WebSearch/WebFetch); **Propose & query** (present 2-3 concrete concepts, use `AskUserQuestion` to let the user pick/refine); **Clone avoidance** (check the chosen concept against App Store guideline 4.3 — must not be a clone); **Output** (write `docs/harness/specs/<date>-research.md` with chosen concept, market rationale, differentiation; update `config.md.app_idea`; set `state.md` `current_phase: research`, `next_role: plan`; append to `pipeline-log.md`). Cite `docs/harness-protocol.md`.

- [ ] **Step 4: Run validator to verify it passes**

Run: `bash scripts/validate.sh` → Expected: `validate: OK`.

- [ ] **Step 5: Commit**

```bash
git add skills/flame-harness-research scripts/validate.sh
git -c user.name='<your-name>' -c user.email='<support-email>' \
  commit -q -m "feat(research): add idea discovery and user-query skill"
```

---

## Task 5: `flame-harness-plan`

**Files:**
- Create: `skills/flame-harness-plan/SKILL.md`

**Interfaces:**
- Consumes: `docs/harness/specs/<date>-research.md`, `config.md`.
- Produces: `docs/harness/plans/<date>-prd.md`; updates `config.md` (`app_name`, `app_slug`, `bundle_id`) and `state.md` (`next_role: design`).

- [ ] **Step 1: Add validator assertions**

```bash
PLAN="$ROOT/skills/flame-harness-plan/SKILL.md"
if [ -f "$PLAN" ]; then
  require_section "$PLAN" "app_slug\|slug" "slug assignment"
  require_section "$PLAN" "com.<company>" "bundle id rule"
  require_section "$PLAN" "scope\|스코프" "scope guard"
  require_section "$PLAN" "lib/" "lib structure map"
fi
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash scripts/validate.sh` → Expected: FAIL → `... missing section: slug assignment`.

- [ ] **Step 3: Write `skills/flame-harness-plan/SKILL.md`**

Frontmatter:

```yaml
---
name: flame-harness-plan
description: Phase 2 — write a Korean game PRD (core loop, mechanics, content metrics, win/lose, scope guard), map the lib/ structure, and assign app name, slug, and bundle id.
argument-hint: ""
allowed-tools: [Agent, Read, Write, Edit, Bash]
---
```

Body sections: **Input** (read research spec + config); **PRD content** (Korean: genre, core loop, mechanics, content metrics = #levels/#enemies/#waves, progression/economy, controls, win/lose, **scope guard** that lists what is explicitly out of scope, App Store compliance checklist); **lib/ structure map** (`game/`, `game/components/`, `game/systems/`, `game/data/`, `screens/`, `ui/`, `l10n/`); **Identity** (set `app_name`, kebab-case `app_slug`, `bundle_id: com.<company>.<slug>` in `config.md`); **Output** (`docs/harness/plans/<date>-prd.md`; `state.md` `current_phase: plan`, `next_role: design`). Cite protocol.

- [ ] **Step 4: Run validator** → Expected: `validate: OK`.

- [ ] **Step 5: Commit**

```bash
git add skills/flame-harness-plan scripts/validate.sh
git -c user.name='<your-name>' -c user.email='<support-email>' \
  commit -q -m "feat(plan): add game PRD skill"
```

---

## Task 6: `flame-harness-design`

**Files:**
- Create: `skills/flame-harness-design/SKILL.md`

**Interfaces:**
- Consumes: `docs/harness/plans/<date>-prd.md`, `config.md`.
- Produces: `docs/harness/plans/<date>-design.md`; updates `state.md` (`next_role: contract`).

- [ ] **Step 1: Add validator assertions**

```bash
DES="$ROOT/skills/flame-harness-design/SKILL.md"
if [ -f "$DES" ]; then
  require_section "$DES" "design_tokens" "design tokens spec"
  require_section "$DES" "asset\|에셋\|audio\|오디오" "asset/audio plan"
  require_section "$DES" "next_role" "state update"
fi
```

- [ ] **Step 2: Run to verify it fails** → Expected: FAIL → `... missing section: design tokens spec`.

- [ ] **Step 3: Write `skills/flame-harness-design/SKILL.md`**

Frontmatter:

```yaml
---
name: flame-harness-design
description: Phase 3 — define the Flutter design_tokens.dart spec (palette, typography, spacing), the game's art/visual concept, and the asset/audio sourcing plan.
argument-hint: ""
allowed-tools: [Agent, Read, Write, Edit, Bash]
---
```

Body sections: **Input** (read PRD + config); **Design tokens** (specify the future `lib/ui/design_tokens.dart`: color palette, typography scale, spacing); **Visual concept** (art direction for sprites/world, overlay UI style); **Asset/audio plan** (sourcing strategy — free packs vs generated; `flutter_launcher_icons` + `flutter_native_splash` config intent); **Output** (`docs/harness/plans/<date>-design.md`; `state.md` `current_phase: design`, `next_role: contract`). Cite protocol.

- [ ] **Step 4: Run validator** → Expected: `validate: OK`.

- [ ] **Step 5: Commit**

```bash
git add skills/flame-harness-design scripts/validate.sh
git -c user.name='<your-name>' -c user.email='<support-email>' \
  commit -q -m "feat(design): add design-concept skill"
```

---

## Task 7: `flame-harness-contract`

**Files:**
- Create: `skills/flame-harness-contract/SKILL.md`

**Interfaces:**
- Consumes: PRD, design doc, `config.md.strict_mode`.
- Produces: `docs/harness/contract.md` (`## Status: AGREED`); updates `state.md` (`next_role: generator`, `current_round: 1`).

- [ ] **Step 1: Add validator assertions**

```bash
CON="$ROOT/skills/flame-harness-contract/SKILL.md"
if [ -f "$CON" ]; then
  require_section "$CON" "flutter analyze" "analyze gate"
  require_section "$CON" "flutter test" "test gate"
  require_section "$CON" "game_config" "config centralization gate"
  require_section "$CON" "AGREED" "agreed status"
  require_section "$CON" "stub\|스텁\|TODO" "anti-stub gate"
fi
```

- [ ] **Step 2: Run to verify it fails** → Expected: FAIL → `... missing section: analyze gate`.

- [ ] **Step 3: Write `skills/flame-harness-contract/SKILL.md`**

Frontmatter:

```yaml
---
name: flame-harness-contract
description: Phase 4 — propose verifiable completion criteria and mandatory hard gates; reach AGREED (1-pass default, multi-round negotiation in --strict).
argument-hint: ""
allowed-tools: [Agent, Read, Write, Edit, Bash]
---
```

Body sections: **Mandatory hard gates (verbatim, every contract includes these):**
- `flutter analyze` → 0 issues.
- `flutter test` → all pass.
- No TODO / stub / placeholder in game logic (grep-checkable).
- All tuning constants centralized in `game_config.dart` (no magic numbers in gameplay code).
- Content (enemies/levels/waves) defined as data, not hardcoded.
- KO + EN l10n complete (no missing keys).
- Core loop works: start → play → win/lose → restart.
- Runs on a simulator with zero crashes and zero console errors.

Then **Functional criteria** (per-game, derived from PRD; each must be verifiable by command, screenshot, or code path); **Negotiation** (default: Generator writes contract and self-marks `AGREED`; `--strict`: Evaluator reviews specificity and requests revisions until AGREED); **Output** (`docs/harness/contract.md`; `state.md` `current_phase: contract`, `next_role: generator`, `current_round: 1`). Cite protocol.

- [ ] **Step 4: Run validator** → Expected: `validate: OK`.

- [ ] **Step 5: Commit**

```bash
git add skills/flame-harness-contract scripts/validate.sh
git -c user.name='<your-name>' -c user.email='<support-email>' \
  commit -q -m "feat(contract): add completion-criteria negotiation skill"
```

---

## Task 8: `flame-harness-generator`

**Files:**
- Create: `skills/flame-harness-generator/SKILL.md`

**Interfaces:**
- Consumes: `contract.md`, PRD, design doc, and (round N>1) `feedback/round-(N-1)-qa.md`.
- Produces: the game project under `<projects-dir>/<app_slug>/`; `handoff/round-N-gen.md`; updates `state.md` (`next_role: evaluator`).

- [ ] **Step 1: Add validator assertions**

```bash
GEN="$ROOT/skills/flame-harness-generator/SKILL.md"
if [ -f "$GEN" ]; then
  require_section "$GEN" "flutter create" "scaffold step"
  require_section "$GEN" "sub-phase\|서브페이즈\|5a\|5b\|5c" "3 sub-phases"
  require_section "$GEN" "analyze.*test\|test.*analyze\|HARD GATE\|게이트" "per-subphase gate"
  require_section "$GEN" "handoff" "handoff output"
  require_section "$GEN" "feedback" "feedback intake on round>1"
fi
```

- [ ] **Step 2: Run to verify it fails** → Expected: FAIL → `... missing section: scaffold step`.

- [ ] **Step 3: Write `skills/flame-harness-generator/SKILL.md`**

Frontmatter:

```yaml
---
name: flame-harness-generator
description: Phase 5 — build the Flame game in 3 gated sub-phases (core loop → systems+components → UI+content), then self-evaluate against the contract.
argument-hint: ""
allowed-tools: [Agent, Read, Write, Edit, Bash, Glob, Grep]
---
```

Body sections:
- **Round handling** — round 1: build from contract/PRD/design. Round N>1: read `feedback/round-(N-1)-qa.md` and fix only the listed failures.
- **Sub-phase 5a (scaffold + core loop)** — `flutter create` at `<projects-dir>/<app_slug>/`, set pubspec (Flame 1.37+, `flame_audio`, `google_mobile_ads`, `shared_preferences`), create the PRD's `lib/` structure, `game_config.dart`, `GameState` enum, `FlameGame` subclass, input handling. **HARD GATE:** `flutter analyze` (0) + `flutter test` before 5b; remove default template files.
- **Sub-phase 5b (systems + components)** — entities, systems (spawning/collision/scoring/audio/difficulty), data catalogs. **HARD GATE** before 5c.
- **Sub-phase 5c (UI + content + polish)** — screens/overlays (menu/HUD/pause/game-over/shop as PRD requires), KO/EN l10n, content data, apply design tokens, `shared_preferences` persistence. **HARD GATE.**
- **Self-evaluation & handoff** — write `handoff/round-N-gen.md` per protocol (built/fixed, contract self-assessment, analyze+test results, environment detection, known issues); set `state.md` `current_phase: generator`, `next_role: evaluator`.
- Cite protocol. Note: per protocol, after `flutter create` the `docs/harness/` directory is moved into the game project so all artifacts share one repo.

- [ ] **Step 4: Run validator** → Expected: `validate: OK`.

- [ ] **Step 5: Commit**

```bash
git add skills/flame-harness-generator scripts/validate.sh
git -c user.name='<your-name>' -c user.email='<support-email>' \
  commit -q -m "feat(generator): add 3-sub-phase game build skill"
```

---

## Task 9: `flame-harness-evaluator`

**Files:**
- Create: `skills/flame-harness-evaluator/SKILL.md`

**Interfaces:**
- Consumes: `handoff/round-N-gen.md`, `contract.md`, `config.md.strict_mode`, `config.md.max_rounds`, the built game.
- Produces: `feedback/round-N-qa.md`; updates `state.md` (PASS → `next_phase: admob`; FAIL → `next_role: generator`, `current_round: N+1`) and `build-log.md`.

- [ ] **Step 1: Add validator assertions**

```bash
EVA="$ROOT/skills/flame-harness-evaluator/SKILL.md"
if [ -f "$EVA" ]; then
  require_section "$EVA" "Run the\|실행.*판\|run the game\|see the" "run-then-judge rule"
  require_section "$EVA" "code.review.only\|코드.*PASS\|review alone" "no code-review-only pass"
  require_section "$EVA" "stub.*FAIL\|스텁.*FAIL\|automatic FAIL" "stub auto-fail"
  require_section "$EVA" "max_rounds" "forced judgment"
  require_section "$EVA" "strict" "strict-mode phases"
fi
```

- [ ] **Step 2: Run to verify it fails** → Expected: FAIL → `... missing section: run-then-judge rule`.

- [ ] **Step 3: Write `skills/flame-harness-evaluator/SKILL.md`**

Frontmatter:

```yaml
---
name: flame-harness-evaluator
description: Phase 6 — skeptical QA. Run the game, watch it, then judge against the contract. Default = functional check; --strict adds quality and edge-case passes.
argument-hint: ""
allowed-tools: [Agent, Read, Write, Edit, Bash, Glob, Grep]
---
```

Body must include this critical rule verbatim near the top:

> **"Run the code, see the app, then judge." Never PASS on code review alone. Execute commands, launch the game on a simulator, play the core loop, capture and study screenshots. Stub detected = automatic FAIL, no exceptions.**

Sections:
- **6.1 Functional (default)** — `flutter analyze` (0) → `flutter test` (pass) → grep for stubs/TODO → verify `game_config.dart` centralization → l10n completeness → each contract criterion with evidence → launch on simulator, play core loop, screenshot into `docs/harness/screenshots/`, study frames.
- **6.2 Quality (`--strict`)** — game-feel/juice, originality, craft, functionality 4-axis scoring + interaction states (loading/error/empty) + responsiveness; threshold weighted ≥7/10 (8/10 strict profile).
- **6.3 Edge (`--strict`)** — agent team via `Agent`: gameplay-edge, balance, lifecycle/crash, performance, test-generator, adversarial reviewer; all must PASS.
- **Judgment** — write `feedback/round-N-qa.md` (verdict + evidence + specific reproducible fixes), update `build-log.md`. PASS → `state.md` `next_phase: admob` (Phase B boundary). FAIL → `next_role: generator`, `current_round: N+1`. If `current_round == max_rounds`, force judgment on current state and advance.
- Cite protocol.

- [ ] **Step 4: Run validator** → Expected: `validate: OK`.

- [ ] **Step 5: Commit**

```bash
git add skills/flame-harness-evaluator scripts/validate.sh
git -c user.name='<your-name>' -c user.email='<support-email>' \
  commit -q -m "feat(evaluator): add skeptical QA loop skill"
```

---

## Task 10: Utility skills `flame-harness-status` and `flame-harness-resume`

**Files:**
- Create: `skills/flame-harness-status/SKILL.md`
- Create: `skills/flame-harness-resume/SKILL.md`

**Interfaces:**
- Consumes: `state.md`, `build-log.md`, `pipeline-log.md`.
- Produces: status report (read-only); resume sets `state.md.status: running` and re-dispatches `next_role`.

- [ ] **Step 1: Add validator assertions**

```bash
STA="$ROOT/skills/flame-harness-status/SKILL.md"
RSM="$ROOT/skills/flame-harness-resume/SKILL.md"
[ -f "$STA" ] && require_section "$STA" "read-only\|읽기 전용\|state.md" "status reads state"
if [ -f "$RSM" ]; then
  require_section "$RSM" "rate_limit" "rate_limit resume"
  require_section "$RSM" "manual_action" "manual_action resume"
fi
```

- [ ] **Step 2: Run to verify it fails** → Expected: FAIL → `... missing section`.

- [ ] **Step 3: Write both skills**

`skills/flame-harness-status/SKILL.md` frontmatter:

```yaml
---
name: flame-harness-status
description: Show the current flame-harness pipeline state — phase, round, scores — read-only.
argument-hint: ""
allowed-tools: [Read, Bash, Glob]
---
```
Body: read `state.md`/`build-log.md`/`pipeline-log.md`, print current phase, round, latest QA score, next role. Read-only — never modifies state.

`skills/flame-harness-resume/SKILL.md` frontmatter:

```yaml
---
name: flame-harness-resume
description: Resume a paused flame-harness run based on pause_reason (rate_limit waits; manual_action confirms with user; error reports).
argument-hint: ""
allowed-tools: [Read, Write, Edit, Bash, AskUserQuestion, Skill]
---
```
Body: read `state.md.pause_reason`. `rate_limit` → confirm window passed, set `status: running`, dispatch `next_role`. `manual_action` → `AskUserQuestion` to confirm steps done, then resume. `error` → report error, ask user to fix before resuming. Cite protocol.

- [ ] **Step 4: Run validator** → Expected: `validate: OK`.

- [ ] **Step 5: Commit**

```bash
git add skills/flame-harness-status skills/flame-harness-resume scripts/validate.sh
git -c user.name='<your-name>' -c user.email='<support-email>' \
  commit -q -m "feat: add status and resume utility skills"
```

---

## Task 11: Stop-failure hook and game .gitignore template

**Files:**
- Create: `hooks/stop-failure-handler.sh`
- Create: `templates/gitignore.template`

**Interfaces:**
- Consumes: `docs/harness/state.md` (in the active game's directory), `$CLAUDE_PLUGIN_ROOT`.
- Produces: on rate-limit, sets `status: paused`, `pause_reason: rate_limit`, appends to `pipeline-log.md`, schedules resume; on non-harness dirs, exits 0 silently.

- [ ] **Step 1: Write the failing hook test**

Create `scripts/test-hook.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; cd "$tmp"
# no state.md → hook must exit 0 silently
echo '{"reason":"rate limit"}' | bash "$ROOT/hooks/stop-failure-handler.sh" ; echo "exit=$?"
# with state.md + rate limit → must set paused
mkdir -p docs/harness; printf 'status: running\npause_reason: ""\n' > docs/harness/state.md
echo '{"reason":"429 rate limit reached"}' | bash "$ROOT/hooks/stop-failure-handler.sh" || true
grep -q 'status: paused' docs/harness/state.md && echo "PASS: paused set" || { echo "FAIL: not paused"; exit 1; }
grep -q 'pause_reason: rate_limit' docs/harness/state.md && echo "PASS: reason set" || { echo "FAIL: reason"; exit 1; }
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash scripts/test-hook.sh`
Expected: FAIL — hook script does not exist yet (`No such file`).

- [ ] **Step 3: Write `hooks/stop-failure-handler.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
STATE="docs/harness/state.md"
[ -f "$STATE" ] || exit 0           # not a harness project
payload="$(cat 2>/dev/null || true)"
echo "$payload" | grep -qiE 'rate.?limit|429' || exit 0
# mark paused (portable sed)
tmp="$(mktemp)"
sed -e 's/^status:.*/status: paused/' \
    -e 's/^pause_reason:.*/pause_reason: rate_limit/' "$STATE" > "$tmp" && mv "$tmp" "$STATE"
printf '| %s | PAUSE | - | rate_limit |\n' "$(date '+%H:%M')" >> docs/harness/pipeline-log.md 2>/dev/null || true
command -v osascript >/dev/null && osascript -e 'display notification "flame-harness paused (rate limit)"' 2>/dev/null || true
exit 0
```

- [ ] **Step 4: Run to verify it passes**

Run: `chmod +x hooks/stop-failure-handler.sh && bash scripts/test-hook.sh`
Expected: PASS lines `PASS: paused set`, `PASS: reason set`.

- [ ] **Step 5: Write `templates/gitignore.template`**

```
.DS_Store
secrets/
*.jks
*.p8
key.properties
**/google-services.json
play-store-key.json
ios/Runner/Runner.entitlements
build/
.dart_tool/
.flutter-plugins*
```

- [ ] **Step 6: Run full validator**

Run: `bash scripts/validate.sh`
Expected: PASS → `validate: OK`.

- [ ] **Step 7: Commit**

```bash
git add hooks templates scripts/test-hook.sh
git -c user.name='<your-name>' -c user.email='<support-email>' \
  commit -q -m "feat: add rate-limit stop-failure hook and game gitignore template"
```

---

## Task 12: Install, smoke test, finalize

**Files:**
- Create: `docs/SMOKE-TEST.md`
- Modify: `README.md` (mark Phase A complete, link smoke test)

**Interfaces:**
- Consumes: the whole plugin.
- Produces: a documented, reproducible Phase-A dry run and a clean public repo.

- [ ] **Step 1: Validate the whole plugin**

Run: `bash scripts/validate.sh && bash scripts/test-hook.sh`
Expected: both PASS.

- [ ] **Step 2: Install the plugin locally**

Run in Claude Code:
```
/plugin marketplace add <projects-dir>/flutter-flame-harness
/plugin install flutter-flame-harness
```
Expected: 9 `flame-harness*` skills appear in the skill list.

- [ ] **Step 3: Write `docs/SMOKE-TEST.md`**

Document a manual dry run with a deliberately tiny game (e.g. `--skip-research` + a one-line idea "tap to flap, single obstacle"). The checklist verifies, in order: orchestrator creates `docs/harness/config.md` + `state.md`; plan produces a PRD with `app_slug` + `com.<company>.<slug>`; design produces tokens doc; contract reaches `## Status: AGREED` containing all 8 mandatory hard gates; generator scaffolds `<projects-dir>/<slug>/` and passes `flutter analyze`+`flutter test`; evaluator launches the game, screenshots, and writes a PASS/FAIL verdict; on FAIL the round increments and re-dispatches generator. Record expected `state.md` transitions against the protocol table.

- [ ] **Step 4: Run the smoke test and record results**

Run: `/flame-harness --skip-research "tap to flap, single obstacle"`
Expected: pipeline advances research→plan→design→contract→generator→evaluator, halting at the Phase B boundary (`admob`) with a handoff message. Note any divergence in `docs/SMOKE-TEST.md`.

- [ ] **Step 5: Finalize README and commit**

Update `README.md` to mark Phase A complete and link `docs/SMOKE-TEST.md`.

```bash
git add docs/SMOKE-TEST.md README.md
git -c user.name='<your-name>' -c user.email='<support-email>' \
  commit -q -m "docs: add Phase A smoke test and finalize README"
git push origin HEAD
```

- [ ] **Step 6: Confirm no secrets leaked**

Run: `git ls-files | grep -Ei 'jks|\.p8|play-store-key|secrets/' || echo "clean"`
Expected: prints `clean`.

---

## Notes for the implementer

- The deliverables are prompt documents, not application code; "tests" here are structural (`validate.sh`), behavioral (`test-hook.sh`), and a manual smoke run. Do not invent unit tests for prose.
- Keep each `SKILL.md` focused: cite `docs/harness-protocol.md` instead of restating schemas (DRY).
- Every skill updates `state.md` per the transition table and appends one line to `pipeline-log.md`. If you add a transition, update the table in `docs/harness-protocol.md` first.
- Phase B skills (admob/build/screenshot/submit/retro) are intentionally out of scope; the evaluator's PASS hands off at the `admob` boundary.
