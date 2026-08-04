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

## Releasing

Any change that affects what the harness produces ships as a release. Do all of it in the **same
commit** as the change — splitting the version bump out is how it gets forgotten:

1. Bump `version` in `.claude-plugin/plugin.json` — minor for anything that changes generated output
   or skill behaviour, patch for guidance/wording only.
2. Add a `## [x.y.z] — YYYY-MM-DD` section to `CHANGELOG.md` describing the symptom, the cause, and
   how it was verified.
3. After pushing, tag it and publish the release:

```bash
git tag vx.y.z && git push origin main vx.y.z
gh release create vx.y.z --title "vx.y.z — <summary>" --notes "<changelog section>"
```

The tag and release are what make the current version visible on GitHub — `plugin.json` alone is
invisible to anyone browsing the repo. Tagging lapsed between 0.16.0 and 0.19.0 precisely because
this was never written down.
