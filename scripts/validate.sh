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

# 3. harness-protocol.md exists and defines required keys
PROTO="$ROOT/docs/harness-protocol.md"
[ -f "$PROTO" ] || err "missing docs/harness-protocol.md"
if [ -f "$PROTO" ]; then
  for key in current_phase current_round next_role status pause_reason; do
    grep -q "$key" "$PROTO" || err "harness-protocol.md missing state key: $key"
  done
fi

# 4. Per-skill required-section assertions (inline grep checks).
require_section() { # file, pattern, label
  grep -qi "$2" "$1" || err "$(basename "$(dirname "$1")") missing section: $3"
}
ORCH="$ROOT/skills/flame-harness/SKILL.md"
if [ -f "$ORCH" ]; then
  require_section "$ORCH" "next_role" "dispatch-by-next_role"
  require_section "$ORCH" "config.md" "config-init"
  require_section "$ORCH" "skip-research\|skip_research" "skip-research flag"
fi

RES="$ROOT/skills/flame-harness-research/SKILL.md"
if [ -f "$RES" ]; then
  require_section "$RES" "AskUserQuestion\|질의\|ask" "user query"
  require_section "$RES" "4\.3\|clone\|클론" "App Store 4.3 clone avoidance"
  require_section "$RES" "auto_idea\|auto-select\|auto select" "auto-idea handling"
  require_section "$RES" "next_role" "state update"
fi

PLAN="$ROOT/skills/flame-harness-plan/SKILL.md"
if [ -f "$PLAN" ]; then
  require_section "$PLAN" "app_slug\|slug" "slug assignment"
  require_section "$PLAN" "com.gonigon" "bundle id rule"
  require_section "$PLAN" "scope\|스코프" "scope guard"
  require_section "$PLAN" "lib/" "lib structure map"
fi

DES="$ROOT/skills/flame-harness-design/SKILL.md"
if [ -f "$DES" ]; then
  require_section "$DES" "design_tokens" "design tokens spec"
  require_section "$DES" "asset\|에셋\|audio\|오디오" "asset/audio plan"
  require_section "$DES" "next_role" "state update"
fi

CON="$ROOT/skills/flame-harness-contract/SKILL.md"
if [ -f "$CON" ]; then
  require_section "$CON" "flutter analyze" "analyze gate"
  require_section "$CON" "flutter test" "test gate"
  require_section "$CON" "game_config" "config centralization gate"
  require_section "$CON" "AGREED" "agreed status"
  require_section "$CON" "stub\|스텁\|TODO" "anti-stub gate"
fi

GEN="$ROOT/skills/flame-harness-generator/SKILL.md"
if [ -f "$GEN" ]; then
  require_section "$GEN" "flutter create" "scaffold step"
  require_section "$GEN" "sub-phase\|서브페이즈\|5a\|5b\|5c" "3 sub-phases"
  require_section "$GEN" "analyze.*test\|test.*analyze\|HARD GATE\|게이트" "per-subphase gate"
  require_section "$GEN" "handoff" "handoff output"
  require_section "$GEN" "feedback" "feedback intake on round>1"
fi

EVA="$ROOT/skills/flame-harness-evaluator/SKILL.md"
if [ -f "$EVA" ]; then
  require_section "$EVA" "Run the\|실행.*판\|run the game\|see the" "run-then-judge rule"
  require_section "$EVA" "code.review.only\|코드.*PASS\|review alone" "no code-review-only pass"
  require_section "$EVA" "stub.*FAIL\|스텁.*FAIL\|automatic FAIL" "stub auto-fail"
  require_section "$EVA" "max_rounds" "forced judgment"
  require_section "$EVA" "strict" "strict-mode phases"
  require_section "$EVA" "auto_deploy\|human-approval\|human review\|review gate" "post-QA review gate"
fi

STA="$ROOT/skills/flame-harness-status/SKILL.md"
RSM="$ROOT/skills/flame-harness-resume/SKILL.md"
[ -f "$STA" ] && require_section "$STA" "read-only\|읽기 전용\|state.md" "status reads state"
if [ -f "$RSM" ]; then
  require_section "$RSM" "rate_limit" "rate_limit resume"
  require_section "$RSM" "manual_action" "manual_action resume"
fi

ADM="$ROOT/skills/flame-harness-admob/SKILL.md"
if [ -f "$ADM" ]; then
  require_section "$ADM" "rewarded\|리워드" "rewarded strategy"
  require_section "$ADM" "ATT\|app_tracking\|UMP\|consent" "ATT/UMP consent"
  require_section "$ADM" "skip_admob\|skip-admob" "skip flag"
  require_section "$ADM" "next_role" "state update"
fi

BLD="$ROOT/skills/flame-harness-build/SKILL.md"
if [ -f "$BLD" ]; then
  require_section "$BLD" "key.properties" "android signing setup"
  require_section "$BLD" "Appfile\|Fastfile" "fastlane config generation"
  require_section "$BLD" "testflight\|TestFlight" "ios upload"
  require_section "$BLD" "internal" "android internal track"
  require_section "$BLD" "next_role" "state update"
fi

SHOT="$ROOT/skills/flame-harness-screenshot/SKILL.md"
if [ -f "$SHOT" ]; then
  require_section "$SHOT" "integration_test" "integration test harness"
  require_section "$SHOT" "ko\|KO\|en\|EN\|locale" "KO+EN locales"
  require_section "$SHOT" "keywords" "ASO keywords"
  require_section "$SHOT" "screenshots\|images" "fastlane upload"
fi

SUB="$ROOT/skills/flame-harness-submit/SKILL.md"
if [ -f "$SUB" ]; then
  require_section "$SUB" "metadata" "metadata upload"
  require_section "$SUB" "manual_action\|paused" "manual pause"
  require_section "$SUB" "Submit for Review\|심사 제출\|production" "manual submit steps"
  require_section "$SUB" "retro" "resume target"
fi

RET="$ROOT/skills/flame-harness-retro/SKILL.md"
if [ -f "$RET" ]; then
  require_section "$RET" "9\|principle\|원칙" "9 principles"
  require_section "$RET" "Generator.*Evaluator\|generator-evaluator" "generator-evaluator principle"
  require_section "$RET" "retro.md" "retro output"
  require_section "$RET" "completed" "completion state"
fi

# Robustness knowledge doc + its propagation into skills
GOTCHAS="$ROOT/docs/game-gotchas.md"
[ -f "$GOTCHAS" ] || err "missing docs/game-gotchas.md"
GEN="$ROOT/skills/flame-harness-generator/SKILL.md"
if [ -f "$GEN" ]; then
  require_section "$GEN" "game-gotchas" "generator cites gotchas"
  require_section "$GEN" "AudioPool" "audio pool guidance"
  require_section "$GEN" "haptics" "haptics system"
  require_section "$GEN" "WidgetsBindingObserver" "lifecycle observer"
  require_section "$GEN" "flutter_launcher_icons" "branding: launcher icons"
  require_section "$GEN" "flutter_native_splash" "branding: native splash"
  require_section "$GEN" "CFBundleDisplayName\|android:label" "branding: display name"
  require_section "$GEN" "UISupportedInterfaceOrientations" "native: orientation lock"
  require_section "$GEN" "TARGETED_DEVICE_FAMILY" "native: iPhone-only"
  require_section "$GEN" "ITSAppUsesNonExemptEncryption" "native: export compliance"
  require_section "$GEN" "PopScope" "native: root back-button"
fi
[ -f "$ROOT/templates/gen_icon.dart.template" ] || err "missing templates/gen_icon.dart.template"
CON2="$ROOT/skills/flame-harness-contract/SKILL.md"
[ -f "$CON2" ] && require_section "$CON2" "Platform-Robustness Gates" "robustness gates block"

[ "$fail" -eq 0 ] && echo "validate: OK" || exit 1
