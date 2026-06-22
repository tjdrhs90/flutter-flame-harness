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
grep -q '^status:' "$STATE" || printf 'status: paused\n' >> "$STATE"
grep -q '^pause_reason:' "$STATE" || printf 'pause_reason: rate_limit\n' >> "$STATE"
printf '| %s | PAUSE | - | rate_limit |\n' "$(date '+%H:%M')" >> docs/harness/pipeline-log.md 2>/dev/null || true
command -v osascript >/dev/null && osascript -e 'display notification "flame-harness paused (rate limit)"' 2>/dev/null || true
exit 0
