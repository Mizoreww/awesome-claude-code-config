#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Codex Configuration Installer
# https://github.com/Mizoreww/awesome-claude-code-config
# ============================================================

CODEX_DIR="$HOME/.codex"
REPO_URL="https://github.com/Mizoreww/awesome-claude-code-config"
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

DRY_RUN=false
FORCE=false
INSTALL_ALL=true
INSTALL_CORE=false
INSTALL_MCP=false
INSTALL_SKILLS=false
UNINSTALL=false
SHOW_VERSION=false
SKILL_GROUP="all"
UNINSTALL_COMPONENTS=()

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
  humanizer
)

LEGACY_SUPERPOWERS_SKILLS=(
  using-superpowers
  systematic-debugging
  writing-plans
  test-driven-development
)

detect_script_dir() {
  local candidate
  candidate="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if [[ -f "$candidate/AGENTS.md" ]]; then
    SCRIPT_DIR="$candidate"
    REMOTE_MODE=false
    return
  fi

  REMOTE_MODE=true
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT

  local version="${VERSION:-codex}"
  local tarball_url="$REPO_URL/archive/refs/heads/${version}.tar.gz"
  if [[ "$version" =~ ^v[0-9] ]]; then
    tarball_url="$REPO_URL/archive/refs/tags/${version}.tar.gz"
  fi

  info "Remote mode: downloading $version..."
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$tarball_url" | tar xz -C "$tmpdir" --strip-components=1
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$tarball_url" | tar xz -C "$tmpdir" --strip-components=1
  else
    error "Neither curl nor wget found. Install one and retry."
    exit 1
  fi

  SCRIPT_DIR="$tmpdir"
  ok "Source downloaded to temporary directory"
}

usage() {
  cat <<EOF2
Usage: $(basename "$0") [OPTIONS]

Install Codex configuration files.

Options:
  --all                 Install everything (default)
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
  $(basename "$0") --skills core
  $(basename "$0") --skills ai-research
  $(basename "$0") --uninstall --skills
  VERSION=v1.0.0 bash <(curl -fsSL $REPO_URL/raw/codex/install.sh)
EOF2
}

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
      --core)
        has_component=true
        INSTALL_CORE=true
        shift
        ;;
      --mcp)
        has_component=true
        INSTALL_MCP=true
        shift
        ;;
      --skills)
        has_component=true
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
        error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done

  if $has_component; then
    INSTALL_ALL=false
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
  local url="$REPO_URL/raw/codex/VERSION"
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
  if [[ "$ver" != "unknown" && ! $DRY_RUN ]]; then
    echo "$ver" > "$VERSION_STAMP_FILE"
  fi
}

install_core() {
  info "Installing core files..."
  mkdir -p "$CODEX_DIR"

  backup_if_exists "$CODEX_DIR/AGENTS.md"
  backup_if_exists "$CODEX_DIR/lessons.md"
  backup_if_exists "$CODEX_DIR/agents"

  if $DRY_RUN; then
    info "Would copy: AGENTS.md -> $CODEX_DIR/AGENTS.md"
    info "Would copy: lessons.md -> $CODEX_DIR/lessons.md"
    info "Would copy: agents/*.toml -> $CODEX_DIR/agents/"
  else
    cp "$SCRIPT_DIR/AGENTS.md" "$CODEX_DIR/AGENTS.md"
    cp "$SCRIPT_DIR/lessons.md" "$CODEX_DIR/lessons.md"
    if [[ -d "$SCRIPT_DIR/agents" ]]; then
      mkdir -p "$CODEX_DIR/agents"
      cp "$SCRIPT_DIR"/agents/*.toml "$CODEX_DIR/agents/"
    fi
    ok "AGENTS.md, lessons.md, and agents installed"
  fi

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

install_mcp() {
  info "Installing MCP servers..."

  if ! command -v codex >/dev/null 2>&1; then
    warn "codex CLI not found. Skip MCP setup."
    return 0
  fi

  if $DRY_RUN; then
    info "Would add MCP server: lark-mcp"
    info "Would add MCP server: context7"
    info "Would add MCP server: github"
    info "Would add MCP server: playwright"
    info "Would add MCP server: openaiDeveloperDocs"
    return 0
  fi

  codex mcp add lark-mcp -- npx -y @larksuiteoapi/lark-mcp mcp -a YOUR_APP_ID -s YOUR_APP_SECRET || true
  codex mcp add context7 -- npx -y @upstash/context7-mcp || true
  codex mcp add github --env GITHUB_PERSONAL_ACCESS_TOKEN=YOUR_GITHUB_PAT -- npx -y @modelcontextprotocol/server-github || true
  codex mcp add playwright -- npx -y @playwright/mcp@latest || true
  codex mcp add openaiDeveloperDocs --url https://developers.openai.com/mcp || true
  ok "MCP setup complete (existing entries are ignored)"
}

install_skill_paths() {
  local repo="$1"
  shift

  if $DRY_RUN; then
    info "Would install from $repo: $*"
    return 0
  fi

  python3 "$INSTALLER" --repo "$repo" --path "$@" || warn "Skill install from $repo returned non-zero (possibly already installed)"
}

cleanup_legacy_superpowers_skills() {
  local removed=false

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
    return 0
  fi

  if [[ -d "$SUPERPOWERS_DIR/.git" ]]; then
    (
      cd "$SUPERPOWERS_DIR"
      git pull --ff-only
    ) || warn "Failed to update existing superpowers repo at $SUPERPOWERS_DIR"
  elif [[ -e "$SUPERPOWERS_DIR" ]]; then
    warn "$SUPERPOWERS_DIR exists but is not a git repo -- skipping full superpowers install"
    return 0
  else
    git clone "$SUPERPOWERS_REPO_URL" "$SUPERPOWERS_DIR" || {
      warn "Failed to clone superpowers repo"
      return 0
    }
    ok "Cloned superpowers repo to $SUPERPOWERS_DIR"
  fi

  mkdir -p "$AGENTS_SKILLS_DIR"

  if [[ -e "$SUPERPOWERS_LINK" && ! -L "$SUPERPOWERS_LINK" ]]; then
    warn "$SUPERPOWERS_LINK exists and is not a symlink -- skipping link creation"
    return 0
  fi

  ln -sfn "$SUPERPOWERS_DIR/skills" "$SUPERPOWERS_LINK"
  ok "Linked superpowers skills into $SUPERPOWERS_LINK"

  cleanup_legacy_superpowers_skills
}

install_local_skills() {
  for skill_dir in "$SCRIPT_DIR"/skills/*/; do
    [[ -d "$skill_dir" ]] || continue
    local skill
    skill=$(basename "$skill_dir")

    if $DRY_RUN; then
      info "Would copy: skills/$skill/ -> $CODEX_DIR/skills/$skill/"
    else
      cp -r "$skill_dir" "$CODEX_DIR/skills/$skill"
      ok "Installed local skill: $skill"
    fi
  done
}

install_skills() {
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
    fi

    install_local_skills
  fi

  if [[ "$SKILL_GROUP" == "ai-research" || "$SKILL_GROUP" == "all" ]]; then
    if ! $remote_installer_available; then
      warn "Skipping AI research skills because skill-installer is unavailable"
      return 0
    fi

    install_skill_paths zechenzhangAGI/AI-research-SKILLs \
      02-tokenization/huggingface-tokenizers 02-tokenization/sentencepiece \
      03-fine-tuning/axolotl 03-fine-tuning/llama-factory 03-fine-tuning/peft 03-fine-tuning/unsloth \
      06-post-training/grpo-rl-training 06-post-training/openrlhf 06-post-training/simpo 06-post-training/trl-fine-tuning 06-post-training/verl \
      08-distributed-training/deepspeed 08-distributed-training/pytorch-fsdp2 08-distributed-training/megatron-core 08-distributed-training/ray-train \
      10-optimization/awq 10-optimization/gptq 10-optimization/gguf 10-optimization/flash-attention 10-optimization/bitsandbytes \
      12-inference-serving/vllm 12-inference-serving/sglang 12-inference-serving/tensorrt-llm 12-inference-serving/llama-cpp
  fi
}

uninstall() {
  local components=("${UNINSTALL_COMPONENTS[@]}")
  if [[ ${#components[@]} -eq 0 ]]; then
    components=(core mcp skills)
  fi

  echo ""
  warn "The following will be removed:"
  for comp in "${components[@]}"; do
    case "$comp" in
      core)
        echo "  - $CODEX_DIR/AGENTS.md"
        echo "  - $CODEX_DIR/lessons.md"
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
  ok "Uninstall complete"
}

main() {
  detect_script_dir
  parse_args "$@"

  if $SHOW_VERSION; then
    show_version
    exit 0
  fi

  if $UNINSTALL; then
    uninstall
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

  mkdir -p "$CODEX_DIR"

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
  ok "Done. Restart Codex to load new skills/config if needed."
}

main "$@"
