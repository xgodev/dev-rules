# dev-rules — Design

**Status:** Approved (design); pending spec review
**Date:** 2026-05-18
**Repo:** new public `github.com/xgodev/dev-rules` (Claude Code plugin)

## 1. Purpose

A single **macro, language-agnostic engineering-discipline skill**. It
encodes how to write/edit/refactor code well in **any** language —
methodology and decision rules a mechanical gate cannot measure. It is the
companion to `xgodev/quality-gate`: the gate catches metric regressions;
`dev-rules` governs the decisions the gate cannot see (coupling, ownership,
honesty of failure, TDD order, docs sync).

Origin: generalized from the battle-tested OpenRig POC
(`openrig-code-quality/SKILL.md`, 499 lines), stripped of all
OpenRig/Rust/Slint/gh-milestone/translation/Command-parity/Responsive-UI
specifics, plus the cross-cutting LAWs learned the expensive way in the
quality-gate work.

Effectiveness is the goal, not coverage. This is a **discipline-enforcing**
skill (rigid, not adaptable): concise, high signal density, with explicit
rationalization counters and red flags, validated against subagents under
pressure (RED-GREEN-REFACTOR). A passive wall of text that agents skim and
ignore is a failure.

## 2. Repo & plugin

```
dev-rules/
├── .claude-plugin/
│   ├── plugin.json          # name "dev-rules", version 0.1.0
│   └── marketplace.json     # marketplace "dev-rules", plugin "dev-rules", source "./"
├── skills/
│   └── dev-rules/
│       └── SKILL.md         # the single macro skill (format A: dense, all inline)
├── CLAUDE.md                # governance (English-only, docs-always-synced, etc.)
├── CHANGELOG.md             # ## [0.1.0]
└── README.md                # what it is, install, update, auto-update
```

- Public, English only, everywhere (docs + skill body).
- Self-contained plugin; no runtime clone; skills under `skills/` (plugin
  convention, confirmed via official docs — never `.claude/skills/`).
- CLAUDE.md carries the same hard rules as the other xgodev repos
  (English-only; docs-always-synced same commit; 3-file version discipline:
  `plugin.json` + CHANGELOG (+ README version line if present); ASCII
  identifiers, `--` not em-dash; never guess Claude Code specifics).

## 3. The skill — `skills/dev-rules/SKILL.md`

### Frontmatter

- `name: dev-rules`
- `description`: third-person, "Use when..."; triggers on writing, editing,
  or refactoring code in **any** language — applied **before** writing, not
  after; not a passive reference. English only. No workflow summary in the
  description (per writing-skills CSO).

### Body (format A — single dense file, inline; target 150–250 lines)

1. **Overview** — one paragraph: what this is, core principle ("apply before
   writing; the gate measures the mechanical, this governs the decisions it
   cannot").
2. **STOP — Check Before You Code** (scannable checklist, language-agnostic):
   - Data Ownership — info defined in its owner, not inferred/duplicated; no
     type/brand decisions from string matching.
   - Separation of Concerns — business logic vs presentation/config; visual
     or env config never inside business modules.
   - Zero Coupling — no references to specific concrete IDs/brands; adding a
     new case must not require editing unrelated files; no consumer knowing
     producers' internals.
   - Single Source of Truth — a value lives in exactly one place; string in
     2+ places → extract a constant; no literals in comparisons.
   - Naming — intent-revealing; no encoded type prefixes leaking
     implementation; consistent across the codebase.
   - No Trash — no dead/commented code, no legacy aliases, no workarounds;
     rename → update ALL references.
   - Impact Analysis — before a change, list what depends on it (build
     scripts, callers, config, data files) and verify each.
   - Safe Refactoring — one concern per commit; after changing a
     struct/signature update ALL constructors/callers; verify before commit.
   - One Responsibility Per File — if you can describe a file with "and", it
     does too much; module entrypoints are re-exports only; a match/if that
     grows with every new case → split.
3. **LAWs (non-negotiable, language-agnostic):**
   - **RED-first TDD** — write the failing test that proves the
     bug/validates the feature; run it, see it fail; only then production
     code. No "test after". Applies to "trivial" fixes too.
   - **Docs always synced** — any change to behavior/API/structure/version
     updates its docs in the **same commit**. A doc that lies is a defect.
   - **Verify before claiming done** — run the verifying command and read
     the evidence before saying fixed/passing/complete. Assertion without
     evidence is forbidden.
   - **No silent fallback / no masking** — an honest, actionable error beats
     a silent substitution that produces a different result; never mask an
     infra/tool failure as a code problem.
   - **No skipped tests to go green** — never ignore/skip/xfail a test to
     pass a gate; root-cause or escalate.
4. **Communication** — answers short; problem before solution; no preface,
   no trailing recap; expand only if asked.
5. **Rationalizations table** — `| Excuse | Reality |` populated from the RED
   phase (real verbatim rationalizations captured from subagents under
   pressure), not invented.
6. **Red Flags — STOP** — first-person thoughts that mean you are about to
   violate a rule ("I'll add the test after", "this is too simple to test",
   "I'll just infer it from the name", "I'll fix the doc later", "it
   probably passes"). Each maps to the rule it warns about.
7. **Living Document** — when the user corrects a methodology mistake, add
   the rule/anti-pattern here in the **same turn**, before closing.

### Out of scope (explicitly removed from the POC)

OpenRig issue/milestone gh rules, translation catalogs, Command/GUI/MCP/gRPC
parity, Responsive UI/Slint, Rust `#[ignore]` (generalized to "no skipped
tests"), YAML data-file rules, gitflow `.solvers/issue-N`, the OpenRig
validation process, references to rust-/slint-best-practices, any
project/company-specific names.

## 4. Effectiveness method (RED-GREEN-REFACTOR — mandatory)

Per `superpowers:writing-skills`. The SKILL.md is NOT written from
imagination:

1. **RED** — define 3+ combined-pressure scenarios (time + sunk cost +
   authority + exhaustion) across multiple languages. Run them with
   subagents **without** the skill. Capture exact rationalizations and which
   rules get violated.
2. **GREEN** — write SKILL.md addressing those specific
   violations/rationalizations (populate the table and red flags with the
   real ones).
3. **REFACTOR** — re-run; for every new loophole add an explicit counter;
   iterate until compliance is stable. Document residual gaps in a "Known
   limitations" section rather than infinite-looping.

Success criterion: a subagent under maximum pressure, in a language not
mentioned in the skill, still follows the rules.

## 5. Relationship to quality-gate

Complementary, not overlapping. `quality-gate` = mechanical metric
regression (fmt/lint/build/test/complexity/coverage), tamper-resistant,
runs in CI/local. `dev-rules` = the judgment the gate cannot measure
(ownership, coupling, honesty, TDD order, docs sync). The skill states this
boundary explicitly so the two are used together, not confused.

## 6. Build sequence (for the plan)

1. Repo skeleton + `.claude-plugin/{plugin.json,marketplace.json}` +
   `CLAUDE.md` + `README.md` + `CHANGELOG.md` (English).
2. RED: pressure scenarios + subagent baseline (multi-language).
3. GREEN: write `skills/dev-rules/SKILL.md` from the captured failures.
4. REFACTOR: re-test, close loopholes, finalize tables/red-flags.
5. Verify: English-only sweep, zero internal refs, plugin JSON valid, docs
   synced, version 0.1.0 consistent.
6. Create public `xgodev/dev-rules`, push.
7. (Optional, separate change) add `dev-rules@dev-rules` as a dependency of
   `xgodev/claude-plugin` so the umbrella offers it too.

## 7. Open decisions deliberately closed

- Format A (single dense file) — chosen by the user.
- Lives in its own plugin `xgodev/dev-rules` — chosen by the user.
- Scope = generalized OpenRig core + session LAWs — chosen by the user.
- Name `dev-rules`, trigger = before writing/editing/refactoring any code —
  proposed; user may rename in spec review.
