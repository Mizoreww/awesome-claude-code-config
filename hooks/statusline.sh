#!/usr/bin/env bash
# Cursor CLI status line — gradient progress bars
# Shows: model, dir, conda/venv, git branch, context window
#
# Reads the StatusLinePayload JSON on stdin. Cursor's payload is aligned with
# Claude Code's (same model.display_name, cwd, context_window.used_percentage,
# context_window.context_window_size), so these segments work unchanged.

# Cross-platform home directory (Windows $HOME may be wrong)
_HOME="${USERPROFILE:-$HOME}"
# Where this script lives, so a custom install dir (--prefix / CURSOR_HOME) still
# finds its bundled jq. Falls back to ~/.cursor for the default install.
_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "$_HOME/.cursor")"

# Ensure jq is available (prefer the copy bundled next to this script, then ~/.cursor/bin)
if ! command -v jq &>/dev/null; then
    for _p in "$_SELF_DIR/bin/jq" "$_SELF_DIR/bin/jq.exe" "$_HOME/.cursor/bin/jq" "$_HOME/.cursor/bin/jq.exe"; do
        if [ -x "$_p" ]; then
            export PATH="$(dirname "$_p"):$PATH"
            break
        fi
    done
fi
if ! command -v jq &>/dev/null; then
    printf "Cursor (jq not found - run installer or install jq)"
    exit 0
fi

input=$(cat)

# --- Extract fields ---
model=$(echo "$input" | jq -r '.model.display_name // "Cursor"')
cwd=$(echo "$input" | jq -r '.cwd // ""')
dir_name=$(basename "$cwd")

# Context window
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')

# Git branch
git_branch=""
if git -C "$cwd" rev-parse --is-inside-work-tree --no-optional-locks 2>/dev/null | grep -q true; then
    git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null || echo "")
fi

# --- Icon detection ---
_use_emoji=false
# Non-Windows: check UTF-8 locale
if [ -z "${USERPROFILE:-}" ]; then
    case "${LANG:-}${LC_ALL:-}${LC_CTYPE:-}" in
        *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) _use_emoji=true ;;
    esac
else
    # Windows: only enable emoji for terminals known to support Unicode
    # WT_SESSION  = Windows Terminal
    # MSYSTEM     = Git Bash / mintty (MINGW64, MINGW32, MSYS, etc.)
    # TERM_PROGRAM whitelist: vscode (VS Code integrated terminal)
    if [ -n "${WT_SESSION:-}" ] || [ -n "${MSYSTEM:-}" ]; then
        _use_emoji=true
    fi
    case "${TERM_PROGRAM:-}" in
        vscode) _use_emoji=true ;;
    esac
fi
# Always disable for known dumb terminals
case "${TERM:-dumb}" in
    dumb|linux|vt100|vt220) _use_emoji=false ;;
esac

if $_use_emoji; then
    ICON_MODEL="\xf0\x9f\xa7\xa0"     # 🧠
    ICON_DIR="\xf0\x9f\x93\x82"       # 📂
    ICON_CONDA="\xf0\x9f\x90\x8d"     # 🐍
    ICON_GIT="\xe2\x8e\x87"           # ⎇ (standard Unicode, safe everywhere)
else
    ICON_MODEL="M:"
    ICON_DIR="D:"
    ICON_CONDA="py:"
    ICON_GIT="br:"
fi

# --- Terminal width ---
# Cursor runs statusline in a pipe (no tty on stdin), so $COLUMNS
# and `tput cols` are unreliable. Probe the real terminal via /dev/pts/*.
_get_term_width() {
    # 1) $COLUMNS if set and positive
    local c="${COLUMNS:-0}"
    [[ "$c" =~ ^[0-9]+$ ]] && [ "$c" -gt 0 ] && { echo "$c"; return; }

    # 2) Walk ancestor process fds to find the real terminal (Linux)
    local _pid=$$
    while [ "$_pid" -gt 1 ] 2>/dev/null; do
        for _fd in /proc/"$_pid"/fd/*; do
            [ -e "$_fd" ] || continue
            local _tgt
            _tgt=$(readlink "$_fd" 2>/dev/null) || continue
            case "$_tgt" in /dev/pts/*|/dev/tty*)
                c=$(stty size < "$_tgt" 2>/dev/null | awk '{print $2}')
                [[ "$c" =~ ^[0-9]+$ ]] && [ "$c" -gt 0 ] && { echo "$c"; return; }
            esac
        done
        _pid=$(awk '{print $4}' /proc/"$_pid"/stat 2>/dev/null) || break
    done

    # 3) Try tput cols as last resort before fallback
    c=$(tput cols 2>/dev/null)
    [[ "$c" =~ ^[0-9]+$ ]] && [ "$c" -gt 0 ] && { echo "$c"; return; }

    # 4) Fallback
    echo 120
}
COLUMNS=$(_get_term_width)

# visible_len: compute display width of a string with ANSI escapes
# Strips escape codes, then uses wc -L for accurate multi-byte/emoji width
visible_len() {
    local stripped w
    stripped=$(printf "%b" "$1" | sed $'s/\x1b\[[0-9;]*[a-zA-Z]//g')
    # wc -L gives display width (handles CJK/emoji double-width) — GNU only
    w=$(printf "%b" "$stripped" | wc -L 2>/dev/null | tr -d ' ')
    # Fallback for macOS/BSD where wc -L is unavailable
    if [ -z "$w" ] || [ "$w" -eq 0 ] 2>/dev/null; then
        w=${#stripped}
    fi
    echo "$w"
}

# --- Colors ---
C_MODEL="\033[38;5;183m"
C_DIR="\033[38;5;117m"
C_GIT="\033[38;5;116m"
C_SEP="\033[38;5;240m"
C_LABEL="\033[38;5;250m"
C_CONDA="\033[38;5;113m"   # soft green (Python/conda)
C_R="\033[0m"

# Gradient: soft green -> green -> yellow-green -> yellow -> orange -> red -> dark red
bar_colors=(71 72 78 114 150 186 222 221 220 214 208 202 196 160 124 88)
BAR_W=20

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

# Format context size
fmt_ctx() {
    local s=${1:-0}
    if [ "$s" -ge 1000000 ]; then
        echo "$(( s / 1000 / 1000 )).$(( s / 1000 % 1000 / 100 ))M"
    elif [ "$s" -ge 1000 ]; then
        echo "$(( s / 1000 ))k"
    else
        echo "$s"
    fi
}

# --- Assemble segments ---
segments=()
sep_visible_w=3  # " │ " is 3 visible characters

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

# Pre-compute widths of all segments (cached for reuse)
_seg_widths=()
_pre_w=0
for _s in "${segments[@]}"; do
    local_w=$(visible_len "$_s")
    local_w=${local_w:-0}
    _seg_widths+=("$local_w")
    [ "$_pre_w" -gt 0 ] && _pre_w=$(( _pre_w + sep_visible_w ))
    _pre_w=$(( _pre_w + local_w ))
done

# Segment 5: Context bar (adaptive width)
ctx_pct_int=$(printf "%.0f" "$ctx_pct" 2>/dev/null || echo "$ctx_pct")
ctx_fmt=$(fmt_ctx "$ctx_size")
# Estimate overhead: "context " (8) + " " (1) + pct "XX%" (3-4) + " " (1) + ctx_fmt (~4) ≈ 18
ctx_label_overhead=18
ctx_bar_w=$BAR_W
ctx_remaining=$(( COLUMNS - _pre_w - sep_visible_w - ctx_label_overhead ))
if [ "$ctx_remaining" -lt "$BAR_W" ]; then
    ctx_bar_w=$(( ctx_remaining >= 8 ? ctx_remaining : BAR_W ))
fi
ctx_bar=$(build_bar "$ctx_pct_int" "$ctx_bar_w")
_ctx_seg="${C_LABEL}context${C_R} ${ctx_bar} ${C_LABEL}${ctx_fmt}${C_R}"
segments+=("$_ctx_seg")
_ctx_w=$(visible_len "$_ctx_seg"); _ctx_w=${_ctx_w:-0}
_seg_widths+=("$_ctx_w")

# --- Wrap algorithm ---
sep_str="${C_SEP} \xe2\x94\x82 ${C_R}"

out=""
line_w=0

_seg_idx=0
for seg in "${segments[@]}"; do
    seg_w=${_seg_widths[$_seg_idx]:-0}
    _seg_idx=$(( _seg_idx + 1 ))
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
