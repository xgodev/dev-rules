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

# 1b. No sentinel => EDIT and WRITE of production are DENIED too (bug discipline).
out="$(run Edit '{"tool_name":"Edit","tool_input":{"file_path":"internal/x.go"}}')"
if denied "$out"; then echo "ok  : edit prod blocked (bug default)"; else echo "FAIL: edit prod should be blocked (no sentinel)"; fail=1; fi
out="$(run Write '{"tool_name":"Write","tool_input":{"file_path":"internal/x.go"}}')"
if denied "$out"; then echo "ok  : write prod blocked (bug default)"; else echo "FAIL: write prod should be blocked (no sentinel)"; fail=1; fi

# 1c. Bash path (bug default): shell read/write of production is gated too; docs allowed.
out="$(run Bash '{"tool_name":"Bash","tool_input":{"command":"cat internal/x.go"}}')"
if denied "$out"; then echo "ok  : bash cat prod blocked"; else echo "FAIL: bash cat prod should block"; fail=1; fi
out="$(run Bash '{"tool_name":"Bash","tool_input":{"command":"rg foo internal/x.go"}}')"
if denied "$out"; then echo "ok  : bash rg prod blocked"; else echo "FAIL: bash rg prod should block"; fail=1; fi
out="$(run Bash '{"tool_name":"Bash","tool_input":{"command":"echo x>internal/x.go"}}')"
if denied "$out"; then echo "ok  : bash redirect prod blocked"; else echo "FAIL: bash redirect prod should block"; fail=1; fi
out="$(run Bash '{"tool_name":"Bash","tool_input":{"command":"cat README.md"}}')"
if denied "$out"; then echo "FAIL: bash cat docs should be allowed"; fail=1; else echo "ok  : bash cat docs allowed"; fi

# 2. Test file always allowed (no deny).
reset
out="$(run Read '{"tool_name":"Read","tool_input":{"file_path":"internal/x_test.go"}}')"
if denied "$out"; then echo "FAIL: test file must be allowed"; fail=1; else echo "ok  : test file allowed"; fi

# 3. .mode-feature => reading production allowed.
reset; mkdir -p "$SBX/.dev-rules"; : >"$SBX/.dev-rules/.mode-feature"
out="$(run Read '{"tool_name":"Read","tool_input":{"file_path":"internal/x.go"}}')"
if denied "$out"; then echo "FAIL: feature mode should allow reads"; fail=1; else echo "ok  : feature mode allows reads"; fi
# 3b. A read that redirects stderr (2>&1) must NOT be misread as a write and blocked.
out="$(run Bash '{"tool_name":"Bash","tool_input":{"command":"cat src/x.ts 2>&1"}}')"
if denied "$out"; then echo "FAIL: bash read with 2>&1 wrongly blocked in feature mode"; fail=1; else echo "ok  : bash read with 2>&1 allowed (feature mode)"; fi

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

# Malformed / empty stdin must not crash or block -- clean allow (exit 0, no deny).
printf '%s' 'not-json' | bash "$GUARD" >/dev/null 2>&1; rc=$?
if [ "$rc" = 0 ]; then echo "ok  : malformed stdin exits 0 (allow)"; else echo "FAIL: malformed stdin exit $rc"; fail=1; fi

exit $fail
