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
SH
chmod +x "$TMP/bin/npx"
export PATH="$TMP/bin:$PATH"

# shellcheck source=/dev/null
source "$TMP/install-lib.sh"
SCRIPT_DIR="$ROOT"

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

clear_skill_selections
SELECT_SKILL_HUMANIZER=true
mkdir -p \
  "$CODEX_DIR/skills/humanizer" \
  "$CODEX_DIR/skills/humanizer-zh" \
  "$CODEX_DIR/skills/private-skill" \
  "$AGENTS_SKILLS_DIR/frontend-slides"
reconcile_interactive_skills
assert_exists "$CODEX_DIR/skills/humanizer"
assert_missing "$CODEX_DIR/skills/humanizer-zh"
assert_exists "$CODEX_DIR/skills/private-skill"
grep -Fq -- 'skills@latest remove' "$NPX_LOG" || fail "npx removal was not invoked"
grep -Fq -- '--global --agent codex --yes' "$NPX_LOG" || fail "npx removal was not Codex-scoped"
grep -Fq -- 'frontend-slides' "$NPX_LOG" || fail "stale npx skill was not requested for removal"

clear_skill_selections
SELECT_SKILL_MATTPOCOCK=true
SELECT_SKILL_HANDOFF=true
mkdir -p "$CODEX_DIR/skills/handoff"
reconcile_interactive_skills
assert_exists "$CODEX_DIR/skills/handoff"

clear_skill_selections
mkdir -p "$CODEX_DIR/skills/pua" "$SUPERPOWERS_DIR/skills"
mkdir -p "$(dirname "$SUPERPOWERS_LINK")"
ln -s "$SUPERPOWERS_DIR/skills" "$SUPERPOWERS_LINK"
reconcile_interactive_skills
assert_missing "$CODEX_DIR/skills/pua"
assert_missing "$SUPERPOWERS_LINK"
assert_missing "$SUPERPOWERS_DIR"

clear_skill_selections
mkdir -p "$CODEX_DIR/skills/pua"
DRY_RUN=true
dry_output="$(reconcile_interactive_skills)"
assert_exists "$CODEX_DIR/skills/pua"
[[ "$dry_output" == *"Would remove unselected managed skill"* ]] || fail "dry-run did not report removal"

noninteractive_home="$TMP/noninteractive-home"
mkdir -p "$noninteractive_home/.codex/skills/pua"
HOME="$noninteractive_home" bash "$ROOT/install.sh" --core >/dev/null
assert_exists "$noninteractive_home/.codex/skills/pua"

printf '%s\n' "Codex skill reconciliation checks passed"
