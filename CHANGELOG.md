# Changelog

All notable changes to this plugin are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/) and the project adheres to
[Semantic Versioning](https://semver.org/).

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
