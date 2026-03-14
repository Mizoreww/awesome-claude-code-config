# Global Instructions (Codex)

## Memory System (Highest Priority)

### Architecture

- `~/.codex/AGENTS.md`: global instructions, auto-loaded
- `~/.codex/lessons.md`: correction source-of-truth (append-only)

### Session Startup Flow

Before the first substantive response in a session, ensure lessons context is loaded from:

- `~/.codex/lessons.md` (via `model_instructions_file`)

### Self-Correction

**Identify corrections early**: user says something is wrong, says "remember / don't do this again", expresses frustration, or same operation fails repeatedly.

**After a correction**:
1. Immediately write a lesson to `~/.codex/lessons.md` (date, context, mistake, rule)
2. Make the rule concrete and actionable
3. Continue task execution only after recording

## Core Settings

- Language: respond in user's preferred language; keep technical terms in English when appropriate
- Shell: zsh (`~/.zshrc`)

## Communication Preferences

- If user says a hypothesis is wrong, stop that direction immediately
- Prefer implementation over repetitive questioning

## Workflow

- Web search: before searching, determine the current real date — prefer system command (`date '+%Y-%m-%d'`), fall back to web time API if system clock may be inaccurate. Include the year (and month if relevant) in search queries. Never rely solely on model knowledge or system prompt for the date.
- Use explicit planning for non-trivial tasks
- Verify before marking done (tests/logs where applicable)
- Fix bugs directly and report what changed

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
- Does not conflict with AGENTS.md: AGENTS.md manages instructions, CHANGELOG.md tracks evolution
- Create the file proactively if it doesn't exist

## Rule Set

- Common + language-specific coding standards are provided via skills:
  - `python-patterns`, `golang-patterns`, `frontend-patterns`

## Paper Reading

- Use `paper-reading` skill for research paper tasks
