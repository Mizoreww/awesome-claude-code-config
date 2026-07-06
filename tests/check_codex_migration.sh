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
assert_file_contains "config.toml" "[tui]"
assert_file_contains "config.toml" 'status_line = ["model", "reasoning", "project-name", "git-branch", "context-used", "context-window-size", "used-tokens"]'
assert_file_contains "config.toml" "status_line_use_colors = true"
assert_file_not_contains "config.toml" "model-with-reasoning"
assert_file_contains "install.sh" "SELECT_CORE_STATUSLINE"
assert_file_contains "install.sh" "core-statusline)"
assert_file_contains "install.ps1" "SelectCoreStatusLine"
assert_file_contains "install.sh" "skill-mattpocock)"
assert_file_contains "install.sh" "skill-frontend-slides)"
for removed in \
  "unsupported-feature-dev" \
  "unsupported-ralph-loop" \
  "unsupported-commit-commands" \
  "unsupported-code-simplifier" \
  "unsupported-codex-plugin" \
  "SELECT_UNSUPPORTED_FEATURE_DEV" \
  "SELECT_UNSUPPORTED_RALPH_LOOP" \
  "SELECT_UNSUPPORTED_COMMIT_COMMANDS" \
  "SELECT_UNSUPPORTED_CODE_SIMPLIFIER" \
  "SELECT_UNSUPPORTED_CODEX_PLUGIN" \
  "SelectUnsupportedFeatureDev" \
  "SelectUnsupportedRalphLoop" \
  "SelectUnsupportedCommitCommands" \
  "SelectUnsupportedCodeSimplifier" \
  "SelectUnsupportedCodexPlugin" \
  "Codex CLI bridge" \
  "feature-dev" \
  "ralph-loop" \
  "commit-commands" \
  "code-simplifier" \
  "coding-foundations"; do
  assert_file_not_contains "install.sh" "$removed"
  assert_file_not_contains "install.ps1" "$removed"
done

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
  "PUA"; do
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
assert_file_not_contains "README.md" "Claude-only plugin command workflows"
assert_file_not_contains "README.zh-CN.md" "Claude-only plugin command 工作流"

for removed in \
  "ppt-master" \
  "hugohe3/ppt-master" \
  "PptMaster" \
  "PPT_MASTER" \
  "SelectSkillPptMaster" \
  "SELECT_SKILL_PPT_MASTER" \
  "skill-ppt-master"; do
  assert_file_not_contains "install.sh" "$removed"
  assert_file_not_contains "install.ps1" "$removed"
  assert_file_not_contains "README.md" "$removed"
  assert_file_not_contains "README.zh-CN.md" "$removed"
done

tmp_home="$(mktemp -d)"
trap 'rm -rf "$tmp_home"' EXIT
mkdir -p "$tmp_home/.codex"
cat > "$tmp_home/.codex/config.toml" <<'TOML'
model = "gpt-5.5"
model_reasoning_effort = "xhigh"

[projects."/tmp/demo"]
trust_level = "trusted"
TOML

HOME="$tmp_home" bash "$ROOT/install.sh" --core >/dev/null

python3 - "$tmp_home/.codex/config.toml" <<'PY'
import sys
import tomllib

expected = [
    "model",
    "reasoning",
    "project-name",
    "git-branch",
    "context-used",
    "context-window-size",
    "used-tokens",
]

with open(sys.argv[1], "rb") as fh:
    data = tomllib.load(fh)

if data.get("status_line") is not None:
    raise SystemExit("status_line must not be written at the top level")
if data.get("tui", {}).get("status_line") != expected:
    raise SystemExit("[tui].status_line was not written with the expected fields")
if data.get("tui", {}).get("status_line_use_colors") is not True:
    raise SystemExit("[tui].status_line_use_colors must be true")
project = data.get("projects", {}).get("/tmp/demo", {})
if "status_line" in project:
    raise SystemExit("status_line leaked into the last [projects.*] table")
PY

echo "Codex migration checks passed"
