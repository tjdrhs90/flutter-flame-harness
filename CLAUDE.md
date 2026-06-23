# flutter-flame-harness — Development Guide

> 한국어 소개는 [README.ko.md](README.ko.md) 를 참고하세요.

This guide is for **developing/contributing to this plugin repo itself** — the `skills/`,
`docs/`, `scripts/`, and `templates/` that make up the plugin, not the games it generates.

Philosophy: **don't vibe-code — delegate the *procedure* to a disciplined workflow.** Question →
plan → build → review, with humans owning direction and final QA. This workflow is
**tool-agnostic and depends on no external plugins**; follow it by hand, or with whatever tooling
you happen to have.

> This harness is itself a game-specific instance of this same philosophy: hard gates / the
> contract = guardrails, research·plan = clarify·plan, the generator↔evaluator loop = build-until-
> verified + independent review. So we develop the plugin the same way it builds games.

---

## Always-on guardrails

Apply these on every edit, review, and refactor — by default:

1. **Think before coding** — state assumptions; if multiple readings exist, surface them and ask.
   Don't silently pick.
2. **Simplicity first** — the minimum that solves the task. No speculative abstraction,
   configurability, or features that weren't requested.
3. **Surgical changes** — touch only the lines the request requires. Match existing style. Don't
   refactor what isn't broken; if you spot unrelated dead code, mention it rather than delete it.
4. **Goal-driven** — turn the task into a verifiable success check, then loop until it passes
   ("make this command pass" beats "make it work").

---

## Development flow

1. **Clarify** — before writing code, agree on intent, constraints, and success criteria, and get
   the design approved. Don't start on ambiguous requirements.
2. **Plan** — write a task-by-task implementation plan under `docs/superpowers/plans/`. Decide the
   test/verification strategy up front.
3. **Build** — implement task by task. Prefer **isolated-context sub-agents** (one per task) with a
   **two-stage review** (spec compliance → code quality); or run in batches with human checkpoints.
   Isolation keeps each unit's context clean and the main thread focused on coordination.
4. **Review** — a fresh, independent pass over the diff (bugs / duplication / efficiency) before
   merge. It's a first filter from a clean context, not a replacement for human review.
5. **Human QA** — design direction and business fit are the human's call. Treat review findings as
   input, not orders; reject false positives.

For long "loop until green" work, **bound the iterations** and judge completion by an **external
signal** (tests / CI / a validation script), never by self-assessment.

---

## This repo's nature (important)

- **Deliverables are prompt documents** (`skills/*/SKILL.md`) plus shell scripts and templates.
  Unit TDD doesn't map cleanly — verify **structurally** instead.
- **Verification gates — must pass after any change:**
  - `bash scripts/validate.sh` — manifest JSON validity, skill frontmatter, per-skill required sections.
  - `bash scripts/validate-fastlane.sh` — `ruby -c` on the fastlane templates.
  - `bash scripts/test-hook.sh` — the rate-limit stop hook behavior.
- **`docs/harness-protocol.md` is the single source of truth** for every file schema and the phase
  state machine. Skills **cite** it (DRY) — never redefine schemas. When adding a state transition,
  update protocol §7 **first**, then align the skills.

---

## Commit rules

- **Conventional Commits** (`feat:`, `fix(scope):`, `docs:`, `chore:`, `refactor:`).
- **Never add AI-authorship trailers** — no `Co-Authored-By`, no "Generated with…" line.
