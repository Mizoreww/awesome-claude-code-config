# Statusline Adaptive Wrap Implementation Plan

> **Historical planning snapshot.** Parts of this document describe behavior that has since been changed or removed (e.g., statusline hooks, lessons.md overwrites, `|| true` MCP setup). Do not implement from this document; treat the current installers and README as the source of truth.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `~/.claude/hooks/statusline.sh` dynamically wrap segments to the next line based on terminal width, with adaptive progress bar sizing.

**Architecture:** Replace the current string-concatenation assembly with a segment-array approach. A `visible_len()` function strips ANSI codes and measures display width. A wrap loop accumulates segments left-to-right, inserting `\n` when a segment would exceed `$COLUMNS`. Progress bars shrink when space is tight.

**Tech Stack:** Bash, sed, wc, tput

**Spec:** `docs/superpowers/specs/2026-04-10-statusline-adaptive-wrap-design.md`

---

### Task 1: Add terminal width detection and `visible_len()` function

**Files:**
- Modify: `~/.claude/hooks/statusline.sh:185-192` (insert new code before the `# --- Colors ---` section)

- [ ] **Step 1: Add terminal width detection after the usage cache block (after line 183)**

Insert this code right before `# --- Colors ---` (currently line 185):

```bash
# --- Terminal width ---
COLUMNS=${COLUMNS:-$(tput cols 2>/dev/null || echo 120)}

# visible_len: compute display width of a string with ANSI escapes
# Strips escape codes, then uses wc -L for accurate multi-byte/emoji width
visible_len() {
    local stripped
    stripped=$(printf "%b" "$1" | sed $'s/\x1b\[[0-9;]*m//g')
    # wc -L gives max display width (handles CJK/emoji double-width)
    printf "%b" "$stripped" | wc -L 2>/dev/null | tr -d ' '
}
```

- [ ] **Step 2: Verify the function works**

Run a quick test in your shell:

```bash
source ~/.claude/hooks/statusline.sh <<< '{"model":{"display_name":"test"},"cwd":"/tmp","context_window":{"used_percentage":50,"context_window_size":200000}}'
```

Expected: Script runs without errors and produces output.

- [ ] **Step 3: Commit**

```bash
cd ~/Desktop/claude-code-config
git add -A
git commit -m "feat(statusline): add terminal width detection and visible_len function"
```

---

### Task 2: Refactor `build_bar()` to accept dynamic width

**Files:**
- Modify: `~/.claude/hooks/statusline.sh:198-221` (the `build_bar` function)

- [ ] **Step 1: Modify `build_bar()` to accept an optional second parameter for bar width**

Replace the current `build_bar()` function (lines 198-221) with:

```bash
build_bar() {
    local pct=$1 w=${2:-$BAR_W}
    local filled=$(( pct * w / 100 ))
    [ "$filled" -gt "$w" ] && filled=$w
    local empty=$(( w - filled ))
    local bar="" nc=${#bar_colors[@]}

    for ((i = 0; i < filled; i++)); do
        local ci=$(( i * nc / w ))
        [ "$ci" -ge "$nc" ] && ci=$((nc - 1))
        bar+="\033[38;5;${bar_colors[$ci]}m\xe2\x96\x88"
    done
    for ((i = 0; i < empty; i++)); do
        bar+="\033[38;5;238m\xe2\x96\x91"
    done

    # Percentage color
    local pc=72
    [ "$pct" -ge 40 ] && pc=222
    [ "$pct" -ge 65 ] && pc=208
    [ "$pct" -ge 85 ] && pc=196

    printf "%b \033[38;5;${pc}m%d%%$C_R" "$bar" "$pct"
}
```

The only change is line 2: `local pct=$1 w=${2:-$BAR_W}` — the second parameter `$2` overrides the default `$BAR_W`.

- [ ] **Step 2: Verify build_bar still works with default width**

Run the statusline script as in Task 1 Step 2. Output should be identical to before — the default value `$BAR_W` (20) is unchanged.

- [ ] **Step 3: Commit**

```bash
cd ~/Desktop/claude-code-config
git add -A
git commit -m "feat(statusline): make build_bar accept dynamic width parameter"
```

---

### Task 3: Refactor assembly from string concatenation to segment array

**Files:**
- Modify: `~/.claude/hooks/statusline.sh:260-298` (the `# --- Assemble ---` section through end of file)

- [ ] **Step 1: Replace the current assembly block (lines 260-298) with segment-array construction**

Remove everything from `# --- Assemble (single line) ---` (line 260) to end of file (line 298) and replace with:

```bash
# --- Assemble segments ---
segments=()

# Segment 1: Model
segments+=("${ICON_MODEL} ${C_MODEL}${model}${C_R}")

# Segment 2: Directory
if [ -n "$dir_name" ]; then
    segments+=("${ICON_DIR} ${C_DIR}${dir_name}${C_R}")
fi

# Segment 3: Conda/venv
conda_env="${CONDA_DEFAULT_ENV:-}"
conda_env="$(basename "$conda_env")"
venv="${VIRTUAL_ENV:-}"
venv="$(basename "$venv")"

if [ -n "$conda_env" ]; then
    segments+=("${ICON_CONDA} ${C_CONDA}${conda_env}${C_R}")
elif [ -n "$venv" ]; then
    segments+=("${ICON_CONDA} ${C_CONDA}${venv}${C_R}")
fi

# Segment 4: Git branch
if [ -n "$git_branch" ]; then
    segments+=("${C_GIT}${ICON_GIT} ${git_branch}${C_R}")
fi

# Segment 5: Context bar
ctx_pct_int=$(printf "%.0f" "$ctx_pct" 2>/dev/null || echo "$ctx_pct")
ctx_bar=$(build_bar "$ctx_pct_int")
ctx_fmt=$(fmt_ctx "$ctx_size")
segments+=("${C_LABEL}context${C_R} ${ctx_bar} ${C_LABEL}${ctx_fmt}${C_R}")

# Segment 6: 5-hour usage bar
if [ -n "$usage_5h" ]; then
    usage_pct=$(printf "%.0f" "$usage_5h" 2>/dev/null || echo "$usage_5h")
    usage_bar=$(build_bar "$usage_pct")
    resets_fmt=$(fmt_resets "$usage_resets")
    usage_seg="${C_LABEL}5h${C_R} ${usage_bar}"
    [ -n "$resets_fmt" ] && usage_seg+=" ${C_LABEL}${resets_fmt}${C_R}"
    segments+=("$usage_seg")
fi

# --- Wrap algorithm ---
sep_str="${C_SEP} \xe2\x94\x82 ${C_R}"
sep_visible_w=3  # " │ " is 3 visible characters

out=""
line_w=0

for seg in "${segments[@]}"; do
    seg_w=$(visible_len "$seg")
    needed=$seg_w
    [ "$line_w" -gt 0 ] && needed=$(( seg_w + sep_visible_w ))

    if [ "$line_w" -gt 0 ] && [ $(( line_w + needed )) -gt "$COLUMNS" ]; then
        # Wrap to next line
        out+="\n"
        line_w=0
        needed=$seg_w
    fi

    if [ "$line_w" -gt 0 ]; then
        out+="$sep_str"
        line_w=$(( line_w + sep_visible_w ))
    fi

    out+="$seg"
    line_w=$(( line_w + seg_w ))
done

printf "%b" "$out"
```

- [ ] **Step 2: Verify at current terminal width**

Run the statusline:

```bash
echo '{"model":{"display_name":"Opus 4.6"},"cwd":"/home/limx/Desktop/claude-code-config","context_window":{"used_percentage":50,"context_window_size":200000}}' | bash ~/.claude/hooks/statusline.sh
```

Expected: Output looks the same as before at normal terminal width. At narrow widths (resize terminal to ~60 cols and re-run), segments wrap to the next line.

- [ ] **Step 3: Test narrow terminal wrapping**

```bash
# Simulate narrow terminal
COLUMNS=60 bash -c 'echo "{\"model\":{\"display_name\":\"Opus 4.6\"},\"cwd\":\"/home/limx/Desktop/claude-code-config\",\"context_window\":{\"used_percentage\":50,\"context_window_size\":200000}}" | bash ~/.claude/hooks/statusline.sh'
```

Expected: Output wraps across multiple lines. No truncation.

- [ ] **Step 4: Test wide terminal (single line)**

```bash
COLUMNS=200 bash -c 'echo "{\"model\":{\"display_name\":\"Opus 4.6\"},\"cwd\":\"/home/limx/Desktop/claude-code-config\",\"context_window\":{\"used_percentage\":50,\"context_window_size\":200000}}" | bash ~/.claude/hooks/statusline.sh'
```

Expected: All segments on a single line, identical to the current behavior.

- [ ] **Step 5: Commit**

```bash
cd ~/Desktop/claude-code-config
git add -A
git commit -m "feat(statusline): adaptive line wrapping based on terminal width"
```

---

### Task 4: Add adaptive progress bar shrinking

**Files:**
- Modify: `~/.claude/hooks/statusline.sh` — the context bar and usage bar segment construction (inside the segment array block from Task 3)

- [ ] **Step 1: Add adaptive bar width calculation before the context bar segment**

Replace the context bar segment construction (the `# Segment 5: Context bar` block) with:

```bash
# Segment 5: Context bar (adaptive width)
ctx_pct_int=$(printf "%.0f" "$ctx_pct" 2>/dev/null || echo "$ctx_pct")
ctx_fmt=$(fmt_ctx "$ctx_size")
# Estimate overhead: "context " (8) + " " (1) + pct "XX%" (3-4) + " " (1) + ctx_fmt (~4) ≈ 18
ctx_label_overhead=18
ctx_bar_w=$BAR_W
ctx_remaining=$(( COLUMNS - line_w - sep_visible_w - ctx_label_overhead ))
if [ "$line_w" -gt 0 ] && [ "$ctx_remaining" -lt "$BAR_W" ] && [ "$ctx_remaining" -ge 8 ]; then
    ctx_bar_w=$ctx_remaining
fi
ctx_bar=$(build_bar "$ctx_pct_int" "$ctx_bar_w")
segments+=("${C_LABEL}context${C_R} ${ctx_bar} ${C_LABEL}${ctx_fmt}${C_R}")
```

Note: `line_w` is not yet available at segment construction time (it's computed during the wrap loop). To make this work, we need to **pre-compute** the cumulative width of segments 1-4 before building segment 5. Add this calculation right before the context bar block:

```bash
# Pre-compute width of segments so far (for adaptive bar sizing)
_pre_w=0
for _s in "${segments[@]}"; do
    [ "$_pre_w" -gt 0 ] && _pre_w=$(( _pre_w + sep_visible_w ))
    _pre_w=$(( _pre_w + $(visible_len "$_s") ))
done
```

Then use `_pre_w` instead of `line_w`:

```bash
ctx_remaining=$(( COLUMNS - _pre_w - sep_visible_w - ctx_label_overhead ))
if [ "$_pre_w" -gt 0 ] && [ "$ctx_remaining" -lt "$BAR_W" ] && [ "$ctx_remaining" -ge 8 ]; then
    ctx_bar_w=$ctx_remaining
fi
```

- [ ] **Step 2: Apply same logic to 5h usage bar**

Replace the `# Segment 6: 5-hour usage bar` block with:

```bash
# Segment 6: 5-hour usage bar (adaptive width)
if [ -n "$usage_5h" ]; then
    usage_pct=$(printf "%.0f" "$usage_5h" 2>/dev/null || echo "$usage_5h")
    resets_fmt=$(fmt_resets "$usage_resets")
    # Overhead: "5h " (3) + " " (1) + pct "XX%" (3-4) + " " (1) + resets (~5) ≈ 14
    usage_label_overhead=14
    usage_bar_w=$BAR_W

    # Re-compute cumulative width including segment 5
    _pre_w=0
    for _s in "${segments[@]}"; do
        [ "$_pre_w" -gt 0 ] && _pre_w=$(( _pre_w + sep_visible_w ))
        _pre_w=$(( _pre_w + $(visible_len "$_s") ))
    done

    usage_remaining=$(( COLUMNS - _pre_w - sep_visible_w - usage_label_overhead ))
    if [ "$_pre_w" -gt 0 ] && [ "$usage_remaining" -lt "$BAR_W" ] && [ "$usage_remaining" -ge 8 ]; then
        usage_bar_w=$usage_remaining
    fi

    usage_bar=$(build_bar "$usage_pct" "$usage_bar_w")
    usage_seg="${C_LABEL}5h${C_R} ${usage_bar}"
    [ -n "$resets_fmt" ] && usage_seg+=" ${C_LABEL}${resets_fmt}${C_R}"
    segments+=("$usage_seg")
fi
```

- [ ] **Step 3: Test adaptive bar shrinking**

```bash
COLUMNS=90 bash -c 'echo "{\"model\":{\"display_name\":\"Opus 4.6\"},\"cwd\":\"/home/limx/Desktop/claude-code-config\",\"context_window\":{\"used_percentage\":75,\"context_window_size\":200000}}" | bash ~/.claude/hooks/statusline.sh'
```

Expected: Progress bars are shorter than 20 chars when they would cause a wrap. Bars should never be shorter than 8 chars.

- [ ] **Step 4: Test that bar stays full width when terminal is wide**

```bash
COLUMNS=200 bash -c 'echo "{\"model\":{\"display_name\":\"Opus 4.6\"},\"cwd\":\"/home/limx/Desktop/claude-code-config\",\"context_window\":{\"used_percentage\":75,\"context_window_size\":200000}}" | bash ~/.claude/hooks/statusline.sh'
```

Expected: Full 20-char progress bars, all on one line.

- [ ] **Step 5: Commit**

```bash
cd ~/Desktop/claude-code-config
git add -A
git commit -m "feat(statusline): adaptive progress bar width based on available space"
```

---

### Task 5: Final integration test and cleanup

**Files:**
- Modify: `~/.claude/hooks/statusline.sh` (verify final state)

- [ ] **Step 1: Remove the old `sep` variable definition**

The old separator variable at line 258 (`sep="${C_SEP} \xe2\x94\x82 $C_R"`) is now unused (replaced by `sep_str` in the wrap loop). Delete it:

```bash
# Delete this line (was line 258):
sep="${C_SEP} \xe2\x94\x82 $C_R"
```

- [ ] **Step 2: Remove old conda/venv variable assignments**

The conda/venv variable assignments that were at lines 268-271 are now inside the segment array block. Verify there are no duplicate assignments. If the old ones at lines 268-271 still exist, delete them.

- [ ] **Step 3: Full integration test — multiple widths**

```bash
INPUT='{"model":{"display_name":"Opus 4.6"},"cwd":"/home/limx/Desktop/claude-code-config","context_window":{"used_percentage":65,"context_window_size":200000}}'

echo "=== 200 cols (single line) ==="
COLUMNS=200 bash -c "echo '$INPUT' | bash ~/.claude/hooks/statusline.sh"
echo ""
echo ""

echo "=== 100 cols (two lines expected) ==="
COLUMNS=100 bash -c "echo '$INPUT' | bash ~/.claude/hooks/statusline.sh"
echo ""
echo ""

echo "=== 60 cols (multi-wrap expected) ==="
COLUMNS=60 bash -c "echo '$INPUT' | bash ~/.claude/hooks/statusline.sh"
echo ""
echo ""

echo "=== 40 cols (heavy wrap / truncation) ==="
COLUMNS=40 bash -c "echo '$INPUT' | bash ~/.claude/hooks/statusline.sh"
echo ""
```

Expected:
- 200 cols: single line, full bars
- 100 cols: wraps to 2 lines, bars may shrink slightly
- 60 cols: wraps to 2-3 lines, bars shrink to ~8-10 chars
- 40 cols: heavy wrapping, terminal may truncate longest segments

- [ ] **Step 4: Verify Claude Code renders correctly**

Open Claude Code in a terminal and resize the window. The statusline should dynamically adapt on each render cycle.

- [ ] **Step 5: Commit final cleanup**

```bash
cd ~/Desktop/claude-code-config
git add -A
git commit -m "chore(statusline): remove unused variables and final cleanup"
```
