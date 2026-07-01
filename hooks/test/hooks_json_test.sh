#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
J="$HERE/../hooks.json"
fail=0
chk() { if eval "$1"; then echo "ok  : $2"; else echo "FAIL: $2"; fail=1; fi; }

chk '[ -f "$J" ]' "hooks.json exists"
chk 'jq -e . "$J" >/dev/null 2>&1' "hooks.json is valid JSON"
chk 'jq -e ".hooks.PreToolUse[] | select(.matcher | test(\"Edit\")) | .hooks[].command | test(\"red-first-guard.sh\")" "$J" >/dev/null 2>&1' "PreToolUse wires red-first-guard.sh"
chk 'jq -e ".hooks.PostToolUse[] | .hooks[].command | test(\"clear-after-commit.sh\")" "$J" >/dev/null 2>&1' "PostToolUse wires clear-after-commit.sh"
chk 'grep -q "CLAUDE_PLUGIN_ROOT" "$J"' "uses CLAUDE_PLUGIN_ROOT path var"
exit $fail
