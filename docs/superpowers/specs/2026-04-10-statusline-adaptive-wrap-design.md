# Statusline Adaptive Wrap Design

> **Historical planning snapshot.** Parts of this document describe behavior that has since been changed or removed (e.g., statusline hooks, lessons.md overwrites, `|| true` MCP setup). Do not implement from this document; treat the current installers and README as the source of truth.

**Date:** 2026-04-10
**Status:** Draft
**File:** `~/.claude/hooks/statusline.sh`

## Problem

The current statusline renders all 6 segments on a single line. When the terminal is narrow, content is truncated by the terminal emulator with no graceful degradation.

## Goal

Make the statusline dynamically wrap segments to the next line based on actual terminal width, so all information remains visible at any reasonable terminal size.

## Approach: Visible-Width Precise Calculation

Calculate the visible character width of each segment (stripping ANSI escape codes), accumulate widths left-to-right, and insert `\n` before any segment that would exceed `$COLUMNS`.

## Segments (in order)

| # | Name | Example visible text | Priority |
|---|------|---------------------|----------|
| 1 | Model | `🧠 Opus 4.6` | High |
| 2 | Directory | `📂 project` | High |
| 3 | Conda/venv | `🐍 base` | Medium |
| 4 | Git branch | `⎇ main` | Medium |
| 5 | Context bar | `context ████░░ 30% 200k` | High |
| 6 | 5h usage bar | `5h ██████░░ 40% 2h15m` | High |

## Key Components

### 1. Terminal Width Detection

```bash
COLUMNS=${COLUMNS:-$(tput cols 2>/dev/null || echo 120)}
```

Fallback to 120 if detection fails (equivalent to current no-wrap behavior).

### 2. `visible_len()` Function

Strips ANSI escape sequences and counts visible characters:

```bash
visible_len() {
    local stripped
    stripped=$(printf "%b" "$1" | sed 's/\x1b\[[0-9;]*m//g')
    echo "${#stripped}"
}
```

Note: Emoji characters (🧠📂🐍) occupy 2 columns each. The function must account for this. On Linux, `wc -L` reports display width correctly for UTF-8 strings, so use `printf "%b" "$1" | sed 's/\x1b\[[0-9;]*m//g' | wc -L` as the width measure.

### 3. Segment Array Construction

Replace the current string-concatenation approach with an array:

```bash
segments=()
segments+=("$model_seg")
[ -n "$dir_name" ] && segments+=("$dir_seg")
[ -n "$conda_env" ] && segments+=("$conda_seg")
[ -n "$git_branch" ] && segments+=("$git_seg")
segments+=("$ctx_seg")
[ -n "$usage_5h" ] && segments+=("$usage_seg")
```

### 4. Wrap Algorithm

```
line_width = 0
separator_width = 3  # " │ "
output = ""

for each segment:
    seg_width = visible_len(segment)
    needed = seg_width + (separator_width if not first on line)

    if line_width + needed > COLUMNS and line_width > 0:
        output += "\n"
        line_width = 0

    if line_width > 0:
        output += separator
        line_width += separator_width

    output += segment
    line_width += seg_width

printf "%b" "$output"
```

### 5. Adaptive Progress Bar Width

`build_bar()` gains an optional width parameter:

```bash
build_bar() {
    local pct=$1 w=${2:-$BAR_W}
    # ... rest of function uses $w instead of $BAR_W
}
```

Before building the context/usage segments, estimate remaining line space. If a full 20-char bar would cause a wrap, shrink it:

- Minimum bar width: 8 characters
- Shrink formula: `bar_w = min(20, remaining_space - label_overhead)`
- If `bar_w < 8`, keep 20 and accept the wrap to the next line

### 6. Edge Cases

| Scenario | Behavior |
|----------|----------|
| Terminal < 30 cols | No special handling; terminal truncates naturally |
| `tput cols` fails | Default 120 cols (current behavior preserved) |
| All segments fit on one line | Single line output (current behavior preserved) |
| Progress bar would be < 8 chars | Keep full 20-char bar, accept line wrap |
| No conda/venv active | Segment omitted entirely (current behavior preserved) |
| No git repo | Git segment omitted (current behavior preserved) |
| No 5h usage data | Usage segment omitted (current behavior preserved) |

## Visual Examples

### Wide terminal (150+ cols) -- single line:

```
🧠 Opus 4.6 │ 📂 project │ 🐍 base │ ⎇ main │ context ████████████░░░░░░░░ 60% 200k │ 5h ████████░░░░░░░░░░░░ 40% 2h15m
```

### Medium terminal (~90 cols) -- two lines:

```
🧠 Opus 4.6 │ 📂 project │ 🐍 base │ ⎇ main
context ████████████░░░░░░░░ 60% 200k │ 5h ████████░░░░░░░░░░░░ 40% 2h15m
```

### Narrow terminal (~60 cols) -- wraps more:

```
🧠 Opus 4.6 │ 📂 project │ 🐍 base
⎇ main │ context ███████░░░ 60% 200k
5h █████░░░░░ 40% 2h15m
```

## Non-Goals

- No element hiding/priority-based truncation (user chose "let terminal truncate")
- No maximum line count enforcement
- No configuration options for wrap behavior (hardcoded logic)

## Testing

- Manually resize terminal and verify wrapping at various widths (40, 60, 80, 100, 120, 150)
- Verify single-line behavior at wide terminals (150+) is unchanged from current
- Verify with and without conda/git/usage segments active
- Verify emoji vs non-emoji mode both calculate widths correctly
