#!/usr/bin/env bash
# Unit tests for detect.sh. Pure functions, no hook I/O.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../lib/detect.sh"

fail=0
ok()  { if "$@"; then echo "ok  : $*"; else echo "FAIL: $*"; fail=1; fi; }
no()  { if "$@"; then echo "FAIL(not): $*"; fail=1; else echo "ok  : !$*"; fi; }

# test files (always allowed)
ok dr_is_test_file "internal/foo_test.go"
ok dr_is_test_file "tests/test_x.py"
ok dr_is_test_file "src/x.spec.ts"
ok dr_is_test_file "crates/c/src/x_tests.rs"
# production
ok dr_is_production "internal/x.go"
ok dr_is_production "app/x.py"
ok dr_is_production "src/x.ts"
ok dr_is_production "crates/c/src/x.rs"
ok dr_is_production "cmd/server/main.go"   # Go cmd/ entrypoint layout
ok dr_is_production "internal"             # bare production-dir token (e.g. a Grep path)
# not production: tests, docs, config
no dr_is_production "internal/foo_test.go"
no dr_is_production "README.md"
no dr_is_production "config/app.yaml"
no dr_is_production "docs/x.md"

# opt-out + enabled flag via .dev-rules.json (guards the jq-false trap)
CFG="$(mktemp -d)"; export CLAUDE_PROJECT_DIR="$CFG"
printf '%s' '{"enabled":false}' > "$CFG/.dev-rules.json"
no dr_enabled                       # enabled:false must DISABLE gating
printf '%s' '{"enabled":true}'  > "$CFG/.dev-rules.json"
ok dr_enabled                       # explicit true keeps gating on
rm -f "$CFG/.dev-rules.json"
ok dr_enabled                       # absent config defaults to enabled
rm -rf "$CFG"; unset CLAUDE_PROJECT_DIR

exit $fail
