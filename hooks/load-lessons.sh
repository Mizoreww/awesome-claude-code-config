#!/usr/bin/env bash
# Cursor sessionStart hook — load the global "lessons learned" file.
#
# Mirrors the Claude Code SessionStart hook, which cat-ed ~/.claude/lessons.md
# and asked the agent to confirm it had loaded them. User hooks run from
# ~/.cursor/, so hooks.json references this script as ./hooks/load-lessons.sh.
#
# LIMITATION (for the coordinator): Cursor's create-hook docs describe
# `sessionStart` as "set up or audit a session" and do NOT document a stdout
# context-injection field (unlike postToolUse's `additional_context`). If the
# installed Cursor build does not feed this stdout into the agent context, the
# lessons still reach the agent via ~/.cursor/AGENTS.md (which references
# lessons.md). The hook is shipped regardless: it is forward-compatible and
# also useful for session auditing.

_HOME="${USERPROFILE:-$HOME}"
# lessons.md sits at the Cursor home root, one level up from this hooks/ dir.
# Self-locate first so a custom install dir (--prefix / CURSOR_HOME) works too,
# then fall back to the default ~/.cursor location.
_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
LESSONS_FILE="$_HOOK_DIR/../lessons.md"
[ -f "$LESSONS_FILE" ] || LESSONS_FILE="$_HOME/.cursor/lessons.md"

if [ -f "$LESSONS_FILE" ]; then
    echo '=== Lessons Learned (auto-loaded via sessionStart hook) ==='
    cat "$LESSONS_FILE"
    echo '=== End of Lessons ==='
    echo 'IMPORTANT: You MUST briefly confirm you have loaded these lessons at session start.'
else
    echo 'No lessons.md found at ~/.cursor/lessons.md'
fi
