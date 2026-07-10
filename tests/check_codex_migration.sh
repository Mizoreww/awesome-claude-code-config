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

assert_file_contains "config.toml" 'model = "gpt-5.6-sol"'
assert_file_contains "config.toml" 'model_reasoning_effort = "max"'
assert_file_contains "config.toml" 'approval_policy = "never"'
assert_file_contains "config.toml" 'sandbox_mode = "danger-full-access"'
assert_file_contains "config.toml" "[tui]"
assert_file_contains "config.toml" 'status_line = ["model", "reasoning", "project-name", "git-branch", "context-used", "five-hour-limit", "weekly-limit"]'
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
  "Lifestyle" \
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
  "PUA"; do
  assert_file_contains "install.sh" "$item"
  assert_file_contains "install.ps1" "$item"
done

assert_file_contains "install.sh" "github|GitHub workflows (MCP; needs a real PAT)|1|mcp-github"
assert_file_contains "install.ps1" 'Label = "github"; Description = "GitHub workflows (MCP; needs a real PAT)"; Default = $true'
assert_file_contains "install.sh" "GITHUB_PERSONAL_ACCESS_TOKEN is not set; skipping GitHub MCP server"
assert_file_contains "install.ps1" "GITHUB_PERSONAL_ACCESS_TOKEN is not set; skipping GitHub MCP server"
assert_file_not_contains "install.sh" "GITHUB_PERSONAL_ACCESS_TOKEN=YOUR_GITHUB_PAT"
assert_file_not_contains "install.ps1" "GITHUB_PERSONAL_ACCESS_TOKEN=YOUR_GITHUB_PAT"

assert_file_contains "install.sh" "npx -y skills@latest add"
assert_file_contains "install.sh" "--agent codex"
assert_file_contains "install.sh" "--full-depth"
assert_file_contains "install.sh" "selected_managed_skill_names"
assert_file_contains "install.sh" "reconcile_interactive_skills"
assert_file_contains "install.sh" "skills@latest remove"
assert_file_contains "install.sh" "--global --agent codex --yes"
assert_file_not_contains "install.sh" "SELECT_SKILL_CODING_FOUNDATIONS"
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

for removed in \
  "claude-mem" \
  "claude-health" \
  "CLAUDE_MEM" \
  "CLAUDE_HEALTH" \
  "SelectSkillClaudeMem" \
  "SelectSkillClaudeHealth" \
  "SELECT_SKILL_CLAUDE_MEM" \
  "SELECT_SKILL_CLAUDE_HEALTH" \
  "skill-claude-mem" \
  "skill-claude-health"; do
  assert_file_not_contains "install.sh" "$removed"
  assert_file_not_contains "install.ps1" "$removed"
  assert_file_not_contains "README.md" "$removed"
  assert_file_not_contains "README.zh-CN.md" "$removed"
done

python3 - "$ROOT/install.sh" "$ROOT/install.ps1" <<'PY'
import re
import sys

removed = {
    "babysit",
    "design-is",
    "do",
    "how-it-works",
    "knowledge-agent",
    "learn-codebase",
    "make-plan",
    "mem-search",
    "oh-my-issues",
    "pathfinder",
    "smart-explore",
    "standup",
    "timeline-report",
    "claude-code-plugin-release",
    "weekly-digests",
    "what-the",
    "wowerpoint",
    "health",
    "check",
    "hunt",
    "learn",
    "read",
    "think",
    "ui",
    "write",
}

bash = open(sys.argv[1], encoding="utf-8").read()
ps = open(sys.argv[2], encoding="utf-8").read()

bash_match = re.search(r"MANAGED_SKILLS=\(\n(?P<body>.*?)\n\)", bash, re.S)
if not bash_match:
    raise SystemExit("could not locate Bash MANAGED_SKILLS")
bash_skills = set(bash_match.group("body").split())

ps_match = re.search(r"\$MANAGED_SKILLS = @\(\n(?P<body>.*?)\n\)", ps, re.S)
if not ps_match:
    raise SystemExit("could not locate PowerShell MANAGED_SKILLS")
ps_skills = set(re.findall(r'"([^"]+)"', ps_match.group("body")))

for label, skills in (("install.sh", bash_skills), ("install.ps1", ps_skills)):
    leaked = sorted(removed & skills)
    if leaked:
        raise SystemExit(f"{label} MANAGED_SKILLS still contains removed claude-mem/claude-health skills: {', '.join(leaked)}")

if bash_skills != ps_skills:
    only_bash = sorted(bash_skills - ps_skills)
    only_ps = sorted(ps_skills - bash_skills)
    raise SystemExit(
        "managed skill catalogues differ: "
        f"Bash-only={only_bash}, PowerShell-only={only_ps}"
    )

bash_ordered = bash_match.group("body").split()
ps_ordered = re.findall(r'"([^"]+)"', ps_match.group("body"))
for label, ordered in (("install.sh", bash_ordered), ("install.ps1", ps_ordered)):
    duplicates = sorted({skill for skill in ordered if ordered.count(skill) > 1})
    if duplicates:
        raise SystemExit(f"{label} MANAGED_SKILLS contains duplicates: {', '.join(duplicates)}")
PY

assert_file_not_contains "install.sh" "AI research skill packs (skill-installer not found)"
assert_file_contains "install.sh" "Would reinstall via npx skills"
assert_file_contains "install.ps1" "Would reinstall via npx skills"
assert_file_not_contains "install.sh" "Would reinstall via Python skill-installer"
assert_file_not_contains "install.ps1" "Would reinstall via Python skill-installer"

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
    "five-hour-limit",
    "weekly-limit",
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

statusline_home="$(mktemp -d)"
mkdir -p "$statusline_home/.codex"
HOME="$statusline_home" bash "$ROOT/install.sh" --core >/dev/null
python3 - "$statusline_home/.codex/config.toml" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as fh:
    data = tomllib.load(fh)

for required in ("model", "model_reasoning_effort", "approval_policy", "sandbox_mode"):
    if required not in data:
        raise SystemExit(f"missing required template field after statusline ensure: {required}")
PY

multiline_home="$(mktemp -d)"
mkdir -p "$multiline_home/.codex"
cat > "$multiline_home/.codex/config.toml" <<'TOML'
model = "gpt-5.5"

[tui]
status_line = [
  "model",
  "git-branch",
]
status_line_use_colors = false

[projects."/tmp/demo"]
trust_level = "trusted"
TOML

HOME="$multiline_home" bash "$ROOT/install.sh" --core >/dev/null
python3 - "$multiline_home/.codex/config.toml" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as fh:
    data = tomllib.load(fh)

expected = [
    "model",
    "reasoning",
    "project-name",
    "git-branch",
    "context-used",
    "five-hour-limit",
    "weekly-limit",
]

if data.get("tui", {}).get("status_line") != expected:
    raise SystemExit("multi-line [tui].status_line was not replaced cleanly")
PY

echo "Codex migration checks passed"
