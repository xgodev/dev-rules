# Changelog

All notable changes to this plugin are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/) and the project adheres to
[Semantic Versioning](https://semver.org/).

## [0.6.1]

### Changed

- **Production detection now covers the `cmd/` entrypoint layout** and bare
  directory tokens. `cmd` is added to the default production segments (common in
  Go: `cmd/<name>/main.go`), and a bare segment token (e.g. a `Grep` with
  `path="internal"`) is now classed as production, not just `.../internal/...`.

### Fixed

- **`red-first-guard.sh` no longer crashes on malformed stdin.** Invalid/empty
  input is validated up front and results in a clean allow (exit 0) instead of a
  `jq` parse error (exit 5).
- **Docs now name the full set of cycle-closing commit patterns.** README and the
  LAW 13 text enumerate `fix(`/`feat(`/`bugfix(`/`Fix #`/`Fixes #` (the re-armer
  already honored all five; the docs had listed a subset).

### Internal

- Renamed the guard's production-hit flag to `prod_touched` (clearer than the
  inverted `hits_prod`); made hook entrypoint exec bits consistent
  (`clear-after-commit.sh` -> 0755, matching `red-first-guard.sh`).

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

## [0.5.0]

### Added

- **LAW 12 -- Concurrency is a premise, not an optimization.** Any system
  processing independent work items (jobs, events, requests, files, URLs) is
  designed AND shipped concurrent from line one: bounded worker pool or async
  fan-out, parallel-safe units, no shared mutable state, idempotent effects.
  A hard-coded sequential loop over independent items is a design defect;
  retrofitting concurrency onto a serial architecture is a rewrite, not a
  tune. The LAW explicitly refuses the trap observed in baseline pressure
  testing: a "concurrency-ready" design defaulted to 1 worker -- the
  non-default path is never exercised and rots, so the shipped default must
  be N > 1. Sequential execution is the exception and requires a stated,
  real constraint (ordering dependency, transactional invariant, upstream
  rate limit), implemented as bounded concurrency tuned down to 1, never as
  an architecture that assumes a single thread. Rationalization table and
  Red Flags updated with the baseline patterns ("concurrency now is
  premature optimization", "default to 1 worker, raising it later is just a
  config change", "concurrency adds untested failure modes").

## [0.4.0]

### Added

- **LAW 11 -- The test is the oracle; never edit it to match the bug.** A
  failing test is a finding, not an obstacle. Changing an assertion, expected
  value, input, or tolerance so a test passes against output you have not
  proven correct hides the defect the test caught. The discriminator: change a
  test to match the SPEC (with proof + its own RED), never to match the
  OUTPUT. Loosening `==` to `>=`, widening a tolerance, deleting an assert, or
  narrowing the input are the same forbidden act; reaching for skip/quarantine
  "to unblock" is the same crime under LAW 5. Rationalization table and Red
  Flags updated with the two patterns observed in baseline pressure testing
  ("just align `want` to what the code returns" and the incident-pressure
  `t.Skip` reflex).

### Fixed

- ASCII compliance sweep across the docs, per the repo's ASCII-only hard rule:
  the LAW 9 corollary in the skill body (em-dash -> `--`, `>=2` -> `>= 2`) and
  the historical `0.3.x` CHANGELOG entries (em-dashes and `->` arrows). Skill
  body and CHANGELOG are now non-ASCII-clean.

## [0.3.1]

### Added

- **LAW 3** now covers process teardown: when verification means launching a process (server/daemon/CLI), tear it down by PID/port -- killing the launcher (`go run`, wrapper, parent shell) leaves the spawned child alive holding the port, which then looks like a fresh bug on the next run.

## [0.3.0]

### Added -- three language-agnostic LAWs

- **LAW 6 -- Secrets are never rendered.** No log/config-dump/diagnostic/error prints a secret value; redact at the source (self-masking field -> `****`) so visibility can be enabled freely.
- **LAW 7 -- Errors keep their classification to the edge.** Use typed/semantic errors the transport edge maps to a code; never wrap in a way that erases the type (a NotFound silently becoming a 500 is a defect). Preserve the language's `Is`/`As`-style matching.
- **LAW 8 -- Local-runnable: no hard external dependency for dev.** Depend on a port, select the impl by config, ship an in-memory implementation; dev default = in-memory (arm wires nothing that dials the network), production overrides via env. A service that can't boot without a live DB/cache is a velocity defect.

## [0.2.2]

### Fixed
- `.claude-plugin/marketplace.json`: `owner` must be an object, not a
  string. Changed `"owner": "xgodev"` to
  `"owner": { "name": "xgodev", "url": "https://github.com/xgodev" }`
  to match the marketplace schema used by sibling `xgodev/boost` and
  `xgodev/quality-gate` plugins. Without this, repair tooling and strict
  schema validators reject the marketplace entry.

## [0.2.1]

### Changed
- Renamed the marketplace identifier from `dev-rules` to `xgodev-dev-rules`
  in `.claude-plugin/marketplace.json` to disambiguate the marketplace from
  the plugin, which is also named `dev-rules`. The plugin name itself is
  unchanged. Install path becomes `dev-rules@xgodev-dev-rules`; update
  commands and the `extraKnownMarketplaces` key in README updated to match.

## [0.2.0]

### Added (STOP-checklist items, language-agnostic)
- **Library before custom (do not reinvent the wheel)** -- before writing
  N lines, search if a well-maintained library already solves it; smaller
  code + battle-tested + removed maintenance burden wins, regardless of
  language.
- **Designed for testability** -- pure functions where possible; side
  effects on the edges; dependencies injected (not imported as globals
  inside the function); no hidden state; if you cannot test it without
  spinning up infra, the design is wrong.
- **Domain at the center (DDD, always)** -- domain pure, depends on
  nothing concrete; application orchestrates use cases; infrastructure on
  the edge implements the domain's ports; dependencies point inward
  (dependency inversion). An inward arrow from the domain to an infra
  package is a broken boundary -- fix now.
- **One Responsibility Per File** extended with the explicit rationale:
  small files/functions/classes let multiple agents and developers work
  in parallel without merge-conflict serialization on god files.

### Updated
- Rationalizations table and Red Flags list extended with the realistic
  excuses each new rule faces (build-it-ourselves, dep-is-bloat, "I'll
  add tests later", "splitting is over-engineering", "DDD is too much",
  "the domain can import this driver").

## [0.1.0]

First public release.

- Single macro, language-agnostic engineering-discipline skill
  (`skills/dev-rules/SKILL.md`): STOP checklist (data ownership,
  separation of concerns, zero coupling, single source of truth, naming,
  no trash, impact analysis, safe refactoring, one responsibility per
  file), non-negotiable LAWs (RED-first TDD, docs always synced, verify
  before claiming done, no silent fallback, no skipped tests to go green),
  communication discipline, a rationalizations table and red flags
  validated against subagents under combined pressure (RED-GREEN-REFACTOR),
  and a living-document clause.
- Plugin manifest and marketplace entry (`dev-rules`, source `./`).
- Governance (`CLAUDE.md`): English-only everywhere, docs-synced commits,
  3-file version discipline, ASCII identifiers and `--` not em-dash, never
  guess Claude Code specifics.
- README with install, update, and auto-update instructions.
