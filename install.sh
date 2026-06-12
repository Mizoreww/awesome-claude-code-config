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
SUPERPOWERS_LINK="$AGENTS_SKILLS_DIR/superpowers"

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
UNINSTALL=false
SHOW_VERSION=false
INTERACTIVE_MODE=false
SKILL_GROUP="all"
UNINSTALL_COMPONENTS=()
SKIPPED_COMPONENTS=()
MCP_FAILED_SERVERS=()
LESSONS_SEEDED=false

SELECT_CORE_AGENTS_MD=false
SELECT_CORE_CONFIG=false
SELECT_CORE_LESSONS=false
SELECT_AGENT_EXPLORER=false
SELECT_AGENT_REVIEWER=false
SELECT_AGENT_DOCS_RESEARCHER=false
SELECT_SKILL_SUPERPOWERS=false
SELECT_SKILL_DOCUMENTS=false
SELECT_SKILL_EXAMPLES=false
SELECT_SKILL_CODING_FOUNDATIONS=false
SELECT_SKILL_PAPER_READING=false
SELECT_SKILL_HUMANIZER=false
SELECT_SKILL_HUMANIZER_ZH=false
SELECT_SKILL_HANDOFF=false
SELECT_SKILL_ADVERSARIAL_REVIEW=false
SELECT_SKILL_UPDATE=false
SELECT_AI_TOKENIZATION=false
SELECT_AI_FINE_TUNING=false
SELECT_AI_POST_TRAINING=false
SELECT_AI_DISTRIBUTED_TRAINING=false
SELECT_AI_INFERENCE_SERVING=false
SELECT_AI_OPTIMIZATION=false
SELECT_AI_DEEPXIV=false
SELECT_MCP_CONTEXT7=false
SELECT_MCP_GITHUB=false
SELECT_MCP_PLAYWRIGHT=false
SELECT_MCP_OPENAI_DOCS=false
SELECT_MCP_LARK=false

MANAGED_SKILLS=(
  frontend-design pdf docx pptx xlsx canvas-design algorithmic-art mcp-builder
  python-patterns python-testing golang-patterns golang-testing frontend-patterns
  security-review tdd-workflow verification-loop api-design database-migrations
  using-superpowers systematic-debugging writing-plans test-driven-development
  huggingface-tokenizers sentencepiece
  axolotl llama-factory peft unsloth
  grpo-rl-training openrlhf simpo trl-fine-tuning verl
  deepspeed pytorch-fsdp2 megatron-core ray-train
  awq gptq gguf flash-attention bitsandbytes
  vllm sglang tensorrt-llm llama-cpp
  paper-reading
  adversarial-review
  handoff
  humanizer
  humanizer-zh
  update
  deepxiv-cli
  deepxiv-baseline-table
  deepxiv-trending-digest
)

LEGACY_SUPERPOWERS_SKILLS=(
  using-superpowers
  systematic-debugging
  writing-plans
  test-driven-development
)

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
  --core                Install AGENTS.md, lessons.md, config.toml, agents/*
  --mcp                 Install MCP servers only
  --skills [GROUP]      Install skills only. GROUP: core, ai-research, all (default: all)
  --uninstall [COMP...] Uninstall managed files. COMP: --core --mcp --skills
  --version             Show source / installed / remote versions
  --dry-run             Preview changes without applying
  --force               Skip uninstall confirmation
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
        if [[ $# -gt 0 && ! "$1" =~ ^-- ]]; then
          case "$1" in
            core|ai-research|all)
              SKILL_GROUP="$1"
              shift
              ;;
            *)
              error "Invalid skill group: $1"
              exit 1
              ;;
          esac
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

# lessons.md is the user's accumulated correction memory (see AGENTS.md), and
# config.toml points model_instructions_file at it. Never overwrite an existing
# copy; only seed the template when the file is absent.
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
    info "Would copy: lessons.md -> $CODEX_DIR/lessons.md"
  else
    mkdir -p "$CODEX_DIR"
    cp "$SCRIPT_DIR/lessons.md" "$CODEX_DIR/lessons.md"
    ok "lessons.md installed"
  fi
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
      if [[ -f "$CODEX_DIR/config.toml" ]]; then
        warn "$CODEX_DIR/config.toml exists -- skipping (merge manually if needed)"
      elif $DRY_RUN; then
        info "Would copy: config.toml -> $CODEX_DIR/config.toml"
      else
        cp "$SCRIPT_DIR/config.toml" "$CODEX_DIR/config.toml"
        ok "config.toml installed"
      fi
      # config.toml references lessons.md via model_instructions_file; make
      # sure the file exists even when the Lessons item was deselected.
      if ! $SELECT_CORE_LESSONS && [[ ! -f "$CODEX_DIR/lessons.md" ]]; then
        warn "config.toml requires lessons.md (model_instructions_file); seeding it although Lessons was deselected"
      fi
      seed_lessons_if_missing
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

report_mcp_result() {
  if [[ ${#MCP_FAILED_SERVERS[@]} -eq 0 ]]; then
    ok "MCP setup complete (existing entries are ignored)"
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
      add_mcp_server github --env GITHUB_PERSONAL_ACCESS_TOKEN=YOUR_GITHUB_PAT -- npx -y @modelcontextprotocol/server-github
    fi
    if $SELECT_MCP_PLAYWRIGHT; then
      add_mcp_server playwright -- npx -y @playwright/mcp@latest
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

  # lark-mcp and github need real credentials; configuring them with the
  # template placeholders would create active-but-broken servers. They stay
  # opt-in via the interactive menu or a manual `codex mcp add`.
  info "Skipping lark-mcp and github MCP servers: they require real credentials."
  info "Enable them via the interactive installer or 'codex mcp add' after filling credentials."
  add_mcp_server context7 -- npx -y @upstash/context7-mcp
  add_mcp_server playwright -- npx -y @playwright/mcp@latest
  add_mcp_server openaiDeveloperDocs --url https://developers.openai.com/mcp
  report_mcp_result
}

install_skill_paths() {
  local repo="$1"
  shift

  if $DRY_RUN; then
    info "Would install from $repo: $*"
    return 0
  fi

  if ! python3 "$INSTALLER" --repo "$repo" --path "$@"; then
    warn "Skill install from $repo returned non-zero (possibly already installed)"
    SKIPPED_COMPONENTS+=("skill pack from $repo (installer returned non-zero)")
  fi
}

reinstall_skill_paths() {
  local repo="$1"
  shift

  if $DRY_RUN; then
    info "Would reinstall from $repo: $*"
    return 0
  fi

  local path skill_name
  for path in "$@"; do
    skill_name=$(basename "$path")
    if [[ -e "$CODEX_DIR/skills/$skill_name" ]]; then
      rm -rf "$CODEX_DIR/skills/$skill_name"
      ok "Removed existing skill before reinstall: $skill_name"
    fi
  done

  if ! python3 "$INSTALLER" --repo "$repo" --path "$@"; then
    warn "Skill reinstall from $repo returned non-zero"
    SKIPPED_COMPONENTS+=("skill pack from $repo (installer returned non-zero)")
  fi
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

install_superpowers() {
  info "Installing full superpowers skill set..."

  if $DRY_RUN; then
    info "Would clone or update: $SUPERPOWERS_REPO_URL -> $SUPERPOWERS_DIR"
    info "Would create symlink: $SUPERPOWERS_LINK -> $SUPERPOWERS_DIR/skills"
    info "Would remove legacy copied superpowers skills from $CODEX_DIR/skills"
    return 0
  fi

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

  mkdir -p "$AGENTS_SKILLS_DIR"
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

  remove_legacy_superpowers_skills
}

copy_local_skill() {
  local selected="$1"
  local skill="$2"
  if ! $selected; then
    return 0
  fi

  local source="$SCRIPT_DIR/skills/$skill"
  local target="$CODEX_DIR/skills/$skill"
  if [[ ! -d "$source" ]]; then
    warn "Local skill not found: skills/$skill"
    return 0
  fi

  if $DRY_RUN; then
    info "Would copy: skills/$skill/ -> $target/"
  else
    mkdir -p "$CODEX_DIR/skills"
    rm -rf "$target"
    cp -r "$source" "$target"
    ok "Installed local skill: $skill"
  fi
}

install_local_skills() {
  if $INTERACTIVE_MODE; then
    copy_local_skill "$SELECT_SKILL_PAPER_READING" "paper-reading"
    copy_local_skill "$SELECT_SKILL_HUMANIZER" "humanizer"
    copy_local_skill "$SELECT_SKILL_HUMANIZER_ZH" "humanizer-zh"
    copy_local_skill "$SELECT_SKILL_HANDOFF" "handoff"
    copy_local_skill "$SELECT_SKILL_ADVERSARIAL_REVIEW" "adversarial-review"
    copy_local_skill "$SELECT_SKILL_UPDATE" "update"
    return 0
  fi

  local skill
  for skill in "$SCRIPT_DIR"/skills/*; do
    [[ -d "$skill" && -f "$skill/SKILL.md" ]] || continue
    copy_local_skill true "$(basename "$skill")"
  done
}


install_selected_recommended_skills() {
  local needs_remote=false
  if $SELECT_SKILL_DOCUMENTS || $SELECT_SKILL_EXAMPLES || $SELECT_SKILL_CODING_FOUNDATIONS; then
    needs_remote=true
  fi

  local remote_installer_available=true
  if [[ ! -f "$INSTALLER" ]]; then
    remote_installer_available=false
    if $needs_remote; then
      warn "skill-installer not found at $INSTALLER"
      warn "Remote skill packs that depend on it will be skipped."
      SKIPPED_COMPONENTS+=("recommended remote skill packs (skill-installer not found)")
    fi
  fi

  if $SELECT_SKILL_SUPERPOWERS; then
    install_superpowers
  fi

  if ! $remote_installer_available; then
    return 0
  fi

  if $SELECT_SKILL_DOCUMENTS; then
    install_skill_paths anthropics/skills \
      skills/pdf skills/docx skills/pptx skills/xlsx
  fi

  if $SELECT_SKILL_EXAMPLES; then
    install_skill_paths anthropics/skills \
      skills/frontend-design skills/canvas-design skills/algorithmic-art skills/mcp-builder
  fi

  if $SELECT_SKILL_CODING_FOUNDATIONS; then
    install_skill_paths affaan-m/everything-claude-code \
      skills/python-patterns skills/python-testing skills/golang-patterns skills/golang-testing \
      skills/frontend-patterns skills/security-review skills/tdd-workflow skills/verification-loop \
      skills/api-design skills/database-migrations
  fi

}

install_selected_ai_skills() {
  local needs_remote=false
  if $SELECT_AI_TOKENIZATION || $SELECT_AI_FINE_TUNING || $SELECT_AI_POST_TRAINING || \
     $SELECT_AI_DISTRIBUTED_TRAINING || $SELECT_AI_INFERENCE_SERVING || \
     $SELECT_AI_OPTIMIZATION || $SELECT_AI_DEEPXIV; then
    needs_remote=true
  fi
  if ! $needs_remote; then
    return 0
  fi

  if [[ ! -f "$INSTALLER" ]]; then
    warn "skill-installer not found at $INSTALLER"
    warn "AI research skill packs that depend on it will be skipped."
    SKIPPED_COMPONENTS+=("AI research skill packs (skill-installer not found)")
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
}

install_skills() {
  if $INTERACTIVE_MODE; then
    info "Installing selected skills..."
    install_selected_recommended_skills
    install_selected_ai_skills
    install_local_skills
    if $SELECT_SKILL_PAPER_READING || $SELECT_SKILL_HUMANIZER || \
       $SELECT_SKILL_HUMANIZER_ZH || $SELECT_SKILL_HANDOFF || \
       $SELECT_SKILL_ADVERSARIAL_REVIEW || $SELECT_SKILL_UPDATE || \
       $SELECT_SKILL_SUPERPOWERS || $SELECT_SKILL_DOCUMENTS || \
       $SELECT_SKILL_EXAMPLES || $SELECT_SKILL_CODING_FOUNDATIONS || \
       $SELECT_AI_TOKENIZATION || $SELECT_AI_FINE_TUNING || \
       $SELECT_AI_POST_TRAINING || $SELECT_AI_DISTRIBUTED_TRAINING || \
       $SELECT_AI_INFERENCE_SERVING || $SELECT_AI_OPTIMIZATION || \
       $SELECT_AI_DEEPXIV; then
      ok "Selected skills processed"
    else
      info "No selected skills to install"
    fi
    return 0
  fi

  info "Installing skills (group: $SKILL_GROUP)..."

  local remote_installer_available=true
  if [[ ! -f "$INSTALLER" ]]; then
    remote_installer_available=false
    warn "skill-installer not found at $INSTALLER"
    warn "Remote skill packs that depend on it will be skipped."
  fi

  if [[ "$SKILL_GROUP" == "core" || "$SKILL_GROUP" == "all" ]]; then
    install_superpowers

    if $remote_installer_available; then
      install_skill_paths anthropics/skills \
        skills/frontend-design skills/pdf skills/docx skills/pptx skills/xlsx \
        skills/canvas-design skills/algorithmic-art skills/mcp-builder

      install_skill_paths affaan-m/everything-claude-code \
        skills/python-patterns skills/python-testing skills/golang-patterns skills/golang-testing \
        skills/frontend-patterns skills/security-review skills/tdd-workflow skills/verification-loop \
        skills/api-design skills/database-migrations
    else
      SKIPPED_COMPONENTS+=("core remote skill packs (skill-installer not found)")
    fi

    install_local_skills
  fi

  if [[ "$SKILL_GROUP" == "ai-research" || "$SKILL_GROUP" == "all" ]]; then
    if ! $remote_installer_available; then
      warn "Skipping AI research skills because skill-installer is unavailable"
      SKIPPED_COMPONENTS+=("AI research skill packs (skill-installer not found)")
      return 0
    fi

    install_skill_paths zechenzhangAGI/AI-research-SKILLs \
      02-tokenization/huggingface-tokenizers 02-tokenization/sentencepiece \
      03-fine-tuning/axolotl 03-fine-tuning/llama-factory 03-fine-tuning/peft 03-fine-tuning/unsloth \
      06-post-training/grpo-rl-training 06-post-training/openrlhf 06-post-training/simpo 06-post-training/trl-fine-tuning 06-post-training/verl \
      08-distributed-training/deepspeed 08-distributed-training/pytorch-fsdp2 08-distributed-training/megatron-core 08-distributed-training/ray-train \
      10-optimization/awq 10-optimization/gptq 10-optimization/gguf 10-optimization/flash-attention 10-optimization/bitsandbytes \
      12-inference-serving/vllm 12-inference-serving/sglang 12-inference-serving/tensorrt-llm 12-inference-serving/llama-cpp

    # DeepXiv is grouped under "Skills — AI Research" in the README and the
    # interactive menu; keep the non-interactive groups consistent with that.
    reinstall_skill_paths DeepXiv/deepxiv_sdk \
      skills/deepxiv-cli skills/deepxiv-baseline-table skills/deepxiv-trending-digest
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
lessons.md|Lessons source-of-truth|1|core-lessons")

  GROUP_LABELS+=("Agents")
  GROUP_HINTS+=("")
  GROUP_ITEMS+=("explorer|Code-path exploration agent|1|agent-explorer
reviewer|Review/regression agent|1|agent-reviewer
docs-researcher|Docs/API verification agent|1|agent-docs-researcher")

  GROUP_LABELS+=("Skills — Recommended")
  GROUP_HINTS+=("")
  GROUP_ITEMS+=("superpowers|Planning and execution workflows|1|skill-superpowers
document-skills|PDF/DOCX/PPTX/XLSX skills pack|1|skill-documents
example-skills|Frontend/art/MCP builder pack|1|skill-examples
coding-foundations|Patterns, testing, security (upstream everything-claude-code)|1|skill-coding-foundations
paper-reading|Research paper summarization|1|skill-paper-reading
humanizer|Remove AI writing patterns|1|skill-humanizer
humanizer-zh|Remove Chinese AI writing patterns|0|skill-humanizer-zh
handoff|Compact context into a handoff doc|1|skill-handoff
adversarial-review|Cross-model adversarial review|1|skill-adversarial-review
update|Update Codex config branch install|1|skill-update")

  GROUP_LABELS+=("Skills — AI Research")
  GROUP_HINTS+=("")
  GROUP_ITEMS+=("tokenization|Tokenizer training and usage|0|ai-tokenization
fine-tuning|Fine-tuning workflows|0|ai-fine-tuning
post-training|RLHF / DPO / GRPO workflows|0|ai-post-training
distributed-training|DeepSpeed / FSDP / Megatron / Ray|0|ai-distributed-training
inference-serving|vLLM / SGLang / TensorRT / llama.cpp|0|ai-inference-serving
optimization|Quantization and optimization|0|ai-optimization
deepxiv|DeepXiv research workflow skills|0|ai-deepxiv")

  GROUP_LABELS+=("MCP Servers")
  GROUP_HINTS+=("")
  GROUP_ITEMS+=("context7|Up-to-date library docs|1|mcp-context7
github|GitHub workflows (needs a real PAT)|0|mcp-github
playwright|Browser automation|1|mcp-playwright
openaiDeveloperDocs|Official OpenAI docs MCP|1|mcp-openai-docs
lark-mcp|Feishu/Lark integration (needs credentials)|0|mcp-lark")

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
      core-lessons)            SELECT_CORE_LESSONS=$is_selected; [[ $is_selected == true ]] && core_selected=true ;;
      agent-explorer)          SELECT_AGENT_EXPLORER=$is_selected; [[ $is_selected == true ]] && core_selected=true ;;
      agent-reviewer)          SELECT_AGENT_REVIEWER=$is_selected; [[ $is_selected == true ]] && core_selected=true ;;
      agent-docs-researcher)   SELECT_AGENT_DOCS_RESEARCHER=$is_selected; [[ $is_selected == true ]] && core_selected=true ;;
      skill-superpowers)       SELECT_SKILL_SUPERPOWERS=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      skill-documents)         SELECT_SKILL_DOCUMENTS=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      skill-examples)          SELECT_SKILL_EXAMPLES=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      skill-coding-foundations)        SELECT_SKILL_CODING_FOUNDATIONS=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      skill-paper-reading)     SELECT_SKILL_PAPER_READING=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      skill-humanizer)         SELECT_SKILL_HUMANIZER=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      skill-humanizer-zh)      SELECT_SKILL_HUMANIZER_ZH=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      skill-handoff)           SELECT_SKILL_HANDOFF=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      skill-adversarial-review) SELECT_SKILL_ADVERSARIAL_REVIEW=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      skill-update)            SELECT_SKILL_UPDATE=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      ai-tokenization)         SELECT_AI_TOKENIZATION=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      ai-fine-tuning)          SELECT_AI_FINE_TUNING=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      ai-post-training)        SELECT_AI_POST_TRAINING=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      ai-distributed-training)  SELECT_AI_DISTRIBUTED_TRAINING=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      ai-inference-serving)    SELECT_AI_INFERENCE_SERVING=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      ai-optimization)         SELECT_AI_OPTIMIZATION=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      ai-deepxiv)              SELECT_AI_DEEPXIV=$is_selected; [[ $is_selected == true ]] && skills_selected=true ;;
      mcp-context7)            SELECT_MCP_CONTEXT7=$is_selected; [[ $is_selected == true ]] && mcp_selected=true ;;
      mcp-github)              SELECT_MCP_GITHUB=$is_selected; [[ $is_selected == true ]] && mcp_selected=true ;;
      mcp-playwright)          SELECT_MCP_PLAYWRIGHT=$is_selected; [[ $is_selected == true ]] && mcp_selected=true ;;
      mcp-openai-docs)         SELECT_MCP_OPENAI_DOCS=$is_selected; [[ $is_selected == true ]] && mcp_selected=true ;;
      mcp-lark)                SELECT_MCP_LARK=$is_selected; [[ $is_selected == true ]] && mcp_selected=true ;;
    esac
  done

  if ! $core_selected && ! $skills_selected && ! $mcp_selected; then
    # Match the PowerShell behavior: an empty submission is a no-op and must
    # not fall through to the version stamp ("installed" with nothing done).
    info "No items selected. Nothing to do."
    cleanup_and_exit 0
  fi

  INSTALL_CORE=$core_selected
  INSTALL_SKILLS=$skills_selected
  INSTALL_MCP=$mcp_selected
  if $skills_selected; then
    if $SELECT_SKILL_SUPERPOWERS || $SELECT_SKILL_DOCUMENTS || $SELECT_SKILL_EXAMPLES || \
       $SELECT_SKILL_CODING_FOUNDATIONS || $SELECT_SKILL_PAPER_READING || $SELECT_SKILL_HUMANIZER || \
       $SELECT_SKILL_HUMANIZER_ZH || $SELECT_SKILL_HANDOFF || \
       $SELECT_SKILL_ADVERSARIAL_REVIEW || $SELECT_SKILL_UPDATE; then
      if $SELECT_AI_TOKENIZATION || $SELECT_AI_FINE_TUNING || $SELECT_AI_POST_TRAINING || \
         $SELECT_AI_DISTRIBUTED_TRAINING || $SELECT_AI_INFERENCE_SERVING || \
         $SELECT_AI_OPTIMIZATION || $SELECT_AI_DEEPXIV; then
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
        for skill in "${MANAGED_SKILLS[@]}"; do
          rm -rf "$CODEX_DIR/skills/$skill"
        done
        rm -f "$SUPERPOWERS_LINK"
        rm -rf "$SUPERPOWERS_DIR"
        ok "Removed managed skills"
        ;;
    esac
  done

  rm -f "$VERSION_STAMP_FILE"
  rm -f "$LEGACY_VERSION_STAMP_FILE"
  ok "Uninstall complete"
}

main() {
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

  stamp_version

  if [[ ${#SKIPPED_COMPONENTS[@]} -gt 0 ]]; then
    echo ""
    warn "Install finished, but some components were skipped:"
    local comp
    for comp in "${SKIPPED_COMPONENTS[@]}"; do
      warn "  - $comp"
    done
    warn "Resolve the issues above and re-run the installer to complete them."
  fi

  ok "Done. Restart Codex to load new skills/config if needed."
}

main "$@"
