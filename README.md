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

```text
/plugin marketplace add git@github.com:xgodev/dev-rules.git
/plugin install dev-rules
```

## Update

Inside Claude Code:

```text
/plugin update dev-rules
```

From the CLI:

```bash
claude plugin update dev-rules@xgodev-dev-rules
```

If it reports `Plugin "..." not found`, specify the scope explicitly:

```bash
claude plugin update dev-rules@xgodev-dev-rules --scope user   # or: project | local | managed
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

-> **Marketplaces** -> select `xgodev-dev-rules` -> **Enable auto-update**.

Or declaratively, in `~/.claude/settings.json` (global) -- add
`"autoUpdate": true` to the marketplace entry under
`extraKnownMarketplaces`:

```json
{
  "extraKnownMarketplaces": {
    "xgodev-dev-rules": {
      "source": {
        "source": "git",
        "url": "git@github.com:xgodev/dev-rules.git"
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
