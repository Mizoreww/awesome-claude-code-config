# Global Instructions (Cursor)

## Memory System (Highest Priority)

### Architecture

- `~/.cursor/AGENTS.md`: global instructions, auto-loaded by Cursor (this file).
- `~/.cursor/lessons.md`: **global** corrections & lessons (cross-project), append-only. A `sessionStart` hook (`~/.cursor/hooks.json`) tries to surface it, but treat that as best-effort — see Session Startup Flow.
- Project-level memory: a project `AGENTS.md` at the repo root (or a project rule in `.cursor/rules/`) holds preferences & context for the current project only.

### Storage Decision

When the user asks to "remember X", determine the scope first:
- **Would this apply in a different project?** → Global, append to `~/.cursor/lessons.md`.
- **Only relevant to the current project?** → Project-level, write to the project's `AGENTS.md` (or a `.cursor/rules/*.mdc` rule).

### Session Startup Flow

Before the first substantive response in a session, make sure the corrections in `~/.cursor/lessons.md` are in context. A `sessionStart` hook runs `~/.cursor/hooks/load-lessons.sh`, but Cursor's `sessionStart` may run **without** injecting a hook's stdout into the agent context — so do not assume it ran. If you have not already been given the contents of `~/.cursor/lessons.md` this session, read the file yourself before proceeding.

### Self-Correction

**Identifying corrections** (low threshold): the user points out errors, says "remember / don't do that again", shows frustration, or the same operation fails 2+ times. When in doubt, treat it as a correction.

**Post-correction flow**:
1. **Determine scope** (see Storage Decision above) and write to the appropriate file (date, context, mistake, concrete rule).
2. Make the rule a concrete instruction that prevents recurrence.
3. Only after writing, continue handling the user's request.

**Rule promotion**: `AGENTS.md` may only be modified when the user **explicitly asks**.

## Core Settings

- Language: respond in the user's preferred language; code comments may use English; keep technical terms in English.
- Shell: Zsh (`~/.zshrc`) on macOS/Linux; Bash (Git Bash) on Windows.

## Conda Environment

Activate conda before running Python:

```bash
source $HOME/anaconda3/etc/profile.d/conda.sh && conda activate <env_name>
# Or directly: $HOME/anaconda3/envs/<env_name>/bin/python script.py
```

## Network & Proxy

- Proxy via SSH reverse port forwarding: `ssh -R <remote_port>:127.0.0.1:<local_port>`, set `http_proxy`/`https_proxy`.
- Do not modify `.bashrc`, `.profile`, or editor config unless explicitly asked.
- Prefer user-space solutions when no `sudo` access.

## Communication Preferences

- When the user says a cause is **not** the problem, **immediately stop** that direction and pivot.
- Prefer writing code over repeated questions; after multiple requests, just implement with assumptions noted in comments.

## Workflow

- Web search: before searching, determine the current real date — prefer a system command (`date '+%Y-%m-%d'` / `Get-Date -Format 'yyyy-MM-dd'`), fall back to a web time API if the system clock may be inaccurate. Include the year (and month if relevant) in search queries. Never rely solely on model knowledge or the system prompt for the date.
- Non-trivial tasks (3+ steps): use Plan mode / an explicit plan first; re-plan on deviation.
- Subagent strategy: one task per subagent, keep the main context clean.
- Verify before marking done (run tests, check logs).
- Fix bugs directly — don't ask for repeated confirmation.

## Cursor Mechanisms

This configuration installs into `~/.cursor/`:
- **Rules**: `.cursor/rules/*.mdc` (per-project) and `~/.cursor/rules/*.mdc` (global). Common rules apply always; language rules apply via file globs.
- **Skills**: `~/.cursor/skills/<name>/SKILL.md`. Explicit/command-style skills set `disable-model-invocation: true`; auto skills are model-invokable from context.
- **MCP servers**: `~/.cursor/mcp.json` (`{"mcpServers": {...}}`).
- **Hooks**: `~/.cursor/hooks.json` (e.g. `sessionStart` → load lessons), with scripts under `~/.cursor/hooks/`.
- **Statusline**: `~/.cursor/statusline.sh`, wired via the `statusLine` entry in `~/.cursor/cli-config.json`.

## Rule Set

Coding standards live in `.cursor/rules/`:
- **Common** (`common-*.mdc`): language-agnostic principles — coding style, git workflow, testing, performance, patterns, hooks, agents, security. These set `alwaysApply: true`.
- **Language-specific** (`python-*`, `typescript-*`, `golang-*`): extend the common rules with language idioms and tooling, scoped by globs (`**/*.py`, `**/*.{ts,tsx,js,jsx}`, `**/*.go`).

## Version Changelog

When making version-level changes to a project (new features, major refactors, architectural changes, breaking changes), maintain a `CHANGELOG.md` in the project root:

```markdown
## [version] - YYYY-MM-DD
### Features
- What was changed
### Design Rationale
- Why it was done this way, what trade-offs were considered
### Notes & Caveats
- Edge cases, compatibility, migration concerns, etc.
```

- Not every commit needs an entry — only update on **version-level changes**.
- Does not conflict with AGENTS.md: AGENTS.md manages instructions, CHANGELOG.md tracks evolution.
- Create the file proactively if it doesn't exist.

## Code Review

Whenever a code review is needed — whether explicitly requested by the user or triggered by a skill or workflow — invoke the `adversarial-review` skill to perform it. The skill spawns reviewers on the **opposite** model's CLI (`codex exec` or `claude -p`) so the critique comes from a genuinely different model. If the opposite-model CLI is unavailable, fall back to a dedicated Cursor review subagent (e.g. the code-review / Bugbot agent). Never substitute the actual review call with a text-only description.

## Paper Reading

- Use the `paper-reading` skill for reading, summarizing, or analyzing research papers.
