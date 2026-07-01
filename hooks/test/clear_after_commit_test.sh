#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../clear-after-commit.sh"
SBX="$(mktemp -d)"; export CLAUDE_PROJECT_DIR="$SBX"
trap 'rm -rf "$SBX"' EXIT
fail=0
arm() { mkdir -p "$SBX/.dev-rules"; : >"$SBX/.dev-rules/.red-first-unlocked"; : >"$SBX/.dev-rules/.mode-feature"; }
present() { [ -f "$SBX/.dev-rules/.red-first-unlocked" ] || [ -f "$SBX/.dev-rules/.mode-feature" ]; }

# 1. feat( commit clears both sentinels.
arm
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"feat(x): y\""},"tool_response":{"exit_code":0}}' | bash "$HOOK" >/dev/null
if present; then echo "FAIL: feat( should clear sentinels"; fail=1; else echo "ok  : feat( cleared sentinels"; fi

# 2. docs( commit does NOT clear.
arm
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"docs: y\""},"tool_response":{"exit_code":0}}' | bash "$HOOK" >/dev/null
if present; then echo "ok  : docs( left sentinels"; else echo "FAIL: docs( must not clear"; fail=1; fi

# 3. failed commit (non-zero) does NOT clear.
arm
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"fix(x): y\""},"tool_response":{"exit_code":1}}' | bash "$HOOK" >/dev/null
if present; then echo "ok  : failed commit left sentinels"; else echo "FAIL: failed commit must not clear"; fail=1; fi

exit $fail
