#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
export XDG_STATE_HOME="$TMP/xdg-state"
export NPX_LOG="$TMP/npx.log"
mkdir -p "$HOME" "$TMP/bin"
sed '$d' "$ROOT/install.sh" > "$TMP/install-lib.sh"

cat > "$TMP/bin/npx" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$NPX_LOG"
if [[ "${NPX_FAIL:-false}" == "true" ]]; then
  exit 1
fi
if [[ " $* " == *" add "* ]]; then
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "--skill" && $# -ge 2 ]]; then
      skill="$2"
      if [[ "$skill" != "${NPX_SKIP_SKILL:-}" ]]; then
        mkdir -p "$HOME/.agents/skills/$skill"
        printf '%s\n' '---' "name: $skill" '---' > "$HOME/.agents/skills/$skill/SKILL.md"
      fi
      shift 2
      continue
    fi
    shift
  done
fi

if [[ " $* " == *" remove "* ]]; then
  remove_all_agents=true
  previous=""
  for arg in "$@"; do
    if [[ "$previous" == "--agent" ]]; then
      # skills@1.5.16 documents '*' but currently rejects it as an invalid
      # agent. Omitting --agent is the supported all-agent removal path.
      [[ "$arg" == "*" ]] && exit 1
      remove_all_agents=false
      break
    fi
    previous="$arg"
  done
  removing=false
  for arg in "$@"; do
    if [[ "$arg" == "remove" ]]; then
      removing=true
      continue
    fi
    $removing || continue
    [[ "$arg" == --* ]] && break
    rm -rf "$HOME/.codex/skills/$arg"
    if $remove_all_agents; then
      rm -rf "$HOME/.agents/skills/$arg" "$HOME/.claude/skills/$arg" \
        "$HOME/.openclaw/skills/$arg"
    fi
  done
fi

if [[ -n "${NPX_REFRESH_LOCK_SKILL:-}" ]]; then
  node - "$NPX_REFRESH_LOCK_FILE" "$NPX_REFRESH_LOCK_SKILL" "$NPX_REFRESH_LOCK_SOURCE" <<'NODE'
const fs = require("fs");
const [lockPath, skill, source] = process.argv.slice(2);
const lock = JSON.parse(fs.readFileSync(lockPath, "utf8"));
lock.skills[skill].source = source;
lock.skills[skill].updatedAt = "refreshed-by-npx-test-double";
fs.writeFileSync(lockPath, JSON.stringify(lock));
NODE
fi
SH
chmod +x "$TMP/bin/npx"
export PATH="$TMP/bin:$PATH"

# shellcheck source=/dev/null
source "$TMP/install-lib.sh"
SCRIPT_DIR="$ROOT"
FORCE=true

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ "$GLOBAL_SKILL_LOCK_FILE" == "$XDG_STATE_HOME/skills/.skill-lock.json" ]] ||
  fail "global skill lock path did not honor XDG_STATE_HOME"

assert_exists() {
  [[ -e "$1" || -L "$1" ]] || fail "expected path to exist: $1"
}

assert_missing() {
  [[ ! -e "$1" && ! -L "$1" ]] || fail "expected path to be absent: $1"
}

clear_skill_selections() {
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
}

write_owned_skills() {
  mkdir -p "$(dirname "$MANAGED_SKILLS_STATE_FILE")"
  printf '%s\n' "$@" > "$MANAGED_SKILLS_STATE_FILE"
  MANAGED_SKILLS_OWNERSHIP_LOADED=false
  OWNED_MANAGED_SKILLS=()
}

reset_ownership_discovery() {
  rm -f "$MANAGED_SKILLS_STATE_FILE" "$GLOBAL_SKILL_LOCK_FILE"
  MANAGED_SKILLS_OWNERSHIP_LOADED=false
  OWNED_MANAGED_SKILLS=()
}

for managed_skill in "${OWNERSHIP_SKILLS[@]}"; do
  [[ -n "$(expected_source_for_skill "$managed_skill")" ]] || \
    fail "ownership skill has no source mapping: $managed_skill"
done

selection_vars=(
  SELECT_SKILL_CODE_REVIEW SELECT_SKILL_KARPATHY SELECT_SKILL_SUPERPOWERS
  SELECT_SKILL_MATTPOCOCK SELECT_SKILL_DOCUMENTS SELECT_SKILL_EXAMPLES
  SELECT_SKILL_FRONTEND_DESIGN SELECT_SKILL_PUA SELECT_SKILL_FRONTEND_SLIDES
  SELECT_SKILL_PPT_MASTER
  SELECT_SKILL_PAPER_READING SELECT_SKILL_HUMANIZER SELECT_SKILL_HUMANIZER_ZH
  SELECT_SKILL_HANDOFF SELECT_SKILL_ADVERSARIAL_REVIEW SELECT_SKILL_UPDATE
  SELECT_AI_TOKENIZATION SELECT_AI_FINE_TUNING SELECT_AI_POST_TRAINING
  SELECT_AI_DISTRIBUTED_TRAINING SELECT_AI_INFERENCE_SERVING
  SELECT_AI_OPTIMIZATION SELECT_AI_DEEPXIV SELECT_AI_RESEARCHSTUDIO
  SELECT_AI_RESEARCHSTUDIO_REEL
)
reachable_file="$TMP/reachable-managed-skills"
: > "$reachable_file"
for selection_var in "${selection_vars[@]}"; do
  clear_skill_selections
  printf -v "$selection_var" '%s' true
  selected_managed_skill_names >> "$reachable_file"
done
sort -u "$reachable_file" -o "$reachable_file"
for managed_skill in "${MANAGED_SKILLS[@]}"; do
  grep -Fxq "$managed_skill" "$reachable_file" || \
    fail "managed skill is unreachable from every selection: $managed_skill"
done

# The Matt Pocock selection follows the pinned v1.1 workflow vocabulary.
clear_skill_selections
SELECT_SKILL_MATTPOCOCK=true
mattpocock_selection="$(selected_managed_skill_names)"
for skill in to-spec to-tickets wayfinder; do
  grep -Fxq "$skill" <<< "$mattpocock_selection" || \
    fail "Matt Pocock selection is missing v1.1 skill: $skill"
done
for skill in to-prd to-issues decision-mapping review; do
  if grep -Fxq "$skill" <<< "$mattpocock_selection"; then
    fail "Matt Pocock selection still exposes retired skill: $skill"
  fi
done

clear_skill_selections
SELECT_SKILL_HUMANIZER=true
mkdir -p \
  "$CODEX_DIR/skills/humanizer" \
  "$CODEX_DIR/skills/humanizer-zh" \
  "$CODEX_DIR/skills/frontend-slides" \
  "$CODEX_DIR/skills/private-skill" \
  "$AGENTS_SKILLS_DIR/frontend-slides" \
  "$AGENTS_SKILLS_DIR/research"
printf '%s\n' managed > "$CODEX_DIR/skills/frontend-slides/SKILL.md"
printf '%s\n' managed > "$AGENTS_SKILLS_DIR/frontend-slides/SKILL.md"
write_owned_skills humanizer humanizer-zh frontend-slides
reconcile_interactive_skills
assert_exists "$CODEX_DIR/skills/humanizer"
assert_missing "$CODEX_DIR/skills/humanizer-zh"
assert_missing "$CODEX_DIR/skills/frontend-slides"
assert_exists "$CODEX_DIR/skills/private-skill"
assert_exists "$AGENTS_SKILLS_DIR/research"
grep -Eq -- '(skills@latest|-- skills) remove' "$NPX_LOG" || fail "npx removal was not invoked"
grep -Fq -- '--global --agent codex --yes' "$NPX_LOG" || fail "npx removal was not Codex-scoped"
grep -Fq -- 'frontend-slides' "$NPX_LOG" || fail "stale npx skill was not requested for removal"

# A catalogue name is not ownership: preserve a custom same-name skill unless
# this installer recorded or safely discovered its provenance.
mkdir -p "$CODEX_DIR/skills/research"
write_owned_skills humanizer
reconcile_interactive_skills
assert_exists "$CODEX_DIR/skills/research"

clear_skill_selections
SELECT_SKILL_MATTPOCOCK=true
SELECT_SKILL_HANDOFF=true
mkdir -p "$CODEX_DIR/skills/handoff"
write_owned_skills handoff
reconcile_interactive_skills
assert_exists "$CODEX_DIR/skills/handoff"

# First-run migration safely recognizes an unchanged bundled local skill.
clear_skill_selections
reset_ownership_discovery
rm -rf "$CODEX_DIR/skills/humanizer-zh"
cp -R "$ROOT/skills/humanizer-zh" "$CODEX_DIR/skills/humanizer-zh"
reconcile_interactive_skills
assert_missing "$CODEX_DIR/skills/humanizer-zh"

# A lock entry is imported only when its source matches the installer source.
reset_ownership_discovery
mkdir -p "$CODEX_DIR/skills/research" "$(dirname "$GLOBAL_SKILL_LOCK_FILE")"
printf '%s\n' '{"version":3,"skills":{"research":{"source":"user/custom-skills"}}}' > "$GLOBAL_SKILL_LOCK_FILE"
reconcile_interactive_skills
assert_exists "$CODEX_DIR/skills/research"

reset_ownership_discovery
mkdir -p "$CODEX_DIR/skills/frontend-slides" "$AGENTS_SKILLS_DIR/frontend-slides" \
  "$(dirname "$GLOBAL_SKILL_LOCK_FILE")"
printf '%s\n' custom > "$CODEX_DIR/skills/frontend-slides/SKILL.md"
printf '%s\n' upstream > "$AGENTS_SKILLS_DIR/frontend-slides/SKILL.md"
printf '%s\n' '{"version":3,"skills":{"frontend-slides":{"source":"zarazhangrui/frontend-slides"}}}' > "$GLOBAL_SKILL_LOCK_FILE"
reconcile_interactive_skills
assert_exists "$CODEX_DIR/skills/frontend-slides"
assert_exists "$AGENTS_SKILLS_DIR/frontend-slides"

reset_ownership_discovery
rm -rf "$CODEX_DIR/skills/frontend-slides"
cp -R "$AGENTS_SKILLS_DIR/frontend-slides" "$CODEX_DIR/skills/frontend-slides"
printf '%s\n' '{"version":3,"skills":{"frontend-slides":{"source":"zarazhangrui/frontend-slides"}}}' > "$GLOBAL_SKILL_LOCK_FILE"
reconcile_interactive_skills
assert_missing "$CODEX_DIR/skills/frontend-slides"
assert_exists "$AGENTS_SKILLS_DIR/frontend-slides"

# Retired coding-foundations names remain cleanup-only: they cannot be selected
# or installed, but a verified legacy copy is removed on the first upgrade.
reset_ownership_discovery
mkdir -p "$CODEX_DIR/skills/python-patterns" "$AGENTS_SKILLS_DIR/python-patterns" \
  "$(dirname "$GLOBAL_SKILL_LOCK_FILE")"
printf '%s\n' legacy > "$AGENTS_SKILLS_DIR/python-patterns/SKILL.md"
cp "$AGENTS_SKILLS_DIR/python-patterns/SKILL.md" "$CODEX_DIR/skills/python-patterns/SKILL.md"
printf '%s\n' '{"version":3,"skills":{"python-patterns":{"source":"affaan-m/everything-claude-code"}}}' > "$GLOBAL_SKILL_LOCK_FILE"
reconcile_interactive_skills
assert_missing "$CODEX_DIR/skills/python-patterns"
assert_exists "$AGENTS_SKILLS_DIR/python-patterns"

clear_skill_selections
mkdir -p "$SUPERPOWERS_DIR/skills" "$SUPERPOWERS_DIR/.git"
mkdir -p "$(dirname "$SUPERPOWERS_LINK")"
printf '%s\n' '[remote "origin"]' '  url = https://github.com/obra/superpowers.git' > "$SUPERPOWERS_DIR/.git/config"
ln -s "$SUPERPOWERS_DIR/skills" "$SUPERPOWERS_LINK"
write_owned_skills
reconcile_interactive_skills
assert_exists "$SUPERPOWERS_LINK"
assert_exists "$SUPERPOWERS_DIR"

mkdir -p "$CODEX_DIR/skills/pua" "$AGENTS_SKILLS_DIR/pua"
printf '%s\n' managed > "$CODEX_DIR/skills/pua/SKILL.md"
printf '%s\n' managed > "$AGENTS_SKILLS_DIR/pua/SKILL.md"
write_owned_skills pua brainstorming
reconcile_interactive_skills
assert_missing "$CODEX_DIR/skills/pua"
assert_missing "$SUPERPOWERS_LINK"
assert_missing "$SUPERPOWERS_DIR"

clear_skill_selections
mkdir -p "$CODEX_DIR/skills/pua"
write_owned_skills pua
DRY_RUN=true
dry_output="$(reconcile_interactive_skills)"
assert_exists "$CODEX_DIR/skills/pua"
[[ "$dry_output" == *"Would remove"* ]] || fail "dry-run did not report removal"
DRY_RUN=false

# A failing npx cleanup preserves both copies and ownership so a later run can
# retry without losing a same-name user directory.
mkdir -p "$CODEX_DIR/skills/pua" "$AGENTS_SKILLS_DIR/pua"
write_owned_skills pua
NPX_FAIL=true reconcile_interactive_skills
assert_exists "$CODEX_DIR/skills/pua"
assert_exists "$AGENTS_SKILLS_DIR/pua"
grep -Fxq pua "$MANAGED_SKILLS_STATE_FILE" || fail "failed removal lost retry ownership"

# Successful local and npx installs register ownership for later reconciliation.
reset_ownership_discovery
copy_local_skill true humanizer
grep -Fxq humanizer "$MANAGED_SKILLS_STATE_FILE" || fail "local install did not record ownership"
mkdir -p "$(dirname "$GLOBAL_SKILL_LOCK_FILE")"
printf '%s\n' '{"version":3,"skills":{"frontend-slides":{"source":"zarazhangrui/frontend-slides","skillFolderHash":"0123456789abcdef0123456789abcdef01234567"}}}' > "$GLOBAL_SKILL_LOCK_FILE"
export NPX_REFRESH_LOCK_SKILL=frontend-slides
export NPX_REFRESH_LOCK_SOURCE=zarazhangrui/frontend-slides
export NPX_REFRESH_LOCK_FILE="$GLOBAL_SKILL_LOCK_FILE"
install_npx_skill_names zarazhangrui/frontend-slides frontend-slides
unset NPX_REFRESH_LOCK_SKILL NPX_REFRESH_LOCK_SOURCE NPX_REFRESH_LOCK_FILE
grep -Fxq frontend-slides "$MANAGED_SKILLS_STATE_FILE" || fail "npx install did not record ownership"

# A zero exit from npx is insufficient when it silently skips a requested
# skill. The installer must verify every requested directory before recording
# ownership or reporting success.
reset_ownership_discovery
rm -rf "$AGENTS_SKILLS_DIR/to-spec" "$AGENTS_SKILLS_DIR/to-tickets"
if NPX_SKIP_SKILL=to-tickets install_npx_skill_names mattpocock/skills to-spec to-tickets; then
  fail "partial npx install was reported as successful"
fi
if [[ -f "$MANAGED_SKILLS_STATE_FILE" ]]; then
  grep -Fxq to-spec "$MANAGED_SKILLS_STATE_FILE" && \
    fail "partial npx install recorded ownership"
  grep -Fxq to-tickets "$MANAGED_SKILLS_STATE_FILE" && \
    fail "missing npx skill recorded ownership"
fi

# Empty skill selections require a second confirmation before bulk removal.
mkdir -p "$CODEX_DIR/skills/pua"
write_owned_skills pua
FORCE=false
confirm_empty_skill_removal() { return 1; }
reconcile_interactive_skills
assert_exists "$CODEX_DIR/skills/pua"
FORCE=true

noninteractive_home="$TMP/noninteractive-home"
mkdir -p "$noninteractive_home/.codex/skills/pua"
HOME="$noninteractive_home" bash "$ROOT/install.sh" --core >/dev/null
assert_exists "$noninteractive_home/.codex/skills/pua"

# The Matt Pocock quickstart is shown only after the full pack installs
# successfully. It must explain Codex's /skills picker rather than inventing
# one slash command per installed skill.
clear_skill_selections
SELECT_SKILL_MATTPOCOCK=true
MATTPOCOCK_QUICKSTART_READY=false
real_install_mattpocock_skill_names="$(declare -f install_mattpocock_skill_names)"
install_mattpocock_skill_names() { return 0; }
install_selected_recommended_skills >/dev/null
$MATTPOCOCK_QUICKSTART_READY || fail "successful Matt Pocock install did not enable the quickstart"
quickstart_output="$(show_mattpocock_quickstart)"
[[ "$quickstart_output" == *"Matt Pocock skills quickstart (30-second setup)"* ]] || fail "quickstart heading missing"
[[ "$quickstart_output" == *"/skills"* ]] || fail "quickstart should explain /skills"
[[ "$quickstart_output" == *"press @"* ]] || fail "quickstart should explain the @ shortcut"
[[ "$quickstart_output" == *"setup-matt-pocock-skills"* ]] || fail "quickstart should name the setup skill"
[[ "$quickstart_output" == *"not individual root slash commands"* ]] || fail "quickstart should explain root slash behavior"

MATTPOCOCK_QUICKSTART_READY=false
SKIPPED_COMPONENTS=()
install_mattpocock_skill_names() { return 1; }
install_selected_recommended_skills >/dev/null 2>&1
$MATTPOCOCK_QUICKSTART_READY && fail "failed Matt Pocock install enabled the quickstart"

MATTPOCOCK_QUICKSTART_READY=true
DRY_RUN=true
[[ -z "$(show_mattpocock_quickstart)" ]] || fail "dry-run displayed the installed quickstart"
DRY_RUN=false
eval "$real_install_mattpocock_skill_names"

# Retired Matt Pocock names are removed from the shared canonical directory
# only when ownership/provenance is known, and their ownership records are
# retired with them.
reset_ownership_discovery
mkdir -p "$AGENTS_SKILLS_DIR/to-prd" "$AGENTS_SKILLS_DIR/to-issues"
printf '%s\n' legacy > "$AGENTS_SKILLS_DIR/to-prd/SKILL.md"
printf '%s\n' legacy > "$AGENTS_SKILLS_DIR/to-issues/SKILL.md"
mkdir -p "$(dirname "$GLOBAL_SKILL_LOCK_FILE")"
printf '%s\n' '{"version":3,"skills":{"to-prd":{"source":"mattpocock/skills"},"to-issues":{"source":"mattpocock/skills"},"custom-skill":{"source":"user/custom-skills"}}}' > \
  "$GLOBAL_SKILL_LOCK_FILE"
write_owned_skills to-prd to-issues
: > "$NPX_LOG"
remove_legacy_mattpocock_skills || fail "legacy Matt Pocock cleanup failed"
assert_missing "$AGENTS_SKILLS_DIR/to-prd"
assert_missing "$AGENTS_SKILLS_DIR/to-issues"
if grep -Fq -- '--agent *' "$NPX_LOG"; then
  fail "legacy Matt Pocock cleanup used the CLI's invalid wildcard agent"
fi
legacy_remove_call="$(tail -n 1 "$NPX_LOG")"
[[ ( "$legacy_remove_call" == *"skills@latest remove "* ||
     "$legacy_remove_call" == *"-- skills remove "* ) &&
   "$legacy_remove_call" == *" --global --yes"* ]] || \
  fail "legacy Matt Pocock cleanup did not use default all-agent removal"
for retired_skill in to-prd to-issues; do
  [[ " $legacy_remove_call " == *" $retired_skill "* ]] || \
    fail "legacy Matt Pocock cleanup omitted $retired_skill"
done
if [[ -f "$MANAGED_SKILLS_STATE_FILE" ]]; then
  grep -Fxq to-prd "$MANAGED_SKILLS_STATE_FILE" && \
    fail "retired to-prd ownership survived migration"
  grep -Fxq to-issues "$MANAGED_SKILLS_STATE_FILE" && \
    fail "retired to-issues ownership survived migration"
fi
python3 - "$GLOBAL_SKILL_LOCK_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    skills = json.load(fh)["skills"]
if "to-prd" in skills or "to-issues" in skills:
    raise SystemExit("retired Matt Pocock lock entries survived migration")
if skills.get("custom-skill", {}).get("source") != "user/custom-skills":
    raise SystemExit("unrelated skill lock entry changed during legacy cleanup")
PY

reset_ownership_discovery
mkdir -p "$AGENTS_SKILLS_DIR/review" "$(dirname "$GLOBAL_SKILL_LOCK_FILE")"
printf '%s\n' custom > "$AGENTS_SKILLS_DIR/review/SKILL.md"
printf '%s\n' '{"version":3,"skills":{"review":{"source":"user/custom-skills"}}}' > \
  "$GLOBAL_SKILL_LOCK_FILE"
remove_legacy_mattpocock_skills || fail "custom-name provenance check failed"
assert_exists "$AGENTS_SKILLS_DIR/review"

# Matt Pocock installs use an immutable source snapshot. The skills CLI
# currently ignores remote tag/commit suffixes, so the installer downloads the
# pinned archive first and then installs from that local directory.
pinned_fixture="$TMP/pinned-mattpocock/skills-test"
mkdir -p "$pinned_fixture/skills/engineering/ask-matt" \
  "$pinned_fixture/skills/engineering/to-spec"
printf '%s\n' '---' 'name: ask-matt' '---' > \
  "$pinned_fixture/skills/engineering/ask-matt/SKILL.md"
printf '%s\n' '---' 'name: to-spec' '---' > \
  "$pinned_fixture/skills/engineering/to-spec/SKILL.md"
fixture_archive="$TMP/pinned-mattpocock.tar.gz"
tar -czf "$fixture_archive" -C "$TMP/pinned-mattpocock" skills-test
download_log="$TMP/mattpocock-download.log"
download_archive() {
  printf '%s\n' "$1" > "$download_log"
  cp "$fixture_archive" "$2"
}

reset_ownership_discovery
mkdir -p "$AGENTS_SKILLS_DIR/to-spec"
printf '%s\n' stale > "$AGENTS_SKILLS_DIR/to-spec/SKILL.md"
write_owned_skills ask-matt to-spec
if NPX_SKIP_SKILL=to-spec TMPDIR="$TMP" \
  install_mattpocock_skill_names ask-matt to-spec; then
  fail "stale Matt Pocock content was accepted as the pinned snapshot"
fi
if [[ -f "$MANAGED_SKILLS_STATE_FILE" ]]; then
  grep -Fxq ask-matt "$MANAGED_SKILLS_STATE_FILE" && \
    fail "failed pinned upgrade retained ask-matt ownership"
  grep -Fxq to-spec "$MANAGED_SKILLS_STATE_FILE" && \
    fail "failed pinned upgrade retained to-spec ownership"
fi
rm -rf "$AGENTS_SKILLS_DIR/ask-matt" "$AGENTS_SKILLS_DIR/to-spec"
mkdir -p "$(dirname "$GLOBAL_SKILL_LOCK_FILE")"
printf '%s\n' '{"version":3,"skills":{"ask-matt":{"source":"mattpocock/skills"},"to-spec":{"source":"mattpocock/skills"},"custom-skill":{"source":"user/custom-skills"}}}' > \
  "$GLOBAL_SKILL_LOCK_FILE"
: > "$NPX_LOG"
TMPDIR="$TMP" install_mattpocock_skill_names ask-matt to-spec || \
  fail "pinned Matt Pocock snapshot install failed"
grep -Fq "$MATTPOCOCK_COMMIT" "$download_log" || \
  fail "Matt Pocock archive URL was not pinned to the release commit"
grep -Fq "$TMP/mattpocock-skills." "$NPX_LOG" || \
  fail "Matt Pocock skills were not installed from the local pinned snapshot"
if grep -Fq 'add mattpocock/skills ' "$NPX_LOG"; then
  fail "Matt Pocock install still passed the mutable remote source to npx"
fi
python3 - "$GLOBAL_SKILL_LOCK_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    skills = json.load(fh)["skills"]
if "ask-matt" in skills or "to-spec" in skills:
    raise SystemExit("remote Matt Pocock lock entries survived pinned installation")
if skills.get("custom-skill", {}).get("source") != "user/custom-skills":
    raise SystemExit("unrelated skill lock entry changed during pinned installation")
PY

printf '%s\n' "Codex skill reconciliation checks passed"
