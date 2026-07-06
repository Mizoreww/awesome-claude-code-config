#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq -- "$needle" "$ROOT/$file" || fail "$file should contain: $needle"
}

assert_file_not_contains() {
  local file="$1"
  local needle="$2"
  if grep -Fq -- "$needle" "$ROOT/$file"; then
    fail "$file should not contain: $needle"
  fi
}

assert_file_contains "config.toml" 'model_reasoning_effort = "xhigh"'
assert_file_contains "config.toml" 'approval_policy = "never"'
assert_file_contains "config.toml" 'sandbox_mode = "danger-full-access"'
assert_file_contains "config.toml" 'status_line = ["model-with-reasoning", "current-dir", "git-branch", "context-remaining"]'
assert_file_contains "install.sh" "SELECT_CORE_STATUSLINE"
assert_file_contains "install.sh" "core-statusline)"
assert_file_contains "install.ps1" "SelectCoreStatusLine"
assert_file_contains "install.sh" "skill-mattpocock)"
assert_file_contains "install.sh" "skill-frontend-slides)"
assert_file_contains "install.sh" "unsupported-feature-dev)"
assert_file_contains "install.sh" "feature-dev|Claude plugin workflow; no Codex target yet|0|unsupported-feature-dev"
assert_file_contains "install.ps1" 'Label = "feature-dev"; Description = "Claude plugin workflow; no Codex target yet"; Default = $false'

for label in \
  "Review" \
  "Workflow" \
  "Development Tools" \
  "Design & Content" \
  "Memory & Lifestyle" \
  "Academic Research" \
  "Slides" \
  "MCP Servers"; do
  assert_file_contains "install.sh" "GROUP_LABELS+=(\"$label\")"
  assert_file_contains "install.ps1" "Label = \"$label\""
done

for item in \
  "mattpocock/skills" \
  "implement" \
  "research" \
  "andrej-karpathy-skills" \
  "frontend-slides" \
  "claude-health" \
  "PUA" \
  "ppt-master"; do
  assert_file_contains "install.sh" "$item"
  assert_file_contains "install.ps1" "$item"
done

assert_file_contains "install.sh" "npx -y skills@latest add"
assert_file_contains "install.sh" "--agent codex"
assert_file_contains "install.sh" "--full-depth"
assert_file_contains "install.sh" "install-skill-from-github.py"
assert_file_contains "install.ps1" "skills@latest"
assert_file_contains "install.ps1" "--agent"
assert_file_contains "install.ps1" "codex"
assert_file_contains "install.ps1" "--full-depth"
assert_file_contains "install.ps1" "Resolve-PythonCommand"

assert_file_not_contains "install.sh" "affaan-m/everything-claude-code"
assert_file_not_contains "install.ps1" "affaan-m/everything-claude-code"

echo "Codex migration checks passed"
