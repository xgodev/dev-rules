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
# not production: tests, docs, config
no dr_is_production "internal/foo_test.go"
no dr_is_production "README.md"
no dr_is_production "config/app.yaml"
no dr_is_production "docs/x.md"

exit $fail
