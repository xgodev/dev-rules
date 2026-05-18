# CLAUDE.md

This repo is the `dev-rules` Claude Code plugin: a single macro,
language-agnostic engineering-discipline skill. It is the companion to
`xgodev/quality-gate` -- the gate catches mechanical metric regressions;
`dev-rules` governs the decisions a gate cannot measure.

## Hard rules

- **English only, everywhere.** Skill body, docs, comments, identifiers,
  commit messages. No Portuguese, no other natural language. Run a
  Portuguese sweep (accented characters + PT word stems) before any commit;
  it must be empty.
- **Docs always synced, same commit.** Any change to the skill, plugin
  manifest, behavior, or version updates its docs in the SAME commit. A doc
  that lies is a defect. README, CHANGELOG, and skill body must reflect the
  shipped state.
- **3-file version discipline, verified before commit.** Bumping the skill
  or plugin requires updating, in lockstep: `.claude-plugin/plugin.json`
  `version`, `CHANGELOG.md`, and the README version line if one exists.
  Verify all three before committing. Patch for a doc fix, minor for a new
  capability, major for a breaking trigger or name change.
- **ASCII identifiers; `--` not em-dash.** No accented characters in code
  identifiers, file names, or shell command examples. Prose uses `--`
  (two hyphens), never an em-dash or en-dash.
- **Never guess Claude Code specifics.** Plugin layout, frontmatter keys,
  marketplace schema, install commands -- verify against official Claude
  Code documentation before asserting. Do not invent behavior.
- **Plugin skills live in `skills/`, not `.claude/skills/`.** The plugin
  convention is `skills/<name>/SKILL.md`. Do not create a `.claude/skills/`
  tree in this repo.

## Common mistakes

- **Don't translate or paraphrase the trigger.** The frontmatter
  `description` is the routing signal and must stay verbatim English:
  "Use when writing, editing, or refactoring code in any language --
  before writing, not after".
- **Don't add a workflow summary to the description.** The description says
  WHEN to load the skill, not what it does step by step.
- **Don't reintroduce project- or company-specific rules.** This skill is
  generalized; no language-, tool-, or organization-specific content
  (no Cargo, no Slint, no gh-milestone, no translation catalogs).
- **Don't ship a passive wall of text.** This is a discipline skill: it must
  keep the rationalizations table and red flags populated from real
  pressure-tested failures, not invented examples.
