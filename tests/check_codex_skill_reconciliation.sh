#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
export NPX_LOG="$TMP/npx.log"
mkdir -p "$HOME" "$TMP/bin"
sed '$d' "$ROOT/install.sh" > "$TMP/install-lib.sh"

cat > "$TMP/bin/npx" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$NPX_LOG"
if [[ "${NPX_FAIL:-false}" == "true" ]]; then
  exit 1
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
}

write_owned_skills() {
  mkdir -p "$(dirname "$MANAGED_SKILLS_STATE_FILE")"
  printf '%s\n' "$@" > "$MANAGED_SKILLS_STATE_FILE"
  MANAGED_SKILLS_OWNERSHIP_LOADED=false
  OWNED_MANAGED_SKILLS=()
}

reset_ownership_discovery() {
  rm -f "$MANAGED_SKILLS_STATE_FILE" "$HOME/.agents/.skill-lock.json"
  MANAGED_SKILLS_OWNERSHIP_LOADED=false
  OWNED_MANAGED_SKILLS=()
}

for managed_skill in "${MANAGED_SKILLS[@]}"; do
  [[ -n "$(expected_source_for_skill "$managed_skill")" ]] || \
    fail "managed skill has no ownership source mapping: $managed_skill"
done

clear_skill_selections
SELECT_SKILL_HUMANIZER=true
mkdir -p \
  "$CODEX_DIR/skills/humanizer" \
  "$CODEX_DIR/skills/humanizer-zh" \
  "$CODEX_DIR/skills/frontend-slides" \
  "$CODEX_DIR/skills/private-skill" \
  "$AGENTS_SKILLS_DIR/research"
write_owned_skills humanizer humanizer-zh frontend-slides
reconcile_interactive_skills
assert_exists "$CODEX_DIR/skills/humanizer"
assert_missing "$CODEX_DIR/skills/humanizer-zh"
assert_missing "$CODEX_DIR/skills/frontend-slides"
assert_exists "$CODEX_DIR/skills/private-skill"
assert_exists "$AGENTS_SKILLS_DIR/research"
grep -Fq -- 'skills@latest remove' "$NPX_LOG" || fail "npx removal was not invoked"
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
mkdir -p "$CODEX_DIR/skills/research" "$HOME/.agents"
printf '%s\n' '{"version":3,"skills":{"research":{"source":"user/custom-skills"}}}' > "$HOME/.agents/.skill-lock.json"
reconcile_interactive_skills
assert_exists "$CODEX_DIR/skills/research"

reset_ownership_discovery
mkdir -p "$CODEX_DIR/skills/frontend-slides" "$HOME/.agents"
printf '%s\n' '{"version":3,"skills":{"frontend-slides":{"source":"zarazhangrui/frontend-slides"}}}' > "$HOME/.agents/.skill-lock.json"
reconcile_interactive_skills
assert_missing "$CODEX_DIR/skills/frontend-slides"

clear_skill_selections
mkdir -p "$SUPERPOWERS_DIR/skills" "$SUPERPOWERS_DIR/.git"
mkdir -p "$(dirname "$SUPERPOWERS_LINK")"
printf '%s\n' '[remote "origin"]' '  url = https://github.com/obra/superpowers.git' > "$SUPERPOWERS_DIR/.git/config"
ln -s "$SUPERPOWERS_DIR/skills" "$SUPERPOWERS_LINK"
write_owned_skills
reconcile_interactive_skills
assert_exists "$SUPERPOWERS_LINK"
assert_exists "$SUPERPOWERS_DIR"

mkdir -p "$CODEX_DIR/skills/pua"
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
[[ "$dry_output" == *"Would remove unselected managed skill"* ]] || fail "dry-run did not report removal"
DRY_RUN=false

# A failing npx cleanup still removes only the recorded Codex-local skill and
# clears its ownership; it must not touch shared ~/.agents skills.
mkdir -p "$CODEX_DIR/skills/pua" "$AGENTS_SKILLS_DIR/pua"
write_owned_skills pua
NPX_FAIL=true reconcile_interactive_skills
assert_missing "$CODEX_DIR/skills/pua"
assert_exists "$AGENTS_SKILLS_DIR/pua"
if grep -Fxq pua "$MANAGED_SKILLS_STATE_FILE"; then
  fail "removed skill remained in installer ownership state"
fi

# Successful local and npx installs register ownership for later reconciliation.
reset_ownership_discovery
copy_local_skill true humanizer
grep -Fxq humanizer "$MANAGED_SKILLS_STATE_FILE" || fail "local install did not record ownership"
install_npx_skill_names zarazhangrui/frontend-slides frontend-slides
grep -Fxq frontend-slides "$MANAGED_SKILLS_STATE_FILE" || fail "npx install did not record ownership"

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

printf '%s\n' "Codex skill reconciliation checks passed"
