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
