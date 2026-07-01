# Spec -- Spec-driven flow LAW + shippable enforcement hooks in `dev-rules`

**Date:** 2026-06-30
**Repo:** `github.com/xgodev/dev-rules` (currently v0.5.0)
**Status:** design APPROVED (post-review 2026-06-30) -- this addendum supersedes
the conflicting parts of sections 4 and 6 below.
**Author:** drafted for handoff to an implementing agent

---

## 0. Design update (post-review 2026-06-30) -- AUTHORITATIVE

Live review resolved the open decisions and reshaped the LAW/hook composition.
Where this section conflicts with sections 4 / 6, THIS section wins.

**The flow (universal entry, then a fork):**

- **Entry, every change:** `brainstorming` -- understand the problem WITH the
  user. No production-code reading yet. (Yes, a bug has brainstorming too.)
- **Bug:** brainstorming -> **RED** (write the failing test from the intended
  behavior, run it, see it fail) -> **only then** read the production code and
  fix (GREEN) -> commit. Reading the buggy code BEFORE the test is forbidden:
  anchoring on what the code does contaminates the oracle (ties to LAW 11).
- **Feature / improvement:** brainstorming -> `writing-plans` ->
  `executing-plans` (RED per unit before that unit's code) -> commit.

**LAWs:** RED-first stays **LAW 1** (sharpened: for a bug, no reading production
code until the test is RED). The flow is a NEW **LAW 13 -- "Spec-driven flow:
understand before you encode"** (appended; existing numbering unchanged to avoid
churning every cross-reference).

**Hooks shipped (only two -- a hard `plan-gate` is dropped; see why below):**

1. **`red-first-guard.sh`** -- mode-aware, language-agnostic. Plugin hook, so the
   project root is `$CLAUDE_PROJECT_DIR` (NOT `BASH_SOURCE` -- the script runs
   from the plugin cache). State machine on sentinels under
   `$CLAUDE_PROJECT_DIR/.dev-rules/` (also honored under
   `.solvers/*/.dev-rules/`):
   - no sentinel -> **bug discipline**: production READ and EDIT both blocked.
   - `.mode-feature` present -> production READ allowed (so brainstorming +
     `writing-plans` can read code to design); EDIT still blocked.
   - `.red-first-unlocked` present -> production READ and EDIT both allowed.
   - Test files, docs, config: never blocked.
2. **`clear-after-commit.sh`** -- PostToolUse/Bash. On a successful `fix(` /
   `feat(` / `bugfix(` / `Fix #` / `Fixes #` commit, remove BOTH `.mode-feature`
   and `.red-first-unlocked` (and `.solvers/*` copies) so the next cycle
   re-brainstorms and re-REDs.

**Why no hard `plan-gate` hook (reverses section 4.2.3 item 1):** a pre-commit
hook cannot tell a bug from a feature, so a hard plan-gate would either block
legitimate bug fixes or be redundant with red-first. `brainstorming` and
`writing-plans` are conversations, not file ops -- they are enforced as LAW 13 +
the skills themselves, not a deny-hook. The mode-aware read-lock IS the
deterministic enforcement, and it structurally forces the bug flow (you cannot
read the code before the test, so the test must come from the conversation).

**Resolved open decisions (section 6):** (1) no triviality carve-out for
feature/improvement/bug; pure chore/docs out of scope via the commit-prefix
filter. (2) hybrid detection: built-in heuristic + `.dev-rules.json` override +
`enabled:false` opt-out. (3) red-first gates ALL production changes; mode-feature
relaxes only READS for the feature flow. (4) `.dev-rules.json` config,
`.dev-rules/` sentinel dir, sentinels `.mode-feature` / `.red-first-unlocked`.
(5) confirmed against live docs: command path uses `${CLAUDE_PLUGIN_ROOT}`; the
script reads `$CLAUDE_PROJECT_DIR` for the project root.

**jq:** hooks require `jq`; if absent they degrade gracefully (warn + allow)
rather than bricking a project. Documented in the README.

---

## 1. Problem

`dev-rules` today enforces engineering discipline as **text only** (SKILL.md
LAWs). The one place a *deterministic* gate exists is **LAW 1 RED-first TDD**,
and that gate is a **hook that lives in the OpenRig repo**
(`.claude/hooks/red-first-guard.sh` + `clear-red-first-after-commit.sh`, wired in
OpenRig `.claude/settings.json`). That hook is **Rust/OpenRig-specific**
(hardcodes `crates/**/src/**/*.rs`, OpenRig wording, `.solvers/` paths). The
`dev-rules` plugin ships **no hooks at all**.

Two gaps follow:

1. **Discipline is only "test-first for bugs."** There is no enforced
   **plan-first** discipline for *features* and *improvements*. The intended
   flow -- `brainstorming -> writing-plans -> executing-plans` -- is not a LAW and
   is not gated. It is skipped under pressure (this spec exists because it was
   skipped).
2. **The deterministic enforcement is trapped in one project.** Because the
   red-first hook lives in OpenRig and is Rust-specific, every other project
   (any language) gets the *text* rule but **no gate**. The user wants the gate
   to **ship with `dev-rules`** so it applies cross-project, cross-language.

## 2. Goals

1. Add a **LAW** to `dev-rules` SKILL.md: for **every** change --
   feature **and** improvement **and** bug -- the work goes through
   `brainstorming -> writing-plans -> executing-plans` **before** production code
   is touched. (For a bug, this flow *contains* the existing RED-first step.)
2. Make `dev-rules` **ship its own hooks** (plugin `hooks/` manifest + scripts),
   **language-agnostic**, that deterministically enforce the discipline:
   - **plan-gate** -- block production-code edits until a plan is approved.
   - **red-first** -- generalised from OpenRig's: block production
     investigation/edit until a failing test exists.
   - **clear-after-commit** -- re-arm both gates after a cycle-closing commit.
3. **Relocate** the red-first enforcement OUT of OpenRig and INTO `dev-rules`
   (the user's explicit ask: "o hook de redfirst tem que ficar no dev-rules").

## 3. Non-goals

- No changes to `xgodev/quality-gate` (the mechanical gate stays orthogonal).
- No attempt to judge **semantic** adequacy of a test/plan -- the skill's
  existing "Known limitations" still hold; gates enforce *order and existence*,
  not *quality*.
- The OpenRig-side cleanup (removing its now-redundant hooks) is a **separate
  follow-up change in the OpenRig repo**, not part of the `dev-rules` PR. See section 8.

## 4. Design

### 4.1 SKILL.md -- the new LAW

Add a LAW (recommended: make it **LAW 1 "Plan-first for every change"** and
renumber RED-first to sit *under* it, since plan-first is the outer gate):

> **Plan-first for every change.** Before touching production code for ANY
> feature, improvement, or bug, the work goes through
> `brainstorming -> writing-plans -> executing-plans`: lock the spec and its
> verifiable criteria (brainstorming), write the plan (writing-plans), then
> execute against it. "I'll just code it, it's small" is the failure mode this
> LAW stops -- the same as RED-first, with no triviality exception. For a **bug**
> the flow CONTAINS the RED-first step (the failing test is part of executing
> the plan); they compose, they do not conflict.

Also add, mirroring the existing structure:
- A **Red Flags** entry: *"I'll just start coding, the plan is obvious" -> Plan-first LAW.*
- A **Rationalizations** row: *"Brainstorming/plan is ceremony for something this
  small" -> the smallest changes are where unexamined assumptions waste the most
  work; the plan can be three sentences, but it must exist and be approved.*
- A **Known limitations** note: the gate proves a plan/spec FILE exists and was
  marked approved; it cannot judge whether the plan is *good* -- reviewer
  judgment still required.

**Carve-out (DECISION 1, see section 6):** pure `chore`/`docs`/formatting commits (no
behavior change) are out of scope -- same boundary the clear-after-commit hook
already uses (`fix(` / `feat(` / `bugfix(` only).

### 4.2 Hooks shipped by the plugin

Add to the plugin:

```
dev-rules/
  hooks/
    hooks.json            # plugin hooks manifest (PreToolUse / PostToolUse)
    plan-gate.sh          # NEW: block prod edits until plan approved
    red-first-guard.sh    # PORTED + generalised from OpenRig
    clear-after-commit.sh # PORTED + generalised from OpenRig
    lib/detect.sh         # shared: is-this-production-code? (sourced by both)
```

Plugins can ship hooks via the plugin's `hooks/hooks.json` (same shape as a
project `settings.json` `hooks` block); they fire in every project where the
plugin is enabled. That is precisely the cross-project reach the user wants.

#### 4.2.1 The hard part -- language-agnostic "is this production code?"

OpenRig's hook keys off `crates/**/src/**/*.rs`. `dev-rules` is language-agnostic
and cannot. Strategy (**DECISION 2, see section 6 -- recommended: hybrid**):

- **Test-file allowlist (always permitted), cross-language heuristic:** paths
  matching any of `*_test.*`, `*_tests.*`, `*.test.*`, `*.spec.*`, `*_spec.rb`,
  `/tests/`, `/test/`, `/__tests__/`, `/spec/`, `conftest.py`, `*_tests.rs` ->
  treated as test code -> never blocked (so the RED test can always be written).
- **Production-source detection:** an optional per-repo config
  `.dev-rules.json` at the repo root:
  ```json
  {
    "production_globs": ["src/**", "lib/**", "app/**", "internal/**", "pkg/**", "crates/**/src/**"],
    "test_globs": ["**/*_test.*", "**/tests/**", "**/*.spec.*"],
    "enabled": true
  }
  ```
  If absent, fall back to a built-in default `production_globs` (the list above)
  minus the test allowlist, and excluding docs/config (`*.md`, `*.json`,
  `*.yaml`, `*.toml`, `.github/**`, etc.). `"enabled": false` (or empty
  `production_globs`) **fully disables** gating for a project -- the documented
  opt-out.
- Put this logic ONCE in `hooks/lib/detect.sh` (single source of truth), sourced
  by both `plan-gate.sh` and `red-first-guard.sh`.

#### 4.2.2 Sentinels + unlock flow

Mirror the proven red-first sentinel pattern, plugin-namespaced to avoid
clashing with a project's `.claude/`:

- `.dev-rules/.plan-approved` -- created after `writing-plans` produces an
  approved plan. Gate 1 (plan-gate) unlocks.
- `.dev-rules/.red-first-unlocked` -- created after the failing test is written,
  run, and seen RED. Gate 2 (red-first) unlocks.
- Both sentinels are also honored under `.solvers/*/.dev-rules/...` so the
  OpenRig isolated-workspace pattern keeps working.
- Order is enforced by composition: production edits need BOTH sentinels; the
  plan sentinel is the outer gate.

#### 4.2.3 The three hooks

1. **`plan-gate.sh`** -- PreToolUse on `Edit|Write` (and `Bash` writes) targeting
   **production code**: `deny` with a message pointing at
   `brainstorming -> writing-plans` until `.dev-rules/.plan-approved` exists.
   Test files, docs, config: always allowed.
2. **`red-first-guard.sh`** -- PreToolUse on `Read|Grep|Glob|Bash|Edit|Write`
   touching **production code**: `deny` until `.dev-rules/.red-first-unlocked`
   exists. This is the OpenRig script with its Rust regex replaced by
   `detect.sh`, its message de-OpenRig-ified, and its `.solvers/` handling kept.
   **DECISION 3 (see section 6):** does red-first gate apply to features too, or only
   bugs? Recommended: **yes, all production changes** (TDD wants a failing test
   before feature code as well) -- plan-gate is the broad outer gate, red-first
   the inner test-first gate; two sentinels, unlocked in order.
3. **`clear-after-commit.sh`** -- PostToolUse on `Bash`: after a successful
   commit whose message matches `fix(` / `feat(` / `bugfix(` / `Fix #` /
   `Fixes #`, remove BOTH sentinels (and the `.solvers/*` copies) so the next
   cycle must re-plan and re-RED. This is OpenRig's existing script extended to
   clear the new plan sentinel too.

`hooks.json` wiring (shape):
```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Edit|Write|Bash", "hooks": [{ "type": "command", "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/plan-gate.sh\"" }] },
      { "matcher": "Read|Grep|Glob|Bash|Edit|Write", "hooks": [{ "type": "command", "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/red-first-guard.sh\"" }] }
    ],
    "PostToolUse": [
      { "matcher": "Bash", "hooks": [{ "type": "command", "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/clear-after-commit.sh\"" }] }
    ]
  }
}
```
(Confirm the exact plugin-hook path variable -- `${CLAUDE_PLUGIN_ROOT}` or the
current equivalent -- against the Claude Code plugin-hooks docs at implementation
time. **DECISION 5, section 6.**)

## 5. Acceptance criteria (verifiable)

- **Plugin loads hooks:** with `dev-rules` enabled, the three hooks fire in a
  fresh project (no project-level `settings.json` needed).
- **plan-gate:** a `Write` to a production file is **denied** when
  `.dev-rules/.plan-approved` is absent; **allowed** once present.
- **red-first:** a `Read`/`Grep`/`Edit` of production code is **denied** without
  `.dev-rules/.red-first-unlocked`; **test files are always allowed**.
- **clear-after-commit:** a `feat(`/`fix(` commit removes both sentinels; a
  `docs(`/`chore(` commit does not.
- **Cross-language matrix** (production blocked / test allowed):
  - Go: `internal/x.go` blocked -- `x_test.go` allowed
  - Python: `app/x.py` blocked -- `tests/test_x.py` allowed
  - TS: `src/x.ts` blocked -- `x.spec.ts` allowed
  - Rust: `crates/c/src/x.rs` blocked -- `crates/c/src/x_tests.rs` allowed
- **Opt-out:** `.dev-rules.json` with `"enabled": false` disables all gating.
- **Self-application (LAW 2):** the change ships SKILL.md + README + CHANGELOG +
  `plugin.json` version bump (0.5.0 -> **0.6.0**, minor -- new feature) in the
  SAME commit. The `dev-rules` repo dogfoods the new flow for this very change.

## 6. Open decisions (confirm before implementing)

1. **Triviality carve-out** -- recommended: NO exception for feature/improvement/
   bug; only pure `chore`/`docs`/formatting are out of scope.
2. **Production-code detection** -- recommended: hybrid (built-in heuristic +
   `.dev-rules.json` override + `enabled:false` opt-out).
3. **Red-first scope** -- recommended: gate ALL production changes (features
   included), plan-gate outer + red-first inner, two ordered sentinels.
4. **Sentinel + config naming** -- recommended: `.dev-rules.json` config,
   `.dev-rules/` sentinel dir.
5. **Plugin-hook path variable** -- confirm `${CLAUDE_PLUGIN_ROOT}` vs current
   equivalent against the live plugin-hooks docs.

## 7. Risks

- **False positives** blocking edits in unusual layouts -> `.dev-rules.json`
  override + `enabled:false` escape hatch; document prominently.
- **Surprise blast radius** -- plugin hooks fire in EVERY project where
  `dev-rules` is enabled. Ship with loud README docs + the opt-out default
  behavior chosen conservatively (e.g., if no `.dev-rules.json` AND no obvious
  source layout, prefer warn-not-deny -- **revisit under DECISION 2**).
- **Sentinel drift** (left unlocked) -> clear-after-commit re-arms each cycle;
  document the reset.

## 8. Follow-up (separate change, OpenRig repo -- NOT this PR)

Once `dev-rules` ships the generic hooks and OpenRig enables the plugin:
- Remove OpenRig `.claude/hooks/red-first-guard.sh` +
  `clear-red-first-after-commit.sh` and their `settings.json` wiring.
- Keep OpenRig-specific guards (`main-folder-guard.sh`, `cap-guard.sh`).
- Add OpenRig `.dev-rules.json` with
  `production_globs: ["crates/**/src/**/*.rs"]`,
  `test_globs: ["**/*_test*.rs", "**/tests/**", "**/*test*.rs"]` to preserve the
  exact Rust precision the current hook has.
- This goes through OpenRig's own flow (issue -> `.solvers/issue-N` -> PR).

## 9. Implementation steps (for the implementing agent)

1. In `github.com/xgodev/dev-rules`, branch per the repo's own flow.
2. Write `hooks/lib/detect.sh` (production-vs-test detection, config-driven) --
   with a RED test first per the repo's own LAW 1 (dogfood).
3. Port `red-first-guard.sh` + `clear-after-commit.sh` from OpenRig, swap the
   Rust regex for `detect.sh`, de-OpenRig the messages, add plan-sentinel
   clearing.
4. Write `plan-gate.sh`.
5. Add `hooks/hooks.json`.
6. Update SKILL.md (new LAW + Red Flag + Rationalization + Known-limitation).
7. Update README (document `.dev-rules.json`, sentinels, unlock flow, opt-out) +
   CHANGELOG + bump `plugin.json` to 0.6.0 -- SAME commit.
8. Run the section 5 acceptance matrix.
9. Open the follow-up OpenRig issue from section 8 (do not implement it here).
