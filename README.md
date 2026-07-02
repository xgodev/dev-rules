# dev-rules

A single macro, **language-agnostic engineering-discipline** Claude Code
plugin. It encodes how to write, edit, and refactor code well in any
language -- the methodology and decision rules a mechanical gate cannot
measure (data ownership, zero coupling, single source of truth, RED-first
TDD, docs-synced commits, honest failure, verify-before-done,
concurrency-first design).

It is the companion to [`xgodev/quality-gate`](https://github.com/xgodev/quality-gate):
the gate catches mechanical metric regressions (fmt, lint, build, test,
complexity, coverage); `dev-rules` governs the judgment the gate cannot see.
Use them together, not interchangeably.

It is a **discipline-enforcing** skill: rigid, concise, applied **before**
writing -- not a passive reference skimmed after the fact.

## Install

The plugin is distributed through the single `xgodev-plugins` marketplace,
hosted in [`xgodev/claude-plugin`](https://github.com/xgodev/claude-plugin),
which lists this repo as a GitHub source (this repo is not a marketplace
itself):

```text
/plugin marketplace add git@github.com:xgodev/claude-plugin.git
/plugin install dev-rules@xgodev-plugins
```

> Until 0.6.4 this repo was its own marketplace (`xgodev-dev-rules`). If you
> installed the old way: `/plugin uninstall dev-rules@xgodev-dev-rules`,
> `/plugin marketplace remove xgodev-dev-rules`, then install as above.

## Update

Inside Claude Code:

```text
/plugin update dev-rules
```

From the CLI:

```bash
claude plugin update dev-rules@xgodev-plugins
```

If it reports `Plugin "..." not found`, specify the scope explicitly:

```bash
claude plugin update dev-rules@xgodev-plugins --scope user   # or: project | local | managed
```

Use `claude plugin list` to find the scope where the plugin is installed.

### Auto-update

Claude Code checks for plugin updates at startup, but **third-party
marketplaces have auto-update disabled by default** -- only Anthropic's
official marketplaces update on their own. To enable it:

Interactive, inside Claude Code:

```text
/plugin
```

-> **Marketplaces** -> select `xgodev-plugins` -> **Enable auto-update**.

Or declaratively, in `~/.claude/settings.json` (global) -- add
`"autoUpdate": true` to the marketplace entry under
`extraKnownMarketplaces`:

```json
{
  "extraKnownMarketplaces": {
    "xgodev-plugins": {
      "source": {
        "source": "git",
        "url": "git@github.com:xgodev/claude-plugin.git"
      },
      "autoUpdate": true
    }
  }
}
```

The same works in a project's `.claude/settings.json` if you want to pin
auto-update for the team via the repo. Restart Claude Code for the change to
take effect.

> An update is only recognized when the `version` in `plugin.json` is
> incremented. Commits without a version bump do not trigger an update --
> even with auto-update on, Claude Code reports "already at latest".

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
| `.mode-feature` | allowed | allowed |
| `.red-first-unlocked` | allowed | allowed |

Test files, docs, and config are never blocked.

**Bug flow:** brainstorm with the user -> write the failing test (allowed) ->
see it RED -> `touch .dev-rules/.red-first-unlocked` -> read code and fix.

**Feature flow:** brainstorm -> `touch .dev-rules/.mode-feature` -> read code,
plan (`writing-plans`), and write the code. Red-first is the bug gate, so feature
mode unlocks edits too; TDD per unit is still expected, governed by the plan and
review rather than the hook.

A cycle-closing commit (`fix(`/`feat(`/`bugfix(`/`Fix #`/`Fixes #`) auto-clears
both sentinels, so the next cycle re-brainstorms and re-REDs.

**Per-repo config / opt-out (`.dev-rules.json` at the repo root):**

```json
{
  "enabled": true,
  "production_globs": ["src/**", "internal/**", "crates/**/src/**"],
  "test_globs": ["**/*_test.*", "**/tests/**", "**/*.spec.*"]
}
```

`"enabled": false` disables all gating for the project. Omit the file to use
built-in detection (production segments: `src lib app cmd internal pkg crates
domain`, minus test/docs/config).
