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

# Malformed / empty stdin: nothing to inspect -> allow cleanly (never crash on a
# jq parse error). Claude Code always sends valid JSON; this is belt-and-braces.
printf '%s' "$input" | jq -e . >/dev/null 2>&1 || exit 0

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
                 # ">"[!&] catches file redirects (> >> >file) but NOT 2>&1 / &> -- so a
                 # read that merely redirects stderr is not misclassified as a write.
    case "$c" in
      *">"[!\&]*|*" sed -i"*|*" tee "*|*" dd "*)
        intent="write"
        # Normalize: replace > with a space so tight redirects like "echo x>file"
        # split into separate whitespace-delimited tokens for hits_prod scanning.
        target="$(printf '%s' "$cmd" | tr '>' ' ')" ;;
      *" grep "*|*" rg "*|*" cat "*|*" sed "*|*" awk "*|*" head "*|*" tail "*|*" less "*|*" nl "*) intent="read"; target="$cmd" ;;
      *) exit 0 ;;
    esac ;;
  *) exit 0 ;;
esac
[ -n "$target" ] || exit 0

# Production implicated (and not a test file)?
prod_touched=""
for tok in $target; do
  if dr_is_production "$tok"; then prod_touched="yes"; break; fi
done
[ -n "$prod_touched" ] || exit 0

deny() {
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
