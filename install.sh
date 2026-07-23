#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Codex Configuration Installer
# https://github.com/Mizoreww/awesome-claude-code-config
# ============================================================

CODEX_DIR="$HOME/.codex"
REPO_OWNER="${REPO_OWNER:-Mizoreww}"
REPO_NAME="${REPO_NAME:-awesome-claude-code-config}"
REPO_BRANCH="${REPO_BRANCH:-codex}"
# These values are interpolated into download URLs used in remote mode.
# Validate against a safe charset so a hostile/garbled environment cannot
# smuggle unexpected content into the URLs. (error() is not defined yet at
# this point in the script, so emit to stderr directly.)
if [[ ! "$REPO_OWNER" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Invalid REPO_OWNER: $REPO_OWNER" >&2; exit 1
fi
if [[ ! "$REPO_NAME" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Invalid REPO_NAME: $REPO_NAME" >&2; exit 1
fi
if [[ ! "$REPO_BRANCH" =~ ^[A-Za-z0-9._/-]+$ ]]; then
  echo "Invalid REPO_BRANCH: $REPO_BRANCH" >&2; exit 1
fi
REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}"
VERSION_STAMP_FILE="$CODEX_DIR/.codex-config-version"
LEGACY_VERSION_STAMP_FILE="$CODEX_DIR/.claude-code-config-version"
INSTALLER="$CODEX_DIR/skills/.system/skill-installer/scripts/install-skill-from-github.py"
SUPERPOWERS_REPO_URL="https://github.com/obra/superpowers.git"
SUPERPOWERS_DIR="$CODEX_DIR/superpowers"
AGENTS_SKILLS_DIR="$HOME/.agents/skills"
# `skills@latest` currently stages universal Codex installs under
# ~/.agents/skills even with --agent codex --copy. Keep that directory as an
# upstream staging/compatibility location only; Codex-branch skills are owned
# and loaded from ~/.codex/skills.
SUPERPOWERS_LINK="$CODEX_DIR/skills/superpowers"
LEGACY_SUPERPOWERS_LINK="$AGENTS_SKILLS_DIR/superpowers"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

SCRIPT_DIR=""
REMOTE_MODE=false
REMOTE_TMPDIR=""
MENU_ACTIVE=false
MENU_SAVED_STTY=""

DRY_RUN=false
FORCE=false
INSTALL_ALL=true
INSTALL_CORE=false
INSTALL_MCP=false
INSTALL_SKILLS=false
INSTALL_RESEARCHSTUDIO_NONINTERACTIVE=false
INSTALL_RESEARCHSTUDIO_REEL_NONINTERACTIVE=false
INSTALL_PPT_MASTER_NONINTERACTIVE=false
UNINSTALL=false
SHOW_VERSION=false
INTERACTIVE_MODE=false
SKILL_GROUP="all"
UNINSTALL_COMPONENTS=()
SKIPPED_COMPONENTS=()
MCP_FAILED_SERVERS=()
LESSONS_SEEDED=false
OWNED_MANAGED_SKILLS=()
MANAGED_SKILLS_OWNERSHIP_LOADED=false
MATTPOCOCK_QUICKSTART_READY=false
MATTPOCOCK_VERSION="v1.1.0"
MATTPOCOCK_COMMIT="d574778f94cf620fcc8ce741584093bc650a61d3"

SELECT_CORE_AGENTS_MD=false
SELECT_CORE_CONFIG=false
SELECT_CORE_LESSONS=false
SELECT_CORE_STATUSLINE=false
SELECT_AGENT_EXPLORER=false
SELECT_AGENT_REVIEWER=false
SELECT_AGENT_DOCS_RESEARCHER=false
SELECT_SKILL_SUPERPOWERS=false
SELECT_SKILL_DOCUMENTS=false
SELECT_SKILL_EXAMPLES=false
SELECT_SKILL_FRONTEND_DESIGN=false
SELECT_SKILL_KARPATHY=false
SELECT_SKILL_MATTPOCOCK=false
SELECT_SKILL_CODE_REVIEW=false
SELECT_SKILL_PUA=false
SELECT_SKILL_FRONTEND_SLIDES=false
SELECT_SKILL_PPT_MASTER=false
SELECT_SKILL_PAPER_READING=false
SELECT_SKILL_HUMANIZER=false
SELECT_SKILL_HUMANIZER_ZH=false
SELECT_SKILL_HANDOFF=false
SELECT_SKILL_NEAT_FREAK=false
SELECT_SKILL_ADVERSARIAL_REVIEW=false
SELECT_SKILL_UPDATE=false
SELECT_AI_TOKENIZATION=false
SELECT_AI_FINE_TUNING=false
SELECT_AI_POST_TRAINING=false
SELECT_AI_DISTRIBUTED_TRAINING=false
SELECT_AI_INFERENCE_SERVING=false
SELECT_AI_OPTIMIZATION=false
SELECT_AI_DEEPXIV=false
SELECT_AI_RESEARCHSTUDIO=false
SELECT_AI_RESEARCHSTUDIO_REEL=false
SELECT_MCP_CONTEXT7=false
SELECT_MCP_GITHUB=false
SELECT_MCP_PLAYWRIGHT=false
SELECT_MCP_OPENAI_DOCS=false
SELECT_MCP_LARK=false

MANAGED_SKILLS=(
  frontend-design pdf docx pptx xlsx canvas-design algorithmic-art mcp-builder
  using-superpowers systematic-debugging writing-plans test-driven-development
  huggingface-tokenizers sentencepiece
  axolotl llama-factory peft-fine-tuning unsloth
  grpo-rl-training openrlhf-training simpo-training fine-tuning-with-trl verl-rl-training
  deepspeed pytorch-fsdp2 training-llms-megatron ray-train
  awq-quantization gptq gguf-quantization optimizing-attention-flash quantizing-models-bitsandbytes
  serving-llms-vllm sglang tensorrt-llm llama-cpp
  paper-reading
  adversarial-review
  handoff
  neat-freak
  humanizer
  humanizer-zh
  update
  deepxiv-cli
  deepxiv-baseline-table
  deepxiv-trending-digest
  idea_spark
  paper_search
  scoop_check
  paper2assets
  paper2poster
  paper2video
  paper2blog
  paper2reel
  code-review
  karpathy-guidelines
  brainstorming dispatching-parallel-agents executing-plans finishing-a-development-branch
  receiving-code-review requesting-code-review subagent-driven-development using-git-worktrees
  verification-before-completion writing-skills
  frontend-slides
  ppt-master
  ask-matt diagnosing-bugs grill-with-docs triage
  implement improve-codebase-architecture setup-matt-pocock-skills tdd
  to-spec to-tickets wayfinder prototype domain-modeling codebase-design
  grill-me grilling research teach writing-great-skills
  pua pua-en pua-ja
)

LEGACY_CLEANUP_SKILLS=(
  python-patterns python-testing golang-patterns golang-testing frontend-patterns
  security-review tdd-workflow verification-loop api-design database-migrations
)

MATTPOCOCK_LEGACY_SKILLS=(
  to-issues to-prd decision-mapping review
)

OWNERSHIP_SKILLS=(
  "${MANAGED_SKILLS[@]}"
  "${LEGACY_CLEANUP_SKILLS[@]}"
  "${MATTPOCOCK_LEGACY_SKILLS[@]}"
)

LEGACY_SUPERPOWERS_SKILLS=(
  using-superpowers
  systematic-debugging
  writing-plans
  test-driven-development
)

MATTPOCOCK_SKILLS=(
  ask-matt diagnosing-bugs grill-with-docs triage
  implement improve-codebase-architecture setup-matt-pocock-skills tdd
  to-spec to-tickets wayfinder prototype domain-modeling codebase-design
  grill-me grilling research teach writing-great-skills
)

RESEARCHSTUDIO_SKILLS=(idea_spark paper_search scoop_check)
RESEARCHSTUDIO_REEL_SKILLS=(paper2assets paper2poster paper2video paper2blog paper2reel)
RESEARCHSTUDIO_REPO_URL="https://github.com/microsoft/ResearchStudio.git"
PUA_SKILLS=(pua pua-en pua-ja)
SUPERPOWERS_SKILLS=(
  brainstorming dispatching-parallel-agents executing-plans finishing-a-development-branch
  receiving-code-review requesting-code-review subagent-driven-development systematic-debugging
  test-driven-development using-git-worktrees using-superpowers verification-before-completion
  writing-plans writing-skills
)
LOCAL_MANAGED_SKILLS=(paper-reading humanizer humanizer-zh handoff neat-freak adversarial-review update)
MANAGED_SKILLS_STATE_FILE="$CODEX_DIR/.awesome-claude-code-config-managed-skills"
if [[ -n "${XDG_STATE_HOME:-}" ]]; then
  GLOBAL_SKILL_LOCK_FILE="$XDG_STATE_HOME/skills/.skill-lock.json"
else
  GLOBAL_SKILL_LOCK_FILE="$HOME/.agents/.skill-lock.json"
fi
CODEX_STATUS_LINE='status_line = ["model", "reasoning", "project-name", "git-branch", "context-used", "five-hour-limit", "weekly-limit"]'
CODEX_STATUS_LINE_USE_COLORS='status_line_use_colors = true'
PLAYWRIGHT_MCP_VERSION="0.0.78"
PLAYWRIGHT_MIN_NODE_MAJOR=20
PLAYWRIGHT_NODE_FALLBACK_VERSION="24"
SKILLS_MIN_NODE_MAJOR=20
SKILLS_NODE_FALLBACK_VERSION="24"
SKILLS_NODE_FALLBACK_NOTIFIED=false
SKILLS_NPX_LAUNCHER_ARGS=()
NPX_VERIFIED_SKILL_NAMES=()

show_mattpocock_quickstart() {
  $MATTPOCOCK_QUICKSTART_READY || return 0
  $DRY_RUN && return 0

  echo ""
  echo "Matt Pocock skills quickstart (30-second setup)"
  echo "  Matt Pocock skills are already installed; do not run npx again."
  echo "  1. Restart Codex if it was open during installation."
  echo "  2. Type /skills (or press @), choose List skills, then search for setup-matt-pocock-skills."
  echo "  3. Insert and run it; it will configure the issue tracker, triage labels when applicable, and domain docs."
  echo "  Note: installed skills are not individual root slash commands such as /setup-matt-pocock-skills."
}

replace_literal_in_file() {
  local file="$1"
  local old_text="$2"
  local new_text="$3"
  local temp_file

  [[ -f "$file" && -n "$old_text" ]] || return 1
  temp_file="$(mktemp "${TMPDIR:-/tmp}/codex-skill-adapter.XXXXXX")" || return 1
  if ! OLD_TEXT="$old_text" NEW_TEXT="$new_text" awk '
    BEGIN {
      old_text = ENVIRON["OLD_TEXT"]
      new_text = ENVIRON["NEW_TEXT"]
    }
    {
      rest = $0
      output = ""
      while ((position = index(rest, old_text)) > 0) {
        output = output substr(rest, 1, position - 1) new_text
        rest = substr(rest, position + length(old_text))
      }
      print output rest
    }
  ' "$file" > "$temp_file"; then
    rm -f "$temp_file"
    return 1
  fi
  if ! cp "$temp_file" "$file"; then
    rm -f "$temp_file"
    return 1
  fi
  rm -f "$temp_file"
}

adapt_researchstudio_idea_for_codex() {
  local paper_skill="$CODEX_DIR/skills/paper_search/SKILL.md"
  local scoop_skill="$CODEX_DIR/skills/scoop_check/SKILL.md"
  local fetch_script="$CODEX_DIR/skills/scoop_check/scripts/fetch_paper.sh"
  local search_script="$CODEX_DIR/skills/paper_search/scripts/search_papers.py"
  local scoop_fetch="$CODEX_DIR/skills/scoop_check/scripts/fetch_paper.sh"

  replace_literal_in_file "$paper_skill" '${CLAUDE_PROJECT_DIR}/skills/paper_search/scripts/search_papers.py' "$search_script" &&
    replace_literal_in_file "$paper_skill" '${CLAUDE_PROJECT_DIR}/allinone.md' '${PWD}/allinone.md' &&
    replace_literal_in_file "$scoop_skill" '.claude/skills/' 'the installed Codex skills directory' &&
    replace_literal_in_file "$scoop_skill" '${CLAUDE_PROJECT_DIR}' '${PWD}' &&
    replace_literal_in_file "$scoop_skill" 'Do **not** use `AskUserQuestion` or pause for confirmation at any point' 'Do **not** ask a blocking clarification question or pause for confirmation at any point' &&
    replace_literal_in_file "$scoop_skill" 'use `TaskCreate` to register all seven steps as tasks up front' "use Codex's \`update_plan\` tool to register all seven steps up front" &&
    replace_literal_in_file "$scoop_skill" 'handing the PDF URL to `WebFetch` directly' 'asking Codex web browsing to summarize the PDF directly' &&
    replace_literal_in_file "$scoop_skill" 'Use `WebFetch` first only to locate the PDF URL' 'Use Codex web browsing only to locate the PDF URL' &&
    replace_literal_in_file "$scoop_skill" 'Use the `Read` tool on the printed `.txt` path.' "Read the printed \`.txt\` path with Codex's local filesystem tools." &&
    replace_literal_in_file "$scoop_skill" 'try `WebFetch` on the abstract / HTML version' 'use Codex web browsing on the abstract / HTML version' &&
    replace_literal_in_file "$scoop_skill" 'scripts/fetch_paper.sh "<PDF_URL>" "<pdf_name>"' "bash \"$scoop_fetch\" \"<PDF_URL>\" \"<pdf_name>\"" &&
    replace_literal_in_file "$fetch_script" ': "${CLAUDE_PROJECT_DIR:?CLAUDE_PROJECT_DIR must be set}"' 'PROJECT_DIR="${CODEX_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-$PWD}}"' &&
    replace_literal_in_file "$fetch_script" '${CLAUDE_PROJECT_DIR}' '${PROJECT_DIR}'
}

researchstudio_idea_adapter_is_ready() {
  local paper_search_skill="$CODEX_DIR/skills/paper_search/SKILL.md"
  local paper_search_script="$CODEX_DIR/skills/paper_search/scripts/search_papers.py"
  local scoop_skill="$CODEX_DIR/skills/scoop_check/SKILL.md"
  local scoop_fetch_script="$CODEX_DIR/skills/scoop_check/scripts/fetch_paper.sh"

  [[ -f "$CODEX_DIR/skills/idea_spark/SKILL.md" &&
     -f "$paper_search_skill" &&
     -f "$paper_search_script" &&
     -f "$scoop_skill" &&
     -f "$scoop_fetch_script" ]] || return 1
  grep -Fq "$paper_search_script" "$paper_search_skill" || return 1
  grep -Fq "bash \"$scoop_fetch_script\"" "$scoop_skill" || return 1
  grep -Eq 'TaskCreate|AskUserQuestion|WebFetch|`Read` tool' "$scoop_skill" && return 1
  grep -q 'CLAUDE_PROJECT_DIR must be set' "$scoop_fetch_script" && return 1
  bash -n "$scoop_fetch_script"
}

cleanup_menu() {
  if $MENU_ACTIVE; then
    MENU_ACTIVE=false
    printf '\033[?1049l' 2>/dev/null || true
    if [[ -n "$MENU_SAVED_STTY" ]]; then
      stty "$MENU_SAVED_STTY" <&3 2>/dev/null || true
    else
      stty echo <&3 2>/dev/null || true
    fi
    tput cnorm 2>/dev/null || printf '\033[?25h'
    exec 3<&- 2>/dev/null || true
    MENU_SAVED_STTY=""
  fi
}

cleanup_runtime() {
  cleanup_menu

  if [[ -n "$REMOTE_TMPDIR" ]]; then
    rm -rf "$REMOTE_TMPDIR"
    REMOTE_TMPDIR=""
  fi

}

cleanup_and_exit() {
  local code="${1:-0}"
  cleanup_runtime
  exit "$code"
}

download_archive() {
  local url="$1"
  local target="$2"
  local attempt

  for attempt in 1 2 3 4 5; do
    if command -v curl >/dev/null 2>&1; then
      if curl -fsSL "$url" -o "$target"; then
        return 0
      fi
    elif command -v wget >/dev/null 2>&1; then
      if wget -qO "$target" "$url"; then
        return 0
      fi
    else
      error "Neither curl nor wget found. Install one and retry."
      return 1
    fi

    if [[ "$attempt" -lt 5 ]]; then
      warn "Download source archive failed (attempt $attempt/5), retrying in 3s..."
      sleep 3
    fi
  done

  return 1
}

detect_script_dir() {
  local candidate
  candidate="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if [[ -f "$candidate/AGENTS.md" ]]; then
    SCRIPT_DIR="$candidate"
    REMOTE_MODE=false
    return
  fi

  REMOTE_MODE=true
  REMOTE_TMPDIR="$(mktemp -d)"
  trap cleanup_runtime EXIT

  local version="${VERSION:-$REPO_BRANCH}"
  local tarball_url="$REPO_URL/archive/refs/heads/${version}.tar.gz"
  if [[ "$version" =~ ^v[0-9] ]]; then
    tarball_url="$REPO_URL/archive/refs/tags/${version}.tar.gz"
  fi

  info "Remote mode: downloading $version..."
  local archive="$REMOTE_TMPDIR/source.tar.gz"
  if ! download_archive "$tarball_url" "$archive"; then
    error "Failed to download source archive: $tarball_url"
    exit 1
  fi
  if ! tar xzf "$archive" -C "$REMOTE_TMPDIR" --strip-components=1; then
    error "Failed to extract source archive: $archive"
    exit 1
  fi
  rm -f "$archive"

  SCRIPT_DIR="$REMOTE_TMPDIR"
  ok "Source downloaded to temporary directory"
}

usage() {
  cat <<EOF2
Usage: $(basename "$0") [OPTIONS]

Install Codex configuration files.
Running without component flags launches an interactive selector.
Use --all for non-interactive full install.

Options:
  --all                 Install everything non-interactively
  --core                Install AGENTS.md, blank global lessons.md, config.toml, agents/*
  --mcp                 Install MCP servers only
  --skills [GROUP]      Install skills only. GROUP: core, ai-research, all (default: all)
                        Default-off ResearchStudio/PPT entries require an explicit GROUP or --all
  --uninstall [COMP...] Uninstall managed files. COMP: --core --mcp --skills
  --version             Show source / installed / remote versions
  --dry-run             Preview changes without applying
  --force               Skip destructive confirmations
  -h, --help            Show help

Examples:
  $(basename "$0")
  $(basename "$0") --all
  $(basename "$0") --skills core
  $(basename "$0") --skills ai-research
  $(basename "$0") --uninstall --skills
  VERSION=v1.0.0 bash <(curl -fsSL $REPO_URL/raw/$REPO_BRANCH/install.sh)
EOF2
}

parse_args() {
  local mode_selected=false

  if [[ $# -eq 0 ]]; then
    # No args -> interactive mode (when a terminal is available).
    INTERACTIVE_MODE=true
    INSTALL_ALL=false
    return
  fi

  local has_component=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all)
        mode_selected=true
        INTERACTIVE_MODE=false
        INSTALL_ALL=true
        INSTALL_RESEARCHSTUDIO_NONINTERACTIVE=true
        INSTALL_RESEARCHSTUDIO_REEL_NONINTERACTIVE=true
        INSTALL_PPT_MASTER_NONINTERACTIVE=true
        shift
        ;;
      --core)
        mode_selected=true
        has_component=true
        INTERACTIVE_MODE=false
        INSTALL_CORE=true
        shift
        ;;
      --mcp)
        mode_selected=true
        has_component=true
        INTERACTIVE_MODE=false
        INSTALL_MCP=true
        shift
        ;;
      --skills)
        mode_selected=true
        has_component=true
        INTERACTIVE_MODE=false
        INSTALL_SKILLS=true
        shift
        local skill_group_explicit=false
        if [[ $# -gt 0 && ! "$1" =~ ^-- ]]; then
          case "$1" in
            core|ai-research|all)
              SKILL_GROUP="$1"
              skill_group_explicit=true
              shift
              ;;
            *)
              error "Invalid skill group: $1"
              exit 1
              ;;
          esac
        fi
        if $skill_group_explicit && [[ "$SKILL_GROUP" == "ai-research" || "$SKILL_GROUP" == "all" ]]; then
          INSTALL_RESEARCHSTUDIO_NONINTERACTIVE=true
          INSTALL_RESEARCHSTUDIO_REEL_NONINTERACTIVE=true
        fi
        if $skill_group_explicit && [[ "$SKILL_GROUP" == "all" ]]; then
          INSTALL_PPT_MASTER_NONINTERACTIVE=true
        fi
        ;;
      --uninstall)
        mode_selected=true
        INTERACTIVE_MODE=false
        UNINSTALL=true
        shift
        while [[ $# -gt 0 && "$1" =~ ^-- ]]; do
          case "$1" in
            --core)
              UNINSTALL_COMPONENTS+=("core")
              shift
              ;;
            --mcp)
              UNINSTALL_COMPONENTS+=("mcp")
              shift
              ;;
            --skills)
              UNINSTALL_COMPONENTS+=("skills")
              shift
              ;;
            --force)
              FORCE=true
              shift
              ;;
            --dry-run)
              DRY_RUN=true
              shift
              ;;
            *)
              break
              ;;
          esac
        done
        ;;
      --version)
        mode_selected=true
        INTERACTIVE_MODE=false
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
        INTERACTIVE_MODE=false
        usage
        exit 0
        ;;
      *)
        error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done

  if $has_component; then
    INSTALL_ALL=false
  fi

  if ! $mode_selected && ! $UNINSTALL && ! $SHOW_VERSION; then
    if $DRY_RUN; then
      # Preserve backward-compatible CLI behavior: explicit --dry-run is a
      # non-interactive full preview, not an interactive selector launch.
      INTERACTIVE_MODE=false
      INSTALL_ALL=true
    else
      INTERACTIVE_MODE=true
      INSTALL_ALL=false
    fi
  fi
}

backup_if_exists() {
  local target="$1"
  if [[ -e "$target" ]]; then
    local backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
    if $DRY_RUN; then
      warn "Would backup: $target -> $backup"
    else
      cp -r "$target" "$backup"
      warn "Backed up: $target -> $backup"
    fi
  fi
}

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
  local answer
  read -r answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

get_source_version() {
  if [[ -f "$SCRIPT_DIR/VERSION" ]]; then
    tr -d '[:space:]' < "$SCRIPT_DIR/VERSION"
  else
    echo "unknown"
  fi
}

get_installed_version() {
  if [[ -f "$VERSION_STAMP_FILE" ]]; then
    tr -d '[:space:]' < "$VERSION_STAMP_FILE"
  elif [[ -f "$LEGACY_VERSION_STAMP_FILE" ]]; then
    tr -d '[:space:]' < "$LEGACY_VERSION_STAMP_FILE"
  else
    echo "not installed"
  fi
}

get_remote_version() {
  local url="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_BRANCH}/VERSION"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" 2>/dev/null | tr -d '[:space:]' || echo "unavailable"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$url" 2>/dev/null | tr -d '[:space:]' || echo "unavailable"
  else
    echo "unavailable"
  fi
}

show_version() {
  local source_ver installed_ver remote_ver
  source_ver="$(get_source_version)"
  installed_ver="$(get_installed_version)"
  remote_ver="$(get_remote_version)"

  echo "codex-config version info:"
  echo "  Source:    $source_ver"
  echo "  Installed: $installed_ver"
  echo "  Remote:    $remote_ver"

  if [[ "$installed_ver" != "not installed" && "$remote_ver" != "unavailable" && "$installed_ver" != "$remote_ver" ]]; then
    warn "Update available: $installed_ver -> $remote_ver"
  fi
}

stamp_version() {
  local ver
  ver="$(get_source_version)"
  if [[ "$ver" != "unknown" ]] && ! $DRY_RUN; then
    # Component-only installs (--mcp, --skills) may run before ~/.codex exists;
    # a failed redirect would kill the script under set -e before the summary.
    mkdir -p "$CODEX_DIR"
    echo "$ver" > "$VERSION_STAMP_FILE"
    rm -f "$LEGACY_VERSION_STAMP_FILE"
  fi
}

copy_file_if_selected() {
  local selected="$1"
  local source="$2"
  local target="$3"
  local label="$4"

  if ! $selected; then
    return 0
  fi

  if [[ -e "$target" ]]; then
    backup_if_exists "$target"
  fi

  if $DRY_RUN; then
    info "Would copy: $label -> $target"
  else
    cp "$source" "$target"
    ok "$label installed"
  fi
}

# ~/.codex/lessons.md is the user's cross-project correction memory (see
# AGENTS.md), and config.toml points model_instructions_file at it. Never copy
# this repository's project lessons into global state; seed only the dedicated
# global template, and never overwrite an existing global log.
seed_lessons_if_missing() {
  if $LESSONS_SEEDED; then
    return 0
  fi
  LESSONS_SEEDED=true

  if [[ -f "$CODEX_DIR/lessons.md" ]]; then
    info "Preserving existing lessons.md (template not copied)"
    return 0
  fi

  if $DRY_RUN; then
    info "Would copy: templates/global-lessons.md -> $CODEX_DIR/lessons.md"
  else
    mkdir -p "$CODEX_DIR"
    cp "$SCRIPT_DIR/templates/global-lessons.md" "$CODEX_DIR/lessons.md"
    ok "Global lessons.md installed"
  fi
}

write_config_template() {
  if [[ -f "$CODEX_DIR/config.toml" ]]; then
    warn "$CODEX_DIR/config.toml exists -- skipping (merge manually if needed)"
  elif $DRY_RUN; then
    info "Would copy: config.toml -> $CODEX_DIR/config.toml"
  else
    if $INTERACTIVE_MODE && ! $SELECT_CORE_STATUSLINE; then
      awk '
        /^\[tui\][[:space:]]*$/ { skip_tui = 1; next }
        /^\[/ { skip_tui = 0 }
        !skip_tui { print }
      ' "$SCRIPT_DIR/config.toml" > "$CODEX_DIR/config.toml"
    else
      cp "$SCRIPT_DIR/config.toml" "$CODEX_DIR/config.toml"
    fi
    ok "config.toml installed"
  fi
}

ensure_status_line_setting() {
  local target="$CODEX_DIR/config.toml"

  if $DRY_RUN; then
    info "Would ensure Codex [tui].status_line in $target"
    return 0
  fi

  mkdir -p "$CODEX_DIR"
  if [[ ! -f "$target" ]]; then
    cp "$SCRIPT_DIR/config.toml" "$target"
    if [[ ! -f "$CODEX_DIR/lessons.md" ]]; then
      warn "config.toml requires lessons.md (model_instructions_file); seeding it while installing StatusLine"
    fi
    seed_lessons_if_missing
    ok "config.toml installed with [tui].status_line"
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  awk -v status_line="$CODEX_STATUS_LINE" \
      -v status_colors="$CODEX_STATUS_LINE_USE_COLORS" '
    function is_status_setting(line) {
      return line ~ /^[[:space:]]*status_line[[:space:]]*=/ || \
             line ~ /^[[:space:]]*status_line_use_colors[[:space:]]*=/
    }

    skip_status_array {
      if ($0 ~ /\]/) {
        skip_status_array = 0
      }
      next
    }

    /^\[tui\][[:space:]]*$/ {
      print
      print status_line
      print status_colors
      saw_tui = 1
      in_tui = 1
      next
    }

    /^\[/ {
      in_tui = 0
    }

    is_status_setting($0) {
      if ($0 ~ /^[[:space:]]*status_line[[:space:]]*=/ && $0 ~ /\[/ && $0 !~ /\]/) {
        skip_status_array = 1
      }
      next
    }

    {
      print
    }

    END {
      if (!saw_tui) {
        if (NR > 0) {
          print ""
        }
        print "[tui]"
        print status_line
        print status_colors
      }
    }
  ' "$target" > "$tmp"
  mv "$tmp" "$target"
  ok "[tui].status_line ensured in config.toml"
}

install_selected_agents() {
  if ! $SELECT_AGENT_EXPLORER && ! $SELECT_AGENT_REVIEWER && ! $SELECT_AGENT_DOCS_RESEARCHER; then
    return 0
  fi

  if ! $DRY_RUN; then
    mkdir -p "$CODEX_DIR/agents"
  fi

  if $SELECT_AGENT_EXPLORER; then
    copy_file_if_selected true "$SCRIPT_DIR/agents/explorer.toml" "$CODEX_DIR/agents/explorer.toml" "agents/explorer.toml"
  fi
  if $SELECT_AGENT_REVIEWER; then
    copy_file_if_selected true "$SCRIPT_DIR/agents/reviewer.toml" "$CODEX_DIR/agents/reviewer.toml" "agents/reviewer.toml"
  fi
  if $SELECT_AGENT_DOCS_RESEARCHER; then
    copy_file_if_selected true "$SCRIPT_DIR/agents/docs-researcher.toml" "$CODEX_DIR/agents/docs-researcher.toml" "agents/docs-researcher.toml"
  fi
}

install_core() {
  if $INTERACTIVE_MODE; then
    info "Installing selected core files..."
    if ! $DRY_RUN; then
      mkdir -p "$CODEX_DIR"
    fi

    copy_file_if_selected $SELECT_CORE_AGENTS_MD "$SCRIPT_DIR/AGENTS.md" "$CODEX_DIR/AGENTS.md" "AGENTS.md"
    if $SELECT_CORE_LESSONS; then
      seed_lessons_if_missing
    fi

    if $SELECT_CORE_CONFIG; then
      write_config_template
      # config.toml references lessons.md via model_instructions_file; make
      # sure the file exists even when the Lessons item was deselected.
      if ! $SELECT_CORE_LESSONS && [[ ! -f "$CODEX_DIR/lessons.md" ]]; then
        warn "config.toml requires lessons.md (model_instructions_file); seeding it although Lessons was deselected"
      fi
      seed_lessons_if_missing
    fi

    if $SELECT_CORE_STATUSLINE; then
      ensure_status_line_setting
    fi

    install_selected_agents
    return 0
  fi

  info "Installing core files..."
  if ! $DRY_RUN; then
    mkdir -p "$CODEX_DIR"
  fi

  backup_if_exists "$CODEX_DIR/AGENTS.md"
  backup_if_exists "$CODEX_DIR/agents"

  if $DRY_RUN; then
    info "Would copy: AGENTS.md -> $CODEX_DIR/AGENTS.md"
    info "Would copy: agents/*.toml -> $CODEX_DIR/agents/"
  else
    cp "$SCRIPT_DIR/AGENTS.md" "$CODEX_DIR/AGENTS.md"
    if [[ -d "$SCRIPT_DIR/agents" ]]; then
      mkdir -p "$CODEX_DIR/agents"
      cp "$SCRIPT_DIR"/agents/*.toml "$CODEX_DIR/agents/"
    fi
    ok "AGENTS.md and agents installed"
  fi

  seed_lessons_if_missing

  if [[ -f "$CODEX_DIR/config.toml" ]]; then
    warn "$CODEX_DIR/config.toml exists -- skipping (merge manually if needed)"
  else
    if $DRY_RUN; then
      info "Would copy: config.toml -> $CODEX_DIR/config.toml"
    else
      cp "$SCRIPT_DIR/config.toml" "$CODEX_DIR/config.toml"
      ok "config.toml installed"
    fi
  fi
  ensure_status_line_setting
}

add_mcp_server() {
  local name="$1"
  shift

  if $DRY_RUN; then
    info "Would add MCP server: $name"
    return 0
  fi

  if codex mcp add "$name" "$@"; then
    ok "MCP server configured: $name"
  else
    warn "Failed to configure MCP server: $name"
    MCP_FAILED_SERVERS+=("$name")
  fi
}

get_node_major_version() {
  local version

  command -v node >/dev/null 2>&1 || return 1
  version="$(node --version 2>/dev/null)" || return 1
  version="${version#v}"
  version="${version%%.*}"
  [[ "$version" =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "$version"
}

resolve_python_command() {
  local minimum_major="${1:-3}"
  local minimum_minor="${2:-0}"
  local candidate
  local resolved

  for candidate in python3 python; do
    command -v "$candidate" >/dev/null 2>&1 || continue
    if "$candidate" -c 'import sys; major=int(sys.argv[1]); minor=int(sys.argv[2]); raise SystemExit(0 if sys.version_info[:2] >= (major, minor) else 1)' \
      "$minimum_major" "$minimum_minor" >/dev/null 2>&1; then
      resolved="$(command -v "$candidate")"
      [[ -n "$resolved" ]] || continue
      printf '%s\n' "$resolved"
      return 0
    fi
  done
  return 1
}

prepare_skills_npx_launcher() {
  command -v npx >/dev/null 2>&1 || return 1

  local node_major
  node_major="$(get_node_major_version)" || return 1
  if (( node_major < SKILLS_MIN_NODE_MAJOR )); then
    if ! $SKILLS_NODE_FALLBACK_NOTIFIED; then
      warn "Node.js $node_major detected; using an isolated Node.js $SKILLS_NODE_FALLBACK_VERSION runtime for npx skills"
      SKILLS_NODE_FALLBACK_NOTIFIED=true
    fi
    SKILLS_NPX_LAUNCHER_ARGS=(
      -y
      --loglevel=error
      "--package=node@$SKILLS_NODE_FALLBACK_VERSION"
      "--package=skills@latest"
      --
      skills
    )
  else
    SKILLS_NPX_LAUNCHER_ARGS=(-y skills@latest)
  fi
}

add_playwright_mcp_server() {
  local node_major=0
  local package="@playwright/mcp@$PLAYWRIGHT_MCP_VERSION"
  local initialize_output
  local initialize_request='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"awesome-claude-code-config-installer","version":"1.0.0"}}}'
  local -a launcher_args

  if ! node_major="$(get_node_major_version)" && ! $DRY_RUN; then
    warn "Node.js is unavailable or its version could not be read; skipping Playwright MCP"
    MCP_FAILED_SERVERS+=("playwright")
    return 0
  fi

  if ! command -v npx >/dev/null 2>&1 && ! $DRY_RUN; then
    warn "npx is unavailable; skipping Playwright MCP"
    MCP_FAILED_SERVERS+=("playwright")
    return 0
  fi

  if (( node_major < PLAYWRIGHT_MIN_NODE_MAJOR )); then
    warn "Node.js $node_major detected; using an isolated Node.js $PLAYWRIGHT_NODE_FALLBACK_VERSION runtime for Playwright MCP"
    launcher_args=(
      -y
      --loglevel=error
      "--package=node@$PLAYWRIGHT_NODE_FALLBACK_VERSION"
      "--package=$package"
      --
      playwright-mcp
    )
  else
    launcher_args=(-y "$package")
  fi

  if ! $DRY_RUN; then
    if ! initialize_output="$(printf '%s\n' "$initialize_request" | npx "${launcher_args[@]}" 2>&1)" ||
       [[ "$initialize_output" != *'"result"'* || "$initialize_output" != *'"serverInfo"'* ]]; then
      warn "Playwright MCP initialize check failed; not registering a broken server"
      MCP_FAILED_SERVERS+=("playwright")
      return 0
    fi
  fi

  add_mcp_server playwright -- npx "${launcher_args[@]}"
}

add_github_mcp_server() {
  if [[ -z "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]]; then
    warn "GITHUB_PERSONAL_ACCESS_TOKEN is not set; skipping GitHub MCP server"
    SKIPPED_COMPONENTS+=("github MCP server (GITHUB_PERSONAL_ACCESS_TOKEN not set)")
    return 0
  fi

  add_mcp_server github --env "GITHUB_PERSONAL_ACCESS_TOKEN=$GITHUB_PERSONAL_ACCESS_TOKEN" -- npx -y @modelcontextprotocol/server-github
}

report_mcp_result() {
  if [[ ${#MCP_FAILED_SERVERS[@]} -eq 0 ]]; then
    ok "MCP setup complete (selected entries are refreshed)"
  else
    warn "MCP setup finished with failures: ${MCP_FAILED_SERVERS[*]}"
    SKIPPED_COMPONENTS+=("MCP servers: ${MCP_FAILED_SERVERS[*]}")
  fi
}

install_mcp() {
  if $INTERACTIVE_MODE; then
    info "Installing selected MCP servers..."
    if ! command -v codex >/dev/null 2>&1; then
      warn "codex CLI not found. Skip MCP setup."
      SKIPPED_COMPONENTS+=("MCP servers (codex CLI not found)")
      return 0
    fi

    if $SELECT_MCP_CONTEXT7; then
      add_mcp_server context7 -- npx -y @upstash/context7-mcp
    fi
    if $SELECT_MCP_GITHUB; then
      add_github_mcp_server
    fi
    if $SELECT_MCP_PLAYWRIGHT; then
      add_playwright_mcp_server
    fi
    if $SELECT_MCP_OPENAI_DOCS; then
      add_mcp_server openaiDeveloperDocs --url https://developers.openai.com/mcp
    fi
    if $SELECT_MCP_LARK; then
      add_mcp_server lark-mcp -- npx -y @larksuiteoapi/lark-mcp mcp -a YOUR_APP_ID -s YOUR_APP_SECRET
    fi
    report_mcp_result
    return 0
  fi

  info "Installing MCP servers..."

  if ! command -v codex >/dev/null 2>&1; then
    warn "codex CLI not found. Skip MCP setup."
    SKIPPED_COMPONENTS+=("MCP servers (codex CLI not found)")
    return 0
  fi

  info "Skipping lark-mcp: it requires real app credentials."
  info "Enable it via the interactive installer or 'codex mcp add' after filling credentials."
  add_mcp_server context7 -- npx -y @upstash/context7-mcp
  add_github_mcp_server
  add_playwright_mcp_server
  add_mcp_server openaiDeveloperDocs --url https://developers.openai.com/mcp
  report_mcp_result
}

skill_name_from_path() {
  case "$(basename "$1")" in
    peft) printf '%s\n' peft-fine-tuning ;;
    openrlhf) printf '%s\n' openrlhf-training ;;
    simpo) printf '%s\n' simpo-training ;;
    trl-fine-tuning) printf '%s\n' fine-tuning-with-trl ;;
    verl) printf '%s\n' verl-rl-training ;;
    megatron-core) printf '%s\n' training-llms-megatron ;;
    awq) printf '%s\n' awq-quantization ;;
    gguf) printf '%s\n' gguf-quantization ;;
    flash-attention) printf '%s\n' optimizing-attention-flash ;;
    bitsandbytes) printf '%s\n' quantizing-models-bitsandbytes ;;
    vllm) printf '%s\n' serving-llms-vllm ;;
    *) basename "$1" ;;
  esac
}

installed_skill_exists() {
  local skill="$1"
  [[ -f "$CODEX_DIR/skills/$skill/SKILL.md" ]]
}

skill_in_array() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

managed_skill_name_is_valid() {
  skill_in_array "$1" "${OWNERSHIP_SKILLS[@]}"
}

expected_source_for_skill() {
  local skill="$1"

  if [[ "$skill" == "code-review" ]] ||
     skill_in_array "$skill" "${MATTPOCOCK_SKILLS[@]}" ||
     skill_in_array "$skill" "${MATTPOCOCK_LEGACY_SKILLS[@]}"; then
    printf '%s\n' "mattpocock/skills"
  elif [[ "$skill" == "karpathy-guidelines" ]]; then
    printf '%s\n' "forrestchang/andrej-karpathy-skills"
  elif skill_in_array "$skill" "${SUPERPOWERS_SKILLS[@]}"; then
    printf '%s\n' "obra/superpowers"
  elif [[ "$skill" =~ ^(frontend-design|pdf|docx|pptx|xlsx|canvas-design|algorithmic-art|mcp-builder)$ ]]; then
    printf '%s\n' "anthropics/skills"
  elif skill_in_array "$skill" "${PUA_SKILLS[@]}"; then
    printf '%s\n' "tanweai/pua"
  elif [[ "$skill" == "frontend-slides" ]]; then
    printf '%s\n' "zarazhangrui/frontend-slides"
  elif [[ "$skill" == "ppt-master" ]]; then
    printf '%s\n' "hugohe3/ppt-master"
  elif [[ "$skill" =~ ^(huggingface-tokenizers|sentencepiece|axolotl|llama-factory|peft-fine-tuning|unsloth|grpo-rl-training|openrlhf-training|simpo-training|fine-tuning-with-trl|verl-rl-training|deepspeed|pytorch-fsdp2|training-llms-megatron|ray-train|awq-quantization|gptq|gguf-quantization|optimizing-attention-flash|quantizing-models-bitsandbytes|serving-llms-vllm|sglang|tensorrt-llm|llama-cpp)$ ]]; then
    printf '%s\n' "zechenzhangAGI/AI-research-SKILLs"
  elif [[ "$skill" =~ ^(deepxiv-cli|deepxiv-baseline-table|deepxiv-trending-digest)$ ]]; then
    printf '%s\n' "DeepXiv/deepxiv_sdk"
  elif skill_in_array "$skill" "${RESEARCHSTUDIO_SKILLS[@]}" ||
       skill_in_array "$skill" "${RESEARCHSTUDIO_REEL_SKILLS[@]}"; then
    printf '%s\n' "microsoft/ResearchStudio"
  elif skill_in_array "$skill" "${LEGACY_CLEANUP_SKILLS[@]}"; then
    printf '%s\n' "affaan-m/everything-claude-code"
  elif skill_in_array "$skill" "${LOCAL_MANAGED_SKILLS[@]}"; then
    printf 'local:%s\n' "$skill"
  fi
  return 0
}

owned_managed_skill_contains() {
  [[ ${#OWNED_MANAGED_SKILLS[@]} -gt 0 ]] || return 1
  skill_in_array "$1" "${OWNED_MANAGED_SKILLS[@]}"
}

superpowers_ownership_is_recorded() {
  local skill
  for skill in "${SUPERPOWERS_SKILLS[@]}"; do
    owned_managed_skill_contains "$skill" && return 0
  done
  return 1
}

append_managed_skill_ownership() {
  local skill="$1"
  managed_skill_name_is_valid "$skill" || return 0
  owned_managed_skill_contains "$skill" && return 0
  OWNED_MANAGED_SKILLS+=("$skill")
}

save_managed_skill_ownership() {
  $DRY_RUN && return 0

  if ! mkdir -p "$CODEX_DIR"; then
    warn "Could not create $CODEX_DIR; managed skill ownership was not saved"
    return 0
  fi

  local tmp="${MANAGED_SKILLS_STATE_FILE}.tmp.$$"
  local skill
  if ! {
    for skill in "${OWNERSHIP_SKILLS[@]}"; do
      if owned_managed_skill_contains "$skill"; then
        printf '%s\n' "$skill"
      fi
    done
  } > "$tmp"; then
    rm -f "$tmp"
    warn "Could not write managed skill ownership to $MANAGED_SKILLS_STATE_FILE"
    return 0
  fi
  if ! mv "$tmp" "$MANAGED_SKILLS_STATE_FILE"; then
    rm -f "$tmp"
    warn "Could not save managed skill ownership to $MANAGED_SKILLS_STATE_FILE"
  fi
  return 0
}

managed_directory_trees_equal() {
  local source="$1"
  local target="$2"
  [[ -d "$source" && -d "$target" ]] || return 1
  command -v diff >/dev/null 2>&1 || return 1
  diff -qr "$source" "$target" >/dev/null 2>&1
}

legacy_local_skill_is_owned() {
  local skill="$1"
  managed_directory_trees_equal "$SCRIPT_DIR/skills/$skill" "$CODEX_DIR/skills/$skill"
}

legacy_locked_skill_pairs() {
  [[ -f "$GLOBAL_SKILL_LOCK_FILE" ]] || return 0
  command -v python3 >/dev/null 2>&1 || return 0

  python3 - "$GLOBAL_SKILL_LOCK_FILE" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        data = json.load(fh)
except (OSError, ValueError):
    raise SystemExit(0)

skills = data.get("skills", {})
if not isinstance(skills, dict):
    raise SystemExit(0)
for name, metadata in skills.items():
    if isinstance(name, str) and isinstance(metadata, dict):
        source = metadata.get("source")
        if isinstance(source, str) and "\t" not in name and "\t" not in source:
            print(f"{name}\t{source}")
PY
}

npx_skill_lock_fingerprint() {
  local skill="$1"
  local expected_source="$2"
  [[ -f "$GLOBAL_SKILL_LOCK_FILE" ]] || return 1
  command -v node >/dev/null 2>&1 || return 1

  node - "$GLOBAL_SKILL_LOCK_FILE" "$skill" "$expected_source" <<'NODE'
const fs = require("fs");

try {
  const data = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
  const entry = data && data.skills && data.skills[process.argv[3]];
  const valid = entry &&
    entry.source === process.argv[4] &&
    typeof entry.skillFolderHash === "string" &&
    entry.skillFolderHash.length > 0;
  if (!valid) process.exit(1);
  process.stdout.write(JSON.stringify([
    entry.source,
    entry.skillFolderHash,
    entry.installedAt || "",
    entry.updatedAt || ""
  ]));
} catch (_) {
  process.exit(1);
}
NODE
}

npx_verified_skill_contains() {
  local expected="$1"
  local verified
  for verified in "${NPX_VERIFIED_SKILL_NAMES[@]}"; do
    [[ "$verified" == "$expected" ]] && return 0
  done
  return 1
}

locked_skill_source_matches() {
  local wanted_name="$1"
  local wanted_source="$2"
  local name source
  while IFS=$'\t' read -r name source; do
    if [[ "$name" == "$wanted_name" && "$source" == "$wanted_source" ]]; then
      return 0
    fi
  done < <(legacy_locked_skill_pairs)
  return 1
}

superpowers_fallback_is_owned() {
  local git_config="$SUPERPOWERS_DIR/.git/config"
  [[ -f "$git_config" ]] || return 1

  local remote=""
  if command -v git >/dev/null 2>&1; then
    remote=$(git config --file "$git_config" --get remote.origin.url 2>/dev/null || true)
  fi
  if [[ -z "$remote" ]]; then
    remote=$(awk '
      /^\[remote "origin"\]/ { in_origin=1; next }
      /^\[/ { in_origin=0 }
      in_origin && /^[[:space:]]*url[[:space:]]*=/ {
        sub(/^[^=]*=[[:space:]]*/, "")
        print
        exit
      }
    ' "$git_config")
  fi

  case "$remote" in
    https://github.com/obra/superpowers|https://github.com/obra/superpowers.git|git@github.com:obra/superpowers.git|git://github.com/obra/superpowers.git)
      return 0
      ;;
  esac
  return 1
}

initialize_managed_skill_ownership() {
  $MANAGED_SKILLS_OWNERSHIP_LOADED && return 0
  OWNED_MANAGED_SKILLS=()

  if [[ -f "$MANAGED_SKILLS_STATE_FILE" ]]; then
    local recorded
    while IFS= read -r recorded || [[ -n "$recorded" ]]; do
      append_managed_skill_ownership "$recorded"
    done < "$MANAGED_SKILLS_STATE_FILE"
    MANAGED_SKILLS_OWNERSHIP_LOADED=true
    return 0
  fi

  local skill expected locked_name locked_source
  for skill in "${LOCAL_MANAGED_SKILLS[@]}"; do
    if legacy_local_skill_is_owned "$skill"; then
      append_managed_skill_ownership "$skill"
    fi
  done

  while IFS=$'\t' read -r locked_name locked_source; do
    managed_skill_name_is_valid "$locked_name" || continue
    expected=$(expected_source_for_skill "$locked_name")
    if [[ -n "$expected" && "$expected" != local:* && "$locked_source" == "$expected" ]] &&
       [[ -f "$CODEX_DIR/skills/$locked_name/SKILL.md" ]] &&
       managed_directory_trees_equal "$AGENTS_SKILLS_DIR/$locked_name" "$CODEX_DIR/skills/$locked_name"; then
      append_managed_skill_ownership "$locked_name"
    fi
  done < <(legacy_locked_skill_pairs)

  if superpowers_fallback_is_owned; then
    for skill in "${SUPERPOWERS_SKILLS[@]}"; do
      append_managed_skill_ownership "$skill"
    done
  fi

  MANAGED_SKILLS_OWNERSHIP_LOADED=true
  save_managed_skill_ownership
}

add_managed_skill_ownership() {
  initialize_managed_skill_ownership
  local skill
  for skill in "$@"; do
    append_managed_skill_ownership "$skill"
  done
  save_managed_skill_ownership
}

remove_managed_skill_ownership() {
  initialize_managed_skill_ownership
  local -a kept=()
  local owned remove candidate
  if [[ ${#OWNED_MANAGED_SKILLS[@]} -gt 0 ]]; then
    for owned in "${OWNED_MANAGED_SKILLS[@]}"; do
      remove=false
      for candidate in "$@"; do
        if [[ "$owned" == "$candidate" ]]; then
          remove=true
          break
        fi
      done
      $remove || kept+=("$owned")
    done
  fi
  OWNED_MANAGED_SKILLS=()
  if [[ ${#kept[@]} -gt 0 ]]; then
    OWNED_MANAGED_SKILLS=("${kept[@]}")
  fi
  save_managed_skill_ownership
}

confirm_empty_skill_removal() {
  local count="$1"
  $FORCE && return 0

  local answer=""
  if [[ -t 0 ]]; then
    printf '%b' "${YELLOW}Remove $count previously installer-managed skill(s)? [y/N] ${NC}"
    read -r answer
  elif exec 4</dev/tty 2>/dev/null; then
    printf '%b' "${YELLOW}Remove $count previously installer-managed skill(s)? [y/N] ${NC}" >/dev/tty
    read -r answer <&4
    exec 4<&-
  else
    warn "Cannot confirm removal without a terminal; preserving existing managed skills"
    return 1
  fi
  [[ "$answer" =~ ^[Yy]$ ]]
}

verify_installed_skill_names() {
  local -a missing=()
  local skill
  for skill in "$@"; do
    if [[ ! -f "$CODEX_DIR/skills/$skill/SKILL.md" ]]; then
      missing+=("$skill")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    warn "npx skills returned success but did not install: ${missing[*]}"
    return 1
  fi
  return 0
}

sync_npx_skill_to_codex() {
  local skill="$1"
  local source="$AGENTS_SKILLS_DIR/$skill"
  local target="$CODEX_DIR/skills/$skill"
  local temporary_target="${target}.tmp.$$"

  managed_skill_name_is_valid "$skill" || return 1
  [[ -d "$source" && ! -L "$source" && -f "$source/SKILL.md" ]] || return 1
  mkdir -p "$CODEX_DIR/skills"
  rm -rf "$temporary_target"
  if ! cp -R "$source" "$temporary_target" || [[ ! -f "$temporary_target/SKILL.md" ]]; then
    rm -rf "$temporary_target"
    return 1
  fi
  rm -rf "$target"
  mv "$temporary_target" "$target"
  [[ -f "$target/SKILL.md" ]]
}

remove_managed_staging_skill() {
  local skill="$1"
  managed_skill_name_is_valid "$skill" || return 1
  [[ -e "$AGENTS_SKILLS_DIR/$skill" || -L "$AGENTS_SKILLS_DIR/$skill" ]] || return 0
  rm -rf "$AGENTS_SKILLS_DIR/$skill"
}

remove_mattpocock_skill_lock_entries() {
  [[ -f "$GLOBAL_SKILL_LOCK_FILE" ]] || return 0
  command -v node >/dev/null 2>&1 || return 1

  node - "$GLOBAL_SKILL_LOCK_FILE" "$@" <<'NODE'
const fs = require("fs");

const [lockPath, ...names] = process.argv.slice(2);
let lock;
try {
  lock = JSON.parse(fs.readFileSync(lockPath, "utf8"));
} catch {
  process.exit(1);
}

if (!lock.skills || typeof lock.skills !== "object") process.exit(0);
for (const name of names) {
  if (lock.skills[name]?.source === "mattpocock/skills") {
    delete lock.skills[name];
  }
}

const tempPath = `${lockPath}.tmp.${process.pid}`;
fs.writeFileSync(tempPath, `${JSON.stringify(lock, null, 2)}\n`, "utf8");
fs.renameSync(tempPath, lockPath);
NODE
}

install_npx_skill_names() {
  local repo="$1"
  shift
  local -a skill_names=("$@")
  NPX_VERIFIED_SKILL_NAMES=()

  if $DRY_RUN; then
    info "Would install via npx skills: $repo -> $*"
    return 0
  fi

  if ! prepare_skills_npx_launcher; then
    return 127
  fi

  # Uses the host Node when supported, otherwise npx supplies an isolated Node 24 runtime.
  local -a args=("${SKILLS_NPX_LAUNCHER_ARGS[@]}" add "$repo" --global --agent codex --copy --yes --full-depth)
  local skill
  for skill in "$@"; do
    args+=(--skill "$skill")
  done

  local local_source=false
  [[ -d "$repo" ]] && local_source=true
  local -a before_fingerprints=()
  if ! $local_source; then
    for skill in "${skill_names[@]}"; do
      before_fingerprints+=("$(npx_skill_lock_fingerprint "$skill" "$repo" 2>/dev/null || true)")
    done
  fi

  local npx_exit=0
  DO_NOT_TRACK=1 npx "${args[@]}" </dev/null || npx_exit=$?

  # Pinned installer-owned snapshots use a local temporary checkout. Their
  # caller performs an exact tree comparison before ownership is retained, so
  # they cannot use the GitHub lock fingerprint required for remote sources.
  if $local_source; then
    local sync_failed=false
    if (( npx_exit == 0 )); then
      for skill in "${skill_names[@]}"; do
        local source_skill
        source_skill=$(find "$repo/skills" -path "*/$skill/SKILL.md" -type f -print -quit 2>/dev/null || true)
        source_skill=${source_skill%/SKILL.md}
        if [[ -z "$source_skill" ]] ||
           ! managed_directory_trees_equal "$source_skill" "$AGENTS_SKILLS_DIR/$skill" ||
           ! sync_npx_skill_to_codex "$skill"; then
          sync_failed=true
        fi
      done
    else
      sync_failed=true
    fi
    if (( npx_exit == 0 )) && ! $sync_failed && verify_installed_skill_names "${skill_names[@]}"; then
      NPX_VERIFIED_SKILL_NAMES=("${skill_names[@]}")
      add_managed_skill_ownership "${skill_names[@]}"
      for skill in "${skill_names[@]}"; do
        remove_managed_staging_skill "$skill" || true
      done
      return 0
    fi
    return 1
  fi

  local -a missing_names=()
  local index after_fingerprint
  for index in "${!skill_names[@]}"; do
    skill="${skill_names[$index]}"
    after_fingerprint="$(npx_skill_lock_fingerprint "$skill" "$repo" 2>/dev/null || true)"
    if [[ -f "$AGENTS_SKILLS_DIR/$skill/SKILL.md" ]] &&
       [[ -n "$after_fingerprint" ]] &&
       [[ "$after_fingerprint" != "${before_fingerprints[$index]}" ]] &&
       sync_npx_skill_to_codex "$skill"; then
      NPX_VERIFIED_SKILL_NAMES+=("$skill")
    else
      missing_names+=("$skill")
    fi
  done
  if [[ ${#NPX_VERIFIED_SKILL_NAMES[@]} -gt 0 ]]; then
    add_managed_skill_ownership "${NPX_VERIFIED_SKILL_NAMES[@]}"
    for skill in "${NPX_VERIFIED_SKILL_NAMES[@]}"; do
      remove_managed_staging_skill "$skill" || true
    done
  fi
  if [[ ${#missing_names[@]} -gt 0 ]]; then
    if (( npx_exit == 0 )); then
      warn "npx returned success, but this run did not freshly verify skill files/source ownership: ${missing_names[*]}"
    fi
    return 1
  fi
  if (( npx_exit != 0 )); then
    warn "npx returned non-zero, but every requested skill was freshly verified from $repo"
  fi
  if [[ ${#NPX_VERIFIED_SKILL_NAMES[@]} -eq ${#skill_names[@]} ]]; then
    return 0
  fi
  return 1
}

install_ppt_master() {
  info "Installing PPT Master skill (runtime dependencies deferred until first use)..."
  if $DRY_RUN; then
    info "Would install the hugohe3/ppt-master skill for Codex without Python packages or browsers"
    return 0
  fi

  if ! install_npx_skill_names hugohe3/ppt-master ppt-master; then
    skip_unsupported_item "ppt-master" "npx skills install failed or source ownership could not be verified"
    return 0
  fi

  ok "PPT Master skill installed for Codex (minimal install; runtime dependencies deferred)"
}

install_researchstudio() {
  local manual_cmd="git clone --depth 1 $RESEARCHSTUDIO_REPO_URL <temp> && copy the three allowlisted ResearchStudio-Idea skills into $CODEX_DIR/skills"

  info "Installing ResearchStudio Idea skills from a full official checkout..."
  if $DRY_RUN; then
    info "Would run: $manual_cmd"
    info "Would apply Codex instruction/path adaptation without installing runtime dependencies"
    return 0
  fi
  if ! command -v git >/dev/null 2>&1; then
    skip_unsupported_item "ResearchStudio Idea" "git is unavailable; install Git and retry"
    return 0
  fi

  local checkout
  checkout="$(mktemp -d "${TMPDIR:-/tmp}/researchstudio-idea.XXXXXX")"
  if ! git clone --depth 1 "$RESEARCHSTUDIO_REPO_URL" "$checkout" </dev/null; then
    rm -rf "$checkout"
    skip_unsupported_item "ResearchStudio Idea" "official repository checkout failed"
    return 0
  fi

  local skill source_dir
  for skill in "${RESEARCHSTUDIO_SKILLS[@]}"; do
    source_dir="$checkout/ResearchStudio-Idea/skills/$skill"
    if [[ ! -f "$source_dir/SKILL.md" ]]; then
      rm -rf "$checkout"
      skip_unsupported_item "ResearchStudio Idea" "official checkout did not contain $source_dir/SKILL.md"
      return 0
    fi
  done
  if find "$checkout/ResearchStudio-Idea/skills" -type l -print -quit | grep -q .; then
    rm -rf "$checkout"
    skip_unsupported_item "ResearchStudio Idea" "official checkout contains symlinks; refusing to copy an unexpected source shape"
    return 0
  fi

  mkdir -p "$CODEX_DIR/skills"
  local copy_failed=false
  for skill in "${RESEARCHSTUDIO_SKILLS[@]}"; do
    source_dir="$checkout/ResearchStudio-Idea/skills/$skill"
    rm -rf "$CODEX_DIR/skills/$skill"
    if ! cp -R "$source_dir" "$CODEX_DIR/skills/$skill"; then
      copy_failed=true
      break
    fi
  done
  rm -rf "$checkout"
  if $copy_failed; then
    skip_unsupported_item "ResearchStudio Idea" "failed to copy one or more allowlisted skill directories"
    return 0
  fi

  local adapter_ready=false
  if adapt_researchstudio_idea_for_codex &&
     researchstudio_idea_adapter_is_ready; then
    adapter_ready=true
  else
    warn "ResearchStudio Idea was copied, but its Codex instruction/path adaptation could not be verified. Rerun this selection to refresh the skill files."
  fi

  add_managed_skill_ownership "${RESEARCHSTUDIO_SKILLS[@]}"
  if $adapter_ready; then
    ok "ResearchStudio Idea skills installed for Codex (minimal install; runtime dependencies deferred)"
  else
    SKIPPED_COMPONENTS+=("ResearchStudio Idea Codex adapter (verification failed)")
  fi
}

install_researchstudio_reel() {
  local manual_cmd="git clone --depth 1 $RESEARCHSTUDIO_REPO_URL <temp> && copy the five allowlisted Reel skills into $CODEX_DIR/skills"

  info "Installing ResearchStudio Reel skills from a full official checkout..."
  if $DRY_RUN; then
    info "Would run: $manual_cmd"
    info "Would install only the five allowlisted Reel skills; runtime dependencies are deferred"
    return 0
  fi
  if ! command -v git >/dev/null 2>&1; then
    skip_unsupported_item "ResearchStudio Reel" "git is unavailable; install Git and retry"
    return 0
  fi

  local checkout
  checkout="$(mktemp -d "${TMPDIR:-/tmp}/researchstudio-reel.XXXXXX")"
  if ! git clone --depth 1 "$RESEARCHSTUDIO_REPO_URL" "$checkout" </dev/null; then
    rm -rf "$checkout"
    skip_unsupported_item "ResearchStudio Reel" "official repository checkout failed"
    return 0
  fi

  local skill source_dir
  for skill in "${RESEARCHSTUDIO_REEL_SKILLS[@]}"; do
    source_dir="$checkout/ResearchStudio-Reel/skills/$skill"
    if [[ ! -f "$source_dir/SKILL.md" ]]; then
      rm -rf "$checkout"
      skip_unsupported_item "ResearchStudio Reel" "official checkout did not contain $source_dir/SKILL.md"
      return 0
    fi
  done
  if find "$checkout/ResearchStudio-Reel/skills" -type l -print -quit | grep -q .; then
    rm -rf "$checkout"
    skip_unsupported_item "ResearchStudio Reel" "official checkout contains symlinks; refusing to copy an unexpected source shape"
    return 0
  fi

  mkdir -p "$CODEX_DIR/skills"
  local copy_failed=false
  for skill in "${RESEARCHSTUDIO_REEL_SKILLS[@]}"; do
    source_dir="$checkout/ResearchStudio-Reel/skills/$skill"
    rm -rf "$CODEX_DIR/skills/$skill"
    if ! cp -R "$source_dir" "$CODEX_DIR/skills/$skill"; then
      copy_failed=true
      break
    fi
  done
  rm -rf "$checkout"
  if $copy_failed; then
    skip_unsupported_item "ResearchStudio Reel" "failed to copy one or more allowlisted skill directories"
    return 0
  fi

  add_managed_skill_ownership "${RESEARCHSTUDIO_REEL_SKILLS[@]}"
  ok "ResearchStudio Reel skills installed for Codex (minimal install; runtime dependencies deferred)"
}

install_mattpocock_skill_names() {
  local -a skill_names=("$@")

  if ! remove_legacy_mattpocock_skills; then
    remove_managed_skill_ownership "${skill_names[@]}"
    return 1
  fi

  if $DRY_RUN; then
    info "Would install Matt Pocock $MATTPOCOCK_VERSION from commit $MATTPOCOCK_COMMIT: $*"
    return 0
  fi

  if ! command -v tar >/dev/null 2>&1; then
    warn "tar not found; cannot unpack pinned Matt Pocock skills"
    remove_managed_skill_ownership "${skill_names[@]}"
    return 1
  fi

  local temp_dir archive source_dir skill
  if ! temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/mattpocock-skills.XXXXXX"); then
    warn "Could not create a temporary directory for pinned Matt Pocock skills"
    remove_managed_skill_ownership "${skill_names[@]}"
    return 1
  fi
  archive="$temp_dir/source.tar.gz"

  if ! download_archive \
    "https://github.com/mattpocock/skills/archive/${MATTPOCOCK_COMMIT}.tar.gz" \
    "$archive"; then
    rm -rf "$temp_dir"
    warn "Could not download Matt Pocock $MATTPOCOCK_VERSION"
    remove_managed_skill_ownership "${skill_names[@]}"
    return 1
  fi

  if ! tar -xzf "$archive" -C "$temp_dir"; then
    rm -rf "$temp_dir"
    warn "Could not unpack Matt Pocock $MATTPOCOCK_VERSION"
    remove_managed_skill_ownership "${skill_names[@]}"
    return 1
  fi

  source_dir=$(find "$temp_dir" -mindepth 1 -maxdepth 1 -type d -print -quit)
  if [[ -z "$source_dir" ]]; then
    rm -rf "$temp_dir"
    warn "Pinned Matt Pocock archive did not contain a repository root"
    remove_managed_skill_ownership "${skill_names[@]}"
    return 1
  fi

  for skill in "${skill_names[@]}"; do
    if ! find "$source_dir/skills" -path "*/$skill/SKILL.md" -type f -print -quit | grep -q .; then
      rm -rf "$temp_dir"
      warn "Pinned Matt Pocock archive is missing requested skill: $skill"
      remove_managed_skill_ownership "${skill_names[@]}"
      return 1
    fi
  done

  local result=0 source_skill target_skill
  install_npx_skill_names "$source_dir" "${skill_names[@]}" || result=$?
  if [[ "$result" -ne 0 ]]; then
    remove_managed_skill_ownership "${skill_names[@]}"
  fi
  if [[ "$result" -eq 0 ]]; then
    for skill in "${skill_names[@]}"; do
      source_skill=$(find "$source_dir/skills" -path "*/$skill/SKILL.md" -type f -print -quit)
      source_skill=${source_skill%/SKILL.md}
      target_skill="$CODEX_DIR/skills/$skill"
      if ! managed_directory_trees_equal "$source_skill" "$target_skill"; then
        warn "Installed Matt Pocock skill does not match pinned snapshot: $skill"
        remove_managed_skill_ownership "${skill_names[@]}"
        result=1
        break
      fi
    done
  fi
  if [[ "$result" -eq 0 ]] &&
     ! remove_mattpocock_skill_lock_entries "${skill_names[@]}"; then
    warn "Could not retire remote Matt Pocock lock entries after pinned installation"
    remove_managed_skill_ownership "${skill_names[@]}"
    result=1
  fi
  rm -rf "$temp_dir"
  return "$result"
}

selected_managed_skill_names() {
  $SELECT_SKILL_CODE_REVIEW && printf '%s\n' code-review
  $SELECT_SKILL_KARPATHY && printf '%s\n' karpathy-guidelines
  $SELECT_SKILL_SUPERPOWERS && printf '%s\n' "${SUPERPOWERS_SKILLS[@]}"
  $SELECT_SKILL_MATTPOCOCK && printf '%s\n' "${MATTPOCOCK_SKILLS[@]}"
  $SELECT_SKILL_DOCUMENTS && printf '%s\n' pdf docx pptx xlsx
  $SELECT_SKILL_EXAMPLES && printf '%s\n' canvas-design algorithmic-art mcp-builder
  $SELECT_SKILL_FRONTEND_DESIGN && printf '%s\n' frontend-design
  $SELECT_SKILL_PUA && printf '%s\n' "${PUA_SKILLS[@]}"
  $SELECT_SKILL_FRONTEND_SLIDES && printf '%s\n' frontend-slides
  $SELECT_SKILL_PPT_MASTER && printf '%s\n' ppt-master
  $SELECT_SKILL_PAPER_READING && printf '%s\n' paper-reading
  $SELECT_SKILL_HUMANIZER && printf '%s\n' humanizer
  $SELECT_SKILL_HUMANIZER_ZH && printf '%s\n' humanizer-zh
  $SELECT_SKILL_HANDOFF && printf '%s\n' handoff
  $SELECT_SKILL_NEAT_FREAK && printf '%s\n' neat-freak
  $SELECT_SKILL_ADVERSARIAL_REVIEW && printf '%s\n' adversarial-review
  $SELECT_SKILL_UPDATE && printf '%s\n' update
  $SELECT_AI_TOKENIZATION && printf '%s\n' huggingface-tokenizers sentencepiece
  $SELECT_AI_FINE_TUNING && printf '%s\n' axolotl llama-factory peft-fine-tuning unsloth
  $SELECT_AI_POST_TRAINING && printf '%s\n' grpo-rl-training openrlhf-training simpo-training fine-tuning-with-trl verl-rl-training
  $SELECT_AI_DISTRIBUTED_TRAINING && printf '%s\n' deepspeed pytorch-fsdp2 training-llms-megatron ray-train
  $SELECT_AI_INFERENCE_SERVING && printf '%s\n' serving-llms-vllm sglang tensorrt-llm llama-cpp
  $SELECT_AI_OPTIMIZATION && printf '%s\n' awq-quantization gptq gguf-quantization optimizing-attention-flash quantizing-models-bitsandbytes
  $SELECT_AI_DEEPXIV && printf '%s\n' deepxiv-cli deepxiv-baseline-table deepxiv-trending-digest
  $SELECT_AI_RESEARCHSTUDIO && printf '%s\n' "${RESEARCHSTUDIO_SKILLS[@]}"
  $SELECT_AI_RESEARCHSTUDIO_REEL && printf '%s\n' "${RESEARCHSTUDIO_REEL_SKILLS[@]}"
  return 0
}

remove_npx_skill_names() {
  [[ $# -gt 0 ]] || return 0

  if $DRY_RUN; then
    info "Would remove via npx skills for Codex: $*"
    return 0
  fi

  if ! prepare_skills_npx_launcher; then
    warn "npx not found; shared/global Codex skill associations could not be removed: $*"
    SKIPPED_COMPONENTS+=("unselected managed skills (npx unavailable): $*")
    return 1
  fi

  local -a args=("${SKILLS_NPX_LAUNCHER_ARGS[@]}" remove "$@" --global --agent codex --yes)
  if ! DO_NOT_TRACK=1 npx "${args[@]}" </dev/null; then
    warn "npx skills could not remove these Codex skills: $*"
    SKIPPED_COMPONENTS+=("unselected managed skills (npx removal failed): $*")
    return 1
  fi
  return 0
}

remove_legacy_mattpocock_skills() {
  initialize_managed_skill_ownership

  local -a removable=()
  local skill
  for skill in "${MATTPOCOCK_LEGACY_SKILLS[@]}"; do
    if owned_managed_skill_contains "$skill" ||
       locked_skill_source_matches "$skill" "mattpocock/skills"; then
      removable+=("$skill")
    fi
  done

  [[ ${#removable[@]} -gt 0 ]] || return 0

  if $DRY_RUN; then
    info "Would remove retired Matt Pocock skills from all agent associations: ${removable[*]}"
    return 0
  fi

  if ! prepare_skills_npx_launcher; then
    warn "npx is unavailable; cannot safely migrate retired Matt Pocock skills: ${removable[*]}"
    return 1
  fi

  # Omitting --agent targets every detected agent. skills@1.5.16 currently
  # rejects the documented wildcard value (`--agent '*'`).
  local -a args=("${SKILLS_NPX_LAUNCHER_ARGS[@]}" remove "${removable[@]}" --global --yes)
  if ! DO_NOT_TRACK=1 npx "${args[@]}" </dev/null; then
    warn "npx skills could not migrate retired Matt Pocock skills: ${removable[*]}"
    return 1
  fi

  for skill in "${removable[@]}"; do
    rm -rf "$AGENTS_SKILLS_DIR/$skill" "$CODEX_DIR/skills/$skill"
  done
  if ! remove_mattpocock_skill_lock_entries "${removable[@]}"; then
    warn "Could not retire matching lock entries for retired Matt Pocock skills: ${removable[*]}"
    return 1
  fi
  remove_managed_skill_ownership "${removable[@]}"
  ok "Removed retired Matt Pocock skills: ${removable[*]}"
}

remove_superpowers_fallback() {
  if ! superpowers_fallback_is_owned; then
    if [[ -L "$SUPERPOWERS_LINK" || -e "$SUPERPOWERS_LINK" || -e "$SUPERPOWERS_DIR" ]]; then
      warn "Preserving unrecognized superpowers fallback paths; expected obra/superpowers provenance"
      SKIPPED_COMPONENTS+=("superpowers fallback cleanup (ownership could not be verified)")
    fi
    return 0
  fi

  if $DRY_RUN; then
    if [[ -L "$SUPERPOWERS_LINK" || -e "$SUPERPOWERS_LINK" ]]; then
      info "Would remove superpowers link: $SUPERPOWERS_LINK"
    fi
    if [[ -L "$LEGACY_SUPERPOWERS_LINK" ]]; then
      info "Would remove legacy superpowers staging link: $LEGACY_SUPERPOWERS_LINK"
    fi
    if [[ -e "$SUPERPOWERS_DIR" ]]; then
      info "Would remove superpowers repository: $SUPERPOWERS_DIR"
    fi
    return 0
  fi

  if [[ -L "$SUPERPOWERS_LINK" ]]; then
    local link_target
    link_target=$(readlink "$SUPERPOWERS_LINK" 2>/dev/null || true)
    if [[ "$link_target" == "$SUPERPOWERS_DIR/skills" ]]; then
      rm -f "$SUPERPOWERS_LINK"
      ok "Removed superpowers link"
    else
      warn "$SUPERPOWERS_LINK does not target the managed superpowers repository; preserving it"
      SKIPPED_COMPONENTS+=("superpowers link cleanup (target ownership could not be verified)")
    fi
  elif [[ -e "$SUPERPOWERS_LINK" ]]; then
    warn "$SUPERPOWERS_LINK is not a symlink; preserving it"
    SKIPPED_COMPONENTS+=("superpowers link cleanup ($SUPERPOWERS_LINK is not a symlink)")
  fi

  if [[ -e "$SUPERPOWERS_DIR" ]]; then
    rm -rf "$SUPERPOWERS_DIR"
    ok "Removed superpowers repository"
  fi
  remove_legacy_superpowers_link
}

reconcile_interactive_skills() {
  local -a desired=()
  local -a stale=()
  local -a removed_stale=()
  local skill wanted selected

  initialize_managed_skill_ownership
  if ! remove_legacy_mattpocock_skills; then
    warn "Retired Matt Pocock skills were preserved because migration cleanup failed"
  fi

  while IFS= read -r skill; do
    [[ -n "$skill" ]] && desired+=("$skill")
  done < <(selected_managed_skill_names)

  if [[ ${#OWNED_MANAGED_SKILLS[@]} -gt 0 ]]; then
    for skill in "${OWNED_MANAGED_SKILLS[@]}"; do
      skill_in_array "$skill" "${MATTPOCOCK_LEGACY_SKILLS[@]}" && continue
      wanted=false
      if [[ ${#desired[@]} -gt 0 ]]; then
        for selected in "${desired[@]}"; do
          if [[ "$selected" == "$skill" ]]; then
            wanted=true
            break
          fi
        done
      fi
      $wanted && continue

      stale+=("$skill")
    done
  fi

  if [[ ${#stale[@]} -gt 0 ]]; then
    if [[ ${#desired[@]} -eq 0 ]] && ! $DRY_RUN; then
      if ! confirm_empty_skill_removal "${#stale[@]}"; then
        info "Managed skill removal cancelled; existing managed skills were preserved"
        return 0
      fi
    fi

    local -a npx_stale=()
    local -a direct_stale=()
    local researchstudio_removed=false
    local expected_source=""
    for skill in "${stale[@]}"; do
      expected_source="$(expected_source_for_skill "$skill")"
      if skill_in_array "$skill" "${RESEARCHSTUDIO_SKILLS[@]}" ||
         skill_in_array "$skill" "${RESEARCHSTUDIO_REEL_SKILLS[@]}"; then
        researchstudio_removed=true
      fi
      if [[ "$expected_source" == local:* || "$expected_source" == "microsoft/ResearchStudio" ]]; then
        direct_stale+=("$skill")
      else
        npx_stale+=("$skill")
      fi
    done

    if [[ ${#npx_stale[@]} -gt 0 ]]; then
      local npx_removal_succeeded=false
      if remove_npx_skill_names "${npx_stale[@]}"; then
        npx_removal_succeeded=true
      fi

      if $npx_removal_succeeded && ! $DRY_RUN; then
        local staging_cleanup_failed=false
        for skill in "${npx_stale[@]}"; do
          rm -rf "$CODEX_DIR/skills/$skill"
          remove_managed_staging_skill "$skill" || staging_cleanup_failed=true
        done
        $staging_cleanup_failed && npx_removal_succeeded=false
      fi

      if $npx_removal_succeeded; then
        removed_stale+=("${npx_stale[@]}")
      fi
    fi

    if [[ ${#direct_stale[@]} -gt 0 ]]; then
      for skill in "${direct_stale[@]}"; do
        if $DRY_RUN; then
          if [[ -e "$CODEX_DIR/skills/$skill" || -L "$CODEX_DIR/skills/$skill" ]]; then
            info "Would remove unselected managed skill: $CODEX_DIR/skills/$skill"
          fi
        elif [[ -e "$CODEX_DIR/skills/$skill" || -L "$CODEX_DIR/skills/$skill" ]]; then
          if rm -rf "$CODEX_DIR/skills/$skill"; then
            if remove_managed_staging_skill "$skill"; then
              ok "Removed unselected managed skill: $skill"
              removed_stale+=("$skill")
            else
              warn "Could not remove the managed staging copy: $AGENTS_SKILLS_DIR/$skill"
              SKIPPED_COMPONENTS+=("unselected managed staging removal failed: $skill")
            fi
          else
            warn "Could not remove unselected managed skill: $skill"
            SKIPPED_COMPONENTS+=("unselected managed skill removal failed: $skill")
          fi
        else
          removed_stale+=("$skill")
        fi
      done
    fi
    if $researchstudio_removed && [[ -f "$CODEX_DIR/skills/.env" ]]; then
      warn "Preserving $CODEX_DIR/skills/.env because it may contain user-managed ResearchStudio credentials; remove it manually if no other skill uses it"
    fi
  fi

  if ! $SELECT_SKILL_SUPERPOWERS && superpowers_ownership_is_recorded; then
    remove_superpowers_fallback
  fi

  if [[ ${#removed_stale[@]} -gt 0 ]] && ! $DRY_RUN; then
    remove_managed_skill_ownership "${removed_stale[@]}"
  fi
}

install_skill_paths_fallback() {
  local repo="$1"
  shift

  if [[ ! -f "$INSTALLER" ]]; then
    warn "skill-installer not found at $INSTALLER"
    SKIPPED_COMPONENTS+=("skill pack from $repo (no npx and fallback installer not found)")
    return 1
  fi

  local -a installed_names=()
  local path skill_name staging_was_owned
  local failed=false
  for path in "$@"; do
    skill_name=$(skill_name_from_path "$path")
    initialize_managed_skill_ownership
    staging_was_owned=false
    owned_managed_skill_contains "$skill_name" && staging_was_owned=true
    if python3 "$INSTALLER" --repo "$repo" --path "$path" --name "$skill_name" &&
       [[ -f "$CODEX_DIR/skills/$skill_name/SKILL.md" ]]; then
      installed_names+=("$skill_name")
      if $staging_was_owned; then
        remove_managed_staging_skill "$skill_name" || true
      fi
    else
      warn "Could not install $skill_name from $repo path $path"
      failed=true
    fi
  done
  if [[ ${#installed_names[@]} -gt 0 ]]; then
    add_managed_skill_ownership "${installed_names[@]}"
  fi
  if $failed; then
    SKIPPED_COMPONENTS+=("skill pack from $repo (fallback installer incomplete)")
    return 1
  fi
  return 0
}

install_skill_paths() {
  local repo="$1"
  shift

  local -a names=()
  local path
  for path in "$@"; do
    names+=("$(skill_name_from_path "$path")")
  done

  if $DRY_RUN; then
    info "Would install via npx skills: $repo -> ${names[*]}"
    info "Fallback if npx fails: install-skill-from-github.py $repo -> $*"
    return 0
  fi

  if install_npx_skill_names "$repo" "${names[@]}"; then
    ok "Installed skills via npx: ${names[*]} ($repo)"
    return 0
  fi

  local -a paths=("$@")
  local -a fallback_paths=()
  local -a verified_names=()
  local index
  for index in "${!paths[@]}"; do
    if npx_verified_skill_contains "${names[$index]}"; then
      verified_names+=("${names[$index]}")
    else
      fallback_paths+=("${paths[$index]}")
    fi
  done
  if [[ ${#verified_names[@]} -gt 0 ]]; then
    add_managed_skill_ownership "${verified_names[@]}"
  fi
  if [[ ${#fallback_paths[@]} -eq 0 ]]; then
    ok "All requested skills have verified source provenance despite the npx non-zero result: ${names[*]} ($repo)"
    return 0
  fi

  warn "npx skills install left ${#fallback_paths[@]} source-unverified skill(s); trying the Python fallback for those paths from $repo"
  install_skill_paths_fallback "$repo" "${fallback_paths[@]}" || true
  return 0
}

reinstall_skill_paths() {
  local repo="$1"
  shift

  local path skill_name
  local -a names=()
  for path in "$@"; do
    skill_name=$(skill_name_from_path "$path")
    names+=("$skill_name")
    if $DRY_RUN; then
      info "Would remove existing skill before reinstall: $CODEX_DIR/skills/$skill_name"
    elif [[ -e "$CODEX_DIR/skills/$skill_name" ]]; then
      rm -rf "$CODEX_DIR/skills/$skill_name"
      ok "Removed existing skill before reinstall: $skill_name"
    fi
  done

  if $DRY_RUN; then
    info "Would reinstall via npx skills: $repo -> ${names[*]}"
    info "Fallback if npx fails: install-skill-from-github.py $repo -> $*"
    return 0
  fi

  install_skill_paths "$repo" "$@"
}

remove_legacy_superpowers_skills() {
  local removed=false
  local skill
  for skill in "${LEGACY_SUPERPOWERS_SKILLS[@]}"; do
    if [[ -e "$CODEX_DIR/skills/$skill" ]]; then
      rm -rf "$CODEX_DIR/skills/$skill"
      removed=true
      ok "Removed legacy superpowers skill copy: $skill"
    fi
  done
  if ! $removed; then
    info "No legacy superpowers skill copies found under $CODEX_DIR/skills"
  fi
}

remove_legacy_superpowers_link() {
  [[ -L "$LEGACY_SUPERPOWERS_LINK" ]] || return 0
  local link_target
  link_target=$(readlink "$LEGACY_SUPERPOWERS_LINK" 2>/dev/null || true)
  if [[ "$link_target" == "$SUPERPOWERS_DIR/skills" ]]; then
    rm -f "$LEGACY_SUPERPOWERS_LINK"
    ok "Removed legacy superpowers staging link"
  else
    warn "Preserving unrecognized legacy superpowers link: $LEGACY_SUPERPOWERS_LINK"
  fi
}

install_superpowers() {
  info "Installing superpowers skill set..."

  if $DRY_RUN; then
    info "Would install via npx skills: obra/superpowers -> all listed superpowers skills"
    info "Fallback if npx fails: clone/update $SUPERPOWERS_REPO_URL -> $SUPERPOWERS_DIR and link $SUPERPOWERS_LINK"
    info "Would remove legacy copied superpowers skills from $CODEX_DIR/skills"
    return 0
  fi

  if install_npx_skill_names obra/superpowers "${SUPERPOWERS_SKILLS[@]}"; then
    ok "Installed superpowers via npx skills"
    remove_legacy_superpowers_skills
    remove_legacy_superpowers_link
    return 0
  fi

  warn "npx skills install failed or npx is unavailable; falling back to git clone/symlink for superpowers"

  if ! command -v git >/dev/null 2>&1; then
    warn "git not found. Skip full superpowers install."
    SKIPPED_COMPONENTS+=("superpowers skill set (git not found)")
    return 0
  fi

  if [[ -d "$SUPERPOWERS_DIR/.git" ]]; then
    if ! git -C "$SUPERPOWERS_DIR" pull --ff-only; then
      warn "Failed to update existing superpowers repo at $SUPERPOWERS_DIR"
    fi
  elif [[ -e "$SUPERPOWERS_DIR" ]]; then
    warn "$SUPERPOWERS_DIR exists but is not a git repo -- skipping full superpowers install"
    SKIPPED_COMPONENTS+=("superpowers skill set ($SUPERPOWERS_DIR is not a git repo)")
    return 0
  else
    if ! git clone "$SUPERPOWERS_REPO_URL" "$SUPERPOWERS_DIR"; then
      warn "Failed to clone superpowers repo"
      SKIPPED_COMPONENTS+=("superpowers skill set (clone failed)")
      return 0
    fi
    ok "Cloned superpowers repo to $SUPERPOWERS_DIR"
  fi

  mkdir -p "$CODEX_DIR/skills"
  local superpowers_skills_dir="$SUPERPOWERS_DIR/skills"
  if [[ -L "$SUPERPOWERS_LINK" || -e "$SUPERPOWERS_LINK" ]]; then
    if [[ ! -L "$SUPERPOWERS_LINK" ]]; then
      warn "$SUPERPOWERS_LINK exists and is not a symlink -- skipping link creation"
      SKIPPED_COMPONENTS+=("superpowers skills link ($SUPERPOWERS_LINK is not a symlink)")
      return 0
    fi
    rm -f "$SUPERPOWERS_LINK"
  fi
  ln -s "$superpowers_skills_dir" "$SUPERPOWERS_LINK"
  ok "Linked superpowers skills into $SUPERPOWERS_LINK"
  add_managed_skill_ownership "${SUPERPOWERS_SKILLS[@]}"

  remove_legacy_superpowers_skills
  remove_legacy_superpowers_link
}

skip_unsupported_item() {
  local item="$1"
  local reason="$2"
  warn "Could not install $item: $reason"
  SKIPPED_COMPONENTS+=("$item ($reason)")
}

copy_local_skill() {
  local selected="$1"
  local skill="$2"
  if ! $selected; then
    return 0
  fi

  local source="$SCRIPT_DIR/skills/$skill"
  local target="$CODEX_DIR/skills/$skill"
  local staging_was_owned=false
  if [[ ! -d "$source" ]]; then
    warn "Local skill not found: skills/$skill"
    return 0
  fi

  initialize_managed_skill_ownership
  owned_managed_skill_contains "$skill" && staging_was_owned=true

  if $DRY_RUN; then
    info "Would copy: skills/$skill/ -> $target/"
  else
    mkdir -p "$CODEX_DIR/skills"
    rm -rf "$target"
    cp -r "$source" "$target"
    if $staging_was_owned; then
      remove_managed_staging_skill "$skill" ||
        warn "Could not remove the legacy staging copy: $AGENTS_SKILLS_DIR/$skill"
    fi
    add_managed_skill_ownership "$skill"
    ok "Installed local skill: $skill"
  fi
}

install_local_skills() {
  if $INTERACTIVE_MODE; then
    copy_local_skill "$SELECT_SKILL_PAPER_READING" "paper-reading"
    copy_local_skill "$SELECT_SKILL_HUMANIZER" "humanizer"
    copy_local_skill "$SELECT_SKILL_HUMANIZER_ZH" "humanizer-zh"
    copy_local_skill "$SELECT_SKILL_HANDOFF" "handoff"
    copy_local_skill "$SELECT_SKILL_NEAT_FREAK" "neat-freak"
    copy_local_skill "$SELECT_SKILL_ADVERSARIAL_REVIEW" "adversarial-review"
    copy_local_skill "$SELECT_SKILL_UPDATE" "update"
    return 0
  fi

  local skill
  for skill in "$SCRIPT_DIR"/skills/*; do
    [[ -d "$skill" && -f "$skill/SKILL.md" ]] || continue
    [[ "$(basename "$skill")" == "adversarial-review" ]] && continue
    copy_local_skill true "$(basename "$skill")"
  done
}


install_selected_recommended_skills() {
  if $SELECT_SKILL_CODE_REVIEW; then
    install_mattpocock_skill_names code-review || \
      skip_unsupported_item "code-review" "npx skills install failed; use Codex /review as the native fallback"
  fi

  if $SELECT_SKILL_KARPATHY; then
    install_npx_skill_names forrestchang/andrej-karpathy-skills karpathy-guidelines || \
      skip_unsupported_item "andrej-karpathy-skills" "npx skills install failed"
  fi

  if $SELECT_SKILL_SUPERPOWERS; then
    install_superpowers
  fi

  if $SELECT_SKILL_MATTPOCOCK; then
    if install_mattpocock_skill_names "${MATTPOCOCK_SKILLS[@]}"; then
      MATTPOCOCK_QUICKSTART_READY=true
    else
      skip_unsupported_item "mattpocock/skills" "npx skills install failed"
    fi
  fi

  if $SELECT_SKILL_DOCUMENTS; then
    install_skill_paths anthropics/skills \
      skills/pdf skills/docx skills/pptx skills/xlsx
  fi

  if $SELECT_SKILL_EXAMPLES; then
    install_skill_paths anthropics/skills \
      skills/canvas-design skills/algorithmic-art skills/mcp-builder
  fi

  if $SELECT_SKILL_FRONTEND_DESIGN; then
    install_skill_paths anthropics/skills skills/frontend-design
  fi

  if $SELECT_SKILL_PUA; then
    install_npx_skill_names tanweai/pua "${PUA_SKILLS[@]}" || \
      skip_unsupported_item "PUA" "npx skills install failed"
  fi
  if $SELECT_SKILL_FRONTEND_SLIDES; then
    install_npx_skill_names zarazhangrui/frontend-slides frontend-slides || \
      skip_unsupported_item "frontend-slides" "npx skills install failed"
  fi
  if $SELECT_SKILL_PPT_MASTER; then
    install_ppt_master
  fi
}

install_selected_ai_skills() {
  local needs_remote=false
  if $SELECT_AI_TOKENIZATION || $SELECT_AI_FINE_TUNING || $SELECT_AI_POST_TRAINING || \
     $SELECT_AI_DISTRIBUTED_TRAINING || $SELECT_AI_INFERENCE_SERVING || \
     $SELECT_AI_OPTIMIZATION || $SELECT_AI_DEEPXIV || $SELECT_AI_RESEARCHSTUDIO ||
     $SELECT_AI_RESEARCHSTUDIO_REEL; then
    needs_remote=true
  fi
  if ! $needs_remote; then
    return 0
  fi

  if $SELECT_AI_TOKENIZATION; then
    install_skill_paths zechenzhangAGI/AI-research-SKILLs \
      02-tokenization/huggingface-tokenizers 02-tokenization/sentencepiece
  fi
  if $SELECT_AI_FINE_TUNING; then
    install_skill_paths zechenzhangAGI/AI-research-SKILLs \
      03-fine-tuning/axolotl 03-fine-tuning/llama-factory 03-fine-tuning/peft 03-fine-tuning/unsloth
  fi
  if $SELECT_AI_POST_TRAINING; then
    install_skill_paths zechenzhangAGI/AI-research-SKILLs \
      06-post-training/grpo-rl-training 06-post-training/openrlhf 06-post-training/simpo 06-post-training/trl-fine-tuning 06-post-training/verl
  fi
  if $SELECT_AI_DISTRIBUTED_TRAINING; then
    install_skill_paths zechenzhangAGI/AI-research-SKILLs \
      08-distributed-training/deepspeed 08-distributed-training/pytorch-fsdp2 08-distributed-training/megatron-core 08-distributed-training/ray-train
  fi
  if $SELECT_AI_INFERENCE_SERVING; then
    install_skill_paths zechenzhangAGI/AI-research-SKILLs \
      12-inference-serving/vllm 12-inference-serving/sglang 12-inference-serving/tensorrt-llm 12-inference-serving/llama-cpp
  fi
  if $SELECT_AI_OPTIMIZATION; then
    install_skill_paths zechenzhangAGI/AI-research-SKILLs \
      10-optimization/awq 10-optimization/gptq 10-optimization/gguf 10-optimization/flash-attention 10-optimization/bitsandbytes
  fi
  if $SELECT_AI_DEEPXIV; then
    reinstall_skill_paths DeepXiv/deepxiv_sdk \
      skills/deepxiv-cli skills/deepxiv-baseline-table skills/deepxiv-trending-digest
  fi
  if $SELECT_AI_RESEARCHSTUDIO; then
    install_researchstudio
  fi
  if $SELECT_AI_RESEARCHSTUDIO_REEL; then
    install_researchstudio_reel
  fi
}

install_skills() {
  if $INTERACTIVE_MODE; then
    info "Installing selected skills..."
    install_selected_recommended_skills
    install_selected_ai_skills
    install_local_skills
    if [[ -n "$(selected_managed_skill_names)" ]]; then
      ok "Selected skills processed"
    else
      info "No selected skills to install"
    fi
    return 0
  fi

  info "Installing skills (group: $SKILL_GROUP)..."

  if [[ "$SKILL_GROUP" == "core" || "$SKILL_GROUP" == "all" ]]; then
    install_mattpocock_skill_names code-review || \
      skip_unsupported_item "code-review" "npx skills install failed; use Codex /review as the native fallback"

    install_npx_skill_names forrestchang/andrej-karpathy-skills karpathy-guidelines || \
      skip_unsupported_item "andrej-karpathy-skills" "npx skills install failed"

    install_superpowers

    if install_mattpocock_skill_names "${MATTPOCOCK_SKILLS[@]}"; then
      MATTPOCOCK_QUICKSTART_READY=true
    else
      skip_unsupported_item "mattpocock/skills" "npx skills install failed"
    fi

    install_skill_paths anthropics/skills \
      skills/frontend-design skills/pdf skills/docx skills/pptx skills/xlsx \
      skills/canvas-design skills/algorithmic-art skills/mcp-builder

    install_local_skills
  fi

  if [[ "$SKILL_GROUP" == "all" ]]; then
    install_npx_skill_names zarazhangrui/frontend-slides frontend-slides || \
      skip_unsupported_item "frontend-slides" "npx skills install failed"
    if $INSTALL_PPT_MASTER_NONINTERACTIVE; then
      install_ppt_master
    fi
  fi

  if [[ "$SKILL_GROUP" == "ai-research" || "$SKILL_GROUP" == "all" ]]; then
    install_skill_paths zechenzhangAGI/AI-research-SKILLs \
      02-tokenization/huggingface-tokenizers 02-tokenization/sentencepiece \
      03-fine-tuning/axolotl 03-fine-tuning/llama-factory 03-fine-tuning/peft 03-fine-tuning/unsloth \
      06-post-training/grpo-rl-training 06-post-training/openrlhf 06-post-training/simpo 06-post-training/trl-fine-tuning 06-post-training/verl \
      08-distributed-training/deepspeed 08-distributed-training/pytorch-fsdp2 08-distributed-training/megatron-core 08-distributed-training/ray-train \
      10-optimization/awq 10-optimization/gptq 10-optimization/gguf 10-optimization/flash-attention 10-optimization/bitsandbytes \
      12-inference-serving/vllm 12-inference-serving/sglang 12-inference-serving/tensorrt-llm 12-inference-serving/llama-cpp

    # DeepXiv is grouped under "Academic Research" in the README and the
    # interactive menu; keep the non-interactive groups consistent with that.
    reinstall_skill_paths DeepXiv/deepxiv_sdk \
      skills/deepxiv-cli skills/deepxiv-baseline-table skills/deepxiv-trending-digest

    if $INSTALL_RESEARCHSTUDIO_NONINTERACTIVE; then
      install_researchstudio
    fi
    if $INSTALL_RESEARCHSTUDIO_REEL_NONINTERACTIVE; then
      install_researchstudio_reel
    fi
  fi
}

interactive_menu() {
  # Open a file descriptor for keyboard input.
  # Prefer stdin when it's a real tty (normal execution); fall back to /dev/tty
  # for piped installs (curl | bash) where stdin carries the script.
  if [[ -t 0 ]]; then
    exec 3<&0
  elif exec 3</dev/tty 2>/dev/null; then
    :
  else
    warn "Cannot open terminal for interactive input, falling back to full install"
    INTERACTIVE_MODE=false
    INSTALL_ALL=true
    return
  fi

  # --- Two-level menu data structure ---
  # Each group has: label, hint, and an array of items.
  # Item format: "label|description|default_on|id"
  # Groups are navigated in the main menu; Enter opens sub-menu.

  local -a GROUP_LABELS=()
  local -a GROUP_HINTS=()
  local -a GROUP_ITEMS=()

  GROUP_LABELS+=("Core")
  GROUP_HINTS+=("")
  GROUP_ITEMS+=("AGENTS.md|Global Codex instructions|1|core-agents-md
config.toml|Codex runtime config template|1|core-config
StatusLine|Codex footer: model, reasoning, branch, context|1|core-statusline
lessons.md|Blank global correction log|1|core-lessons
explorer|Code-path exploration agent|1|agent-explorer
reviewer|Review/regression agent|1|agent-reviewer
docs-researcher|Docs/API verification agent|1|agent-docs-researcher")

  GROUP_LABELS+=("Review")
  GROUP_HINTS+=("Claude parity; Codex-native where available")
  GROUP_ITEMS+=("code-review|PR code review skill or Codex /review fallback|1|skill-code-review
adversarial-review|Cross-model adversarial review|0|skill-adversarial-review")

  GROUP_LABELS+=("Workflow")
  GROUP_HINTS+=("planning, iteration, code quality, meta-config")
GROUP_ITEMS+=("andrej-karpathy-skills|Karpathy coding guidelines|1|skill-karpathy
superpowers|Planning, brainstorming, TDD, debugging|0|skill-superpowers
mattpocock/skills|Agent workflows via npx skills|1|skill-mattpocock
handoff|Conversation handoff skill|1|skill-handoff
neat-freak|Knowledge and governance closeout (KKKKhazix/khazix-skills)|1|skill-neat-freak
update-config|Update Codex config branch install|1|skill-update")

  GROUP_LABELS+=("Development Tools")
  GROUP_HINTS+=("Codex MCP equivalents")
  GROUP_ITEMS+=("context7|Up-to-date library docs (MCP)|1|mcp-context7
github|GitHub workflows (MCP; needs a real PAT)|1|mcp-github
playwright|Browser automation (MCP)|1|mcp-playwright
openaiDeveloperDocs|Official OpenAI docs MCP|1|mcp-openai-docs")

  GROUP_LABELS+=("Design & Content")
  GROUP_HINTS+=("documents, UI, creative artifacts, humanization")
  GROUP_ITEMS+=("document-skills|PDF/DOCX/PPTX/XLSX skills pack|1|skill-documents
example-skills|Canvas/art/MCP builder skill pack|1|skill-examples
frontend-design|Frontend UI design skill|1|skill-frontend-design
humanizer|Remove AI writing patterns|1|skill-humanizer
humanizer-zh|Remove Chinese AI writing patterns|0|skill-humanizer-zh")

  GROUP_LABELS+=("Lifestyle")
  GROUP_HINTS+=("personal productivity")
  GROUP_ITEMS+=("PUA|Productivity coaching skills (CN / EN / JA)|0|skill-pua")

  GROUP_LABELS+=("Academic Research")
  GROUP_HINTS+=("research ideation, literature, training/inference")
  GROUP_ITEMS+=("paper-reading|Research paper summarization|1|skill-paper-reading
researchstudio-idea|Research ideation: idea-spark, paper-search, scoop-check|0|ai-researchstudio
researchstudio-reel|Paper-to-poster, video, blog, and interactive reel|0|ai-researchstudio-reel
tokenization|Tokenizer training and usage|0|ai-tokenization
fine-tuning|Fine-tuning workflows|0|ai-fine-tuning
post-training|RLHF / DPO / GRPO workflows|0|ai-post-training
distributed-training|DeepSpeed / FSDP / Megatron / Ray|0|ai-distributed-training
inference-serving|vLLM / SGLang / TensorRT / llama.cpp|0|ai-inference-serving
optimization|Quantization and optimization|0|ai-optimization
deepxiv|DeepXiv research workflow skills|0|ai-deepxiv")

  GROUP_LABELS+=("Slides")
  GROUP_HINTS+=("AI slide / PPTX generation; default off")
  GROUP_ITEMS+=("frontend-slides|HTML slide generator with PPT conversion|0|skill-frontend-slides
ppt-master|Native editable PPTX generation with live preview|0|skill-ppt-master")

  GROUP_LABELS+=("MCP Servers")
  GROUP_HINTS+=("")
  GROUP_ITEMS+=("lark-mcp|Feishu/Lark integration (needs credentials)|0|mcp-lark")

  local num_groups=${#GROUP_LABELS[@]}

  local -a ALL_LABELS=() ALL_DESCS=() ALL_DEFAULTS=() ALL_IDS=()
  local -a GROUP_START=() GROUP_END=()
  local flat_idx=0
  local g line
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
  local i
  for (( i=0; i<n; i++ )); do
    selected[$i]="${ALL_DEFAULTS[$i]}"
  done

  MENU_SAVED_STTY=$(stty -g <&3 2>/dev/null) || MENU_SAVED_STTY=""
  MENU_ACTIVE=true
  trap 'cleanup_runtime' EXIT
  trap 'cleanup_and_exit 130' INT
  trap 'cleanup_and_exit 143' TERM

  _read_key() {
    local key="" _read_ret=0
    IFS= read -r -s -n 1 key <&3 2>/dev/null || _read_ret=$?
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

  _group_count() {
    local g=$1 cnt=0
    for (( i=GROUP_START[g]; i<=GROUP_END[g]; i++ )); do
      (( selected[i] )) && (( cnt++ )) || true
    done
    echo "$cnt"
  }

  _group_total() {
    local g=$1
    echo $(( GROUP_END[g] - GROUP_START[g] + 1 ))
  }

  _draw_main_menu() {
    local buf=""
    buf+='\033[H'
    buf+='\033[K\n'
    buf+='  \033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\033[K\n'
    buf+="    \033[1;36mCodex Config Installer\033[0m  \033[2m${_cached_version}\033[0m\033[K\n"
    buf+='  \033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\033[K\n'
    buf+='\033[K\n'
    buf+='  \033[2m↑/↓ Navigate   Enter/→ Open   a All  n None  d Defaults  q Quit\033[0m\033[K\n'
    buf+='\033[K\n'

    local g
    for (( g=0; g<num_groups; g++ )); do
      local cnt tot label hint padded count_str
      cnt=$(_group_count "$g")
      tot=$(_group_total "$g")
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

    if [[ $cursor -eq $num_groups ]]; then
      buf+='  \033[32m>\033[0m  \033[1;32m[ Submit ]\033[0m\033[K\n'
    else
      buf+='     \033[2m[ Submit ]\033[0m\033[K\n'
    fi
    buf+='\033[K\n\033[J'
    printf '%b' "$buf"
  }

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

    if [[ $sub_cursor -eq $sub_n ]]; then
      buf+='  \033[32m>\033[0m  \033[1;33m[ Back ]\033[0m\033[K\n'
    else
      buf+='     \033[2m[ Back ]\033[0m\033[K\n'
    fi
    buf+='\033[K\n\033[J'
    printf '%b' "$buf"
  }

  local _cached_version
  _cached_version="$(get_source_version)"

  printf '\033[?1049h' 2>/dev/null
  tput civis 2>/dev/null || printf '\033[?25l'
  stty -echo <&3 2>/dev/null || true

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
          if [[ "$key" == "ENTER" ]]; then break; fi
          continue
        fi
        local sub_g=$cursor
        local sub_n=$(( GROUP_END[sub_g] - GROUP_START[sub_g] + 1 ))
        local sub_cursor=0
        local in_sub=true
        while $in_sub; do
          _draw_sub_menu "$sub_g" "$sub_cursor"
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
              fi
              ;;
            ENTER)
              if (( sub_cursor == sub_n )); then
                in_sub=false
              else
                local abs_idx=$(( GROUP_START[sub_g] + sub_cursor ))
                selected[$abs_idx]=$(( 1 - ${selected[$abs_idx]} ))
              fi
              ;;
            ALL)
              for (( i=GROUP_START[sub_g]; i<=GROUP_END[sub_g]; i++ )); do
                selected[$i]=1
              done
              ;;
            NONE)
              for (( i=GROUP_START[sub_g]; i<=GROUP_END[sub_g]; i++ )); do
                selected[$i]=0
              done
              ;;
            DEFAULT)
              for (( i=GROUP_START[sub_g]; i<=GROUP_END[sub_g]; i++ )); do
                selected[$i]="${ALL_DEFAULTS[$i]}"
              done
              ;;
            QUIT|ESC|LEFT)
              in_sub=false
              ;;
          esac
        done
        ;;
      SPACE)
        ;;
      ALL)
        for (( i=0; i<n; i++ )); do selected[$i]=1; done
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
        cleanup_runtime
        echo ""
        info "Cancelled."
        exit 0
        ;;
    esac
  done

  cleanup_menu
  trap - INT TERM

  local item_id is_selected
  local core_selected=false
  local skills_selected=false
  local mcp_selected=false

  for (( i=0; i<n; i++ )); do
    is_selected=false
    [[ ${selected[$i]} -eq 1 ]] && is_selected=true
    item_id="${ALL_IDS[$i]}"
    case "$item_id" in
      core-agents-md)          SELECT_CORE_AGENTS_MD=$is_selected; [[ $is_selected == true ]] && core_selected=true ;;
      core-config)             SELECT_CORE_CONFIG=$is_selected; [[ $is_selected == true ]] && core_selected=true ;;
      core-statusline)         SELECT_CORE_STATUSLINE=$is_selected; [[ $is_selected == true ]] && core_selected=true ;;
      core-lessons)            SELECT_CORE_LESSONS=$is_selected; [[ $is_selected == true ]] && core_selected=true ;;
      agent-explorer)          SELECT_AGENT_EXPLORER=$is_selected; [[ $is_selected == true ]] && core_selected=true ;;
      agent-reviewer)          SELECT_AGENT_REVIEWER=$is_selected; [[ $is_selected == true ]] && core_selected=true ;;
      agent-docs-researcher)   SELECT_AGENT_DOCS_RESEARCHER=$is_selected; [[ $is_selected == true ]] && core_selected=true ;;
      skill-code-review)       SELECT_SKILL_CODE_REVIEW=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      skill-karpathy)          SELECT_SKILL_KARPATHY=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      skill-superpowers)       SELECT_SKILL_SUPERPOWERS=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      skill-mattpocock)        SELECT_SKILL_MATTPOCOCK=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      skill-documents)         SELECT_SKILL_DOCUMENTS=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      skill-examples)          SELECT_SKILL_EXAMPLES=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      skill-frontend-design)   SELECT_SKILL_FRONTEND_DESIGN=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      skill-paper-reading)     SELECT_SKILL_PAPER_READING=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      skill-humanizer)         SELECT_SKILL_HUMANIZER=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      skill-humanizer-zh)      SELECT_SKILL_HUMANIZER_ZH=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      skill-handoff)           SELECT_SKILL_HANDOFF=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      skill-neat-freak)       SELECT_SKILL_NEAT_FREAK=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      skill-adversarial-review) SELECT_SKILL_ADVERSARIAL_REVIEW=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      skill-update)            SELECT_SKILL_UPDATE=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      skill-pua)               SELECT_SKILL_PUA=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      skill-frontend-slides)   SELECT_SKILL_FRONTEND_SLIDES=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      skill-ppt-master)        SELECT_SKILL_PPT_MASTER=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      ai-tokenization)         SELECT_AI_TOKENIZATION=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      ai-fine-tuning)          SELECT_AI_FINE_TUNING=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      ai-post-training)        SELECT_AI_POST_TRAINING=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      ai-distributed-training)  SELECT_AI_DISTRIBUTED_TRAINING=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      ai-inference-serving)    SELECT_AI_INFERENCE_SERVING=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      ai-optimization)         SELECT_AI_OPTIMIZATION=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      ai-deepxiv)              SELECT_AI_DEEPXIV=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      ai-researchstudio)       SELECT_AI_RESEARCHSTUDIO=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      ai-researchstudio-reel)  SELECT_AI_RESEARCHSTUDIO_REEL=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      mcp-context7)            SELECT_MCP_CONTEXT7=$is_selected; [[ $is_selected == true ]] && mcp_selected=true ;;
      mcp-github)              SELECT_MCP_GITHUB=$is_selected; [[ $is_selected == true ]] && mcp_selected=true ;;
      mcp-playwright)          SELECT_MCP_PLAYWRIGHT=$is_selected; [[ $is_selected == true ]] && mcp_selected=true ;;
      mcp-openai-docs)         SELECT_MCP_OPENAI_DOCS=$is_selected; [[ $is_selected == true ]] && mcp_selected=true ;;
      mcp-lark)                SELECT_MCP_LARK=$is_selected; [[ $is_selected == true ]] && mcp_selected=true ;;
    esac
  done

  if ! $core_selected && ! $skills_selected && ! $mcp_selected; then
    info "No items selected. Existing installer-managed skills will be removed."
  fi

  INSTALL_CORE=$core_selected
  INSTALL_SKILLS=$skills_selected
  INSTALL_MCP=$mcp_selected
  if $skills_selected; then
    if $SELECT_SKILL_CODE_REVIEW || $SELECT_SKILL_KARPATHY || $SELECT_SKILL_SUPERPOWERS || \
       $SELECT_SKILL_MATTPOCOCK || $SELECT_SKILL_DOCUMENTS || $SELECT_SKILL_EXAMPLES || \
       $SELECT_SKILL_FRONTEND_DESIGN || \
       $SELECT_SKILL_PAPER_READING || $SELECT_SKILL_HUMANIZER || \
       $SELECT_SKILL_HUMANIZER_ZH || $SELECT_SKILL_HANDOFF || $SELECT_SKILL_NEAT_FREAK || \
       $SELECT_SKILL_ADVERSARIAL_REVIEW || $SELECT_SKILL_UPDATE || \
       $SELECT_SKILL_PUA || \
       $SELECT_SKILL_FRONTEND_SLIDES || $SELECT_SKILL_PPT_MASTER; then
      if $SELECT_AI_TOKENIZATION || $SELECT_AI_FINE_TUNING || $SELECT_AI_POST_TRAINING || \
         $SELECT_AI_DISTRIBUTED_TRAINING || $SELECT_AI_INFERENCE_SERVING || \
         $SELECT_AI_OPTIMIZATION || $SELECT_AI_DEEPXIV || $SELECT_AI_RESEARCHSTUDIO ||
         $SELECT_AI_RESEARCHSTUDIO_REEL; then
        SKILL_GROUP="all"
      else
        SKILL_GROUP="core"
      fi
    else
      SKILL_GROUP="ai-research"
    fi
  fi
  INTERACTIVE_MODE=true
  INSTALL_ALL=false
}

uninstall() {
  # bash 3.2 + set -u: expanding an empty array with [@] raises "unbound
  # variable", so guard with a length check before copying.
  local components=()
  if [[ ${#UNINSTALL_COMPONENTS[@]} -gt 0 ]]; then
    components=("${UNINSTALL_COMPONENTS[@]}")
  fi
  if [[ ${#components[@]} -eq 0 ]]; then
    components=(core mcp skills)
  fi

  echo ""
  warn "The following will be removed:"
  for comp in "${components[@]}"; do
    case "$comp" in
      core)
        echo "  - $CODEX_DIR/AGENTS.md"
        echo "  - $CODEX_DIR/lessons.md (backed up first -- it holds your accumulated corrections)"
        echo "  - $CODEX_DIR/config.toml"
        echo "  - $CODEX_DIR/agents/*"
        ;;
      mcp)
        echo "  - MCP servers: lark-mcp, context7, github, playwright, openaiDeveloperDocs"
        ;;
      skills)
        echo "  - Managed skills under $CODEX_DIR/skills"
        echo "  - $MANAGED_SKILLS_STATE_FILE"
        echo "  - $SUPERPOWERS_DIR"
        echo "  - $SUPERPOWERS_LINK"
        ;;
    esac
  done
  if [[ -f "$VERSION_STAMP_FILE" ]]; then
    echo "  - $VERSION_STAMP_FILE"
  fi
  if [[ -f "$LEGACY_VERSION_STAMP_FILE" ]]; then
    echo "  - $LEGACY_VERSION_STAMP_FILE"
  fi
  echo ""

  if $DRY_RUN; then
    warn "DRY RUN -- nothing will be removed"
    return 0
  fi

  if ! confirm "Proceed with uninstall?"; then
    info "Cancelled."
    return 0
  fi

  for comp in "${components[@]}"; do
    case "$comp" in
      core)
        # lessons.md holds the user's accumulated corrections; keep a backup
        # next to it so an uninstall is never silent data loss.
        backup_if_exists "$CODEX_DIR/lessons.md"
        rm -f "$CODEX_DIR/AGENTS.md" "$CODEX_DIR/lessons.md" "$CODEX_DIR/config.toml"
        rm -rf "$CODEX_DIR/agents"
        ok "Removed core files"
        ;;
      mcp)
        if command -v codex >/dev/null 2>&1; then
          codex mcp remove lark-mcp 2>/dev/null || true
          codex mcp remove context7 2>/dev/null || true
          codex mcp remove github 2>/dev/null || true
          codex mcp remove playwright 2>/dev/null || true
          codex mcp remove openaiDeveloperDocs 2>/dev/null || true
          ok "Removed MCP entries (if present)"
        else
          warn "codex CLI not found -- skip MCP removal"
        fi
        ;;
      skills)
        initialize_managed_skill_ownership
        for skill in "${MANAGED_SKILLS[@]}"; do
          rm -rf "$CODEX_DIR/skills/$skill"
        done
        rm -f "$SUPERPOWERS_LINK"
        for skill in "${OWNED_MANAGED_SKILLS[@]}"; do
          remove_managed_staging_skill "$skill" || true
        done
        remove_legacy_superpowers_link
        rm -rf "$SUPERPOWERS_DIR"
        rm -f "$MANAGED_SKILLS_STATE_FILE"
        ok "Removed managed skills"
        ;;
    esac
  done

  rm -f "$VERSION_STAMP_FILE"
  rm -f "$LEGACY_VERSION_STAMP_FILE"
  ok "Uninstall complete"
}

main() {
  trap cleanup_runtime EXIT
  trap 'cleanup_and_exit 130' INT
  trap 'cleanup_and_exit 143' TERM

  parse_args "$@"

  # Uninstall only touches local state; --help/argument errors exit inside
  # parse_args. None of these need the source archive, so only enter remote
  # download mode (detect_script_dir) after handling them.
  if $UNINSTALL; then
    uninstall
    exit 0
  fi

  detect_script_dir

  if $SHOW_VERSION; then
    show_version
    exit 0
  fi

  echo ""
  echo "========================================="
  echo "  Codex Config Installer"
  echo "  $(get_source_version)"
  echo "========================================="
  echo ""

  if $DRY_RUN; then
    warn "DRY RUN MODE -- no changes will be made"
    echo ""
  fi

  # No args -> interactive selector (when a terminal is available).
  # Explicit component flags and --all remain non-interactive flows.
  if $INTERACTIVE_MODE; then
    interactive_menu
    if $INTERACTIVE_MODE; then
      reconcile_interactive_skills
    fi
  fi

  if $INSTALL_ALL; then
    install_core
    install_mcp
    install_skills
  else
    $INSTALL_CORE && install_core
    $INSTALL_MCP && install_mcp
    $INSTALL_SKILLS && install_skills
  fi

  if [[ ${#SKIPPED_COMPONENTS[@]} -gt 0 ]]; then
    echo ""
    warn "Install finished, but some components were skipped:"
    local comp
    for comp in "${SKIPPED_COMPONENTS[@]}"; do
      warn "  - $comp"
    done
    warn "Resolve the issues above and re-run the installer to complete them."
    warn "The installed-version stamp was not updated."
  else
    stamp_version
    ok "All selected components installed."
  fi

  show_mattpocock_quickstart
  if [[ ${#SKIPPED_COMPONENTS[@]} -gt 0 ]]; then
    warn "Done with incomplete components. Restart Codex after resolving and rerunning the installer."
    return 1
  else
    ok "Done. Restart Codex to load new skills/config if needed."
  fi
}

main "$@"
