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

# Install MesloLGS NF font for statusline icons (bundled in fonts/)
install_nerd_font() {
    # Check if already installed (fc-list first — more reliable than filename glob)
    if command -v fc-list &>/dev/null; then
        if fc-list 2>/dev/null | grep -qi "MesloLGS NF"; then
            return 0
        fi
    fi
    local font_dir
    case "$(uname -s)" in
        Darwin) font_dir="$HOME/Library/Fonts" ;;
        *)      font_dir="$HOME/.local/share/fonts" ;;
    esac
    # Fallback: check by font files directly (works without fontconfig)
    if ls "$font_dir"/MesloLGS\ NF* &>/dev/null 2>&1; then
        return 0
    fi

    if $DRY_RUN; then
        info "Would install MesloLGS NF font"
        return 0
    fi

    info "Installing MesloLGS NF font for statusline icons..."
    mkdir -p "$font_dir"

    # Copy bundled fonts from repository
    local src_dir="$SCRIPT_DIR/fonts"
    if [ ! -d "$src_dir" ] || ! ls "$src_dir"/*.ttf &>/dev/null 2>&1; then
        warn "Bundled fonts not found in $src_dir — statusline will use text fallback"
        return 1
    fi
    cp "$src_dir"/*.ttf "$font_dir"/

    # Verify copy succeeded
    if ! ls "$font_dir"/MesloLGS\ NF* &>/dev/null 2>&1; then
        warn "Font installation failed — no font files found"
        return 1
    fi
    # Refresh font cache
    if command -v fc-cache &>/dev/null; then
        fc-cache -f "$font_dir" 2>/dev/null || true
    fi
    ok "MesloLGS NF font installed to $font_dir"
    warn "Set your terminal font to 'MesloLGS NF' for best icon display"
    return 0
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
        # Not local — trap needs access after function returns (set -u)
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
INSTALL_DEEPXIV=false
UNINSTALL=false
FORCE=false
SHOW_VERSION=false
INTERACTIVE=false
RULE_LANGS=()
RULE_LANGS_EXPLICIT=false
PLUGIN_GROUPS=()
REVIEW_ADVERSARIAL=false
REVIEW_CODEX=false
SELECTED_SKILLS=()
SELECTED_PLUGINS=()
SELECTED_DEEPXIV_SKILLS=()
DEEPXIV_KNOWN_SKILLS=("deepxiv-cli" "deepxiv-trending-digest" "deepxiv-baseline-table")

# --- Plugin groups ------------------------------------------------------

PLUGINS_ESSENTIAL=(
    "andrej-karpathy-skills@karpathy-skills"
    "superpowers@claude-plugins-official"
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

PLUGINS_OPTIONAL=(
    "everything-claude-code@everything-claude-code"
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

PLUGINS_PUA=(
    "pua@pua-skills"
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

    # --- Two-level menu data structure ---
    # Each group has: label, hint, and an array of items.
    # Item format: "label|description|default_on|id"
    # Groups are navigated in the main menu; Enter opens sub-menu.
    # Mutual exclusion: review-adversarial and review-codex (handled in toggle logic).

    local -a GROUP_LABELS=()
    local -a GROUP_HINTS=()
    local -a GROUP_ITEMS=()    # pipe-separated list of items per group

    # Group 0: Core
    GROUP_LABELS+=("Core")
    GROUP_HINTS+=("")
    GROUP_ITEMS+=("CLAUDE.md|Global instructions template|1|claude-md
settings.json|Smart-merged Claude Code settings|1|settings
Common rules|Coding style, git, security, testing|1|rules-common
StatusLine|Gradient progress bar & usage display|1|statusline
Lessons|lessons.md template + SessionStart hook|1|lessons")

    # Group 1: Language Rules
    GROUP_LABELS+=("Language Rules")
    GROUP_HINTS+=("only install what your projects need")
    GROUP_ITEMS+=("Python rules|PEP 8, pytest, type hints, bandit|0|rules-python
TypeScript rules|Zod, Playwright, immutability|0|rules-ts
Go rules|gofmt, table-driven tests, gosec|0|rules-go")

    # Group 2: Review
    GROUP_LABELS+=("Review")
    GROUP_HINTS+=("adversarial-review and Codex are mutually exclusive")
    GROUP_ITEMS+=("code-review plugin|PR code review (claude-plugins-official)|1|review-code-review
adversarial-review|Cross-model adversarial review (poteto/noodle)|1|review-adversarial
Codex CLI|Codex adversarial review (openai/codex)|0|review-codex")

    # Group 3: Workflow
    GROUP_LABELS+=("Workflow")
    GROUP_HINTS+=("planning, iteration, code quality, meta-config")
    GROUP_ITEMS+=("andrej-karpathy-skills|Karpathy coding guidelines (Think-First, Simplicity, Surgical)|1|plug-andrej-karpathy-skills
superpowers|Planning, brainstorming, TDD, debugging|1|plug-superpowers
feature-dev|Guided feature development|1|plug-feature-dev
ralph-loop|Automated iteration loop|1|plug-ralph-loop
commit-commands|git commit / push / PR workflow|1|plug-commit-commands
code-simplifier|Code simplification & cleanup|1|plug-code-simplifier
everything-claude-code|TDD, security, database, Go/Python/Spring Boot|0|plug-everything-claude-code
update-config|Configure Claude Code via settings.json (skill)|1|skill-update-config
handoff|Compact conversation into a handoff doc (mattpocock) (skill)|1|skill-handoff")

    # Group 4: Integrations
    GROUP_LABELS+=("Integrations")
    GROUP_HINTS+=("external tools & services")
    GROUP_ITEMS+=("context7|Real-time library documentation|1|plug-context7
github|GitHub integration (issues, PRs, workflows)|1|plug-github
playwright|Browser automation & E2E testing|1|plug-playwright")

    # Group 5: Design & Content
    GROUP_LABELS+=("Design & Content")
    GROUP_HINTS+=("documents, UI, creative artifacts, humanization")
    GROUP_ITEMS+=("document-skills|Document processing (PDF, DOCX, PPTX, XLSX)|1|plug-document-skills
example-skills|Frontend/design/canvas/algorithmic-art skills|1|plug-example-skills
frontend-design|Frontend UI design|1|plug-frontend-design
humanizer|Remove AI writing patterns (English, blader) (skill)|1|skill-humanizer
humanizer-zh|Remove AI writing patterns (Chinese, op7418) (skill)|0|skill-humanizer-zh")

    # Group 6: Memory & Lifestyle
    GROUP_LABELS+=("Memory & Lifestyle")
    GROUP_HINTS+=("session memory and personal productivity")
    GROUP_ITEMS+=("claude-mem|Cross-session memory (~3k tokens/session)|0|plug-claude-mem
claude-health|Health check & wellness dashboard|0|plug-claude-health
PUA|AI agent productivity booster (pua, pua-en, pua-ja)|0|plug-pua")

    # Group 7: Academic Research (AI Research plugins + DeepXiv skills + paper-reading)
    GROUP_LABELS+=("Academic Research")
    GROUP_HINTS+=("training/inference plugins + paper-reading & DeepXiv skills")
    GROUP_ITEMS+=("paper-reading|Research paper summarization (skill)|1|skill-paper-reading
tokenization|Tokenizer training & usage|0|plug-tokenization
fine-tuning|Model fine-tuning|0|plug-fine-tuning
post-training|Post-training (RLHF, DPO, GRPO)|0|plug-post-training
inference-serving|Inference serving (vLLM, SGLang, TensorRT)|0|plug-inference-serving
distributed-training|Distributed training (DeepSpeed, FSDP, Megatron)|0|plug-distributed-training
optimization|Quantization & optimization (GPTQ, AWQ, Flash Attn)|0|plug-optimization
deepxiv-cli|arXiv/PMC paper search & reading CLI skill|0|deepxiv-cli
deepxiv-trending-digest|Trending paper digest generation|0|deepxiv-trending-digest
deepxiv-baseline-table|Baseline comparison table from papers|0|deepxiv-baseline-table")

    # Group 8: MCP Servers
    GROUP_LABELS+=("MCP Servers")
    GROUP_HINTS+=("")
    GROUP_ITEMS+=("Lark MCP server|Feishu/Lark integration|0|mcp")

    local num_groups=${#GROUP_LABELS[@]}

    # Flatten all items into parallel arrays for indexing
    local -a ALL_LABELS=() ALL_DESCS=() ALL_DEFAULTS=() ALL_IDS=()
    local -a GROUP_START=() GROUP_END=()
    local flat_idx=0
    for (( g=0; g<num_groups; g++ )); do
        GROUP_START[$g]=$flat_idx
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            local _l _d _df _id
            IFS='|' read -r _l _d _df _id <<< "$line"
            ALL_LABELS+=("$_l")
            ALL_DESCS+=("$_d")
            ALL_DEFAULTS+=("$_df")
            ALL_IDS+=("$_id")
            (( ++flat_idx ))
        done <<< "${GROUP_ITEMS[$g]}"
        GROUP_END[$g]=$(( flat_idx - 1 ))
    done

    local n=$flat_idx
    local selected=()
    local cursor=0

    # Initialize selections from defaults
    local i
    for (( i=0; i<n; i++ )); do
        selected[$i]="${ALL_DEFAULTS[$i]}"
    done

    # Save terminal state (operate on fd 3 which points to the actual tty)
    local saved_stty
    saved_stty=$(stty -g <&3 2>/dev/null) || saved_stty=""

    _menu_active=false  # Not local — trap handlers need access under bash 5.x
    _menu_cleanup() {
        $_menu_active || return 0
        _menu_active=false
        printf '\033[?1049l' 2>/dev/null
        [[ -n "$saved_stty" ]] && stty "$saved_stty" <&3 2>/dev/null || stty echo <&3 2>/dev/null || true
        tput cnorm 2>/dev/null || printf '\033[?25h'
        exec 3<&- 2>/dev/null || true
    }
    trap '_menu_cleanup; exit 0' INT TERM
    # Also clean up on unexpected exit (e.g. set -e) to restore terminal.
    # Chain with tmpdir cleanup for remote mode.
    if $REMOTE_MODE; then
        trap '_menu_cleanup; rm -rf "${tmpdir:-}"' EXIT
    else
        trap '_menu_cleanup' EXIT
    fi

    _read_key() {
        local key="" _read_ret=0
        IFS= read -r -s -n 1 key <&3 2>/dev/null || _read_ret=$?
        # EOF (ret=1) → treat as quit, not enter
        if [[ $_read_ret -eq 1 ]]; then
            echo "QUIT"
            return
        fi

        if [[ "$key" == $'\033' ]]; then
            local rest=""
            IFS= read -r -s -n 2 -t 1 rest <&3 2>/dev/null || true
            case "$rest" in
                '[A') echo "UP" ;;
                '[B') echo "DOWN" ;;
                '[C') echo "RIGHT" ;;
                '[D') echo "LEFT" ;;
                '')   echo "ESC" ;;
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

    # --- Helper: count selected items in a group ---
    _group_count() {
        local g=$1 cnt=0
        for (( j=GROUP_START[g]; j<=GROUP_END[g]; j++ )); do
            (( selected[j] )) && (( cnt++ )) || true
        done
        echo $cnt
    }
    _group_total() {
        local g=$1
        echo $(( GROUP_END[g] - GROUP_START[g] + 1 ))
    }

    # --- Helper: enforce mutual exclusion for review items ---
    _enforce_review_mutex() {
        local toggled_idx=$1
        local toggled_id="${ALL_IDS[$toggled_idx]}"
        # Only enforce if we just turned ON one of the mutually exclusive pair
        if [[ ${selected[$toggled_idx]} -eq 1 ]]; then
            if [[ "$toggled_id" == "review-adversarial" ]]; then
                # Find and turn off review-codex
                for (( j=GROUP_START[2]; j<=GROUP_END[2]; j++ )); do
                    [[ "${ALL_IDS[$j]}" == "review-codex" ]] && selected[$j]=0 || true
                done
            elif [[ "$toggled_id" == "review-codex" ]]; then
                # Find and turn off review-adversarial
                for (( j=GROUP_START[2]; j<=GROUP_END[2]; j++ )); do
                    [[ "${ALL_IDS[$j]}" == "review-adversarial" ]] && selected[$j]=0 || true
                done
            fi
        fi
    }

    # --- Draw main menu (groups as rows with counts) ---
    _draw_main_menu() {
        local buf=""
        buf+='\033[H'
        buf+='\033[K\n'
        buf+='  \033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\033[K\n'
        buf+="    \033[1;36mAwesome Claude Code Config Installer\033[0m  \033[2m${_cached_version}\033[0m\033[K\n"
        buf+='  \033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\033[K\n'
        buf+='\033[K\n'
        buf+='  \033[2m↑/↓ Navigate   Enter/→ Open   a All  n None  d Defaults  q Quit\033[0m\033[K\n'
        buf+='\033[K\n'

        local g
        for (( g=0; g<num_groups; g++ )); do
            local cnt tot label hint padded count_str
            cnt=$(_group_count $g)
            tot=$(_group_total $g)
            label="${GROUP_LABELS[$g]}"
            hint="${GROUP_HINTS[$g]}"
            printf -v padded '%-24s' "$label"
            count_str="[${cnt}/${tot}]"
            printf -v count_str '%-7s' "$count_str"

            if [[ $g -eq $cursor ]]; then
                buf+="  \033[32m>\033[0m ${count_str} \033[1m${padded}\033[0m"
            else
                buf+="    ${count_str} ${padded}"
            fi
            if [[ -n "$hint" ]]; then
                buf+=" \033[2m(${hint})\033[0m"
            fi
            buf+='\033[K\n'
        done
        buf+='\033[K\n'

        # Submit button
        if [[ $cursor -eq $num_groups ]]; then
            buf+='  \033[32m>\033[0m  \033[1;32m[ Submit ]\033[0m\033[K\n'
        else
            buf+='     \033[2m[ Submit ]\033[0m\033[K\n'
        fi
        buf+='\033[K\n\033[J'
        printf '%b' "$buf"
    }

    # --- Draw sub-menu (items within a group) ---
    _draw_sub_menu() {
        local g=$1 sub_cursor=$2
        local g_start=${GROUP_START[$g]} g_end=${GROUP_END[$g]}
        local sub_n=$(( g_end - g_start + 1 ))

        local buf=""
        buf+='\033[H'
        buf+='\033[K\n'
        buf+='  \033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\033[K\n'
        buf+="    \033[1;36m${GROUP_LABELS[$g]}\033[0m"
        if [[ -n "${GROUP_HINTS[$g]}" ]]; then
            buf+="  \033[2m(${GROUP_HINTS[$g]})\033[0m"
        fi
        buf+='\033[K\n'
        buf+='  \033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\033[K\n'
        buf+='\033[K\n'
        buf+='  \033[2m↑/↓ Navigate   Space Toggle   ←/Esc/Enter Back\033[0m\033[K\n'
        buf+='  \033[2ma All   n None   d Defaults\033[0m\033[K\n'
        buf+='\033[K\n'

        local j rel=0
        for (( j=g_start; j<=g_end; j++, rel++ )); do
            local label="${ALL_LABELS[$j]}"
            local desc="${ALL_DESCS[$j]}"
            local padded
            printf -v padded '%-28s' "$label"

            local mark=" "
            if [[ ${selected[$j]} -eq 1 ]]; then
                mark='\033[32m*\033[0m'
            fi

            if [[ $rel -eq $sub_cursor ]]; then
                buf+="  \033[32m>\033[0m [${mark}] \033[1m${padded}\033[0m \033[2m${desc}\033[0m\033[K\n"
            else
                buf+="    [${mark}] ${padded} \033[2m${desc}\033[0m\033[K\n"
            fi
        done
        buf+='\033[K\n'

        # Back button
        if [[ $sub_cursor -eq $sub_n ]]; then
            buf+='  \033[32m>\033[0m  \033[1;33m[ Back ]\033[0m\033[K\n'
        else
            buf+='     \033[2m[ Back ]\033[0m\033[K\n'
        fi
        buf+='\033[K\n\033[J'
        printf '%b' "$buf"
    }

    # Cache version to avoid file reads on every redraw
    local _cached_version
    _cached_version="$(get_source_version)"

    # Enter alternate screen, hide cursor, disable echo
    _menu_active=true
    printf '\033[?1049h' 2>/dev/null
    tput civis 2>/dev/null || printf '\033[?25l'
    stty -echo <&3 2>/dev/null || true

    # Main menu loop
    cursor=0
    while true; do
        _draw_main_menu

        local key
        key="$(_read_key)"

        case "$key" in
            UP)
                (( cursor > 0 )) && (( cursor-- )) || true
                ;;
            DOWN)
                (( cursor < num_groups )) && (( cursor++ )) || true
                ;;
            ENTER|RIGHT)
                if (( cursor == num_groups )); then
                    # Submit (only on ENTER, not RIGHT)
                    if [[ "$key" == "ENTER" ]]; then break; fi
                    continue
                fi
                # Enter sub-menu for this group
                local sub_g=$cursor
                local sub_n=$(( GROUP_END[sub_g] - GROUP_START[sub_g] + 1 ))
                local sub_cursor=0
                local in_sub=true
                while $in_sub; do
                    _draw_sub_menu $sub_g $sub_cursor
                    key="$(_read_key)"
                    case "$key" in
                        UP)
                            (( sub_cursor > 0 )) && (( sub_cursor-- )) || true
                            ;;
                        DOWN)
                            (( sub_cursor < sub_n )) && (( sub_cursor++ )) || true
                            ;;
                        SPACE)
                            if (( sub_cursor < sub_n )); then
                                local abs_idx=$(( GROUP_START[sub_g] + sub_cursor ))
                                selected[$abs_idx]=$(( 1 - ${selected[$abs_idx]} ))
                                _enforce_review_mutex $abs_idx
                            fi
                            ;;
                        ENTER)
                            # Back button or toggle
                            if (( sub_cursor == sub_n )); then
                                in_sub=false
                            else
                                local abs_idx=$(( GROUP_START[sub_g] + sub_cursor ))
                                selected[$abs_idx]=$(( 1 - ${selected[$abs_idx]} ))
                                _enforce_review_mutex $abs_idx
                            fi
                            ;;
                        ALL)
                            for (( j=GROUP_START[sub_g]; j<=GROUP_END[sub_g]; j++ )); do
                                selected[$j]=1
                            done
                            # Re-enforce mutex only when in the Review group
                            if (( sub_g == 2 )); then
                                for (( j=GROUP_START[2]; j<=GROUP_END[2]; j++ )); do
                                    [[ "${ALL_IDS[$j]}" == "review-codex" ]] && selected[$j]=0 || true
                                done
                            fi
                            ;;
                        NONE)
                            for (( j=GROUP_START[sub_g]; j<=GROUP_END[sub_g]; j++ )); do
                                selected[$j]=0
                            done
                            ;;
                        DEFAULT)
                            for (( j=GROUP_START[sub_g]; j<=GROUP_END[sub_g]; j++ )); do
                                selected[$j]="${ALL_DEFAULTS[$j]}"
                            done
                            ;;
                        QUIT|ESC|LEFT)
                            in_sub=false
                            ;;
                    esac
                done
                ;;
            SPACE)
                # On main menu, Space does nothing (Enter to open sub-menu)
                ;;
            ALL)
                for (( i=0; i<n; i++ )); do selected[$i]=1; done
                # Enforce review mutex: adversarial ON (default), codex OFF
                for (( j=${GROUP_START[2]}; j<=${GROUP_END[2]}; j++ )); do
                    [[ "${ALL_IDS[$j]}" == "review-codex" ]] && selected[$j]=0 || true
                done
                ;;
            NONE)
                for (( i=0; i<n; i++ )); do selected[$i]=0; done
                ;;
            DEFAULT)
                for (( i=0; i<n; i++ )); do
                    selected[$i]="${ALL_DEFAULTS[$i]}"
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
    trap - INT TERM EXIT
    # Restore tmpdir cleanup for remote mode
    $REMOTE_MODE && [[ -n "${tmpdir:-}" ]] && trap 'rm -rf "$tmpdir"' EXIT || true

    # Map selections to install flags
    INSTALL_ALL=false
    RULE_LANGS_EXPLICIT=true

    # Helper: map plug-* ID to package name (bash 3.2 compatible, no associative arrays)
    _plug_id_to_pkg() {
        case "$1" in
            plug-andrej-karpathy-skills) echo "andrej-karpathy-skills@karpathy-skills" ;;
            plug-everything-claude-code) echo "everything-claude-code@everything-claude-code" ;;
            plug-superpowers)       echo "superpowers@claude-plugins-official" ;;
            plug-context7)          echo "context7@claude-plugins-official" ;;
            plug-commit-commands)   echo "commit-commands@claude-plugins-official" ;;
            plug-document-skills)   echo "document-skills@anthropic-agent-skills" ;;
            plug-playwright)        echo "playwright@claude-plugins-official" ;;
            plug-feature-dev)       echo "feature-dev@claude-plugins-official" ;;
            plug-code-simplifier)   echo "code-simplifier@claude-plugins-official" ;;
            plug-ralph-loop)        echo "ralph-loop@claude-plugins-official" ;;
            plug-frontend-design)   echo "frontend-design@claude-plugins-official" ;;
            plug-example-skills)    echo "example-skills@anthropic-agent-skills" ;;
            plug-github)            echo "github@claude-plugins-official" ;;
            plug-claude-mem)        echo "claude-mem@thedotmack" ;;
            plug-claude-health)     echo "health@claude-health" ;;
            plug-pua)               echo "pua@pua-skills" ;;
            plug-tokenization)      echo "tokenization@ai-research-skills" ;;
            plug-fine-tuning)       echo "fine-tuning@ai-research-skills" ;;
            plug-post-training)     echo "post-training@ai-research-skills" ;;
            plug-inference-serving) echo "inference-serving@ai-research-skills" ;;
            plug-distributed-training) echo "distributed-training@ai-research-skills" ;;
            plug-optimization)      echo "optimization@ai-research-skills" ;;
            *) echo "" ;;
        esac
    }

    for (( i=0; i<n; i++ )); do
        [[ ${selected[$i]} -eq 0 ]] && continue

        local item_id="${ALL_IDS[$i]}"

        case "$item_id" in
            # Core
            claude-md)              INSTALL_CLAUDE_MD=true ;;
            settings)               INSTALL_SETTINGS=true ;;
            rules-common)           INSTALL_RULES=true ;;
            statusline)             INSTALL_STATUSLINE=true ;;
            lessons)                INSTALL_LESSONS=true ;;
            # Language rules
            rules-python)           INSTALL_RULES=true; RULE_LANGS+=("python") ;;
            rules-ts)               INSTALL_RULES=true; RULE_LANGS+=("typescript") ;;
            rules-go)               INSTALL_RULES=true; RULE_LANGS+=("golang") ;;
            # Review
            review-code-review)     INSTALL_PLUGINS=true; SELECTED_PLUGINS+=("code-review@claude-plugins-official") ;;
            review-adversarial)     REVIEW_ADVERSARIAL=true; INSTALL_SKILLS=true; SELECTED_SKILLS+=("adversarial-review") ;;
            review-codex)           REVIEW_CODEX=true; INSTALL_PLUGINS=true; SELECTED_PLUGINS+=("codex@openai-codex") ;;
            # Skills
            skill-paper-reading)    INSTALL_SKILLS=true; SELECTED_SKILLS+=("paper-reading") ;;
            skill-humanizer)        INSTALL_SKILLS=true; SELECTED_SKILLS+=("humanizer") ;;
            skill-humanizer-zh)     INSTALL_SKILLS=true; SELECTED_SKILLS+=("humanizer-zh") ;;
            skill-update-config)    INSTALL_SKILLS=true; SELECTED_SKILLS+=("update-config") ;;
            skill-handoff)          INSTALL_SKILLS=true; SELECTED_SKILLS+=("handoff") ;;
            # DeepXiv
            deepxiv-cli)            INSTALL_DEEPXIV=true; SELECTED_DEEPXIV_SKILLS+=("deepxiv-cli") ;;
            deepxiv-trending-digest) INSTALL_DEEPXIV=true; SELECTED_DEEPXIV_SKILLS+=("deepxiv-trending-digest") ;;
            deepxiv-baseline-table) INSTALL_DEEPXIV=true; SELECTED_DEEPXIV_SKILLS+=("deepxiv-baseline-table") ;;
            # MCP
            mcp)                    INSTALL_MCP=true ;;
            # Plugins (all plug-* ids)
            plug-*)
                INSTALL_PLUGINS=true
                local pkg
                pkg="$(_plug_id_to_pkg "$item_id")"
                [[ -n "$pkg" ]] && SELECTED_PLUGINS+=("$pkg") || true
                ;;
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
        info "  Code Review: adversarial=$REVIEW_ADVERSARIAL codex=$REVIEW_CODEX"
    else
        cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"

        # Dynamic Code Review section based on review tool selection
        local review_line
        if $REVIEW_ADVERSARIAL; then
            review_line='Whenever a code review is needed — whether explicitly requested by the user or triggered by a skill (e.g., `code-reviewer`, `simplify`) — always invoke the `adversarial-review` skill to perform it. If the adversarial-review skill is unavailable (e.g., `codex` CLI not installed), fall back to using the `code-reviewer` agent for the review. Never substitute the actual review call with a text-only description.'
        elif $REVIEW_CODEX; then
            review_line='Whenever a code review is needed — whether explicitly requested by the user or triggered by a skill (e.g., `code-reviewer`, `simplify`) — first check if the Codex plugin is available by running `/codex:setup`. If Codex is ready (`ready: true`), invoke `/codex:adversarial-review` to perform the review. If Codex is unavailable or not authenticated, fall back to using the `code-reviewer` agent for the review. Never substitute the actual review call with a text-only description.'
        else
            review_line='Whenever a code review is needed — whether explicitly requested by the user or triggered by a skill (e.g., `code-reviewer`, `simplify`) — use the `code-reviewer` agent to perform it. Never substitute the actual review call with a text-only description.'
        fi

        # Replace the Code Review line in CLAUDE.md (the line after "## Code Review\n")
        if command -v sed &>/dev/null; then
            # Use a temp file to avoid sed -i portability issues
            local tmp="$CLAUDE_DIR/CLAUDE.md.tmp"
            sed '/^Whenever a code review is needed/c\'"$review_line" "$CLAUDE_DIR/CLAUDE.md" > "$tmp" && mv "$tmp" "$CLAUDE_DIR/CLAUDE.md"
        fi

        ok "CLAUDE.md installed"
    fi
}

# Emit a JSON array of effective selected plugin packages (name@marketplace).
# Combines SELECTED_PLUGINS (individual picks) with PLUGIN_GROUPS expansion.
_effective_selected_plugins_json() {
    local pkgs=()
    if [[ ${#SELECTED_PLUGINS[@]} -gt 0 ]]; then
        pkgs+=("${SELECTED_PLUGINS[@]}")
    fi
    if [[ ${#PLUGIN_GROUPS[@]} -gt 0 ]]; then
        local g
        for g in "${PLUGIN_GROUPS[@]}"; do
            case "$g" in
                essential|core) pkgs+=("${PLUGINS_ESSENTIAL[@]}") ;;
                claude-mem)     pkgs+=("${PLUGINS_CLAUDE_MEM[@]}") ;;
                ai-research)    pkgs+=("${PLUGINS_AI_RESEARCH[@]}") ;;
                health)         pkgs+=("${PLUGINS_HEALTH[@]}") ;;
                pua)            pkgs+=("${PLUGINS_PUA[@]}") ;;
                all)            pkgs+=("${PLUGINS_ESSENTIAL[@]}" "${PLUGINS_OPTIONAL[@]}" "${PLUGINS_CLAUDE_MEM[@]}" "${PLUGINS_AI_RESEARCH[@]}" "${PLUGINS_HEALTH[@]}" "${PLUGINS_PUA[@]}") ;;
            esac
        done
    fi
    if [[ ${#pkgs[@]} -eq 0 ]]; then
        echo "[]"
        return
    fi
    if command -v jq &>/dev/null; then
        printf '%s\n' "${pkgs[@]}" | jq -R . | jq -cs 'unique'
    else
        local out="[" sep="" p
        for p in "${pkgs[@]}"; do
            local esc="${p//\\/\\\\}"; esc="${esc//\"/\\\"}"
            out+="${sep}\"${esc}\""
            sep=","
        done
        out+="]"
        echo "$out"
    fi
}

_supports_auto_mode() {
    # Auto mode requires Claude Code >= 2.1.80 (shipped 2026-03-24)
    local ver
    ver=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1) || return 1
    [[ -z "$ver" ]] && return 1
    local major minor patch
    IFS='.' read -r major minor patch <<< "$ver"
    # 2.1.80+
    (( major > 2 || (major == 2 && minor > 1) || (major == 2 && minor == 1 && patch >= 80) ))
}

install_settings() {
    info "Installing settings.json..."

    # Hoist jq install — both the merge branch and the fresh-install selection filter
    # need it. Without this, fresh installs on jq-less machines silently skipped
    # the plugin filter (bug_003) when statusline+lessons were both kept default-on.
    install_jq || true

    # Auto mode detection: downgrade to bypassPermissions if Claude Code is too old
    local USE_AUTO_MODE=true
    if ! command -v claude &>/dev/null; then
        USE_AUTO_MODE=false
        info "Claude Code not found — defaulting to bypassPermissions (auto mode available after install)"
    elif ! _supports_auto_mode; then
        USE_AUTO_MODE=false
        warn "Claude Code too old for auto mode (requires >= 2.1.80) — falling back to bypassPermissions"
    fi

    if [[ ! -f "$CLAUDE_DIR/settings.json" ]]; then
        # New file: copy with optional field stripping
        if $DRY_RUN; then
            info "Would copy: settings.json -> $CLAUDE_DIR/settings.json"
            $INSTALL_STATUSLINE || info "  - statusLine: skipped (not selected)"
            $INSTALL_LESSONS    || info "  - hooks.SessionStart: skipped (not selected)"
        else
            if ! $INSTALL_STATUSLINE || ! $INSTALL_LESSONS; then
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
            # Downgrade auto -> bypassPermissions if Claude Code too old
            if ! $USE_AUTO_MODE && [[ -f "$CLAUDE_DIR/settings.json" ]]; then
                if command -v jq &>/dev/null; then
                    local tmp; tmp=$(jq '.permissions.defaultMode = "bypassPermissions"' "$CLAUDE_DIR/settings.json")
                    echo "$tmp" > "$CLAUDE_DIR/settings.json"
                else
                    local sedtmp="$CLAUDE_DIR/settings.json.sedtmp"
                    sed 's/"defaultMode": "auto"/"defaultMode": "bypassPermissions"/' "$CLAUDE_DIR/settings.json" > "$sedtmp" && mv "$sedtmp" "$CLAUDE_DIR/settings.json"
                fi
            fi
            # Apply enabledPlugins selection filter. Catalogue = source keys ∪ selection,
            # so plugins picked in the menu that aren't declared in the shipped
            # settings.json (codex, health, pua) still land as true.
            if $INSTALL_PLUGINS && command -v jq &>/dev/null && [[ -f "$CLAUDE_DIR/settings.json" ]]; then
                local sel_json; sel_json="$(_effective_selected_plugins_json)"
                local tmp; tmp="$(jq --argjson selected "$sel_json" '
                    ($selected | reduce .[] as $p ({}; .[$p] = true)) as $sel |
                    .enabledPlugins = (((.enabledPlugins // {}) + $sel) | to_entries | map({key, value: ($sel[.key] // false)}) | from_entries)
                ' "$CLAUDE_DIR/settings.json")"
                echo "$tmp" > "$CLAUDE_DIR/settings.json"
            fi
            ok "settings.json installed (new)"
        fi
        return
    fi

    # File exists: smart merge with jq if available (jq was hoisted at function start)
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
        if $INSTALL_PLUGINS; then
            info "  - enabledPlugins: selection-aware rebuild (unselected known plugins disabled, unknown plugins preserved)"
        else
            info "  - enabledPlugins: union (existing preserved on conflict)"
        fi
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

    # Build JSON array of effective selected plugin packages. When plugins were
    # interacted with this run, unselected-but-locally-present plugins are disabled.
    local selected_json
    selected_json="$(_effective_selected_plugins_json)"
    local apply_sel=false
    $INSTALL_PLUGINS && apply_sel=true

    jq -s --argjson inc_sl "$inc_sl" --argjson inc_lh "$inc_lh" \
          --argjson selected "$selected_json" --argjson apply_sel "$apply_sel" '
    def unique_array: [.[] | tostring] | unique | [.[] | fromjson? // .];

    # $base = incoming (defaults), $over = existing (user overrides)
    .[0] as $base | .[1] as $over |

    # env: incoming as defaults, existing overrides
    ($base.env // {}) * ($over.env // {}) as $env |

    # permissions.allow: union
    (($base.permissions.allow // []) + ($over.permissions.allow // []) | unique) as $allow |

    # enabledPlugins:
    # When $apply_sel is true, apply the selection filter ONLY to keys the installer
    # knows about (keys of $base.enabledPlugins) — those become true iff in $selected,
    # else false. Keys that exist only in $over (user-added plugins outside our
    # catalogue) are preserved verbatim so the installer never silently disables
    # third-party plugins.
    # When $apply_sel is false, fall back to union (existing wins on conflict).
    (($selected | reduce .[] as $p ({}; .[$p] = true))) as $sel |
    (if $apply_sel then
       (
         # Known catalogue = $base keys + $sel keys (so plugins picked in the menu
         # that are not declared in the shipped settings.json — e.g. codex, health,
         # pua — still land in enabledPlugins as true).
         (($base.enabledPlugins // {}) + $sel) as $catalogue |
         ($catalogue | to_entries
           | map({key, value: ($sel[.key] // false)}) | from_entries) as $known_map |
         (($catalogue | keys)) as $known_keys |
         (($over.enabledPlugins // {})
           | with_entries(select(.key as $k | ($known_keys | index($k)) | not))) as $over_only |
         ($known_map + $over_only)
       )
     else
       # Fallback union: existing ($over) wins on conflict per the documented promise.
       (($base.enabledPlugins // {}) * ($over.enabledPlugins // {}))
     end) as $plugins |

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
        # Downgrade auto -> bypassPermissions if Claude Code too old
        if ! $USE_AUTO_MODE; then
            jq '.permissions.defaultMode = "bypassPermissions"' "$merged" > "${merged}.tmp" && mv "${merged}.tmp" "$merged"
        fi
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

    # Use `"${arr[@]+"${arr[@]}"}"` for langs: macOS ships bash 3.2 where the
    # plain form aborts under `set -u` when the array is empty (selective install
    # picking rules-common with no language rules).
    for lang in "${langs[@]+"${langs[@]}"}"; do
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
            for lang in "${langs[@]+"${langs[@]}"}"; do
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

    # Migration: remove renamed/deleted skills from previous installs
    for old_skill in "update"; do
        if [[ -d "$CLAUDE_DIR/skills/$old_skill" ]]; then
            rm -rf "$CLAUDE_DIR/skills/$old_skill"
            ok "Removed legacy skill: $old_skill"
        fi
    done

    # If specific skills were selected (interactive mode), install only those
    if [[ ${#SELECTED_SKILLS[@]} -gt 0 ]]; then
        for skill in "${SELECTED_SKILLS[@]}"; do
            local skill_dir="$SCRIPT_DIR/skills/$skill"
            if [[ -d "$skill_dir" ]]; then
                if $DRY_RUN; then
                    info "Would copy: skills/$skill/ -> $CLAUDE_DIR/skills/$skill/"
                else
                    rm -rf "$CLAUDE_DIR/skills/$skill"
                    cp -r "$skill_dir" "$CLAUDE_DIR/skills/$skill"
                    ok "Skill installed: $skill"
                fi
            else
                warn "Skill not found: $skill"
            fi
        done
    else
        # --all mode: install everything
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
    fi
}

install_deepxiv() {
    local repo_url="https://github.com/DeepXiv/deepxiv_sdk"
    info "Installing DeepXiv skills from github.com/DeepXiv/deepxiv_sdk..."
    mkdir -p "$CLAUDE_DIR/skills"

    # Pre-flight: git must be available
    if ! command -v git &>/dev/null; then
        error "git is required to install DeepXiv skills but was not found. Please install git first."
        return 1
    fi

    local deepxiv_tmp
    deepxiv_tmp="$(mktemp -d "${TMPDIR:-/tmp}/deepxiv_sdk.XXXXXX")" || { error "Failed to create temporary directory"; return 1; }

    # Use local copy; default to known list when nothing selected (--all mode)
    local -a skills_to_install=("${SELECTED_DEEPXIV_SKILLS[@]}")
    if [[ ${#skills_to_install[@]} -eq 0 ]]; then
        skills_to_install=("${DEEPXIV_KNOWN_SKILLS[@]}")
    fi

    # Clone the deepxiv_sdk repo (shallow clone for speed)
    local clone_ok=false
    if $DRY_RUN; then
        info "Would clone $repo_url (shallow) to temporary directory"
        clone_ok=true
    else
        if retry 3 3 "Clone deepxiv_sdk" git clone --depth 1 "$repo_url" "$deepxiv_tmp/deepxiv_sdk"; then
            clone_ok=true
            ok "DeepXiv SDK repo cloned (latest)"
        else
            error "Failed to clone deepxiv_sdk repo. Check network/proxy and try again."
            (( INSTALL_WARNINGS++ )) || true
            rm -rf "$deepxiv_tmp"
            return 1
        fi
    fi

    if $clone_ok && ! $DRY_RUN; then
        local src_skills="$deepxiv_tmp/deepxiv_sdk/skills"
        if [[ ! -d "$src_skills" ]]; then
            error "deepxiv_sdk/skills directory not found in cloned repo"
            (( INSTALL_WARNINGS++ )) || true
            rm -rf "$deepxiv_tmp"
            return 1
        fi

        for skill in "${skills_to_install[@]}"; do
            local skill_src="$src_skills/$skill"
            if [[ -d "$skill_src" ]]; then
                rm -rf "$CLAUDE_DIR/skills/$skill"
                cp -r "$skill_src" "$CLAUDE_DIR/skills/$skill"
                ok "DeepXiv skill installed: $skill"
            else
                warn "DeepXiv skill not found in repo: $skill"
                (( INSTALL_WARNINGS++ )) || true
            fi
        done
    elif $DRY_RUN; then
        for skill in "${skills_to_install[@]}"; do
            info "Would install DeepXiv skill: $skill -> $CLAUDE_DIR/skills/$skill/"
        done
    fi

    # Clean up
    rm -rf "$deepxiv_tmp"
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

    # Collect plugins from both SELECTED_PLUGINS and group-based collection
    local plugins=()
    # Add individually selected plugins (interactive mode / review selections)
    if [[ ${#SELECTED_PLUGINS[@]} -gt 0 ]]; then
        plugins+=("${SELECTED_PLUGINS[@]}")
    fi
    # Add group-based plugins (--all mode)
    if [[ ${#PLUGIN_GROUPS[@]} -gt 0 ]]; then
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
                pua)
                    plugins+=("${PLUGINS_PUA[@]}")
                    ;;
                all)
                    plugins+=("${PLUGINS_ESSENTIAL[@]}" "${PLUGINS_OPTIONAL[@]}" "${PLUGINS_CLAUDE_MEM[@]}" "${PLUGINS_AI_RESEARCH[@]}" "${PLUGINS_HEALTH[@]}" "${PLUGINS_PUA[@]}")
                    ;;
            esac
        done
    fi

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

    # Collect required marketplaces from selected plugins
    local marketplace_list=(
        "anthropic-agent-skills|anthropics/skills"
        "everything-claude-code|affaan-m/everything-claude-code"
        "ai-research-skills|zechenzhangAGI/AI-research-SKILLs"
        "claude-plugins-official|anthropics/claude-plugins-official"
        "thedotmack|thedotmack/claude-mem"
        "claude-health|tw93/claude-health"
        "pua-skills|tanweai/pua"
        "openai-codex|openai/codex-plugin-cc"
        "karpathy-skills|forrestchang/andrej-karpathy-skills"
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

    # Fix execute permissions on plugin shell scripts
    # Git clone / GitHub tarballs do not preserve the execute bit, causing
    # "Permission denied" errors when Claude Code runs hook scripts.
    if ! $DRY_RUN; then
        local fixed=0
        while IFS= read -r -d '' sh_file; do
            chmod +x "$sh_file"
            (( ++fixed ))
        done < <(find "$HOME/.claude/plugins/marketplaces" -name "*.sh" -type f ! -perm -u+x -print0 2>/dev/null)
        if (( fixed > 0 )); then
            ok "Fixed execute permissions on $fixed plugin shell script(s)"
        fi
    else
        info "Would fix execute permissions on plugin shell scripts"
    fi
}

# --- Uninstall ----------------------------------------------------------

uninstall() {
    echo ""
    warn "The following will be removed:"
    echo "  - $CLAUDE_DIR/CLAUDE.md"
    echo "  - $CLAUDE_DIR/settings.json (backed up first)"
    echo "  - $CLAUDE_DIR/rules/"
    echo "  - $CLAUDE_DIR/skills/ (installer-managed only)"
    echo "  - $CLAUDE_DIR/skills/deepxiv-* (DeepXiv skills)"
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

    # Remove DeepXiv skills (glob to catch any installed by --all)
    for deepxiv_skill in "$CLAUDE_DIR"/skills/deepxiv-*/; do
        [[ -d "$deepxiv_skill" ]] || continue
        rm -rf "$deepxiv_skill" && ok "Removed DeepXiv skill: $(basename "$deepxiv_skill")"
    done

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
        local all_plugins=("${PLUGINS_ESSENTIAL[@]}" "${PLUGINS_OPTIONAL[@]}" "${PLUGINS_CLAUDE_MEM[@]}" "${PLUGINS_AI_RESEARCH[@]}" "${PLUGINS_HEALTH[@]}" "${PLUGINS_PUA[@]}")
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
        # Review defaults for --all: adversarial ON, codex OFF
        REVIEW_ADVERSARIAL=true
        if $EXPLICIT_ALL; then
            # Explicit --all: install everything including MCP, DeepXiv, and all plugin groups
            INSTALL_MCP=true
            INSTALL_DEEPXIV=true
            SELECTED_DEEPXIV_SKILLS=("${DEEPXIV_KNOWN_SKILLS[@]}")
            PLUGIN_GROUPS=("all")
            # Add code-review plugin (normally from Review group)
            SELECTED_PLUGINS+=("code-review@claude-plugins-official")
        else
            # Implicit (non-TTY fallback): essential plugins only, no MCP
            PLUGIN_GROUPS=("essential")
        fi
    fi

    # Check if anything was selected
    if ! $INSTALL_CLAUDE_MD && ! $INSTALL_SETTINGS && ! $INSTALL_RULES && \
       ! $INSTALL_SKILLS && ! $INSTALL_LESSONS && ! $INSTALL_STATUSLINE && \
       ! $INSTALL_PLUGINS && ! $INSTALL_MCP && ! $INSTALL_DEEPXIV; then
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
    $INSTALL_DEEPXIV && install_deepxiv

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
