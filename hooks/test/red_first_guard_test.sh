#!/usr/bin/env bash
# Feeds hook-input JSON to red-first-guard.sh and asserts deny/allow.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD="$HERE/../red-first-guard.sh"
SBX="$(mktemp -d)"; export CLAUDE_PROJECT_DIR="$SBX"
trap 'rm -rf "$SBX"' EXIT
fail=0
denied() { grep -q '"permissionDecision":"deny"' <<<"$1"; }

run() { # tool, json-input
  printf '%s' "$2" | bash "$GUARD"
}

reset() { rm -rf "$SBX/.dev-rules"; }

# 1. No sentinel => bug discipline: reading production is DENIED.
reset
out="$(run Read '{"tool_name":"Read","tool_input":{"file_path":"internal/x.go"}}')"
if denied "$out"; then echo "ok  : read prod blocked (bug default)"; else echo "FAIL: read prod should be blocked"; fail=1; fi

# 2. Test file always allowed (no deny).
reset
out="$(run Read '{"tool_name":"Read","tool_input":{"file_path":"internal/x_test.go"}}')"
if denied "$out"; then echo "FAIL: test file must be allowed"; fail=1; else echo "ok  : test file allowed"; fi

# 3. .mode-feature => reading production allowed.
reset; mkdir -p "$SBX/.dev-rules"; : >"$SBX/.dev-rules/.mode-feature"
out="$(run Read '{"tool_name":"Read","tool_input":{"file_path":"internal/x.go"}}')"
if denied "$out"; then echo "FAIL: feature mode should allow reads"; fail=1; else echo "ok  : feature mode allows reads"; fi

# 4. .mode-feature but EDIT still blocked (no RED yet).
out="$(run Edit '{"tool_name":"Edit","tool_input":{"file_path":"internal/x.go"}}')"
if denied "$out"; then echo "ok  : edit blocked without RED"; else echo "FAIL: edit must be blocked without RED"; fail=1; fi

# 5. .red-first-unlocked => edit allowed.
reset; mkdir -p "$SBX/.dev-rules"; : >"$SBX/.dev-rules/.red-first-unlocked"
out="$(run Edit '{"tool_name":"Edit","tool_input":{"file_path":"internal/x.go"}}')"
if denied "$out"; then echo "FAIL: edit must be allowed after RED"; fail=1; else echo "ok  : edit allowed after RED"; fi

# 6. Docs always allowed.
reset
out="$(run Edit '{"tool_name":"Edit","tool_input":{"file_path":"README.md"}}')"
if denied "$out"; then echo "FAIL: docs must be allowed"; fail=1; else echo "ok  : docs allowed"; fi

exit $fail
