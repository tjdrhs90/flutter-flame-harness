# Contributing

Thanks for your interest! Bug reports, feature requests, and PRs are welcome.

## Reporting issues

Use the **bug report** or **feature request** template. For anything security-related, follow
[SECURITY.md](SECURITY.md) (report privately — not a public issue).

## Project structure

```
.claude-plugin/   plugin.json (version + manifest), marketplace.json
skills/           one SKILL.md per phase (research, plan, design, contract, generator,
                  evaluator, admob, build, screenshot, submit, retro, resume, status)
docs/             harness-protocol.md (the single source of truth: file schemas + state machine),
                  game-gotchas.md (battle-tested Flutter/Flame fixes)
templates/        files the generator drops into each game (.gitignore, README, LICENSE, fastlane,
                  CI, audio/icon/asset tools, save layer)
scripts/          the verification gates
hooks/            stop-failure handler
```

The harness is **prompt documents**, not application code — verify changes **structurally** (below),
not with unit tests. See [`CLAUDE.md`](CLAUDE.md) for the development philosophy and
[`docs/harness-protocol.md`](docs/harness-protocol.md) for how the phases fit together.

## Before you open a PR

Run all three gates and make sure they pass (CI runs the same ones):

```bash
bash scripts/validate.sh           # manifest JSON, skill frontmatter, required sections, no identity leak
bash scripts/validate-fastlane.sh  # ruby -c on the fastlane templates
bash scripts/test-hook.sh          # stop-failure hook behavior
```

If you change a state transition or a file schema, update `docs/harness-protocol.md` **first**, then
align the skills (it's the single source of truth — skills cite it, never redefine it).

## Commit & PR rules

- [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix(scope):`, `docs:`, `chore:`).
- **Never add AI-authorship trailers** — no `Co-Authored-By`, no "Generated with…" line.
- No credentials or personal info in the diff.
- Keep PRs small and focused; open an issue first for larger changes.
