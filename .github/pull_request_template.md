## Summary
<!-- What does this change and why? Link any related issue (#123). -->

## Checklist
- [ ] Ran `bash scripts/validate.sh` — passes
- [ ] Ran `bash scripts/validate-fastlane.sh` (if fastlane templates changed) — passes
- [ ] Ran `bash scripts/test-hook.sh` (if the hook changed) — passes
- [ ] No credentials or personal info in the diff
- [ ] [Conventional Commits](https://www.conventionalcommits.org/) messages, **no AI-authorship trailers**
- [ ] Updated `docs/harness-protocol.md` first if a state transition / schema changed
- [ ] Bumped the version in `.claude-plugin/plugin.json` and added a `CHANGELOG.md` entry (if user-facing)
