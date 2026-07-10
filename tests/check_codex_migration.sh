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
assert_file_contains "AGENTS.md" 'invoke the `code-review` skill from `mattpocock/skills`'
assert_file_contains "AGENTS.md" 'do not invoke `adversarial-review`'
assert_file_not_contains "AGENTS.md" 'invoke the `adversarial-review` skill to perform it'
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
assert_file_contains "install.sh" "initialize_managed_skill_ownership"
assert_file_contains "install.sh" "add_managed_skill_ownership"
assert_file_contains "install.sh" "remove_managed_skill_ownership"
assert_file_contains "install.sh" "confirm_empty_skill_removal"
assert_file_contains "install.sh" "MATTPOCOCK_QUICKSTART_READY"
assert_file_contains "install.sh" "show_mattpocock_quickstart"
assert_file_contains "install.sh" "Matt Pocock skills quickstart (30-second setup)"
assert_file_contains "install.sh" "Type /skills (or press @)"
assert_file_contains "install.sh" "not individual root slash commands"
assert_file_contains "install.sh" "superpowers_ownership_is_recorded"
assert_file_contains "install.sh" "skills@latest remove"
assert_file_contains "install.sh" "--global --agent codex --yes"
assert_file_not_contains "install.sh" "SELECT_SKILL_CODING_FOUNDATIONS"
assert_file_contains "install.sh" "handoff|Conversation handoff skill|1|skill-handoff"
assert_file_not_contains "install.sh" '-e "$AGENTS_SKILLS_DIR/$skill"'
assert_file_contains "install.sh" "install-skill-from-github.py"
assert_file_contains "install.ps1" "skills@latest"
assert_file_contains "install.ps1" "--agent"
assert_file_contains "install.ps1" "codex"
assert_file_contains "install.ps1" "--full-depth"
assert_file_contains "install.ps1" "function Get-SelectedManagedSkills"
assert_file_contains "install.ps1" "function Remove-NpxSkillNames"
assert_file_contains "install.ps1" "function Remove-SuperpowersFallback"
assert_file_contains "install.ps1" "function Sync-InteractiveSkills"
assert_file_contains "install.ps1" "function Initialize-ManagedSkillOwnership"
assert_file_contains "install.ps1" "function Add-ManagedSkillOwnership"
assert_file_contains "install.ps1" "function Remove-ManagedSkillOwnership"
assert_file_contains "install.ps1" "function Confirm-EmptySkillRemoval"
assert_file_contains "install.ps1" "MattPocockQuickstartReady"
assert_file_contains "install.ps1" "function Show-MattPocockQuickstart"
assert_file_contains "install.ps1" "Matt Pocock skills quickstart (30-second setup)"
assert_file_contains "install.ps1" "Type /skills (or press @)"
assert_file_contains "install.ps1" "not individual root slash commands"
assert_file_contains "install.ps1" "function Test-SuperpowersOwnershipRecorded"
assert_file_contains "install.ps1" '"--global", "--agent", "codex", "--yes"'
assert_file_contains "install.ps1" 'Label = "handoff"; Description = "Conversation handoff skill"; Default = $true; StateVar = "SelectSkillHandoff"'
assert_file_not_contains "install.ps1" 'SelectSkillCodingFoundations'
assert_file_not_contains "install.ps1" 'Join-Path $AGENTS_SKILLS_DIR $skill'
assert_file_contains "install.ps1" "Resolve-PythonCommand"

assert_file_contains "install.sh" "affaan-m/everything-claude-code"
assert_file_contains "install.ps1" "affaan-m/everything-claude-code"
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

unreachable_legacy = {
    "python-patterns",
    "python-testing",
    "golang-patterns",
    "golang-testing",
    "frontend-patterns",
    "security-review",
    "tdd-workflow",
    "verification-loop",
    "api-design",
    "database-migrations",
}

bash = open(sys.argv[1], encoding="utf-8").read()
ps = open(sys.argv[2], encoding="utf-8").read()

legacy_source = "affaan-m/everything-claude-code"
if bash.count(legacy_source) != 1 or ps.count(legacy_source) != 1:
    raise SystemExit(
        "retired coding-foundations source must appear only as legacy ownership provenance"
    )

bash_match = re.search(r"MANAGED_SKILLS=\(\n(?P<body>.*?)\n\)", bash, re.S)
if not bash_match:
    raise SystemExit("could not locate Bash MANAGED_SKILLS")
bash_skills = set(bash_match.group("body").split())

ps_match = re.search(r"\$MANAGED_SKILLS = @\(\n(?P<body>.*?)\n\)", ps, re.S)
if not ps_match:
    raise SystemExit("could not locate PowerShell MANAGED_SKILLS")
ps_skills = set(re.findall(r'"([^"]+)"', ps_match.group("body")))

bash_legacy_match = re.search(
    r"LEGACY_CLEANUP_SKILLS=\(\n(?P<body>.*?)\n\)",
    bash,
    re.S,
)
ps_legacy_match = re.search(
    r"\$LEGACY_CLEANUP_SKILLS = @\(\n(?P<body>.*?)\n\)",
    ps,
    re.S,
)
if not bash_legacy_match or not ps_legacy_match:
    raise SystemExit("could not locate legacy cleanup catalogues")
bash_legacy_skills = set(bash_legacy_match.group("body").split())
ps_legacy_skills = set(re.findall(r'"([^"]+)"', ps_legacy_match.group("body")))
if bash_legacy_skills != unreachable_legacy or ps_legacy_skills != unreachable_legacy:
    raise SystemExit(
        "legacy cleanup catalogues must contain exactly the retired coding-foundations skills"
    )
if bash_skills & bash_legacy_skills or ps_skills & ps_legacy_skills:
    raise SystemExit("current managed and legacy cleanup catalogues must be disjoint")

for label, skills in (("install.sh", bash_skills), ("install.ps1", ps_skills)):
    leaked = sorted(removed & skills)
    if leaked:
        raise SystemExit(f"{label} MANAGED_SKILLS still contains removed claude-mem/claude-health skills: {', '.join(leaked)}")
    unreachable = sorted(unreachable_legacy & skills)
    if unreachable:
        raise SystemExit(
            f"{label} MANAGED_SKILLS contains names no current selection can own: "
            f"{', '.join(unreachable)}"
        )

if bash_skills != ps_skills:
    only_bash = sorted(bash_skills - ps_skills)
    only_ps = sorted(ps_skills - bash_skills)
    raise SystemExit(
        "managed skill catalogues differ: "
        f"Bash-only={only_bash}, PowerShell-only={only_ps}"
    )

for array_name in ("SUPERPOWERS_SKILLS", "MATTPOCOCK_SKILLS", "PUA_SKILLS"):
    bash_array = re.search(
        rf"(?m)^{array_name}=\((?P<body>.*?)\)",
        bash,
        re.S,
    )
    ps_array = re.search(
        rf"(?m)^\${array_name} = @\((?P<body>.*?)\)",
        ps,
        re.S,
    )
    if not bash_array or not ps_array:
        raise SystemExit(f"could not locate {array_name} in both installers")
    bash_values = bash_array.group("body").split()
    ps_values = re.findall(r'"([^"]+)"', ps_array.group("body"))
    if bash_values != ps_values:
        raise SystemExit(
            f"{array_name} differs between installers: "
            f"Bash={bash_values}, PowerShell={ps_values}"
        )
    missing = sorted(set(bash_values) - bash_skills)
    if missing:
        raise SystemExit(f"{array_name} contains unmanaged skills: {', '.join(missing)}")

if bash.count("reconcile_interactive_skills") != 2:
    raise SystemExit("Bash reconciliation should have exactly one definition and one interactive call")
if ps.count("Sync-InteractiveSkills") != 2:
    raise SystemExit("PowerShell reconciliation should have exactly one definition and one interactive call")

bash_reconcile = re.search(
    r"reconcile_interactive_skills\(\) \{(?P<body>.*?)\n\}",
    bash,
    re.S,
)
ps_reconcile = re.search(
    r"function Sync-InteractiveSkills \{(?P<body>.*?)\n\}",
    ps,
    re.S,
)
if not bash_reconcile or not ps_reconcile:
    raise SystemExit("could not locate both reconciliation function bodies")
if "AGENTS_SKILLS_DIR" in bash_reconcile.group("body"):
    raise SystemExit("Bash reconciliation must not scan shared ~/.agents/skills")
if "AGENTS_SKILLS_DIR" in ps_reconcile.group("body"):
    raise SystemExit("PowerShell reconciliation must not scan shared ~/.agents/skills")

bash_mapper = re.search(
    r"selected_managed_skill_names\(\) \{(?P<body>.*?)\n\}",
    bash,
    re.S,
)
if not bash_mapper:
    raise SystemExit("could not locate selected_managed_skill_names")
bash_menu_ids = set(re.findall(r"\|([a-z0-9-]+)(?:\n|\")", bash))
bash_selection_ids = {
    variable: item_id
    for item_id, variable in re.findall(
        r"^\s*([a-z0-9-]+)\)\s+(SELECT_(?:SKILL|AI)_[A-Z0-9_]+)=",
        bash,
        re.M,
    )
}
for variable in set(re.findall(r"\$(SELECT_(?:SKILL|AI)_[A-Z0-9_]+)", bash_mapper.group("body"))):
    item_id = bash_selection_ids.get(variable)
    if not item_id or item_id not in bash_menu_ids:
        raise SystemExit(f"Bash selection mapper variable is not reachable from the menu: {variable}")

ps_mapper = re.search(
    r"function Get-SelectedManagedSkills \{(?P<body>.*?)\n\}",
    ps,
    re.S,
)
if not ps_mapper:
    raise SystemExit("could not locate Get-SelectedManagedSkills")
ps_reachable_skills = set()
for literal_body in re.findall(
    r"Add-Names\s+\$script:\w+\s+@\(([^)]*)\)",
    ps_mapper.group("body"),
):
    ps_reachable_skills.update(re.findall(r'"([^"]+)"', literal_body))
for array_name in re.findall(
    r"Add-Names\s+\$script:\w+\s+\$(\w+_SKILLS)\s*$",
    ps_mapper.group("body"),
    re.M,
):
    array_match = re.search(
        rf"(?m)^\${array_name}\s*=\s*@\((?P<body>.*?)\)",
        ps,
        re.S,
    )
    if not array_match:
        raise SystemExit(f"could not locate PowerShell mapper array {array_name}")
    ps_reachable_skills.update(re.findall(r'"([^"]+)"', array_match.group("body")))
unreachable_ps_skills = sorted(ps_skills - ps_reachable_skills)
if unreachable_ps_skills:
    raise SystemExit(
        "PowerShell managed skills are unreachable from every selection: "
        + ", ".join(unreachable_ps_skills)
    )
ps_menu_vars = set(re.findall(r'StateVar\s*=\s*"(Select(?:Skill|Ai)\w+)"', ps))
for variable in set(re.findall(r"\$script:(Select(?:Skill|Ai)\w+)", ps_mapper.group("body"))):
    if variable not in ps_menu_vars:
        raise SystemExit(f"PowerShell selection mapper variable is not reachable from the menu: {variable}")

reset_match = re.search(
    r"function Reset-InteractiveSelections \{(?P<body>.*?)\n\}",
    ps,
    re.S,
)
if not reset_match:
    raise SystemExit("could not locate Reset-InteractiveSelections")
reset_defaults = {
    name: value == "true"
    for name, value in re.findall(
        r"\$script:(\w+)\s*=\s*\$(true|false)",
        reset_match.group("body"),
        re.I,
    )
}
menu_defaults = {
    name: value == "true"
    for value, name in re.findall(
        r"Default\s*=\s*\$(true|false);\s*StateVar\s*=\s*\"([^\"]+)\"",
        ps,
        re.I,
    )
}
for name, expected_default in menu_defaults.items():
    if name not in reset_defaults:
        raise SystemExit(f"Reset-InteractiveSelections does not reset {name}")
    if reset_defaults[name] != expected_default:
        raise SystemExit(
            f"PowerShell reset default differs from menu for {name}: "
            f"reset={reset_defaults[name]}, menu={expected_default}"
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

if data.get("model") != "gpt-5.5":
    raise SystemExit("existing model was overwritten during statusline reconciliation")
if data.get("model_reasoning_effort") != "xhigh":
    raise SystemExit("existing model_reasoning_effort was overwritten during statusline reconciliation")
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

expected_defaults = {
    "model": "gpt-5.6-sol",
    "model_reasoning_effort": "max",
    "approval_policy": "never",
    "sandbox_mode": "danger-full-access",
}
for key, expected in expected_defaults.items():
    if data.get(key) != expected:
        raise SystemExit(
            f"unexpected fresh config default for {key}: "
            f"expected {expected!r}, got {data.get(key)!r}"
        )
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
