# Spec-Driven Flow LAW + Language-Agnostic Enforcement Hooks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add LAW 13 (spec-driven flow: brainstorming -> bug:RED / feature:plan -> code) to the `dev-rules` skill, and ship the plugin's first hooks -- a language-agnostic, mode-aware RED-first guard plus a commit re-armer -- so the discipline is enforced deterministically across every project, in any language.

**Architecture:** Two bash hooks shipped under `hooks/`, wired by `hooks/hooks.json` with `${CLAUDE_PLUGIN_ROOT}`. A shared `hooks/lib/detect.sh` does production-vs-test path detection (built-in heuristic + optional `.dev-rules.json` override). The guard is a sentinel-driven state machine rooted at `$CLAUDE_PROJECT_DIR/.dev-rules/`: no sentinel = bug discipline (read+edit of production blocked); `.mode-feature` = reads allowed for planning, edits still blocked; `.red-first-unlocked` = both allowed. `clear-after-commit.sh` wipes both sentinels on a cycle-closing commit. Plan-first is enforced as LAW text + the brainstorming/writing-plans skills, NOT a hard hook (a hook cannot tell a bug from a feature pre-commit).

**Tech Stack:** POSIX-ish bash, `jq` (required at runtime; hooks degrade to warn+allow if absent). Tests are plain bash assertion scripts that pipe hook-input JSON to a script and grep its stdout -- zero test-framework dependency.

## Global Constraints

Copied verbatim from the repo's `CLAUDE.md` and the approved spec; every task inherits these.

- **English only, everywhere** (skill, docs, comments, identifiers, commit messages). Run a Portuguese sweep (accented chars + PT word stems) before any commit; it must be empty.
- **Docs always synced, SAME commit** as the behavior change (README, CHANGELOG, SKILL.md).
- **3-file version discipline:** bump `.claude-plugin/plugin.json` `version`, `CHANGELOG.md`, and the README version line *if one exists* -- in lockstep. This change is a new capability => **0.5.0 -> 0.6.0 (minor)**.
- **ASCII identifiers; `--` not em-dash.** No accented chars in code/file names/shell examples. Prose uses `--`.
- **Never guess Claude Code specifics.** Verified: plugin hooks live in `hooks/hooks.json`; command path var is `${CLAUDE_PLUGIN_ROOT}`; the project root inside a hook is `$CLAUDE_PROJECT_DIR`; PreToolUse deny shape is `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"..."}}`; stdin carries `tool_name`, `tool_input`, `tool_response`.
- **Plugin layout:** skills in `skills/`, hooks in `hooks/`. Do NOT create `.claude/skills/`.
- **Dogfood note:** the `dev-rules` repo does not wire these hooks into its own `.claude/`, so development is not self-blocked. This change still follows the repo flow: branch first; this plan IS the `writing-plans` output of a feature; each hook task is test-first per LAW 1.

---

## Task 0: Branch

- [ ] **Step 1: Create the feature branch**

```bash
cd /Users/joao.faria/Projetos/github.com/xgodev/dev-rules
git checkout -b feat/spec-driven-flow-and-redfirst-hooks
```

---

## Task 1: `hooks/lib/detect.sh` -- production-vs-test path detection

**Files:**
- Create: `hooks/lib/detect.sh`
- Test: `hooks/test/detect_test.sh`

**Interfaces:**
- Consumes: optional `$CLAUDE_PROJECT_DIR/.dev-rules.json`, `jq` (optional).
- Produces (sourced by callers): `dr_enabled` (0 if gating on), `dr_is_test_file PATH` (0 if test), `dr_is_production PATH` (0 if gated production source). Built-in production segments: `src lib app internal pkg crates domain`.

- [ ] **Step 1: Write the failing test**

Create `hooks/test/detect_test.sh`:

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash hooks/test/detect_test.sh`
Expected: FAIL -- `detect.sh` does not exist yet (source error / functions undefined).

- [ ] **Step 3: Write minimal implementation**

Create `hooks/lib/detect.sh`:

```bash
#!/usr/bin/env bash
# dev-rules: language-agnostic production-vs-test path detection.
# Sourced by the gate hooks. Reads optional .dev-rules.json at the project
# root ($CLAUDE_PROJECT_DIR); otherwise uses built-in defaults. Best-effort
# and tunable per-repo via .dev-rules.json (see README).

DR_DEFAULT_PROD_SEGMENTS="src lib app internal pkg crates domain"

# dr_config <jq-filter> <default> -- read a key from .dev-rules.json if present.
dr_config() {
  local filter="$1" default="$2" cfg="${CLAUDE_PROJECT_DIR:-.}/.dev-rules.json"
  if [ -f "$cfg" ] && command -v jq >/dev/null 2>&1; then
    # NOTE: do NOT use `// empty` here -- jq's `//` treats a JSON `false`
    # as absent, which would break the `enabled:false` opt-out. Filter for
    # null on the shell side instead.
    local v; v="$(jq -r "$filter" "$cfg" 2>/dev/null)"
    [ -n "$v" ] && [ "$v" != "null" ] && { printf '%s' "$v"; return; }
  fi
  printf '%s' "$default"
}

dr_enabled() { [ "$(dr_config '.enabled' 'true')" != "false" ]; }

# Translate '**' to '*' and match with bash [[ == ]].
dr_glob_match() { local p="$1" g="${2//\*\*/\*}"; [[ "$p" == $g ]]; }

dr_is_test_file() {
  case "$1" in
    *_test.*|*_tests.*|*.test.*|*.spec.*|*_spec.rb|*_tests.rs) return 0 ;;
    tests/*|test/*|__tests__/*|spec/*) return 0 ;;
    */tests/*|*/test/*|*/__tests__/*|*/spec/*|*conftest.py) return 0 ;;
  esac
  local g
  while IFS= read -r g; do
    [ -n "$g" ] && dr_glob_match "$1" "$g" && return 0
  done <<EOF
$(dr_config '.test_globs[]?' '')
EOF
  return 1
}

dr_is_docs_or_config() {
  case "$1" in
    *.md|*.markdown|*.json|*.yaml|*.yml|*.toml|*.txt|*.lock) return 0 ;;
    .github/*|docs/*|.dev-rules/*|*/.github/*|*/docs/*|*/.dev-rules/*) return 0 ;;
  esac
  return 1
}

dr_is_production() {
  local path="$1"
  dr_is_test_file "$path" && return 1
  dr_is_docs_or_config "$path" && return 1
  # Explicit production_globs in config win exclusively when present.
  local g had_cfg=1
  while IFS= read -r g; do
    if [ -n "$g" ]; then had_cfg=0; dr_glob_match "$path" "$g" && return 0; fi
  done <<EOF
$(dr_config '.production_globs[]?' '')
EOF
  [ "$had_cfg" = 0 ] && return 1
  # Built-in default: a known production segment appears in the path.
  local seg
  for seg in $DR_DEFAULT_PROD_SEGMENTS; do
    case "$path" in "$seg"/*|*/"$seg"/*) return 0 ;; esac
  done
  return 1
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash hooks/test/detect_test.sh`
Expected: PASS -- every line prints `ok`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add hooks/lib/detect.sh hooks/test/detect_test.sh
git commit -m "feat(hooks): language-agnostic production-vs-test detection lib"
```

---

## Task 2: `hooks/red-first-guard.sh` -- mode-aware RED-first gate

**Files:**
- Create: `hooks/red-first-guard.sh`
- Test: `hooks/test/red_first_guard_test.sh`

**Interfaces:**
- Consumes: stdin hook JSON (`tool_name`, `tool_input`, `cwd`), `$CLAUDE_PROJECT_DIR`, `hooks/lib/detect.sh`. Sentinels under `$CLAUDE_PROJECT_DIR/.dev-rules/`.
- Produces: stdout PreToolUse JSON; `permissionDecision:"deny"` when blocked, nothing (exit 0) when allowed.

- [ ] **Step 1: Write the failing test**

Create `hooks/test/red_first_guard_test.sh`:

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash hooks/test/red_first_guard_test.sh`
Expected: FAIL -- `red-first-guard.sh` does not exist (script not found / no deny output).

- [ ] **Step 3: Write minimal implementation**

Create `hooks/red-first-guard.sh`:

```bash
#!/usr/bin/env bash
# dev-rules RED-first + mode-aware read gate (language-agnostic).
# Plugin hook: it runs from the plugin cache, so the PROJECT root comes from
# $CLAUDE_PROJECT_DIR, never BASH_SOURCE.
#
# Sentinels under $CLAUDE_PROJECT_DIR/.dev-rules/ (also honored under
# .solvers/*/.dev-rules/ for isolated-workspace flows):
#   none               -> bug discipline: production READ and EDIT blocked.
#   .mode-feature      -> production READ allowed (planning); EDIT still blocked.
#   .red-first-unlocked-> production READ and EDIT allowed.
# Test files, docs, config: never blocked.
set -euo pipefail

input="$(cat)"

# Degrade gracefully if jq is missing: cannot inspect the call -> allow + warn.
if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","additionalContext":"dev-rules gate skipped: jq not found on PATH (install jq to enable RED-first enforcement)."}}'
  exit 0
fi

tool="$(printf '%s' "$input" | jq -r '.tool_name // empty')"
proj="${CLAUDE_PROJECT_DIR:-$(printf '%s' "$input" | jq -r '.cwd // "."')}"

. "$(dirname "${BASH_SOURCE[0]}")/lib/detect.sh"
dr_enabled || exit 0

sentinel() {
  [ -f "$proj/.dev-rules/$1" ] && return 0
  ls "$proj"/.solvers/*/.dev-rules/"$1" >/dev/null 2>&1 && return 0
  return 1
}
red_unlocked() { sentinel ".red-first-unlocked"; }
feature_mode() { sentinel ".mode-feature"; }

# Classify intent (read vs write) and gather the target path(s).
intent="read"; target=""
case "$tool" in
  Read)  target="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')" ;;
  Grep|Glob) target="$(printf '%s' "$input" | jq -r '(.tool_input.path // "") + " " + (.tool_input.glob // "")')" ;;
  Edit|Write) intent="write"; target="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')" ;;
  Bash)
    cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
    c=" $cmd "   # pad so a leading/trailing command token still matches the spaced arms;
                 # ">"[!\&] matches file redirects (> >> >file) but NOT 2>&1 / &> -- the &
                 # MUST be escaped (bash 3.2 errors on an unescaped & in a case bracket).
    case "$c" in
      *">"[!\&]*|*" sed -i"*|*" tee "*|*" dd "*)
        intent="write"
        # tr > to space so tight redirects ("echo x>file") split into scannable tokens.
        target="$(printf '%s' "$cmd" | tr '>' ' ')" ;;
      *" grep "*|*" rg "*|*" cat "*|*" sed "*|*" awk "*|*" head "*|*" tail "*|*" less "*|*" nl "*) intent="read"; target="$cmd" ;;
      *) exit 0 ;;
    esac ;;
  *) exit 0 ;;
esac
[ -n "$target" ] || exit 0

# Production implicated (and not a test file)?
hits_prod=1
for tok in $target; do
  if dr_is_production "$tok"; then hits_prod=0; break; fi
done
[ "$hits_prod" = 0 ] || exit 0

deny() {
  # -c: compact one-line JSON (the hook output format; also what the tests grep)
  jq -nc --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

if [ "$intent" = "write" ]; then
  red_unlocked && exit 0
  deny "RED-first (dev-rules LAW 1): no production EDIT before a failing test exists. Brainstorm the problem, write the test that encodes the INTENDED behavior, run it, SEE it fail (RED), then create .dev-rules/.red-first-unlocked and proceed."
else
  red_unlocked && exit 0
  feature_mode && exit 0
  deny "Read-locked (dev-rules LAW 13): choose a flow first. BUG: brainstorm with the user and write the failing test from the intended behavior BEFORE reading the code (reading the buggy code first contaminates the oracle), then create .dev-rules/.red-first-unlocked. FEATURE/IMPROVEMENT: after brainstorming, create .dev-rules/.mode-feature to read code for planning."
fi
```

- [ ] **Step 4: Run test to verify it passes**

Run: `chmod +x hooks/red-first-guard.sh && bash hooks/test/red_first_guard_test.sh`
Expected: PASS -- all six assertions print `ok`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add hooks/red-first-guard.sh hooks/test/red_first_guard_test.sh
git commit -m "feat(hooks): mode-aware language-agnostic RED-first guard"
```

---

## Task 3: `hooks/clear-after-commit.sh` -- re-arm gates on cycle-closing commit

**Files:**
- Create: `hooks/clear-after-commit.sh`
- Test: `hooks/test/clear_after_commit_test.sh`

**Interfaces:**
- Consumes: stdin PostToolUse JSON (`tool_name`=="Bash", `tool_input.command`, `tool_response.exit_code`), `$CLAUDE_PROJECT_DIR`.
- Produces: removes `$CLAUDE_PROJECT_DIR/.dev-rules/.red-first-unlocked` and `.mode-feature` (plus `.solvers/*` copies) on a successful `fix(`/`feat(`/`bugfix(`/`Fix #`/`Fixes #` commit; emits a re-armed `additionalContext` note.

- [ ] **Step 1: Write the failing test**

Create `hooks/test/clear_after_commit_test.sh`:

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash hooks/test/clear_after_commit_test.sh`
Expected: FAIL -- script does not exist; sentinels remain or script not found.

- [ ] **Step 3: Write minimal implementation**

Create `hooks/clear-after-commit.sh`:

```bash
#!/usr/bin/env bash
# dev-rules: re-arm the gates after a cycle-closing commit. PostToolUse/Bash.
# Idempotent: a missing sentinel is a no-op; a failed commit never clears.
set -euo pipefail

input="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0
tool="$(printf '%s' "$input" | jq -r '.tool_name // empty')"
[ "$tool" = "Bash" ] || exit 0

cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
case "$cmd" in *"git commit"*) ;; *) exit 0 ;; esac

# Tolerate exit_code / exitCode / success; a missing field means success.
# Do NOT use jq `//` here: it treats a JSON `false` (a FAILED commit reported
# as {"success":false}) as absent, which would wrongly clear on failure.
exit_code="$(printf '%s' "$input" | jq -r '
  if   .tool_response.exit_code != null then .tool_response.exit_code
  elif .tool_response.exitCode  != null then .tool_response.exitCode
  elif .tool_response.success   != null then (if .tool_response.success then 0 else 1 end)
  else 0 end | tostring')"
case "$exit_code" in 0) ;; *) exit 0 ;; esac

# Only commits that close a TDD cycle re-arm; chore/docs do not. The match is
# substring (intentionally broad): any of these appearing in the command counts.
case "$cmd" in *"fix("*|*"feat("*|*"bugfix("*|*"Fix #"*|*"Fixes #"*) ;; *) exit 0 ;; esac

proj="${CLAUDE_PROJECT_DIR:-$(printf '%s' "$input" | jq -r '.cwd // "."')}"
removed=0
for name in .red-first-unlocked .mode-feature; do
  for f in "$proj/.dev-rules/$name" "$proj"/.solvers/*/.dev-rules/"$name"; do
    [ -f "$f" ] && { rm -f "$f"; removed=$((removed + 1)); }
  done
done

if [ "$removed" -gt 0 ]; then
  jq -nc --arg n "$removed" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:("dev-rules gates re-armed: cleared \($n) sentinel(s) after commit. Next cycle must re-brainstorm and write a fresh failing test.")}}'
fi
exit 0
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash hooks/test/clear_after_commit_test.sh`
Expected: PASS -- three `ok` lines, exit 0.

- [ ] **Step 5: Commit**

```bash
git add hooks/clear-after-commit.sh hooks/test/clear_after_commit_test.sh
git commit -m "feat(hooks): clear-after-commit re-armer for both gate sentinels"
```

---

## Task 4: `hooks/hooks.json` + SKILL.md LAW + docs + version bump (ONE commit)

This task makes the behavior live (wires the hooks) and therefore carries ALL docs and the version bump in the same commit, per the docs-synced LAW and 3-file version discipline.

**Files:**
- Create: `hooks/hooks.json`
- Modify: `skills/dev-rules/SKILL.md` (sharpen LAW 1; add LAW 13; add Red Flags, a Rationalization row, a Known-limitation)
- Modify: `README.md` (new "Enforcement hooks" section; bump version line if one exists)
- Modify: `CHANGELOG.md` (0.6.0 entry)
- Modify: `.claude-plugin/plugin.json` (`version` 0.5.0 -> 0.6.0; extend description)
- Test: `hooks/test/hooks_json_test.sh`

**Interfaces:**
- Consumes: the three scripts from Tasks 1-3 by relative path under `${CLAUDE_PLUGIN_ROOT}/hooks/`.
- Produces: a valid plugin hooks manifest wiring PreToolUse(`Read|Grep|Glob|Bash|Edit|Write`) -> guard and PostToolUse(`Bash`) -> re-armer.

- [ ] **Step 1: Write the failing test (manifest validity + wiring)**

Create `hooks/test/hooks_json_test.sh`:

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash hooks/test/hooks_json_test.sh`
Expected: FAIL -- `hooks.json` does not exist.

- [ ] **Step 3a: Create `hooks/hooks.json`**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read|Grep|Glob|Bash|Edit|Write",
        "hooks": [
          { "type": "command", "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/red-first-guard.sh\"" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/clear-after-commit.sh\"" }
        ]
      }
    ]
  }
}
```

- [ ] **Step 3b: Sharpen LAW 1 in `skills/dev-rules/SKILL.md`**

In LAW 1, replace the final sentence `Applies to "trivial" fixes too.` with:

```
Applies to "trivial" fixes too. For a BUG you understand the problem from the
spec and the user (brainstorming) and write the test from the INTENDED
behavior -- you do NOT read the production code first, because anchoring on
what the buggy code does contaminates the oracle (LAW 11). Read the
implementation only after the test is RED. This flow is LAW 13.
```

- [ ] **Step 3c: Add LAW 13** at the end of the numbered LAWs list in `skills/dev-rules/SKILL.md` (after LAW 12):

```
13. **Spec-driven flow: understand before you encode.** Every change starts
    with `brainstorming` -- lock the problem and the intended behavior WITH the
    user before touching production code. Then the path forks. A **bug** goes
    brainstorming -> RED (write the failing test from the intended behavior,
    run it, see it fail) -> only THEN read the implementation and fix. A
    **feature/improvement** goes brainstorming -> `writing-plans` ->
    `executing-plans` (a fresh RED per unit before that unit's code). "I'll
    just code it, it's small" is the failure mode this LAW stops -- no
    triviality exception, same as LAW 1; the brainstorm can be three sentences
    and the plan three bullets, but understanding must precede code. The plugin
    ships hooks that enforce the ORDER deterministically: production code is
    read-locked until you declare the feature flow (`.dev-rules/.mode-feature`)
    or a failing test exists (`.dev-rules/.red-first-unlocked`), and production
    EDITS are blocked until the test exists; a cycle-closing `fix(`/`feat(`
    commit re-arms both. The gates prove order and existence, never quality --
    a sound plan and a meaningful test stay your job (and the reviewer's).
```

- [ ] **Step 3d: Add Red Flags** -- insert into the "Red Flags -- STOP" list:

```
- "Let me go straight to the [buggy function/block] and see what it does" ->
  LAW 13 (both baseline agents said exactly this -- "go straight to the coupon
  branch"; diagnosing from the code first anchors your oracle on what the code
  DOES, not what it should do -- read the implementation only after the test is
  RED).
- "I traced/verified it mentally, the fix is obviously right, no failing test
  needed" -> LAW 13 + LAW 1 (a baseline agent shipped after "verify mentally
  before shipping"; a mental trace is not a RED and it came from the suspect
  code, not the intended behavior).
- "I'll just start coding, the brainstorm/plan is obvious" -> LAW 13 (every
  change starts with brainstorming; bug -> RED, feature -> writing-plans).
```

- [ ] **Step 3e: Add three Rationalization rows** to the table (grounded in the
  RED baseline run -- the quoted phrases are from real agent output, not invented):

```
| "The bug report points right at the [suspect] code -- I'll go straight there and read it, I get it in 30 seconds" | Reading the production code first makes your test assert what the code DOES, not what it SHOULD do. Both baseline agents went "straight to the coupon branch" and derived the expected value from the code they had just read. Lock the intended behavior WITH the user, encode it as a failing test, and open the implementation only after RED. |
| "I traced it by hand and verified mentally, the fix is obviously correct -- a failing test is ceremony here" | Mental verification is not a RED (LAW 1), and the trace came from the suspect code, not the spec. A baseline agent shipped a fix having only "verified mentally" -- that is confidence, not evidence (LAW 3). |
| "Brainstorming/a plan is ceremony for something this small" | The smallest changes are where unexamined assumptions waste the most work. The brainstorm can be three sentences and the plan three bullets, but understanding the intended behavior WITH the user must precede code. |
```

- [ ] **Step 3f: Add a Known-limitation** bullet:

```
- The flow gates (LAW 13) prove a plan/test exists and that you unlocked in
  order; they cannot judge whether the plan is sound or the test asserts the
  right behavior. They also cannot tell a feature from a bug -- you declare the
  flow by creating `.dev-rules/.mode-feature` (feature) or going straight to
  RED (bug). Reviewer judgment still required.
```

- [ ] **Step 3g: Add the "Enforcement hooks" section to `README.md`** (place after the install/update section):

```markdown
## Enforcement hooks (shipped with the plugin)

`dev-rules` ships language-agnostic hooks that fire in every project where the
plugin is enabled. They make LAW 1 (RED-first) and LAW 13 (spec-driven flow)
deterministic instead of advisory.

**Requirement:** `jq` on `PATH`. Without it the hooks degrade to warn + allow
(they never block when they cannot inspect the call).

**State machine** (sentinels live under `<project>/.dev-rules/`, also honored
under `.solvers/*/.dev-rules/`):

| Sentinel | Production READ | Production EDIT |
|---|---|---|
| none (bug default) | blocked | blocked |
| `.mode-feature` | allowed | blocked |
| `.red-first-unlocked` | allowed | allowed |

Test files, docs, and config are never blocked.

**Bug flow:** brainstorm with the user -> write the failing test (allowed) ->
see it RED -> `touch .dev-rules/.red-first-unlocked` -> read code and fix.

**Feature flow:** brainstorm -> `touch .dev-rules/.mode-feature` -> read code
and plan (`writing-plans`) -> per unit, write the failing test -> RED ->
`touch .dev-rules/.red-first-unlocked` -> write the code.

A `fix(`/`feat(`/`bugfix(` commit auto-clears both sentinels, so the next cycle
re-brainstorms and re-REDs.

**Per-repo config / opt-out (`.dev-rules.json` at the repo root):**

```json
{
  "enabled": true,
  "production_globs": ["src/**", "internal/**", "crates/**/src/**"],
  "test_globs": ["**/*_test.*", "**/tests/**", "**/*.spec.*"]
}
```

`"enabled": false` disables all gating for the project. Omit the file to use
built-in detection (production segments: `src lib app internal pkg crates
domain`, minus test/docs/config).
```

If `README.md` has an explicit version line (e.g. `Version: 0.5.0`), bump it to `0.6.0`; if none exists, skip (per the 3-file rule's "if one exists").

- [ ] **Step 3h: Add the CHANGELOG 0.6.0 entry** at the top of `CHANGELOG.md` (above `## [0.5.0]`):

```markdown
## [0.6.0]

### Added

- **LAW 13 -- Spec-driven flow: understand before you encode.** Every change
  starts with `brainstorming`; a bug then goes RED-first (test from the intended
  behavior, code read only after RED -- reading the buggy code first contaminates
  the oracle), a feature/improvement goes `writing-plans` -> `executing-plans`
  with a fresh RED per unit. LAW 1 sharpened to state the bug read-discipline.
- **The plugin now ships hooks** (`hooks/hooks.json` + scripts) -- its first
  deterministic, language-agnostic enforcement, fired in every project where the
  plugin is enabled:
  - `red-first-guard.sh` -- mode-aware gate. Production code is read-locked until
    `.dev-rules/.mode-feature` (feature flow) or `.dev-rules/.red-first-unlocked`
    exists; production edits are blocked until `.red-first-unlocked`. Test files,
    docs, and config are never blocked. Production-vs-test detection is a built-in
    heuristic overridable via `.dev-rules.json` (`enabled:false` opts out).
  - `clear-after-commit.sh` -- removes both sentinels after a `fix(`/`feat(`
    commit so the next cycle re-brainstorms and re-REDs.
  - Requires `jq`; degrades to warn + allow when absent.

### Notes

- The OpenRig-specific red-first hook is superseded by this generic one; removing
  it from OpenRig and adding an OpenRig `.dev-rules.json` is a separate follow-up
  in that repo (see the spec, section 8).
```

- [ ] **Step 3i: Bump `.claude-plugin/plugin.json`**

Change `"version": "0.5.0"` to `"version": "0.6.0"`, and extend `description` to end with: `...and concurrency-first design. Ships language-agnostic RED-first enforcement hooks.`

- [ ] **Step 4: Verify -- run every hook test, validate manifest, ASCII + Portuguese sweeps**

```bash
for t in hooks/test/*.sh; do echo "== $t"; bash "$t" || { echo "TEST FAILED: $t"; break; }; done
jq -e . hooks/hooks.json >/dev/null && echo "hooks.json valid"
jq -e '.version=="0.6.0"' .claude-plugin/plugin.json >/dev/null && echo "version 0.6.0"
# ASCII / em-dash + Portuguese sweep over the shipped files (must print nothing):
LC_ALL=C grep -nRP '[^\x00-\x7F]' hooks skills/dev-rules/SKILL.md README.md CHANGELOG.md .claude-plugin/plugin.json || echo "ASCII clean"
grep -nRiE '\b(nao|voce|funcao|codigo|teste falha|proibido|usuario)\b' hooks skills/dev-rules/SKILL.md README.md CHANGELOG.md || echo "PT sweep clean"
```

Expected: every `hooks/test/*.sh` prints only `ok` lines and exits 0; `hooks.json valid`; `version 0.6.0`; `ASCII clean`; `PT sweep clean`.

- [ ] **Step 5: Commit (single commit -- behavior + docs + version)**

```bash
git add hooks/hooks.json hooks/test/hooks_json_test.sh skills/dev-rules/SKILL.md README.md CHANGELOG.md .claude-plugin/plugin.json
git commit -m "feat(dev-rules): LAW 13 spec-driven flow + ship enforcement hooks (0.6.0)"
```

---

## Task 5: Cross-language acceptance matrix (verification only)

**Files:** none (uses the guard + a temp project root).

- [ ] **Step 1: Run the production-blocked / test-allowed matrix**

```bash
SBX="$(mktemp -d)"; export CLAUDE_PROJECT_DIR="$SBX"   # no sentinel => bug default
g() { printf '%s' "$2" | bash hooks/red-first-guard.sh; }
chk_deny() { g x "$2" | grep -q '"permissionDecision":"deny"' && echo "ok  : blocked $1" || echo "FAIL: should block $1"; }
chk_allow() { g x "$2" | grep -q '"permissionDecision":"deny"' && echo "FAIL: should allow $1" || echo "ok  : allowed $1"; }

chk_deny  "Go prod"   '{"tool_name":"Read","tool_input":{"file_path":"internal/x.go"}}'
chk_allow "Go test"   '{"tool_name":"Read","tool_input":{"file_path":"x_test.go"}}'
chk_deny  "Py prod"   '{"tool_name":"Read","tool_input":{"file_path":"app/x.py"}}'
chk_allow "Py test"   '{"tool_name":"Read","tool_input":{"file_path":"tests/test_x.py"}}'
chk_deny  "TS prod"   '{"tool_name":"Read","tool_input":{"file_path":"src/x.ts"}}'
chk_allow "TS test"   '{"tool_name":"Read","tool_input":{"file_path":"x.spec.ts"}}'
chk_deny  "Rust prod" '{"tool_name":"Read","tool_input":{"file_path":"crates/c/src/x.rs"}}'
chk_allow "Rust test" '{"tool_name":"Read","tool_input":{"file_path":"crates/c/src/x_tests.rs"}}'
rm -rf "$SBX"
```

Expected: all eight print `ok`.

- [ ] **Step 2: Verify opt-out**

```bash
SBX="$(mktemp -d)"; export CLAUDE_PROJECT_DIR="$SBX"
printf '%s' '{"enabled":false}' > "$SBX/.dev-rules.json"
printf '%s' '{"tool_name":"Read","tool_input":{"file_path":"internal/x.go"}}' | bash hooks/red-first-guard.sh \
  | grep -q '"permissionDecision":"deny"' && echo "FAIL: opt-out should disable gating" || echo "ok  : enabled:false disables gating"
rm -rf "$SBX"
```

Expected: `ok : enabled:false disables gating`.

---

## Follow-up (separate change, OpenRig repo -- NOT this PR)

Per spec section 8: once this ships and OpenRig enables the plugin, remove OpenRig's `.claude/hooks/red-first-guard.sh` + `clear-red-first-after-commit.sh` and their `settings.json` wiring, keep the OpenRig-specific guards, and add an OpenRig `.dev-rules.json` with `production_globs: ["crates/**/src/**"]` and Rust `test_globs`. Goes through OpenRig's own flow.

---

## Self-Review

1. **Spec coverage:** LAW 13 + LAW 1 sharpening (Task 4b/4c) <- spec section 0 / 4.1; `detect.sh` hybrid detection (Task 1) <- section 0 decision 2 / 4.2.1; `red-first-guard.sh` mode-aware (Task 2) <- section 0 hook 1 / 4.2.3; `clear-after-commit.sh` (Task 3) <- section 0 hook 2; `hooks.json` with `${CLAUDE_PLUGIN_ROOT}` (Task 4a) <- section 0 decision 5 / 4.2; README opt-out + sentinels (Task 4g) <- section 5 / 7; cross-language + opt-out matrix (Task 5) <- section 5; version bump 0.6.0 + docs (Task 4) <- section 5 self-application. No hard `plan-gate` -- dropped per section 0 (documented as the reversal of 4.2.3 item 1).
2. **Placeholder scan:** every code step contains complete, runnable content; no TBD/TODO.
3. **Type consistency:** function names `dr_enabled` / `dr_is_test_file` / `dr_is_production` and sentinel names `.mode-feature` / `.red-first-unlocked` are used identically across detect.sh, the guard, the re-armer, and the tests.
