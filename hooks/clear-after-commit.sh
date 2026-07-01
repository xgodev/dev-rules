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
