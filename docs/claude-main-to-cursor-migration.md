# Claude Code (`main`) → Cursor migration map

This document explains how the configuration from this repo's `main` branch
(built for [Claude Code](https://claude.com/claude-code)) maps onto **Cursor**
(IDE + CLI agent), and how to install it. The `cursor` branch is a
Cursor-targeted variant of the same config — the same instructions, coding
rules, skills, MCP servers, hooks, and status line, expressed through Cursor's
native mechanisms and installed into `~/.cursor/`.

## Concept mapping

| Claude Code (`main`) | Cursor equivalent | Installed to |
|---|---|---|
| `CLAUDE.md` | `AGENTS.md` | `~/.cursor/AGENTS.md` |
| `settings.json` → `statusLine` | `cli-config.json` → `statusLine` | `~/.cursor/cli-config.json` (merged) |
| `settings.json` → `SessionStart` hook (load lessons) | `hooks.json` → `sessionStart` hook | `~/.cursor/hooks.json` + `~/.cursor/hooks/` |
| `settings.json` → permissions / env / model | Cursor Settings UI (no 1:1 file) | configure in Cursor |
| `mcp/mcp-servers.json` | `mcp.json` (`{"mcpServers": {…}}`) | `~/.cursor/mcp.json` (merged) |
| `rules/**/*.md` | `.cursor/rules/*.mdc` (with frontmatter) | `~/.cursor/rules/*.mdc` |
| `skills/<name>/SKILL.md` | Cursor skills (same `SKILL.md` format) | `~/.cursor/skills/<name>/` |
| `hooks/statusline.sh` | same script, de-Claude-ified | `~/.cursor/statusline.sh` |
| Claude plugins | Skills + MCP servers | see "What does NOT migrate 1:1" below |
| `~/.claude/lessons.md` | `~/.cursor/lessons.md` | `~/.cursor/lessons.md` (seeded only if absent) |

## What gets installed where

After running the installer, your Cursor home (`~/.cursor/` by default) contains:

```
~/.cursor/
├── AGENTS.md            # global instructions (was CLAUDE.md)
├── lessons.md           # cross-project corrections (only seeded if missing)
├── mcp.json             # MCP servers (merged with any you already have)
├── cli-config.json      # holds the statusLine entry (merged)
├── statusline.sh        # the status line script
├── hooks.json           # user hooks (sessionStart → load lessons)
├── hooks/
│   ├── load-lessons.sh  # cats ~/.cursor/lessons.md at session start
│   └── statusline.sh    # copy kept alongside the hooks
├── rules/               # *.mdc coding-standard rules
│   ├── common-*.mdc     # always applied
│   └── {python,typescript,golang}-*.mdc   # applied via file globs
└── skills/<name>/       # bundled skills (SKILL.md each)
```

### Rules

Rules are `.cursor/rules/*.mdc` files with frontmatter:

- **Common rules** (`common-*.mdc`) set `alwaysApply: true` — coding style, git
  workflow, testing, performance, patterns, security, hooks, agents.
- **Language rules** (`python-*`, `typescript-*`, `golang-*`) are scoped by
  `globs` (`**/*.py`, `**/*.{ts,tsx,js,jsx}`, `**/*.go`) and apply only when you
  touch matching files.

Cursor reads rules both from a project's `.cursor/rules/` and from the global
`~/.cursor/rules/`. The installer writes the global copy; the repo also keeps a
project copy so the config dogfoods itself.

### Skills

Skills keep the same `SKILL.md` format Claude Code uses, so they port directly.
Command-style skills (invoked explicitly, e.g. `update`, `handoff`, `teach`,
`update-config`) set `disable-model-invocation: true`; auto skills (e.g.
`humanizer`, `paper-reading`, `adversarial-review`) stay model-invokable.
`update` is the Cursor self-updater that re-runs this config from the repo into
`~/.cursor/`.

### MCP servers

Cursor reads MCP servers from `~/.cursor/mcp.json` (global) or a project
`.cursor/mcp.json`, in the format `{"mcpServers": {"<name>": {…}}}`. The
installer **merges** this repo's servers into your existing file — servers you
already have win on conflict, so your setup is never clobbered.

Two zero-config servers ship active (no credentials): `context7`
(library/framework docs) and `playwright` (browser automation). Servers that
need secrets — `github` (a Personal Access Token) and `lark` (an app id +
secret) — are **documented in [`mcp.README.md`](../mcp.README.md), not placed in
the active `mcp.json`**. Strict JSON has no comments, and Cursor would otherwise
spawn them every session with bogus credentials. To enable one, copy its block
from `mcp.README.md` into your `~/.cursor/mcp.json` and fill in real values.

### Hooks & lessons

`hooks.json` registers a `sessionStart` hook that runs
`~/.cursor/hooks/load-lessons.sh`, which prints `~/.cursor/lessons.md` so your
accumulated corrections are reloaded each session.

> **Caveat:** Cursor's `sessionStart` hook is documented for "set up or audit a
> session" and may not inject its stdout into the agent context the way Claude
> Code's `SessionStart` hook did. The lessons still reach the agent reliably via
> `~/.cursor/AGENTS.md` (which references `lessons.md`). The hook is shipped
> regardless — it is forward-compatible and useful for session auditing.

### Status line

`statusline.sh` renders model, directory, conda/venv, git branch, and a gradient
context-window bar. Cursor's status line payload is aligned with Claude Code's,
so the segments work unchanged; the Claude-only "5-hour API usage" block was
removed. It is wired up by the `statusLine` entry in `cli-config.json`.

> The status line needs [`jq`](https://jqlang.github.io/jq/). The installer
> tries to fetch a static `jq` into `~/.cursor/bin/` (where `statusline.sh` also
> looks for it); if that fails it prints install instructions and the status
> line degrades gracefully to a one-line notice.

## How to install

From a clone of this branch:

**macOS / Linux**

```bash
./install-cursor.sh
```

**Windows (PowerShell)**

```powershell
.\install-cursor.ps1
```

Or without a clone (downloads this branch into a temp dir first):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/cursor/install-cursor.sh)
```

Useful flags (both installers):

- `--dry-run` / `-DryRun` — print every action, change nothing.
- `--prefix <dir>` / `-Prefix <dir>` — install into a custom directory instead
  of `~/.cursor` (also honored via the `CURSOR_HOME` environment variable).
- `--uninstall` / `-Uninstall` — revert to the pre-install state (see below).
- `--purge-lessons` / `-PurgeLessons` — with uninstall, also delete a
  `lessons.md` the installer seeded (kept by default).
- `--force` / `-Force` — skip the uninstall confirmation prompt.

The installer is **idempotent and non-destructive**: it backs up any config file
it overwrites to `<file>.bak.<timestamp>`, merges `mcp.json` / `cli-config.json` /
`hooks.json` rather than replacing them, leaves rules/skills you added yourself
untouched, and never overwrites an existing `lessons.md`. It also stamps the
installed version to `~/.cursor/.awesome-claude-code-config-version` so the
`update` skill can detect upgrades.

### Uninstall (revert to the pre-install state)

```bash
./install-cursor.sh --uninstall        # macOS / Linux
.\install-cursor.ps1 -Uninstall        # Windows (PowerShell)
```

To make this reliable, the **first** install records two things under
`~/.cursor`: a verbatim snapshot of every config file it is about to overwrite
(`.awesome-claude-code-config.backup/`) and a manifest of everything it installs
(`.awesome-claude-code-config.manifest`). Uninstall then:

- **restores** each snapshotted original (files that pre-existed your install),
- **deletes** files the installer itself created (rules, skills, hooks, the
  status line, the version stamp, the snapshot, and the manifest), and
- **surgically un-merges** only its own entries from `mcp.json`, `hooks.json`,
  and `cli-config.json`, leaving any servers/hooks/keys you added in place
  (a file is removed only if nothing of yours remains).

`lessons.md` is **kept by default** because it holds your own corrections; pass
`--purge-lessons` / `-PurgeLessons` to drop one that the installer seeded. Pair
with `--dry-run` to preview the exact actions first.

**Limitations.** Configs installed by an older build that predates the
snapshot/manifest fall back to a **degraded best-effort** removal: a file is
deleted only when it is byte-identical to what the repo currently ships, and JSON
files are un-merged surgically; anything you modified, merged, or that pre-existed
is left in place with a warning. Edits you made *after* installing (e.g. tweaking
an installed rule) are likewise preserved rather than reverted.

## What does **not** migrate 1:1

### Claude plugins → skills + MCP

Cursor has no plugin marketplace/registry like Claude Code. The `cursor` branch
therefore migrates *capabilities*, not plugin identities:

- documentation lookup → the `context7` MCP server;
- browser automation / E2E → the `playwright` MCP server;
- GitHub workflows → the `github` MCP server (documented, secret-gated);
- coding patterns / testing / security → the `.cursor/rules/*.mdc` rule set;
- review, paper reading, humanizing, handoff, teaching → bundled **skills**.

### Proprietary Anthropic skills are referenced, not bundled

Anthropic's proprietary skill packs (e.g. `document-skills`, `example-skills`)
are **not** redistributed in this branch for licensing reasons. They are
referenced in the docs only; install them from their original source if you want
them.

### Claude `settings.json` runtime keys

Permission modes, environment defaults, and model selection that lived in
Claude's `settings.json` have no single config-file equivalent in Cursor — set
those in Cursor's Settings UI. Only the `statusLine` and session hook moved into
files (`cli-config.json` and `hooks.json`).

## Mental model for users coming from `main`

Think of the Cursor config in four layers:

1. **Instructions** — `AGENTS.md` (+ `lessons.md` for accumulated corrections).
2. **Coding standards** — `.cursor/rules/*.mdc`, scoped globally or by language.
3. **Reusable behavior** — skills in `~/.cursor/skills/`.
4. **External tools** — MCP servers in `~/.cursor/mcp.json`.

That maps cleanly onto how Cursor actually loads configuration, rather than
trying to recreate Claude Code's exact file layout.
