#!/usr/bin/env bash
set -euo pipefail

CODEX_DIR="${HOME}/.codex"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="${CODEX_DIR}/skills/.system/skill-installer/scripts/install-skill-from-github.py"
CODEX_MEM_BIN="${CODEX_DIR}/bin/codex-mem"

info(){ printf "[INFO] %s\n" "$*"; }
warn(){ printf "[WARN] %s\n" "$*"; }

backup() {
  local target="$1"
  if [[ -e "$target" ]]; then
    cp -r "$target" "${target}.backup.$(date +%Y%m%d%H%M%S)"
  fi
}

install_core() {
  mkdir -p "$CODEX_DIR"
  backup "$CODEX_DIR/AGENTS.md"
  backup "$CODEX_DIR/lessons.md"
  cp "$SCRIPT_DIR/AGENTS.md" "$CODEX_DIR/AGENTS.md"
  cp "$SCRIPT_DIR/lessons.md" "$CODEX_DIR/lessons.md"

  if [[ -f "$CODEX_DIR/config.toml" ]]; then
    warn "~/.codex/config.toml exists. Merge manually with config.toml"
  else
    cp "$SCRIPT_DIR/config.toml" "$CODEX_DIR/config.toml"
  fi
}

install_mcp() {
  codex mcp add lark-mcp -- npx -y @larksuiteoapi/lark-mcp mcp -a YOUR_APP_ID -s YOUR_APP_SECRET || true
  codex mcp add context7 -- npx -y @upstash/context7-mcp || true
  codex mcp add github --env GITHUB_PERSONAL_ACCESS_TOKEN=YOUR_GITHUB_PAT -- npx -y @modelcontextprotocol/server-github || true
  codex mcp add playwright -- npx -y @playwright/mcp@latest || true
}

install_skills() {
  if [[ ! -f "$INSTALLER" ]]; then
    warn "skill-installer not found at $INSTALLER"
    warn "Install core Codex system skills first, then rerun."
    return 0
  fi

  # Anthropic skills pack
  python3 "$INSTALLER" --repo anthropics/skills --path \
    skills/frontend-design skills/pdf skills/docx skills/pptx skills/xlsx \
    skills/canvas-design skills/algorithmic-art skills/mcp-builder || true

  # Everything Claude Code core set
  python3 "$INSTALLER" --repo affaan-m/everything-claude-code --path \
    skills/python-patterns skills/python-testing skills/golang-patterns skills/golang-testing \
    skills/frontend-patterns skills/security-review skills/tdd-workflow skills/verification-loop \
    skills/api-design skills/database-migrations || true

  # AI research set
  python3 "$INSTALLER" --repo zechenzhangAGI/AI-research-SKILLs --path \
    03-fine-tuning/axolotl 03-fine-tuning/llama-factory 03-fine-tuning/peft 03-fine-tuning/unsloth \
    06-post-training/grpo-rl-training 06-post-training/openrlhf 06-post-training/simpo 06-post-training/trl-fine-tuning 06-post-training/verl \
    08-distributed-training/deepspeed 08-distributed-training/pytorch-fsdp2 08-distributed-training/megatron-core 08-distributed-training/ray-train \
    10-optimization/awq 10-optimization/gptq 10-optimization/gguf 10-optimization/flash-attention 10-optimization/bitsandbytes \
    12-inference-serving/vllm 12-inference-serving/sglang 12-inference-serving/tensorrt-llm 12-inference-serving/llama-cpp || true

  # Superpowers
  python3 "$INSTALLER" --repo obra/superpowers --path skills/using-superpowers skills/systematic-debugging skills/writing-plans skills/test-driven-development || true

  # Claude Mem
  python3 "$INSTALLER" --repo thedotmack/claude-mem --path skills/do skills/make-plan || true
}

install_codex_mem() {
  mkdir -p "$CODEX_DIR/bin" "$CODEX_DIR/skills/codex-mem" "$CODEX_DIR/skills/mem-search"
  cp "$SCRIPT_DIR/codex-mem/codex-mem.py" "$CODEX_MEM_BIN"
  chmod +x "$CODEX_MEM_BIN"

  # Codex-native memory skills (override incompatible mem-search from upstream if present)
  cp "$SCRIPT_DIR/skills/codex-mem/SKILL.md" "$CODEX_DIR/skills/codex-mem/SKILL.md"
  cp "$SCRIPT_DIR/skills/mem-search/SKILL.md" "$CODEX_DIR/skills/mem-search/SKILL.md"

  "$CODEX_MEM_BIN" init >/dev/null 2>&1 || true
  "$CODEX_MEM_BIN" build-context \
    --output "$CODEX_DIR/MEMORY.md" \
    --lessons "$CODEX_DIR/lessons.md" >/dev/null 2>&1 || true
}

main() {
  install_core
  install_mcp
  install_skills
  install_codex_mem
  info "Done. Restart Codex to load new skills and config."
}

main "$@"
