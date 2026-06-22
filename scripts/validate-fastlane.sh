#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
for tpl in "$ROOT/templates/fastlane/ios-Fastfile.template" "$ROOT/templates/fastlane/android-Fastfile.template"; do
  [ -f "$tpl" ] || { echo "FAIL: missing $tpl"; fail=1; continue; }
  # substitute placeholders with dummy values, then ruby -c
  sed -e 's/__APP_ID__/com.gonigon.dummy/g' \
      -e 's/__APP_NAME__/Dummy/g' \
      -e 's/__IPA_NAME__/Dummy.ipa/g' \
      -e 's/__PACKAGE__/com.gonigon.dummy/g' \
      -e 's/__PROFILE_NAME__/com.gonigon.dummy AppStore/g' "$tpl" \
    | ruby -c 2>/dev/null | grep -q "Syntax OK" || { echo "FAIL: ruby syntax in $tpl"; fail=1; }
done
[ "$fail" -eq 0 ] && echo "validate-fastlane: OK" || exit 1
