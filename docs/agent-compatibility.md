# Multi-Agent Compatibility Guide

`flutter-flame-harness` is designed to be **agent-agnostic**. The harness operates through structured file schemas (`docs/harness/`), state transitions, and hard quality gates that execute identically across AI coding environments (Claude Code, Google Antigravity, OpenAI Codex, Cursor, etc.).

---

## Tool Mapping Across Environments

| Feature | Claude Code | Google Antigravity | OpenAI Codex / CLI |
| :--- | :--- | :--- | :--- |
| **Orchestrator Entry** | `/flame-harness "idea"` | `/flame-harness "idea"` | `@flame-harness "idea"` or task prompt |
| **Phase Invocation** | `Skill("flame-harness-<role>")` | Read `skills/flame-harness-<role>/SKILL.md` | Execute skill file or injection |
| **Context Isolation** | `Agent(role, prompt)` | `invoke_subagent` (TypeName="self") | Subprocess agent execution |
| **User Interaction** | `AskUserQuestion` | `ask_question` / user prompt | Stdin / prompt |
| **State Machine** | `docs/harness/state.md` | `docs/harness/state.md` | `docs/harness/state.md` |

---

## How to Set Up in Your Agent Environment

### 1. Claude Code
Install via Claude Code plugin marketplace or clone directly into `.claude-plugin/`:
```bash
claude plugins marketplace add tjdrhs90/flutter-flame-harness
claude plugins install flutter-flame-harness@flutter-flame-harness
```
Invoke with:
```
/flame-harness "cyberpunk arcade roguelike"
```

### 2. Google Antigravity
Link the harness skills into your workspace's `.agents/skills/`:
```bash
mkdir -p .agents/skills
ln -s /path/to/flutter-flame-harness/skills/flame-harness .agents/skills/flame-harness
```
Antigravity automatically detects the `SKILL.md` frontmatter and registers it. Run with:
```
/flame-harness "cyberpunk arcade roguelike"
```

### 3. OpenAI Codex & CLI Agents
Provide `skills/flame-harness/SKILL.md` as the root instruction. The orchestrator drives `docs/harness/state.md` and dispatches each phase sequentially with full context isolation.
