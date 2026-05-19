# Changelog

All notable changes to this plugin are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/) and the project adheres to
[Semantic Versioning](https://semver.org/).

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
