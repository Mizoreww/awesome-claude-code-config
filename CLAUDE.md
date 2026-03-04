# Global Instructions

## Memory System (Highest Priority)

### Architecture

- `~/.claude/CLAUDE.md`: Global instructions, auto-loaded
- `~/.claude/lessons.md`: Correction log, **auto-injected via SessionStart hook**
- Project `MEMORY.md`: `~/.claude/projects/<path>/memory/MEMORY.md`, auto-loaded

### Self-Correction

**Identifying corrections** (low threshold): user points out errors, says "remember/don't again...", shows frustration, same operation fails 2+ times. When in doubt, treat it as a correction.

**Post-correction flow**:
1. **Immediately** write to `~/.claude/lessons.md` (date, context, mistake, rule) — the only valid path; any path containing `projects/` is WRONG
2. Rules must be concrete instructions to prevent recurrence
3. Only after writing, continue handling the user's request

**Rule promotion**: `CLAUDE.md` can only be modified when the user **explicitly asks**.

## Core Settings

- Extended thinking: ultrathink
- Language: respond in the user's preferred language; code comments may use English; keep technical terms in English
- Shell: Zsh (`~/.zshrc`)

## Conda Environment

Activate conda before running Python:

```bash
source $HOME/anaconda3/etc/profile.d/conda.sh && conda activate <env_name>
# Or directly: $HOME/anaconda3/envs/<env_name>/bin/python script.py
```

## Network & Proxy

- Proxy via SSH reverse port forwarding: `ssh -R <remote_port>:127.0.0.1:<local_port>`, set `http_proxy`/`https_proxy`
- Do not modify `.bashrc`, `.profile`, or VSCode config unless explicitly asked
- Prefer user-space solutions when no `sudo` access

## Communication Preferences

- When the user says a cause is **not** the problem, **immediately stop** that direction and pivot
- Prefer writing code over repeated questions; after multiple requests, just implement with assumptions noted in comments

## Workflow

- Include current year in web searches for up-to-date results
- Non-trivial tasks (3+ steps): enter Plan Mode first; re-plan on deviation
- Subagent strategy: one task per subagent, keep main context clean
- Verify before marking done (run tests, check logs)
- Fix bugs directly — don't ask for repeated confirmation

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

- Not every commit needs an entry — only update on **version-level changes**
- Does not conflict with CLAUDE.md: CLAUDE.md manages instructions, CHANGELOG.md tracks evolution
- Create the file proactively if it doesn't exist

## Code Review

Whenever a code review is needed — whether explicitly requested by the user or triggered by a skill (e.g., `code-reviewer`, `simplify`) — always invoke the `mcp__codex-cli__review` tool to perform it. Never substitute the actual review call with a text-only description.
