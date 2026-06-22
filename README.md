# flutter-flame-harness

A Claude Code plugin that takes a Flutter/Flame game from raw idea all the way to the app stores. The harness orchestrates a structured pipeline of skills — research, planning, design, contract negotiation, and a generator–evaluator build loop — so every stage produces a verified, hand-off-ready artifact before the next one begins.

## Phases

**Phase A (this release): research → plan → design → contract → generator ↔ evaluator → playable game**

The generator and evaluator negotiate completion criteria before any code is written, then build the Flutter/Flame project in three sub-phases (scaffold → API wiring → UI polish), with the evaluator gating each hand-off.

**Phase B (planned): admob, build, screenshot, submit, retro**

Automates AdMob integration, release builds (Android + iOS), App Store / Play Store screenshots, submission, and a post-launch retrospective.

## Install

```bash
/plugin marketplace add /Users/ssg/AndroidStudioProjects/flutter-flame-harness
/plugin install flutter-flame-harness
```

## Usage

```
/flame-harness <idea>
```

Flags:

| Flag | Default | Description |
|------|---------|-------------|
| `--strict` | off | Run the evaluator in strict 3-phase QA mode |
| `--rounds N` | 3 | Maximum generator–evaluator negotiation rounds |
| `--skip-research` | off | Skip the market-research phase |

## Phase A Skills

| Skill | Trigger command | Purpose |
|-------|----------------|---------|
| `flame-harness-research` | `/flame-harness-research` | Market research and genre analysis |
| `flame-harness-plan` | `/flame-harness-plan` | PRD, Flame component map, Riverpod state design |
| `flame-harness-design` | `/flame-harness-design` | Visual style system and component specs |
| `flame-harness-contract` | `/flame-harness-contract` | Generator/evaluator negotiate completion criteria |
| `flame-harness-generator` | `/flame-harness-generator` | Build the Flutter/Flame project in 3 sub-phases |
| `flame-harness-evaluator` | `/flame-harness-evaluator` | QA gating — functional check or strict 3-phase |

## File Protocol

See [`docs/harness-protocol.md`](docs/harness-protocol.md) for the full inter-skill file handoff protocol.

## Security

Credentials and secrets never enter this repository. The `.gitignore` permanently excludes `credentials/`, `secrets/`, `*.jks`, `*.p8`, `play-store-key.json`, and `sheets-key.json`. Never commit signing keys, API credentials, or service-account files — pass them via environment variables or a secrets manager at runtime.
