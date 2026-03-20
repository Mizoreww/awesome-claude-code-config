#!/usr/bin/env bash
# Claude Code status line — gradient progress bars
# Shows: model, dir, git branch, context window, 5h usage (from API)

# Cross-platform home directory (Windows $HOME may be wrong)
_HOME="${USERPROFILE:-$HOME}"

# Ensure jq is available (check ~/.claude/bin/ for Windows installs)
if ! command -v jq &>/dev/null; then
    for _p in "$_HOME/.claude/bin/jq.exe" "$_HOME/.claude/bin/jq"; do
        if [ -x "$_p" ]; then
            export PATH="$(dirname "$_p"):$PATH"
            break
        fi
    done
fi
if ! command -v jq &>/dev/null; then
    printf "Claude (jq not found - run installer or install jq)"
    exit 0
fi

input=$(cat)

# --- Extract fields ---
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
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

# --- 5-hour usage from API (non-blocking, async refresh) ---
# Strategy: statusline ONLY reads from cache (never blocks on network).
# If cache is stale, a background process refreshes it for next render.
_TMPDIR="${TMPDIR:-${TMP:-/tmp}}"
USAGE_CACHE="$_TMPDIR/claude-usage-cache.json"
USAGE_LOCK="$_TMPDIR/claude-usage-fetch.lock"
CACHE_TTL=60
CACHE_MAX_AGE=600  # 10min — don't display data older than this
usage_5h=""
usage_resets=""

# Background fetch: updates cache file, never blocks the statusline
bg_fetch_usage() {
    # Prevent concurrent fetches
    if [ -f "$USAGE_LOCK" ]; then
        local lock_age lock_mtime
        lock_mtime=$(stat -c %Y "$USAGE_LOCK" 2>/dev/null || stat -f %m "$USAGE_LOCK" 2>/dev/null || echo 0)
        lock_age=$(( $(date +%s) - lock_mtime ))
        # Stale lock (>30s) — remove and continue
        [ "$lock_age" -lt 30 ] && return
    fi
    echo $$ > "$USAGE_LOCK"

    local token kc_json
    # 1) macOS Keychain
    kc_json=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
    # 2) Linux libsecret (GNOME Keyring / KWallet)
    [ -z "$kc_json" ] && kc_json=$(secret-tool lookup service "Claude Code-credentials" 2>/dev/null)
    # 3) Windows Credential Manager (Git Bash / MSYS2)
    if [ -z "$kc_json" ] && command -v powershell.exe &>/dev/null; then
        kc_json=$(powershell.exe -NoProfile -NoLogo -Command '
            try {
                $cred = Get-StoredCredential -Target "Claude Code-credentials" -ErrorAction Stop
                if ($cred) { [System.Net.NetworkCredential]::new("", $cred.Password).Password }
            } catch {
                try {
                    Add-Type -AssemblyName System.Security
                    $path = Join-Path $env:LOCALAPPDATA "claude-code\credentials.json"
                    if (Test-Path $path) { Get-Content $path -Raw }
                } catch {}
            }
        ' 2>/dev/null)
    fi
    if [ -n "$kc_json" ]; then
        token=$(echo "$kc_json" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
    fi
    # 3) Fall back to credentials file
    if [ -z "$token" ]; then
        local creds="$_HOME/.claude/.credentials.json"
        [ -f "$creds" ] || { rm -f "$USAGE_LOCK"; return; }
        token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds" 2>/dev/null)
    fi
    if [ -z "$token" ]; then
        rm -f "$USAGE_LOCK"
        return
    fi

    local api_result http_code
    # Inherit proxy from environment (all_proxy, https_proxy, etc.)
    http_code=$(curl -s -o "$USAGE_CACHE.tmp" -w '%{http_code}' \
        --connect-timeout 2 --max-time 5 \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -H "User-Agent: claude-code/2.1.71" \
        -H "anthropic-beta: oauth-2025-04-20" \
        "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

    if [ "$http_code" = "200" ] && [ -s "$USAGE_CACHE.tmp" ] \
        && jq -e '.five_hour' "$USAGE_CACHE.tmp" &>/dev/null; then
        mv -f "$USAGE_CACHE.tmp" "$USAGE_CACHE" 2>/dev/null
        rm -f "$USAGE_CACHE.err"
    else
        rm -f "$USAGE_CACHE.tmp"
        # Negative cache: record failure timestamp to avoid hammering API
        echo "$http_code" > "$USAGE_CACHE.err" 2>/dev/null
    fi
    rm -f "$USAGE_LOCK"
}

# Read from cache (instant, no network)
now=$(date +%s)
cache_is_fresh=false
if [ -f "$USAGE_CACHE" ]; then
    cache_mtime=$(stat -c %Y "$USAGE_CACHE" 2>/dev/null || stat -f %m "$USAGE_CACHE" 2>/dev/null || echo 0)
    cache_age=$(( now - cache_mtime ))
    if [ "$cache_age" -lt "$CACHE_TTL" ]; then
        cache_is_fresh=true
    fi
    # Display from cache only if not too old
    if [ "$cache_age" -lt "$CACHE_MAX_AGE" ]; then
        usage_5h=$(jq -r '.five_hour.utilization // empty' "$USAGE_CACHE" 2>/dev/null)
        usage_resets=$(jq -r '.five_hour.resets_at // empty' "$USAGE_CACHE" 2>/dev/null)
    fi
fi

# If cache is stale or missing, trigger async background refresh
# But respect negative cache: skip if last failure was < 5 min ago
if ! $cache_is_fresh; then
    _should_fetch=true
    if [ -f "$USAGE_CACHE.err" ]; then
        _err_mtime=$(stat -c %Y "$USAGE_CACHE.err" 2>/dev/null || stat -f %m "$USAGE_CACHE.err" 2>/dev/null || echo 0)
        _err_age=$(( now - _err_mtime ))
        [ "$_err_age" -lt 300 ] && _should_fetch=false
    fi
    if $_should_fetch; then
        bg_fetch_usage &>/dev/null &
        disown 2>/dev/null
    fi
fi

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
    local pct=$1 w=$BAR_W
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

# Format reset time as relative
fmt_resets() {
    local resets_at="$1"
    [ -z "$resets_at" ] && return
    # Strip microseconds and timezone offset, treat as UTC
    # "2026-03-05T13:00:00.293168+00:00" -> "2026-03-05T13:00:00"
    local clean
    clean=$(echo "$resets_at" | sed 's/\.[0-9]*//; s/[+-][0-9][0-9]:[0-9][0-9]$//; s/Z$//')
    local reset_epoch
    # macOS: TZ=UTC date -j -f, Linux: date -d (handles ISO natively)
    reset_epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$clean" +%s 2>/dev/null \
        || date -d "$resets_at" +%s 2>/dev/null) || return
    local diff=$(( reset_epoch - now ))
    [ "$diff" -le 0 ] && { echo "now"; return; }
    local h=$(( diff / 3600 )) m=$(( diff % 3600 / 60 ))
    if [ "$h" -gt 0 ]; then
        echo "${h}h${m}m"
    else
        echo "${m}m"
    fi
}

# --- Separator ---
sep="${C_SEP} \xe2\x94\x82 $C_R"

# --- Assemble (single line) ---
out="${ICON_MODEL} ${C_MODEL}${model}${C_R}"

if [ -n "$dir_name" ]; then
    out+="${sep}${ICON_DIR} ${C_DIR}${dir_name}${C_R}"
fi

# Virtual environment (conda > venv/poetry/pipenv)
conda_env="${CONDA_DEFAULT_ENV:-}"
conda_env="$(basename "$conda_env")"
venv="${VIRTUAL_ENV:-}"
venv="$(basename "$venv")"

if [ -n "$conda_env" ]; then
    out+="${sep}${ICON_CONDA} ${C_CONDA}${conda_env}${C_R}"
elif [ -n "$venv" ]; then
    out+="${sep}${ICON_CONDA} ${C_CONDA}${venv}${C_R}"
fi

if [ -n "$git_branch" ]; then
    out+="${sep}${C_GIT}${ICON_GIT} ${git_branch}${C_R}"
fi

# Context bar
ctx_pct_int=$(printf "%.0f" "$ctx_pct" 2>/dev/null || echo "$ctx_pct")
ctx_bar=$(build_bar "$ctx_pct_int")
ctx_fmt=$(fmt_ctx "$ctx_size")
out+="${sep}${C_LABEL}context${C_R} ${ctx_bar} ${C_LABEL}${ctx_fmt}${C_R}"

# 5-hour usage bar (from API)
if [ -n "$usage_5h" ]; then
    usage_pct=$(printf "%.0f" "$usage_5h" 2>/dev/null || echo "$usage_5h")
    usage_bar=$(build_bar "$usage_pct")
    resets_fmt=$(fmt_resets "$usage_resets")
    out+="${sep}${C_LABEL}5h${C_R} ${usage_bar}"
    [ -n "$resets_fmt" ] && out+=" ${C_LABEL}${resets_fmt}${C_R}"
fi

printf "%b" "$out"
