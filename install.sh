#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Awesome Claude Code Configuration Installer
# https://github.com/Mizoreww/awesome-claude-code-config
# ============================================================

CLAUDE_DIR="$HOME/.claude"
REPO_URL="https://github.com/Mizoreww/awesome-claude-code-config"
VERSION_STAMP_FILE="$CLAUDE_DIR/.awesome-claude-code-config-version"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Retry wrapper: retry <max_attempts> <delay_seconds> <description> <command...>
# Returns 0 on success, 1 if all attempts fail.
retry() {
    local max_attempts="$1"; shift
    local delay="$1"; shift
    local description="$1"; shift
    local attempt=1

    while (( attempt <= max_attempts )); do
        if "$@" ; then
            return 0
        fi
        if (( attempt < max_attempts )); then
            warn "$description failed (attempt $attempt/$max_attempts), retrying in ${delay}s..."
            sleep "$delay"
        else
            warn "$description failed after $max_attempts attempts, skipping."
        fi
        (( attempt++ ))
    done
    return 1
}

# Install jq if not available (needed for settings merge & statusline)
install_jq() {
    command -v jq &>/dev/null && return 0
    # Check ~/.claude/bin/jq
    if [[ -x "$CLAUDE_DIR/bin/jq" ]]; then
        export PATH="$CLAUDE_DIR/bin:$PATH"; return 0
    fi

    if $DRY_RUN; then
        info "Would install jq (not found in PATH or $CLAUDE_DIR/bin/)"
        return 0
    fi

    info "jq not found, attempting to install..."

    # 1) Download pre-built binary (no sudo, preferred for CI/headless)
    local os arch
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    case "$os" in darwin) os="macos";; linux) os="linux";; esac
    arch="$(uname -m)"
    case "$arch" in x86_64) arch="amd64";; aarch64|arm64) arch="arm64";; esac

    if [[ -n "${os:-}" && -n "${arch:-}" ]]; then
        local url="https://github.com/jqlang/jq/releases/latest/download/jq-${os}-${arch}"
        mkdir -p "$CLAUDE_DIR/bin"
        if curl -fsSL "$url" -o "$CLAUDE_DIR/bin/jq" 2>/dev/null || \
           wget -qO "$CLAUDE_DIR/bin/jq" "$url" 2>/dev/null; then
            chmod +x "$CLAUDE_DIR/bin/jq"
            export PATH="$CLAUDE_DIR/bin:$PATH"
            ok "jq installed to $CLAUDE_DIR/bin/jq"
            return 0
        fi
    fi

    # 2) Package manager chain (fallback, may need sudo)
    if command -v brew &>/dev/null; then
        brew install jq &>/dev/null && { ok "jq installed via brew"; return 0; }
    fi
    if command -v sudo &>/dev/null; then
        for pm_cmd in "apt-get install -y jq" "dnf install -y jq" \
                      "yum install -y jq" "pacman -S --noconfirm jq" "apk add jq"; do
            local pm="${pm_cmd%% *}"
            command -v "$pm" &>/dev/null && sudo $pm_cmd &>/dev/null && { ok "jq installed via $pm"; return 0; }
        done
    fi

    warn "Could not install jq automatically"
    return 1
}

# Install JetBrainsMono Nerd Font for statusline icons
install_nerd_font() {
    # Check if already installed (fc-list first — more reliable than filename glob)
    if command -v fc-list &>/dev/null; then
        if fc-list 2>/dev/null | grep -qi "JetBrainsMono.*Nerd"; then
            return 0
        fi
    fi
    local font_dir
    case "$(uname -s)" in
        Darwin) font_dir="$HOME/Library/Fonts" ;;
        *)      font_dir="$HOME/.local/share/fonts" ;;
    esac
    # Fallback: check by font files directly (works without fontconfig)
    if ls "$font_dir"/JetBrainsMonoNerd* &>/dev/null 2>&1; then
        return 0
    fi

    if $DRY_RUN; then
        info "Would download and install JetBrainsMono Nerd Font"
        return 0
    fi

    info "Installing JetBrainsMono Nerd Font for statusline icons..."
    mkdir -p "$font_dir"

    local tmpzip
    tmpzip="$(mktemp -t nerd-font-XXXXXX.zip 2>/dev/null || mktemp /tmp/nerd-font-XXXXXX.zip)"
    local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"

    if curl --connect-timeout 10 --max-time 120 -fsSL "$url" -o "$tmpzip" 2>/dev/null || \
       wget --connect-timeout=10 --timeout=120 -qO "$tmpzip" "$url" 2>/dev/null; then
        if command -v unzip &>/dev/null; then
            unzip -oq "$tmpzip" -d "$font_dir" '*.ttf' 2>/dev/null
        else
            warn "unzip not found — cannot extract Nerd Font"
            rm -f "$tmpzip"
            return 1
        fi
        rm -f "$tmpzip"
        # Verify extraction succeeded
        if ! ls "$font_dir"/JetBrainsMonoNerd* &>/dev/null 2>&1; then
            warn "Nerd Font extraction failed — no font files found"
            return 1
        fi
        # Refresh font cache
        if command -v fc-cache &>/dev/null; then
            fc-cache -f "$font_dir" 2>/dev/null || true
        fi
        ok "JetBrainsMono Nerd Font installed to $font_dir"
        warn "Set your terminal font to 'JetBrainsMono Nerd Font' for best icon display"
        return 0
    fi

    rm -f "$tmpzip"
    warn "Could not download Nerd Font — statusline will use text fallback"
    return 1
}

# --- Remote install detection -------------------------------------------

detect_script_dir() {
    local candidate
    candidate="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if [[ -f "$candidate/CLAUDE.md" ]]; then
        # Running from a local clone
        SCRIPT_DIR="$candidate"
        REMOTE_MODE=false
    else
        # Remote mode: download tarball to temp dir
        REMOTE_MODE=true
        local tmpdir
        tmpdir="$(mktemp -d)"
        trap 'rm -rf "$tmpdir"' EXIT

        local version="${VERSION:-main}"
        # Sanitize VERSION to prevent command injection
        if [[ ! "$version" =~ ^[a-zA-Z0-9._-]+$ ]]; then
            error "Invalid VERSION value: $version (only alphanumeric, dots, hyphens, underscores allowed)"
            exit 1
        fi
        local tarball_url="$REPO_URL/archive/refs/heads/${version}.tar.gz"
        # If version looks like a tag (v1.0.0), use tags URL
        if [[ "$version" =~ ^v[0-9] ]]; then
            tarball_url="$REPO_URL/archive/refs/tags/${version}.tar.gz"
        fi

        info "Remote mode: downloading $version..."
        local download_cmd
        if command -v curl &>/dev/null; then
            download_cmd="curl -fsSL $tarball_url"
        elif command -v wget &>/dev/null; then
            download_cmd="wget -qO- $tarball_url"
        else
            error "Neither curl nor wget found. Install one and retry."
            exit 1
        fi

        if ! retry 5 3 "Download source tarball" bash -c "$download_cmd | tar xz -C '$tmpdir' --strip-components=1"; then
            error "Failed to download source after retries. Cannot continue in remote mode."
            exit 1
        fi

        SCRIPT_DIR="$tmpdir"
        ok "Source downloaded to temporary directory"
    fi
}

# --- Version management -------------------------------------------------

get_source_version() {
    if [[ -f "$SCRIPT_DIR/VERSION" ]]; then
        cat "$SCRIPT_DIR/VERSION" | tr -d '[:space:]'
    else
        echo "unknown"
    fi
}

get_installed_version() {
    if [[ -f "$VERSION_STAMP_FILE" ]]; then
        cat "$VERSION_STAMP_FILE" | tr -d '[:space:]'
    else
        echo "not installed"
    fi
}

get_remote_version() {
    local url="https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/main/VERSION"
    local result=""
    _fetch_version() {
        if command -v curl &>/dev/null; then
            result="$(curl -fsSL "$url" 2>/dev/null | tr -d '[:space:]')"
        elif command -v wget &>/dev/null; then
            result="$(wget -qO- "$url" 2>/dev/null | tr -d '[:space:]')"
        else
            return 1
        fi
        [[ -n "$result" ]]
    }
    if retry 5 2 "Fetch remote version" _fetch_version; then
        echo "$result"
    else
        echo "unavailable"
    fi
}

show_version() {
    local source_ver installed_ver remote_ver
    source_ver="$(get_source_version)"
    installed_ver="$(get_installed_version)"
    remote_ver="$(get_remote_version)"

    echo "awesome-claude-code-config version info:"
    echo "  Source:    $source_ver"
    echo "  Installed: $installed_ver"
    echo "  Remote:    $remote_ver"

    if [[ "$installed_ver" != "not installed" && "$remote_ver" != "unavailable" \
          && "$installed_ver" != "$remote_ver" ]]; then
        warn "Update available: $installed_ver -> $remote_ver"
    fi
}

stamp_version() {
    local ver
    ver="$(get_source_version)"
    if [[ "$ver" != "unknown" ]]; then
        echo "$ver" > "$VERSION_STAMP_FILE"
    fi
}

# --- Helpers ------------------------------------------------------------

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install Claude Code configuration files.

Running without options launches an interactive component selector.
Works with both local and piped installs (curl | bash).

Options:
    --all               Install everything (non-interactive)
    --uninstall         Remove all installed files
    --version           Show version info
    --dry-run           Show what would be installed without doing it
    --force             Skip confirmation prompts
    -h, --help          Show this help

Examples:
    $(basename "$0")                                 # Interactive selector
    $(basename "$0") --all                           # Install everything
    $(basename "$0") --uninstall                     # Uninstall everything
    $(basename "$0") --dry-run --all                 # Preview full install
    bash <(curl -fsSL $REPO_URL/raw/main/install.sh)        # Remote install (interactive)
    bash <(curl -fsSL $REPO_URL/raw/main/install.sh) --all  # Remote install (everything)
EOF
}

# --- Flags & state ------------------------------------------------------

DRY_RUN=false
INSTALL_ALL=false
EXPLICIT_ALL=false
INSTALL_WARNINGS=0
INSTALL_RULES=false
INSTALL_SKILLS=false
INSTALL_LESSONS=false
INSTALL_STATUSLINE=false
INSTALL_MCP=false
INSTALL_PLUGINS=false
INSTALL_CLAUDE_MD=false
INSTALL_SETTINGS=false
UNINSTALL=false
FORCE=false
SHOW_VERSION=false
INTERACTIVE=false
RULE_LANGS=()
RULE_LANGS_EXPLICIT=false
PLUGIN_GROUPS=()

# --- Plugin groups ------------------------------------------------------

PLUGINS_ESSENTIAL=(
    "everything-claude-code@everything-claude-code"
    "superpowers@claude-plugins-official"
    "code-review@claude-plugins-official"
    "context7@claude-plugins-official"
    "commit-commands@claude-plugins-official"
    "document-skills@anthropic-agent-skills"
    "playwright@claude-plugins-official"
    "feature-dev@claude-plugins-official"
    "code-simplifier@claude-plugins-official"
    "ralph-loop@claude-plugins-official"
    "frontend-design@claude-plugins-official"
    "example-skills@anthropic-agent-skills"
    "github@claude-plugins-official"
)

PLUGINS_CLAUDE_MEM=(
    "claude-mem@thedotmack"
)

PLUGINS_AI_RESEARCH=(
    "tokenization@ai-research-skills"
    "fine-tuning@ai-research-skills"
    "post-training@ai-research-skills"
    "inference-serving@ai-research-skills"
    "distributed-training@ai-research-skills"
    "optimization@ai-research-skills"
)

PLUGINS_HEALTH=(
    "health@claude-health"
)

# --- Terminal detection (single source of truth) -----------------------

# Can we interact with a human? Returns 0 if stdout is a tty AND we can
# read keyboard input (either stdin is a tty or /dev/tty is accessible).
can_interact() {
    [[ -t 1 ]] && { [[ -t 0 ]] || [[ -r /dev/tty ]]; }
}

# --- Argument parsing ---------------------------------------------------

parse_args() {
    if [[ $# -eq 0 ]]; then
        # No args: interactive mode if terminal available (including piped installs
        # like "curl | bash" where /dev/tty is still accessible), else install all
        if can_interact; then
            INTERACTIVE=true
        else
            INSTALL_ALL=true
        fi
        return
    fi

    local has_action=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all)
                INSTALL_ALL=true
                EXPLICIT_ALL=true
                has_action=true
                shift
                ;;
            --uninstall)
                UNINSTALL=true
                has_action=true
                shift
                ;;
            --version)
                SHOW_VERSION=true
                has_action=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                error "Run '$(basename "$0") --help' for available options."
                exit 1
                ;;
        esac
    done

    # Only modifier flags (--dry-run, --force) with no action
    if ! $has_action; then
        if can_interact; then
            INTERACTIVE=true
        else
            INSTALL_ALL=true
        fi
    fi
}

# --- Interactive menu ---------------------------------------------------

interactive_menu() {
    # Open a file descriptor for keyboard input.
    # Prefer stdin when it's a real tty (normal execution); fall back to /dev/tty
    # for piped installs (curl | bash) where stdin carries the script.
    if [[ -t 0 ]]; then
        exec 3<&0
    elif ! exec 3</dev/tty 2>/dev/null; then
        warn "Cannot open terminal for interactive input, falling back to default install"
        INSTALL_ALL=true
        return
    fi

    # Item format: "label|description|default_on|id"
    local items=(
        "CLAUDE.md|Global instructions template|1|claude-md"
        "settings.json|Smart-merged Claude Code settings|1|settings"
        "Common rules|Coding style, git, security, testing|1|rules-common"
        "StatusLine|Gradient progress bar & usage display|1|statusline"
        "Lessons|lessons.md template + SessionStart hook|1|lessons"
        "Custom skills|adversarial-review, paper-reading, humanizer|1|skills"
        "Python rules|PEP 8, pytest, type hints, bandit|0|rules-python"
        "TypeScript rules|Zod, Playwright, immutability|0|rules-ts"
        "Go rules|gofmt, table-driven tests, gosec|0|rules-go"
        "Plugins (13)|superpowers, code-review, playwright, feature-dev...|1|plugins-essential"
        "claude-mem|Cross-session memory (~3k tokens/session)|0|plugins-claude-mem"
        "AI Research plugins|fine-tuning, inference, optimization...|0|plugins-ai-research"
        "claude-health|Health check & wellness dashboard|0|plugins-health"
        "Lark MCP server|Feishu/Lark integration|0|mcp"
    )

    local n=${#items[@]}
    local selected=()
    local cursor=0

    # Initialize selections from defaults
    local i
    for (( i=0; i<n; i++ )); do
        local _f1 _f2 _def _f4
        IFS='|' read -r _f1 _f2 _def _f4 <<< "${items[$i]}"
        selected[$i]="$_def"
    done

    # Group definitions: start|end|label|hint
    local groups=(
        "0|5|Core|"
        "6|8|Language Rules|only install what your projects need"
        "9|11|Plugins|"
        "12|12|MCP Servers|"
    )

    # Save terminal state (operate on fd 3 which points to the actual tty)
    local saved_stty
    saved_stty=$(stty -g <&3 2>/dev/null) || saved_stty=""

    _menu_cleanup() {
        printf '\033[?1049l' 2>/dev/null
        [[ -n "$saved_stty" ]] && stty "$saved_stty" <&3 2>/dev/null || stty echo <&3 2>/dev/null || true
        tput cnorm 2>/dev/null || printf '\033[?25h'
        exec 3<&- 2>/dev/null || true
    }
    trap '_menu_cleanup; exit 0' INT TERM

    _read_key() {
        local key
        IFS= read -r -s -n 1 key <&3 2>/dev/null || true

        if [[ "$key" == $'\033' ]]; then
            local rest=""
            IFS= read -r -s -n 2 -t 1 rest <&3 2>/dev/null || true
            case "$rest" in
                '[A') echo "UP" ;;
                '[B') echo "DOWN" ;;
                *)    echo "OTHER" ;;
            esac
            return
        fi

        case "$key" in
            '')     echo "ENTER" ;;
            ' ')    echo "SPACE" ;;
            a|A)    echo "ALL" ;;
            n|N)    echo "NONE" ;;
            d|D)    echo "DEFAULT" ;;
            q|Q)    echo "QUIT" ;;
            j|J)    echo "DOWN" ;;
            k|K)    echo "UP" ;;
            *)      echo "OTHER" ;;
        esac
    }

    _draw_menu() {
        local buf=""
        # Move cursor home (no clear - overwrite in place to prevent flicker)
        buf+='\033[H'
        # Header
        buf+='\033[K\n'
        buf+='  \033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\033[K\n'
        buf+="    \033[1;36mAwesome Claude Code Config Installer\033[0m  \033[2m${_cached_version}\033[0m\033[K\n"
        buf+='  \033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\033[K\n'
        buf+='\033[K\n'
        buf+='  \033[2m↑/↓ Navigate   Space Toggle   Enter Submit\033[0m\033[K\n'
        buf+='  \033[2ma All   n None   d Defaults   q Quit\033[0m\033[K\n'
        buf+='\033[K\n'

        for group_def in "${groups[@]}"; do
            local g_start g_end g_label g_hint
            IFS='|' read -r g_start g_end g_label g_hint <<< "$group_def"

            if [[ -n "$g_hint" ]]; then
                buf+="  \033[1;36m${g_label}\033[0m  \033[2m(${g_hint})\033[0m\033[K\n"
            else
                buf+="  \033[1;36m${g_label}\033[0m\033[K\n"
            fi

            local j
            for (( j=g_start; j<=g_end; j++ )); do
                local label desc _def _id
                IFS='|' read -r label desc _def _id <<< "${items[$j]}"

                local padded
                printf -v padded '%-24s' "$label"

                local mark=" "
                if [[ ${selected[$j]} -eq 1 ]]; then
                    mark='\033[32m*\033[0m'
                fi

                if [[ $j -eq $cursor ]]; then
                    buf+="  \033[32m>\033[0m [${mark}] \033[1m${padded}\033[0m \033[2m${desc}\033[0m\033[K\n"
                else
                    buf+="    [${mark}] ${padded} \033[2m${desc}\033[0m\033[K\n"
                fi
            done
            buf+='\033[K\n'
        done

        # Submit button
        if [[ $cursor -eq $n ]]; then
            buf+='  \033[32m>\033[0m  \033[1;32m[ Submit ]\033[0m\033[K\n'
        else
            buf+='     \033[2m[ Submit ]\033[0m\033[K\n'
        fi
        buf+='\033[K\n'
        # Clear any remaining lines from previous render
        buf+='\033[J'
        # Single atomic write eliminates flicker
        printf '%b' "$buf"
    }

    # Cache version to avoid file reads on every redraw
    local _cached_version
    _cached_version="$(get_source_version)"

    # Title is plain bold white, borders are green

    # Enter alternate screen, hide cursor, disable echo
    printf '\033[?1049h' 2>/dev/null
    tput civis 2>/dev/null || printf '\033[?25l'
    stty -echo <&3 2>/dev/null || true

    # Main loop
    while true; do
        _draw_menu

        local key
        key="$(_read_key)"

        case "$key" in
            UP)
                (( cursor > 0 )) && (( cursor-- )) || true
                ;;
            DOWN)
                (( cursor < n )) && (( cursor++ )) || true
                ;;
            ENTER|SPACE)
                if (( cursor == n )); then
                    # Submit
                    break
                else
                    selected[$cursor]=$(( 1 - ${selected[$cursor]} ))
                fi
                ;;
            ALL)
                for (( i=0; i<n; i++ )); do selected[$i]=1; done
                ;;
            NONE)
                for (( i=0; i<n; i++ )); do selected[$i]=0; done
                ;;
            DEFAULT)
                for (( i=0; i<n; i++ )); do
                    local _f1 _f2 _def _f4
                    IFS='|' read -r _f1 _f2 _def _f4 <<< "${items[$i]}"
                    selected[$i]="$_def"
                done
                ;;
            QUIT)
                _menu_cleanup
                echo ""
                info "Cancelled."
                exit 0
                ;;
        esac
    done

    # Restore terminal (fd 3 closed by _menu_cleanup)
    _menu_cleanup
    trap - INT TERM

    # Map selections to install flags
    INSTALL_ALL=false
    RULE_LANGS_EXPLICIT=true

    for (( i=0; i<n; i++ )); do
        [[ ${selected[$i]} -eq 0 ]] && continue

        local item_id _f1 _f2 _f3
        IFS='|' read -r _f1 _f2 _f3 item_id <<< "${items[$i]}"

        case "$item_id" in
            claude-md)           INSTALL_CLAUDE_MD=true ;;
            settings)            INSTALL_SETTINGS=true ;;
            rules-common)        INSTALL_RULES=true ;;
            statusline)          INSTALL_STATUSLINE=true ;;
            lessons)             INSTALL_LESSONS=true ;;
            skills)              INSTALL_SKILLS=true ;;
            rules-python)        INSTALL_RULES=true; RULE_LANGS+=("python") ;;
            rules-ts)            INSTALL_RULES=true; RULE_LANGS+=("typescript") ;;
            rules-go)            INSTALL_RULES=true; RULE_LANGS+=("golang") ;;
            plugins-essential)   INSTALL_PLUGINS=true; PLUGIN_GROUPS+=("essential") ;;
            plugins-claude-mem)  INSTALL_PLUGINS=true; PLUGIN_GROUPS+=("claude-mem") ;;
            plugins-ai-research) INSTALL_PLUGINS=true; PLUGIN_GROUPS+=("ai-research") ;;
            plugins-health)      INSTALL_PLUGINS=true; PLUGIN_GROUPS+=("health") ;;
            mcp)                 INSTALL_MCP=true ;;
        esac
    done

    # Auto-enable settings.json when StatusLine or Lessons needs it for config
    if ($INSTALL_STATUSLINE || $INSTALL_LESSONS) && ! $INSTALL_SETTINGS; then
        INSTALL_SETTINGS=true
        info "settings.json auto-enabled (required by StatusLine/Lessons)"
    fi
}

# --- Confirm prompt (respects --force) ----------------------------------

confirm() {
    local prompt="${1:-Continue?}"
    if $FORCE; then
        return 0
    fi
    if ! can_interact; then
        error "Non-interactive shell detected. Use --force to skip confirmation."
        exit 1
    fi
    if [[ -t 0 ]]; then
        echo -en "${YELLOW}${prompt} [y/N] ${NC}"
        read -r answer
    else
        # Piped stdin: send prompt AND read answer via /dev/tty so they stay paired
        echo -en "${YELLOW}${prompt} [y/N] ${NC}" > /dev/tty
        read -r answer </dev/tty
    fi
    [[ "$answer" =~ ^[Yy]$ ]]
}

# --- Install functions --------------------------------------------------

install_claude_md() {
    info "Installing CLAUDE.md..."
    if $DRY_RUN; then
        info "Would copy: CLAUDE.md -> $CLAUDE_DIR/CLAUDE.md"
    else
        cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
        ok "CLAUDE.md installed"
    fi
}

install_settings() {
    info "Installing settings.json..."
    if [[ ! -f "$CLAUDE_DIR/settings.json" ]]; then
        # New file: copy with optional field stripping
        if $DRY_RUN; then
            info "Would copy: settings.json -> $CLAUDE_DIR/settings.json"
            $INSTALL_STATUSLINE || info "  - statusLine: skipped (not selected)"
            $INSTALL_LESSONS    || info "  - hooks.SessionStart: skipped (not selected)"
        else
            if ! $INSTALL_STATUSLINE || ! $INSTALL_LESSONS; then
                install_jq || true
                if command -v jq &>/dev/null; then
                    local filter="."
                    $INSTALL_STATUSLINE || filter="$filter | del(.statusLine)"
                    $INSTALL_LESSONS    || filter="$filter | del(.hooks.SessionStart)"
                    jq "$filter" "$SCRIPT_DIR/settings.json" > "$CLAUDE_DIR/settings.json"
                else
                    cp "$SCRIPT_DIR/settings.json" "$CLAUDE_DIR/settings.json"
                    warn "jq not available — settings.json includes all fields (statusLine/SessionStart)"
                    (( INSTALL_WARNINGS++ )) || true
                fi
            else
                cp "$SCRIPT_DIR/settings.json" "$CLAUDE_DIR/settings.json"
            fi
            ok "settings.json installed (new)"
        fi
        return
    fi

    # File exists: smart merge with jq if available
    install_jq || true
    if ! command -v jq &>/dev/null; then
        warn "settings.json already exists and jq is not installed"
        warn "  Cannot perform smart merge. Please merge manually:"
        warn "  Source: $SCRIPT_DIR/settings.json"
        warn "  Target: $CLAUDE_DIR/settings.json"
        (( INSTALL_WARNINGS++ )) || true
        return
    fi

    if $DRY_RUN; then
        info "Would smart-merge settings.json (jq available)"
        info "  - env: incoming as defaults, existing overrides"
        info "  - permissions.allow: union of arrays"
        info "  - enabledPlugins: merged, existing keys take priority"
        if $INSTALL_LESSONS; then
            info "  - hooks.SessionStart: deduplicated by matcher"
        else
            info "  - hooks.SessionStart: skipped (not selected)"
        fi
        if $INSTALL_STATUSLINE; then
            info "  - statusLine: incoming takes priority"
        else
            info "  - statusLine: skipped (not selected)"
        fi
        return
    fi

    local existing="$CLAUDE_DIR/settings.json"
    local incoming="$SCRIPT_DIR/settings.json"
    local merged
    merged="$(mktemp)"

    local inc_sl=false inc_lh=false
    $INSTALL_STATUSLINE && inc_sl=true
    $INSTALL_LESSONS && inc_lh=true

    jq -s --argjson inc_sl "$inc_sl" --argjson inc_lh "$inc_lh" '
    def unique_array: [.[] | tostring] | unique | [.[] | fromjson? // .];

    # $base = incoming (defaults), $over = existing (user overrides)
    .[0] as $base | .[1] as $over |

    # env: incoming as defaults, existing overrides
    ($base.env // {}) * ($over.env // {}) as $env |

    # permissions.allow: union
    (($base.permissions.allow // []) + ($over.permissions.allow // []) | unique) as $allow |

    # enabledPlugins: merge, existing wins
    (($base.enabledPlugins // {}) * ($over.enabledPlugins // {})) as $plugins |

    # hooks.SessionStart: deduplicate by matcher (only merge incoming if lessons selected)
    (if $inc_lh then
      (($base.hooks.SessionStart // []) + ($over.hooks.SessionStart // []))
      | group_by(.matcher)
      | map(last)
    else
      ($over.hooks.SessionStart // [])
    end) as $session_hooks |

    # statusLine: use incoming if selected, otherwise preserve existing
    (if $inc_sl then ($base.statusLine // null)
     else ($over.statusLine // null)
    end) as $status_line |

    # Build merged object: start with incoming, overlay existing, then set merged fields
    ($base * $over) * {
      env: $env,
      enabledPlugins: $plugins,
      statusLine: $status_line,
      permissions: (($base.permissions // {}) * ($over.permissions // {}) + {allow: $allow}),
      hooks: (($base.hooks // {}) * ($over.hooks // {}) + {SessionStart: $session_hooks})
    }
    # Remove null statusLine (when neither side had one)
    | if .statusLine == null then del(.statusLine) else . end
    ' "$incoming" "$existing" > "$merged"

    if jq empty "$merged" 2>/dev/null; then
        mv "$merged" "$existing"
        ok "settings.json smart-merged"
    else
        rm -f "$merged"
        error "Merge produced invalid JSON — keeping existing file"
        warn "Please merge manually: $incoming -> $existing"
        (( INSTALL_WARNINGS++ )) || true
    fi
}

install_rules() {
    info "Installing rules..."
    mkdir -p "$CLAUDE_DIR/rules"

    # Always install common rules when any rules are selected
    if $DRY_RUN; then
        info "Would copy: rules/common/ -> $CLAUDE_DIR/rules/common/"
    else
        rm -rf "$CLAUDE_DIR/rules/common"
        cp -r "$SCRIPT_DIR/rules/common" "$CLAUDE_DIR/rules/common"
        ok "Common rules installed"
    fi

    # Determine which language rules to install
    local langs=()
    if [[ ${#RULE_LANGS[@]} -gt 0 ]]; then
        langs=("${RULE_LANGS[@]}")
    elif ! $RULE_LANGS_EXPLICIT; then
        # Auto-detect: install all available languages (--all mode or legacy)
        for lang_dir in "$SCRIPT_DIR"/rules/*/; do
            local lang
            lang=$(basename "$lang_dir")
            [[ "$lang" == "common" || "$lang" == "README.md" ]] && continue
            langs+=("$lang")
        done
    fi
    # If RULE_LANGS_EXPLICIT=true and RULE_LANGS is empty, skip language rules

    for lang in "${langs[@]}"; do
        if [[ -d "$SCRIPT_DIR/rules/$lang" ]]; then
            if $DRY_RUN; then
                info "Would copy: rules/$lang/ -> $CLAUDE_DIR/rules/$lang/"
            else
                rm -rf "$CLAUDE_DIR/rules/$lang"
                cp -r "$SCRIPT_DIR/rules/$lang" "$CLAUDE_DIR/rules/$lang"
                ok "$lang rules installed"
            fi
        else
            error "Language rules not found: $lang"
        fi
    done

    # Clean up known language rule dirs that were NOT selected (from previous installs)
    # Only removes languages this installer knows about; preserves user-created dirs
    if $RULE_LANGS_EXPLICIT; then
        local known_langs=("python" "typescript" "golang")
        for known in "${known_langs[@]}"; do
            local keep=false
            for lang in "${langs[@]}"; do
                if [[ "$lang" == "$known" ]]; then
                    keep=true
                    break
                fi
            done

            if ! $keep && [[ -d "$CLAUDE_DIR/rules/$known" ]]; then
                if $DRY_RUN; then
                    info "Would remove unselected: $CLAUDE_DIR/rules/$known/"
                else
                    rm -rf "$CLAUDE_DIR/rules/$known"
                    ok "Removed unselected rules: $known"
                fi
            fi
        done
    fi

    if $DRY_RUN; then
        info "Would copy: rules/README.md -> $CLAUDE_DIR/rules/README.md"
    else
        cp "$SCRIPT_DIR/rules/README.md" "$CLAUDE_DIR/rules/README.md"
    fi
}

install_skills() {
    info "Installing custom skills..."
    mkdir -p "$CLAUDE_DIR/skills"

    for skill_dir in "$SCRIPT_DIR"/skills/*/; do
        [[ -d "$skill_dir" ]] || continue
        local skill
        skill=$(basename "$skill_dir")

        if $DRY_RUN; then
            info "Would copy: skills/$skill/ -> $CLAUDE_DIR/skills/$skill/"
        else
            rm -rf "$CLAUDE_DIR/skills/$skill"
            cp -r "$skill_dir" "$CLAUDE_DIR/skills/$skill"
            ok "Skill installed: $skill"
        fi
    done
}

install_lessons() {
    info "Installing lessons.md template..."
    local target="$CLAUDE_DIR/lessons.md"

    if [[ -f "$target" ]]; then
        warn "lessons.md already exists -- skipping"
    else
        if $DRY_RUN; then
            info "Would copy: lessons.md -> $target"
        else
            cp "$SCRIPT_DIR/lessons.md" "$target"
            ok "lessons.md template installed to $target"
        fi
    fi
}

install_statusline() {
    info "Installing StatusLine..."
    mkdir -p "$CLAUDE_DIR/hooks"

    local hook_file="$SCRIPT_DIR/hooks/statusline.sh"
    if [[ -f "$hook_file" ]]; then
        if $DRY_RUN; then
            info "Would copy: hooks/statusline.sh -> $CLAUDE_DIR/hooks/statusline.sh"
        else
            cp "$hook_file" "$CLAUDE_DIR/hooks/statusline.sh"
            chmod +x "$CLAUDE_DIR/hooks/statusline.sh"
            ok "Hook installed: statusline.sh"
        fi
    fi

    # Ensure jq is available (required by statusline hook)
    install_jq || true

    # Install Nerd Font for statusline icons
    install_nerd_font || true
}

install_mcp() {
    info "Installing MCP servers..."

    if ! command -v claude &>/dev/null; then
        error "Claude Code CLI not found. Install it first: https://claude.com/claude-code"
        return 1
    fi

    # Lark MCP
    if $DRY_RUN; then
        info "Would add MCP server: lark-mcp (stdio)"
    else
        if retry 5 3 "Add MCP server lark-mcp" claude mcp add --scope user --transport stdio lark-mcp \
            -- npx -y @larksuiteoapi/lark-mcp mcp -a YOUR_APP_ID -s YOUR_APP_SECRET 2>/dev/null; then
            ok "MCP server added: lark-mcp"
        else
            warn "MCP server lark-mcp may already exist or could not be added, skipping"
        fi
        warn "Replace YOUR_APP_ID and YOUR_APP_SECRET with your Feishu credentials"
    fi
}

install_plugins() {
    if ! command -v claude &>/dev/null; then
        error "Claude Code CLI not found. Install it first: https://claude.com/claude-code"
        return 1
    fi

    # Collect plugins from all selected groups
    local plugins=()
    for group in "${PLUGIN_GROUPS[@]}"; do
        case "$group" in
            essential|core)
                plugins+=("${PLUGINS_ESSENTIAL[@]}")
                ;;
            claude-mem)
                plugins+=("${PLUGINS_CLAUDE_MEM[@]}")
                ;;
            ai-research)
                plugins+=("${PLUGINS_AI_RESEARCH[@]}")
                ;;
            health)
                plugins+=("${PLUGINS_HEALTH[@]}")
                ;;
            all)
                plugins+=("${PLUGINS_ESSENTIAL[@]}" "${PLUGINS_CLAUDE_MEM[@]}" "${PLUGINS_AI_RESEARCH[@]}" "${PLUGINS_HEALTH[@]}")
                ;;
        esac
    done

    # Deduplicate
    local unique_plugins=()
    local seen=""
    for entry in "${plugins[@]}"; do
        if [[ "$seen" != *"|$entry|"* ]]; then
            unique_plugins+=("$entry")
            seen="$seen|$entry|"
        fi
    done
    plugins=("${unique_plugins[@]}")

    local group_names
    group_names="$(IFS=','; echo "${PLUGIN_GROUPS[*]}")"
    info "Installing plugins (groups: $group_names)..."

    # Collect required marketplaces from selected plugins
    local marketplace_list=(
        "anthropic-agent-skills|anthropics/skills"
        "everything-claude-code|affaan-m/everything-claude-code"
        "ai-research-skills|zechenzhangAGI/AI-research-SKILLs"
        "claude-plugins-official|anthropics/claude-plugins-official"
        "thedotmack|thedotmack/claude-mem"
        "claude-health|tw93/claude-health"
    )

    # Build set of needed marketplaces (bash 3.2 compatible, no associative arrays)
    local needed_marketplaces=""
    for entry in "${plugins[@]}"; do
        local marketplace="${entry##*@}"
        needed_marketplaces="$needed_marketplaces|$marketplace|"
    done

    # Step 1: Add required marketplaces
    info "Adding marketplaces..."
    for entry in "${marketplace_list[@]}"; do
        local marketplace="${entry%%|*}"
        local repo="${entry##*|}"
        [[ "$needed_marketplaces" != *"|$marketplace|"* ]] && continue

        # Skip if already installed
        if [[ -d "$HOME/.claude/plugins/marketplaces/$marketplace" ]]; then
            ok "Marketplace already exists: $marketplace"
            continue
        fi

        if $DRY_RUN; then
            info "Would add marketplace: $marketplace (github.com/$repo)"
        else
            if retry 5 3 "Add marketplace $marketplace" claude plugin marketplace add "https://github.com/$repo" 2>/dev/null; then
                ok "Marketplace added: $marketplace"
            else
                warn "Marketplace $marketplace may already exist or could not be added"
            fi
        fi
    done

    # Step 2: Install plugins
    info "Installing ${#plugins[@]} plugins..."
    for entry in "${plugins[@]}"; do
        local plugin_name="${entry%%@*}"
        local marketplace="${entry##*@}"
        if $DRY_RUN; then
            info "Would install plugin: $plugin_name from $marketplace"
        else
            if retry 5 3 "Install plugin $plugin_name" claude plugin install "${plugin_name}@${marketplace}" 2>/dev/null; then
                ok "Plugin installed: $plugin_name"
            else
                warn "Plugin $plugin_name could not be installed, skipping"
                (( INSTALL_WARNINGS++ )) || true
            fi
        fi
    done
}

# --- Uninstall ----------------------------------------------------------

uninstall() {
    echo ""
    warn "The following will be removed:"
    echo "  - $CLAUDE_DIR/CLAUDE.md"
    echo "  - $CLAUDE_DIR/settings.json (backed up first)"
    echo "  - $CLAUDE_DIR/rules/"
    echo "  - $CLAUDE_DIR/skills/ (installer-managed only)"
    echo "  - $CLAUDE_DIR/lessons.md"
    echo "  - $CLAUDE_DIR/hooks/ (installer-managed only)"
    echo "  - Installed plugins (requires claude CLI)"
    echo "  - MCP server: lark-mcp (requires claude CLI)"
    [[ -f "$VERSION_STAMP_FILE" ]] && echo "  - $VERSION_STAMP_FILE"
    echo ""

    if $DRY_RUN; then
        warn "DRY RUN -- nothing will be removed"
        return
    fi

    if ! confirm "Proceed with uninstall?"; then
        info "Cancelled."
        exit 0
    fi

    rm -f "$CLAUDE_DIR/CLAUDE.md" && ok "Removed CLAUDE.md"

    if [[ -f "$CLAUDE_DIR/settings.json" ]]; then
        cp "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/settings.json.bak"
        ok "Backed up settings.json -> settings.json.bak"
        rm -f "$CLAUDE_DIR/settings.json" && ok "Removed settings.json"
    fi

    rm -rf "$CLAUDE_DIR/rules" && ok "Removed rules/"

    # Only remove skills that ship with this repo
    if [[ -d "$SCRIPT_DIR/skills" ]]; then
        for skill_dir in "$SCRIPT_DIR"/skills/*/; do
            [[ -d "$skill_dir" ]] || continue
            local skill
            skill=$(basename "$skill_dir")
            rm -rf "$CLAUDE_DIR/skills/$skill" && ok "Removed skill: $skill"
        done
    else
        rm -rf "$CLAUDE_DIR/skills" && ok "Removed skills/"
    fi

    rm -f "$CLAUDE_DIR/lessons.md" && ok "Removed lessons.md"

    # Only remove hooks that ship with this repo
    if [[ -d "$SCRIPT_DIR/hooks" ]]; then
        for hook_file in "$SCRIPT_DIR"/hooks/*; do
            [[ -f "$hook_file" ]] || continue
            local fname
            fname=$(basename "$hook_file")
            rm -f "$CLAUDE_DIR/hooks/$fname" && ok "Removed hook: $fname"
        done
    else
        rm -rf "$CLAUDE_DIR/hooks" && ok "Removed hooks/"
    fi

    if command -v claude &>/dev/null; then
        local all_plugins=("${PLUGINS_ESSENTIAL[@]}" "${PLUGINS_CLAUDE_MEM[@]}" "${PLUGINS_AI_RESEARCH[@]}" "${PLUGINS_HEALTH[@]}")
        for entry in "${all_plugins[@]}"; do
            local plugin_name="${entry%%@*}"
            claude plugin uninstall "$entry" 2>/dev/null && \
                ok "Uninstalled plugin: $plugin_name" || \
                warn "Could not uninstall: $plugin_name"
        done
        claude mcp remove lark-mcp 2>/dev/null && \
            ok "Removed MCP server: lark-mcp" || \
            warn "Could not remove lark-mcp"
    else
        warn "Claude CLI not found — cannot uninstall plugins or MCP servers"
    fi

    rm -f "$VERSION_STAMP_FILE"
    echo ""
    ok "Uninstall complete."
}

# --- Main ---------------------------------------------------------------

main() {
    detect_script_dir
    parse_args "$@"

    # Handle --version
    if $SHOW_VERSION; then
        show_version
        exit 0
    fi

    # Handle --uninstall
    if $UNINSTALL; then
        echo ""
        echo "========================================="
        echo "  Claude Code Config — Uninstaller"
        echo "========================================="
        uninstall
        exit 0
    fi

    # Interactive mode: show menu first
    if $INTERACTIVE; then
        interactive_menu
    fi

    # --all mode: set all flags
    if $INSTALL_ALL; then
        INSTALL_CLAUDE_MD=true
        INSTALL_SETTINGS=true
        INSTALL_RULES=true
        INSTALL_SKILLS=true
        INSTALL_LESSONS=true
        INSTALL_STATUSLINE=true
        INSTALL_PLUGINS=true
        if $EXPLICIT_ALL; then
            # Explicit --all: install everything including MCP and all plugin groups
            INSTALL_MCP=true
            PLUGIN_GROUPS=("all")
        else
            # Implicit (non-TTY fallback): essential plugins only, no MCP
            PLUGIN_GROUPS=("essential")
        fi
    fi

    # Check if anything was selected
    if ! $INSTALL_CLAUDE_MD && ! $INSTALL_SETTINGS && ! $INSTALL_RULES && \
       ! $INSTALL_SKILLS && ! $INSTALL_LESSONS && ! $INSTALL_STATUSLINE && \
       ! $INSTALL_PLUGINS && ! $INSTALL_MCP; then
        warn "Nothing selected to install."
        exit 0
    fi

    echo ""
    echo "========================================="
    echo "  Awesome Claude Code Config Installer"
    echo "  $(get_source_version)"
    echo "========================================="
    echo ""

    if $DRY_RUN; then
        warn "DRY RUN MODE -- no changes will be made"
        echo ""
    fi

    local installed_ver
    installed_ver="$(get_installed_version)"
    if [[ "$installed_ver" != "not installed" ]]; then
        info "Upgrading from $installed_ver -> $(get_source_version)"
    fi

    mkdir -p "$CLAUDE_DIR"

    $INSTALL_CLAUDE_MD && install_claude_md
    $INSTALL_SETTINGS && install_settings
    $INSTALL_RULES && install_rules
    $INSTALL_SKILLS && install_skills
    $INSTALL_LESSONS && install_lessons
    $INSTALL_STATUSLINE && install_statusline
    $INSTALL_MCP && install_mcp
    $INSTALL_PLUGINS && install_plugins

    # Stamp version (skip if there were critical warnings)
    if ! $DRY_RUN; then
        if [[ $INSTALL_WARNINGS -eq 0 ]]; then
            stamp_version
        else
            warn "Skipping version stamp due to $INSTALL_WARNINGS warning(s)"
        fi
    fi

    echo ""
    if [[ $INSTALL_WARNINGS -gt 0 ]]; then
        warn "Installation completed with $INSTALL_WARNINGS warning(s) — review messages above"
    else
        ok "Installation complete! ($(get_source_version))"
    fi
    echo ""
    info "Next steps:"
    echo "  1. Restart Claude Code for changes to take effect"
    echo "  2. Customize CLAUDE.md for your specific projects"
    if $INSTALL_MCP; then
        echo "  3. Replace YOUR_APP_ID/YOUR_APP_SECRET in Lark MCP config"
    fi
    echo ""
}

main "$@"
