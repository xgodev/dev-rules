#!/usr/bin/env bash
set -eu
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../clear-after-commit.sh"
SBX="$(mktemp -d)"; export CLAUDE_PROJECT_DIR="$SBX"
trap 'rm -rf "$SBX"' EXIT
fail=0

arm()     { mkdir -p "$SBX/.dev-rules"; : >"$SBX/.dev-rules/.red-first-unlocked"; : >"$SBX/.dev-rules/.mode-feature"; }
cleared() { [ ! -f "$SBX/.dev-rules/.red-first-unlocked" ] && [ ! -f "$SBX/.dev-rules/.mode-feature" ]; }
intact()  { [ -f "$SBX/.dev-rules/.red-first-unlocked" ] && [ -f "$SBX/.dev-rules/.mode-feature" ]; }
# set -e aborts if the hook itself crashes (never a false "ok").
fire()    { printf '%s' "$1" | bash "$HOOK" >/dev/null; }
cj()      { printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m \\"%s\\""},"tool_response":%s}' "$1" "$2"; }

# Every clearing pattern must clear BOTH sentinels on a successful commit.
for msg in "feat(x): y" "fix(x): y" "bugfix(x): y" "Fix #12 y" "Fixes #12 y"; do
  arm; fire "$(cj "$msg" '{"exit_code":0}')"
  if cleared; then echo "ok  : cleared on [$msg]"; else echo "FAIL: should clear on [$msg]"; fail=1; fi
done

# Non-clearing: chore/docs commit leaves both sentinels.
arm; fire "$(cj "docs: y" '{"exit_code":0}')"
if intact; then echo "ok  : docs left sentinels"; else echo "FAIL: docs must not clear"; fail=1; fi

# Non-clearing: failed commit by exit_code leaves both.
arm; fire "$(cj "fix(x): y" '{"exit_code":1}')"
if intact; then echo "ok  : failed (exit_code) left sentinels"; else echo "FAIL: failed exit_code must not clear"; fail=1; fi

# Non-clearing: failed commit reported as {"success":false} leaves both
# (guards the jq // -false trap: false must not be read as "absent"->success).
arm; fire "$(cj "fix(x): y" '{"success":false}')"
if intact; then echo "ok  : failed (success:false) left sentinels"; else echo "FAIL: success:false must not clear"; fail=1; fi

# .solvers/* copy is also cleared on a cycle-closing commit.
arm; mkdir -p "$SBX/.solvers/issue-1/.dev-rules"; : >"$SBX/.solvers/issue-1/.dev-rules/.red-first-unlocked"
fire "$(cj "feat(x): y" '{"exit_code":0}')"
if [ ! -f "$SBX/.solvers/issue-1/.dev-rules/.red-first-unlocked" ]; then echo "ok  : .solvers sentinel cleared"; else echo "FAIL: .solvers sentinel not cleared"; fail=1; fi

exit $fail
