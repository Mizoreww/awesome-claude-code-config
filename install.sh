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

Options:
    --all               Install everything (default; MCP excluded, see --mcp)
    --rules LANG...     Install common + specific language rules
                        Available: python, typescript, golang
    --skills            Install custom skills only
    --lessons           Install lessons.md template only
    --hooks             Install hooks (statusline) only
    --mcp               Install MCP servers (Lark) — not included in --all
    --plugins [GROUP]   Install plugins (default: core)
                        Groups: core, ai-research, all
    --claude-md         Install CLAUDE.md only
    --settings          Install settings.json only
    --uninstall [COMP]  Remove installed files (optionally: rules, skills, settings, etc.)
    --version           Show version info
    --dry-run           Show what would be installed without doing it
    --force             Skip confirmation prompts (for non-interactive use)
    -h, --help          Show this help

Examples:
    $(basename "$0")                                 # Install everything (core plugins)
    $(basename "$0") --rules python golang           # Install common + Python + Go rules
    $(basename "$0") --plugins                       # Install core plugins
    $(basename "$0") --plugins all                   # Install all plugins
    $(basename "$0") --plugins ai-research           # Install AI research plugins only
    $(basename "$0") --uninstall                     # Uninstall everything
    $(basename "$0") --uninstall --rules             # Uninstall rules only
    $(basename "$0") --dry-run                       # Preview changes
    bash <(curl -fsSL $REPO_URL/raw/main/install.sh) # Remote install
EOF
}

# --- Flags & state ------------------------------------------------------

DRY_RUN=false
INSTALL_ALL=true
INSTALL_RULES=false
INSTALL_SKILLS=false
INSTALL_LESSONS=false
INSTALL_HOOKS=false
INSTALL_MCP=false
INSTALL_PLUGINS=false
INSTALL_CLAUDE_MD=false
INSTALL_SETTINGS=false
UNINSTALL=false
FORCE=false
SHOW_VERSION=false
PLUGIN_GROUP="core"
RULE_LANGS=()
UNINSTALL_COMPONENTS=()

# --- Plugin groups ------------------------------------------------------

PLUGINS_CORE=(
    "document-skills@anthropic-agent-skills"
    "example-skills@anthropic-agent-skills"
    "everything-claude-code@everything-claude-code"
    "claude-mem@thedotmack"
    "frontend-design@claude-plugins-official"
    "context7@claude-plugins-official"
    "superpowers@claude-plugins-official"
    "code-review@claude-plugins-official"
    "github@claude-plugins-official"
    "playwright@claude-plugins-official"
    "feature-dev@claude-plugins-official"
    "code-simplifier@claude-plugins-official"
    "ralph-loop@claude-plugins-official"
    "commit-commands@claude-plugins-official"
)

PLUGINS_AI_RESEARCH=(
    "fine-tuning@ai-research-skills"
    "post-training@ai-research-skills"
    "inference-serving@ai-research-skills"
    "distributed-training@ai-research-skills"
    "optimization@ai-research-skills"
)

# --- Argument parsing ---------------------------------------------------

parse_args() {
    if [[ $# -eq 0 ]]; then
        return
    fi

    local has_component=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all)
                INSTALL_ALL=true
                shift
                ;;
            --rules)
                has_component=true
                INSTALL_RULES=true
                shift
                while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do
                    RULE_LANGS+=("$1")
                    shift
                done
                ;;
            --skills)
                has_component=true
                INSTALL_SKILLS=true
                shift
                ;;
            --lessons)
                has_component=true
                INSTALL_LESSONS=true
                shift
                ;;
            --hooks)
                has_component=true
                INSTALL_HOOKS=true
                shift
                ;;
            --mcp)
                has_component=true
                INSTALL_MCP=true
                shift
                ;;
            --plugins)
                has_component=true
                INSTALL_PLUGINS=true
                shift
                # Optional group argument
                if [[ $# -gt 0 && ! "$1" =~ ^-- ]]; then
                    case "$1" in
                        core|ai-research|all)
                            PLUGIN_GROUP="$1"
                            shift
                            ;;
                        *)
                            # Not a group name, leave for next iteration
                            ;;
                    esac
                fi
                ;;
            --claude-md)
                has_component=true
                INSTALL_CLAUDE_MD=true
                shift
                ;;
            --settings)
                has_component=true
                INSTALL_SETTINGS=true
                shift
                ;;
            --uninstall)
                UNINSTALL=true
                shift
                # Collect component flags that follow --uninstall
                while [[ $# -gt 0 && "$1" =~ ^-- ]]; do
                    case "$1" in
                        --rules)    UNINSTALL_COMPONENTS+=("rules"); shift ;;
                        --skills)   UNINSTALL_COMPONENTS+=("skills"); shift ;;
                        --settings) UNINSTALL_COMPONENTS+=("settings"); shift ;;
                        --claude-md) UNINSTALL_COMPONENTS+=("claude-md"); shift ;;
                        --lessons)  UNINSTALL_COMPONENTS+=("lessons"); shift ;;
                        --hooks)    UNINSTALL_COMPONENTS+=("hooks"); shift ;;
                        --plugins)  UNINSTALL_COMPONENTS+=("plugins"); shift ;;
                        --mcp)      UNINSTALL_COMPONENTS+=("mcp"); shift ;;
                        --force)    FORCE=true; shift ;;
                        --dry-run)  DRY_RUN=true; shift ;;
                        *)          break ;;
                    esac
                done
                ;;
            --version)
                SHOW_VERSION=true
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
                # Legacy mode: treat bare args as language names
                has_component=true
                INSTALL_RULES=true
                RULE_LANGS+=("$1")
                shift
                ;;
        esac
    done

    if $has_component; then
        INSTALL_ALL=false
    fi
}

# --- Confirm prompt (respects --force) ----------------------------------

confirm() {
    local prompt="${1:-Continue?}"
    if $FORCE; then
        return 0
    fi
    if [[ ! -t 0 ]]; then
        error "Non-interactive shell detected. Use --force to skip confirmation."
        exit 1
    fi
    echo -en "${YELLOW}${prompt} [y/N] ${NC}"
    read -r answer
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
        # New file: just copy
        if $DRY_RUN; then
            info "Would copy: settings.json -> $CLAUDE_DIR/settings.json"
        else
            cp "$SCRIPT_DIR/settings.json" "$CLAUDE_DIR/settings.json"
            ok "settings.json installed (new)"
        fi
        return
    fi

    # File exists: smart merge with jq if available
    if ! command -v jq &>/dev/null; then
        warn "settings.json already exists and jq is not installed"
        warn "  Cannot perform smart merge. Please merge manually:"
        warn "  Source: $SCRIPT_DIR/settings.json"
        warn "  Target: $CLAUDE_DIR/settings.json"
        return
    fi

    if $DRY_RUN; then
        info "Would smart-merge settings.json (jq available)"
        info "  - env: incoming as defaults, existing overrides"
        info "  - permissions.allow: union of arrays"
        info "  - enabledPlugins: merged, existing keys take priority"
        info "  - hooks.SessionStart: deduplicated by matcher"
        info "  - statusLine: incoming takes priority"
        return
    fi

    local existing="$CLAUDE_DIR/settings.json"
    local incoming="$SCRIPT_DIR/settings.json"
    local merged
    merged="$(mktemp)"

    jq -s '
    def unique_array: [.[] | tostring] | unique | [.[] | fromjson? // .];

    # $base = incoming (defaults), $over = existing (user overrides)
    .[0] as $base | .[1] as $over |

    # env: incoming as defaults, existing overrides
    ($base.env // {}) * ($over.env // {}) as $env |

    # permissions.allow: union
    (($base.permissions.allow // []) + ($over.permissions.allow // []) | unique) as $allow |

    # enabledPlugins: merge, existing wins
    (($base.enabledPlugins // {}) * ($over.enabledPlugins // {})) as $plugins |

    # hooks.SessionStart: deduplicate by matcher
    (
      (($base.hooks.SessionStart // []) + ($over.hooks.SessionStart // []))
      | group_by(.matcher)
      | map(last)
    ) as $session_hooks |

    # Build merged object: start with incoming, overlay existing, then set merged fields
    ($base * $over) * {
      env: $env,
      enabledPlugins: $plugins,
      statusLine: ($base.statusLine // null),
      permissions: (($base.permissions // {}) * ($over.permissions // {}) + {allow: $allow}),
      hooks: (($base.hooks // {}) * ($over.hooks // {}) + {SessionStart: $session_hooks})
    }
    ' "$incoming" "$existing" > "$merged"

    if jq empty "$merged" 2>/dev/null; then
        mv "$merged" "$existing"
        ok "settings.json smart-merged"
    else
        rm -f "$merged"
        error "Merge produced invalid JSON — keeping existing file"
        warn "Please merge manually: $incoming -> $existing"
    fi
}

install_rules() {
    info "Installing rules..."
    mkdir -p "$CLAUDE_DIR/rules"

    # Always install common rules

    if $DRY_RUN; then
        info "Would copy: rules/common/ -> $CLAUDE_DIR/rules/common/"
    else
        cp -r "$SCRIPT_DIR/rules/common" "$CLAUDE_DIR/rules/common"
        ok "Common rules installed"
    fi

    # Install language-specific rules
    local langs=()
    if [[ ${#RULE_LANGS[@]} -gt 0 ]]; then
        langs=("${RULE_LANGS[@]}")
    fi
    if [[ ${#langs[@]} -eq 0 ]]; then
        for lang_dir in "$SCRIPT_DIR"/rules/*/; do
            local lang
            lang=$(basename "$lang_dir")
            [[ "$lang" == "common" || "$lang" == "README.md" ]] && continue
            langs+=("$lang")
        done
    fi

    for lang in "${langs[@]}"; do
        if [[ -d "$SCRIPT_DIR/rules/$lang" ]]; then

            if $DRY_RUN; then
                info "Would copy: rules/$lang/ -> $CLAUDE_DIR/rules/$lang/"
            else
                cp -r "$SCRIPT_DIR/rules/$lang" "$CLAUDE_DIR/rules/$lang"
                ok "$lang rules installed"
            fi
        else
            error "Language rules not found: $lang"
        fi
    done

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

install_hooks() {
    info "Installing hooks..."
    mkdir -p "$CLAUDE_DIR/hooks"

    for hook_file in "$SCRIPT_DIR"/hooks/*; do
        [[ -f "$hook_file" ]] || continue
        local fname
        fname=$(basename "$hook_file")
        if $DRY_RUN; then
            info "Would copy: hooks/$fname -> $CLAUDE_DIR/hooks/$fname"
        else
            cp "$hook_file" "$CLAUDE_DIR/hooks/$fname"
            chmod +x "$CLAUDE_DIR/hooks/$fname"
            ok "Hook installed: $fname"
        fi
    done
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
    info "Installing plugins (group: $PLUGIN_GROUP)..."

    if ! command -v claude &>/dev/null; then
        error "Claude Code CLI not found. Install it first: https://claude.com/claude-code"
        return 1
    fi

    # Determine which plugins to install
    local plugins=()
    case "$PLUGIN_GROUP" in
        core)
            plugins=("${PLUGINS_CORE[@]}")
            ;;
        ai-research)
            plugins=("${PLUGINS_AI_RESEARCH[@]}")
            ;;
        all)
            plugins=("${PLUGINS_CORE[@]}" "${PLUGINS_AI_RESEARCH[@]}")
            ;;
    esac

    # Collect required marketplaces from selected plugins
    local marketplace_list=(
        "anthropic-agent-skills|anthropics/skills"
        "everything-claude-code|affaan-m/everything-claude-code"
        "ai-research-skills|zechenzhangAGI/AI-research-SKILLs"
        "claude-plugins-official|anthropics/claude-plugins-official"
        "thedotmack|thedotmack/claude-mem"
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
            fi
        fi
    done
}

# --- Uninstall ----------------------------------------------------------

uninstall() {
    local components=("${UNINSTALL_COMPONENTS[@]}")

    # If no specific components, uninstall everything
    if [[ ${#components[@]} -eq 0 ]]; then
        components=(claude-md settings rules skills lessons hooks)
    fi

    echo ""
    warn "The following will be removed:"
    for comp in "${components[@]}"; do
        case "$comp" in
            claude-md) echo "  - $CLAUDE_DIR/CLAUDE.md" ;;
            settings)  echo "  - $CLAUDE_DIR/settings.json" ;;
            rules)     echo "  - $CLAUDE_DIR/rules/" ;;
            skills)    echo "  - $CLAUDE_DIR/skills/ (installer-managed only)" ;;
            lessons)   echo "  - $CLAUDE_DIR/lessons.md" ;;
            hooks)     echo "  - $CLAUDE_DIR/hooks/ (installer-managed only)" ;;
            plugins)   echo "  - Installed plugins (requires claude CLI)" ;;
            mcp)       echo "  - MCP server: lark-mcp (requires claude CLI)" ;;
        esac
    done
    if [[ -f "$VERSION_STAMP_FILE" ]]; then
        echo "  - $VERSION_STAMP_FILE"
    fi
    echo ""

    if $DRY_RUN; then
        warn "DRY RUN -- nothing will be removed"
        return
    fi

    if ! confirm "Proceed with uninstall?"; then
        info "Cancelled."
        exit 0
    fi

    for comp in "${components[@]}"; do
        case "$comp" in
            claude-md)
                rm -f "$CLAUDE_DIR/CLAUDE.md" && ok "Removed CLAUDE.md" ;;
            settings)
                rm -f "$CLAUDE_DIR/settings.json" && ok "Removed settings.json" ;;
            rules)
                rm -rf "$CLAUDE_DIR/rules" && ok "Removed rules/" ;;
            skills)
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
                ;;
            lessons)
                rm -f "$CLAUDE_DIR/lessons.md" && ok "Removed lessons.md" ;;
            hooks)
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
                ;;
            plugins)
                if command -v claude &>/dev/null; then
                    local all_plugins=("${PLUGINS_CORE[@]}" "${PLUGINS_AI_RESEARCH[@]}")
                    for entry in "${all_plugins[@]}"; do
                        local plugin_name="${entry%%@*}"
                        claude plugin uninstall "$entry" 2>/dev/null && \
                            ok "Uninstalled plugin: $plugin_name" || \
                            warn "Could not uninstall: $plugin_name"
                    done
                else
                    warn "Claude CLI not found — cannot uninstall plugins"
                fi
                ;;
            mcp)
                if command -v claude &>/dev/null; then
                    claude mcp remove lark-mcp 2>/dev/null && \
                        ok "Removed MCP server: lark-mcp" || \
                        warn "Could not remove lark-mcp"
                else
                    warn "Claude CLI not found — cannot remove MCP servers"
                fi
                ;;
        esac
    done

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

    if $INSTALL_ALL; then
        install_claude_md
        install_settings
        install_rules
        install_skills
        install_lessons
        install_hooks
        # MCP is NOT included in --all; use --mcp explicitly
        install_plugins
    else
        $INSTALL_CLAUDE_MD && install_claude_md
        $INSTALL_SETTINGS && install_settings
        $INSTALL_RULES && install_rules
        $INSTALL_SKILLS && install_skills
        $INSTALL_LESSONS && install_lessons
        $INSTALL_HOOKS && install_hooks
        $INSTALL_MCP && install_mcp
        $INSTALL_PLUGINS && install_plugins
    fi

    # Stamp version
    if ! $DRY_RUN; then
        stamp_version
    fi

    echo ""
    ok "Installation complete! ($(get_source_version))"
    echo ""
    info "Next steps:"
    echo "  1. Restart Claude Code for changes to take effect"
    if $INSTALL_MCP || { $INSTALL_ALL && false; }; then
        echo "  2. Replace YOUR_APP_ID/YOUR_APP_SECRET in Lark MCP config"
    fi
    echo "  3. Customize CLAUDE.md for your specific projects"
    echo "  4. Review settings.json and merge with your existing config"
    echo ""
}

main "$@"
