#!/usr/bin/env bash
# Re-exec under bash if invoked via `sh install-cursor.sh` (we use bash arrays/[[).
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi
set -euo pipefail

# ============================================================
# Awesome Claude Code Config — Cursor Installer
# https://github.com/Mizoreww/awesome-claude-code-config (branch: cursor)
#
# Installs this repo's Cursor configuration into ~/.cursor (override with
# CURSOR_HOME or --prefix). Non-destructive: backs up config files before
# overwriting, merges JSON instead of clobbering, and never touches an
# existing lessons.md.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"

# --- Defaults / flags ---------------------------------------------------
CURSOR_HOME="${CURSOR_HOME:-$HOME/.cursor}"
DRY_RUN=false
HAVE_JQ=false
REMOTE_MODE=false
UNINSTALL=false
FORCE=false
PURGE_LESSONS=false
JQ_BOOTSTRAPPED=false
MANIFEST_BODY=""
TS="$(date +%Y%m%d%H%M%S)"

# Repo coordinates — used only in remote mode (`bash <(curl … install-cursor.sh)`).
# Validated against a safe charset because they are interpolated into a download
# URL evaluated by `bash -c`.
REPO_OWNER="${REPO_OWNER:-Mizoreww}"
REPO_NAME="${REPO_NAME:-awesome-claude-code-config}"
REPO_BRANCH="${REPO_BRANCH:-cursor}"
case "$REPO_OWNER"  in *[!A-Za-z0-9._-]*)  echo "Invalid REPO_OWNER: $REPO_OWNER" >&2; exit 1 ;; esac
case "$REPO_NAME"   in *[!A-Za-z0-9._-]*)  echo "Invalid REPO_NAME: $REPO_NAME" >&2; exit 1 ;; esac
case "$REPO_BRANCH" in *[!A-Za-z0-9._/-]*) echo "Invalid REPO_BRANCH: $REPO_BRANCH" >&2; exit 1 ;; esac
REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}"

# Colors (disabled when stdout is not a tty)
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; NC=''
fi
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error(){ echo -e "${RED}[ERROR]${NC} $*" >&2; }
rel()  { echo "${1#"$SCRIPT_DIR"/}"; }

# retry <max> <delay_seconds> <description> <command...>
retry() {
    local max="$1" delay="$2" desc="$3"; shift 3
    local attempt=1
    while [ "$attempt" -le "$max" ]; do
        if "$@"; then return 0; fi
        if [ "$attempt" -lt "$max" ]; then
            warn "$desc failed (attempt $attempt/$max), retrying in ${delay}s..."
            sleep "$delay"
        fi
        attempt=$((attempt + 1))
    done
    return 1
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install this repo's Cursor configuration into ~/.cursor.

Options:
  --prefix <dir>    Install into <dir> instead of ~/.cursor (for testing)
  --dry-run         Print what would happen; change nothing
  --uninstall       Remove this config and restore the pre-install state
  --purge-lessons   With --uninstall: also delete a lessons.md seeded by the
                    installer (default: keep your corrections)
  --force           Skip the uninstall confirmation prompt
  -h, --help        Show this help

Environment:
  CURSOR_HOME       Target dir (default: ~/.cursor; --prefix overrides this)

Installs: AGENTS.md, .cursor/rules -> rules/, skills/, mcp.json (merged),
hooks.json + hooks/, statusline.sh, cli-config.json (statusLine merged),
and lessons.md (only if absent). A manifest + a snapshot of any pre-existing
files are recorded so --uninstall can restore the previous state.
EOF
}

# --- Argument parsing ---------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --prefix)   [[ $# -ge 2 ]] || { error "--prefix needs a directory"; exit 1; }; CURSOR_HOME="$2"; shift 2 ;;
        --prefix=*) CURSOR_HOME="${1#*=}"; shift ;;
        --dry-run)  DRY_RUN=true; shift ;;
        --uninstall) UNINSTALL=true; shift ;;
        --purge-lessons) PURGE_LESSONS=true; shift ;;
        --force)    FORCE=true; shift ;;
        -h|--help)  usage; exit 0 ;;
        *) error "Unknown option: $1"; usage; exit 1 ;;
    esac
done
# Expand a leading ~/ that the shell did not (e.g. --prefix=~/foo)
case "$CURSOR_HOME" in "~/"*) CURSOR_HOME="$HOME/${CURSOR_HOME#"~/"}" ;; esac

# Derived state paths (depend on the final CURSOR_HOME).
SNAPSHOT_DIR="$CURSOR_HOME/.awesome-claude-code-config.backup"
MANIFEST_FILE="$CURSOR_HOME/.awesome-claude-code-config.manifest"
VERSION_STAMP_FILE="$CURSOR_HOME/.awesome-claude-code-config-version"

# The set of single files the installer overwrites/merges. These are snapshotted
# (if they pre-exist) so --uninstall can restore the exact previous content.
# One relpath per line; statusline.sh + the two hook scripts included.
managed_files() {
    printf '%s\n' \
        "AGENTS.md" \
        "mcp.json" \
        "hooks.json" \
        "cli-config.json" \
        "statusline.sh" \
        "hooks/load-lessons.sh" \
        "hooks/statusline.sh"
}

# Map an installed managed file back to its source path in the repo (for the
# degraded-mode byte-compare when no snapshot exists).
source_path_for() {
    case "$1" in
        statusline.sh)          echo "$SCRIPT_DIR/hooks/statusline.sh" ;;
        hooks/load-lessons.sh)  echo "$SCRIPT_DIR/hooks/load-lessons.sh" ;;
        hooks/statusline.sh)    echo "$SCRIPT_DIR/hooks/statusline.sh" ;;
        *)                      echo "$SCRIPT_DIR/$1" ;;
    esac
}

source_version() {
    [ -f "$SCRIPT_DIR/VERSION" ] && tr -d '[:space:]' < "$SCRIPT_DIR/VERSION" || echo "unknown"
}

mf_add() { MANIFEST_BODY="${MANIFEST_BODY}$1
"; }

# --- Safe filesystem helpers (all honor --dry-run) ----------------------
ensure_dir() {
    if $DRY_RUN; then [ -d "$1" ] || info "would create dir: $1"; return 0; fi
    mkdir -p "$1"
}

backup_if_exists() {
    local target="$1"
    [ -e "$target" ] || return 0
    local backup="${target}.bak.${TS}"
    if $DRY_RUN; then warn "would back up: $target -> $(basename "$backup")"; return 0; fi
    cp -p "$target" "$backup"
    warn "backed up: $(basename "$target") -> $(basename "$backup")"
}

# copy_file SRC DST — backs up DST if present, then copies (preserving mode).
copy_file() {
    local src="$1" dst="$2"
    [ -e "$src" ] || { warn "source missing, skipping: $(rel "$src")"; return 0; }
    backup_if_exists "$dst"
    if $DRY_RUN; then info "would copy: $(rel "$src") -> $dst"; return 0; fi
    ensure_dir "$(dirname "$dst")"
    cp -p "$src" "$dst"
    ok "installed: $dst"
}

# merge_json SRC DST FILTER LABEL — jq-slurp merge ([0]=incoming, [1]=existing).
# If DST is absent: plain copy. If jq is unavailable: keep DST untouched + warn.
merge_json() {
    local src="$1" dst="$2" filter="$3" label="$4"
    [ -e "$src" ] || { warn "source missing, skipping: $(rel "$src")"; return 0; }
    if [ ! -e "$dst" ]; then copy_file "$src" "$dst"; return 0; fi
    if ! $HAVE_JQ; then
        warn "jq unavailable — cannot merge $label; kept existing $dst unchanged."
        warn "  Merge manually from: $(rel "$src")"
        return 0
    fi
    backup_if_exists "$dst"
    if $DRY_RUN; then info "would merge $label (jq): $(rel "$src") -> $dst"; return 0; fi
    local tmp; tmp="$(mktemp)"
    if jq -s "$filter" "$src" "$dst" >"$tmp" 2>/dev/null && jq empty "$tmp" >/dev/null 2>&1; then
        mv "$tmp" "$dst"
        ok "merged $label -> $dst"
    else
        rm -f "$tmp"
        error "$label merge produced invalid JSON — kept existing file (backup retained)"
    fi
}

# --- jq bootstrap -------------------------------------------------------
# Cursor's statusline also looks for ~/.cursor/bin/jq, so installing it there
# benefits both the merges below and the status line at runtime.
ensure_jq() {
    if command -v jq >/dev/null 2>&1; then HAVE_JQ=true; return 0; fi
    if [ -x "$CURSOR_HOME/bin/jq" ]; then
        export PATH="$CURSOR_HOME/bin:$PATH"; HAVE_JQ=true
        # Remember it was ours so --uninstall can clean it up on re-runs too.
        [ -e "$SNAPSHOT_DIR/.jq-bootstrapped" ] && JQ_BOOTSTRAPPED=true
        return 0
    fi
    if $DRY_RUN; then warn "jq not found — would attempt to install into $CURSOR_HOME/bin"; return 0; fi

    info "jq not found — attempting to download a static binary..."
    local os arch url
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"; case "$os" in darwin) os=macos ;; linux) os=linux ;; esac
    arch="$(uname -m)"; case "$arch" in x86_64|amd64) arch=amd64 ;; aarch64|arm64) arch=arm64 ;; esac
    url="https://github.com/jqlang/jq/releases/latest/download/jq-${os}-${arch}"
    mkdir -p "$CURSOR_HOME/bin"
    if { command -v curl >/dev/null 2>&1 && curl -fsSL --connect-timeout 10 --max-time 60 "$url" -o "$CURSOR_HOME/bin/jq"; } \
       || { command -v wget >/dev/null 2>&1 && wget -q --timeout=60 --tries=1 -O "$CURSOR_HOME/bin/jq" "$url"; }; then
        chmod +x "$CURSOR_HOME/bin/jq"
        export PATH="$CURSOR_HOME/bin:$PATH"
        if jq --version >/dev/null 2>&1; then
            ok "jq installed -> $CURSOR_HOME/bin/jq"; HAVE_JQ=true; JQ_BOOTSTRAPPED=true
            [ -d "$SNAPSHOT_DIR" ] && : > "$SNAPSHOT_DIR/.jq-bootstrapped"
            return 0
        fi
    fi

    rm -f "$CURSOR_HOME/bin/jq" 2>/dev/null || true
    warn "Could not install jq automatically."
    warn "  JSON merges (mcp.json, cli-config.json) are skipped when a target already exists."
    warn "  Install it manually — 'brew install jq' (macOS) / 'sudo apt install jq' (Debian) — and re-run."
}

# --- Remote-mode source resolution -------------------------------------
# Run from a local clone: AGENTS.md sits next to this script. Run via
# `bash <(curl … install-cursor.sh)`: it does not, so download the branch
# tarball into a temp dir and install from there.
detect_script_dir() {
    if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/AGENTS.md" ]; then
        REMOTE_MODE=false
        return 0
    fi
    REMOTE_MODE=true
    # Not 'local': the EXIT trap below runs after this function returns and must
    # still see $tmpdir (under set -u a local would be unbound at exit time).
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT
    local url="$REPO_URL/archive/refs/heads/${REPO_BRANCH}.tar.gz"
    case "$REPO_BRANCH" in v[0-9]*) url="$REPO_URL/archive/refs/tags/${REPO_BRANCH}.tar.gz" ;; esac
    info "Remote mode: downloading ${REPO_OWNER}/${REPO_NAME}@${REPO_BRANCH}..."
    local dl
    if command -v curl >/dev/null 2>&1; then dl="curl -fsSL '$url'"
    elif command -v wget >/dev/null 2>&1; then dl="wget -qO- '$url'"
    else error "Neither curl nor wget found; cannot download in remote mode."; exit 1
    fi
    if ! retry 5 3 "Download source tarball" bash -c "$dl | tar xz -C '$tmpdir' --strip-components=1"; then
        error "Failed to download source after retries. Cannot continue in remote mode."
        exit 1
    fi
    SCRIPT_DIR="$tmpdir"
    ok "Source downloaded to a temporary directory"
}

# --- Install steps ------------------------------------------------------
install_agents() {
    copy_file "$SCRIPT_DIR/AGENTS.md" "$CURSOR_HOME/AGENTS.md"
}

install_rules() {
    local srcroot="$SCRIPT_DIR/.cursor/rules"
    [ -d "$srcroot" ] || { warn "no .cursor/rules/ in source — skipping rules"; return 0; }
    ensure_dir "$CURSOR_HOME/rules"
    local f count=0
    for f in "$srcroot"/*.mdc; do
        [ -e "$f" ] || continue
        if $DRY_RUN; then info "would install rule: $(basename "$f")"; else cp -p "$f" "$CURSOR_HOME/rules/$(basename "$f")"; fi
        mf_add "rule:$(basename "$f")"
        count=$((count + 1))
    done
    $DRY_RUN || ok "rules installed ($count files) -> $CURSOR_HOME/rules/"
}

install_skills() {
    local srcroot="$SCRIPT_DIR/skills"
    [ -d "$srcroot" ] || { warn "no skills/ in source — skipping skills"; return 0; }
    ensure_dir "$CURSOR_HOME/skills"
    local d name dst
    for d in "$srcroot"/*/; do
        [ -d "$d" ] || continue
        name="$(basename "$d")"
        dst="$CURSOR_HOME/skills/$name"
        mf_add "skill:$name"
        if $DRY_RUN; then info "would install skill: $name -> $dst"; continue; fi
        rm -rf "$dst"
        cp -a "${d%/}" "$dst"
        ok "skill: $name"
    done
}

install_mcp() {
    # Existing servers win on conflict so we never clobber the user's MCP setup.
    merge_json "$SCRIPT_DIR/mcp.json" "$CURSOR_HOME/mcp.json" \
        '.[1] + { mcpServers: ((.[0].mcpServers // {}) + (.[1].mcpServers // {})) }' \
        "mcp.json (mcpServers)"
}

install_hooks() {
    # Merge our sessionStart hook into any existing hooks.json (keep the user's
    # hooks; dedupe identical entries) rather than overwriting the whole file.
    merge_json "$SCRIPT_DIR/hooks.json" "$CURSOR_HOME/hooks.json" \
        '(.[0]) as $i | (.[1]) as $e | ($i + $e) | .hooks = ((((($i.hooks // {})|keys) + (($e.hooks // {})|keys))|unique) as $ks | reduce $ks[] as $k ({}; .[$k] = ((($e.hooks // {})[$k] // []) + (($i.hooks // {})[$k] // []) | unique)))' \
        "hooks.json (hooks)"
    local srcroot="$SCRIPT_DIR/hooks"
    [ -d "$srcroot" ] || return 0
    ensure_dir "$CURSOR_HOME/hooks"
    local f name dst
    for f in "$srcroot"/*; do
        [ -f "$f" ] || continue
        name="$(basename "$f")"
        dst="$CURSOR_HOME/hooks/$name"
        mf_add "hook:$name"
        if $DRY_RUN; then info "would install hook script: $name"; continue; fi
        cp -p "$f" "$dst"
        case "$name" in *.sh) chmod +x "$dst" ;; esac
    done
    $DRY_RUN || ok "hook scripts installed -> $CURSOR_HOME/hooks/"
}

install_statusline() {
    copy_file "$SCRIPT_DIR/hooks/statusline.sh" "$CURSOR_HOME/statusline.sh"
    $DRY_RUN || { [ -f "$CURSOR_HOME/statusline.sh" ] && chmod +x "$CURSOR_HOME/statusline.sh"; }
}

install_cli_config() {
    # Our statusLine wins (that's what we're installing); other keys preserved.
    merge_json "$SCRIPT_DIR/cli-config.json" "$CURSOR_HOME/cli-config.json" \
        '.[1] + { statusLine: .[0].statusLine }' \
        "cli-config.json (statusLine)"
    # Point statusLine.command at the actual install dir (handles --prefix/CURSOR_HOME).
    set_statusline_command
}

# Rewrite statusLine.command in the installed cli-config.json to the resolved
# install path so a custom --prefix / CURSOR_HOME works at runtime.
set_statusline_command() {
    local dst="$CURSOR_HOME/cli-config.json" cmd="$CURSOR_HOME/statusline.sh"
    [ -e "$dst" ] || return 0
    if $DRY_RUN; then info "would set statusLine.command -> $cmd"; return 0; fi
    $HAVE_JQ || { warn "jq unavailable — statusLine.command left as-is in $(rel "$dst")"; return 0; }
    local tmp; tmp="$(mktemp)"
    if jq --arg cmd "$cmd" '.statusLine.command = $cmd' "$dst" >"$tmp" 2>/dev/null && jq empty "$tmp" >/dev/null 2>&1; then
        mv "$tmp" "$dst"; ok "statusLine.command -> $cmd"
    else
        rm -f "$tmp"; warn "could not set statusLine.command in $(rel "$dst")"
    fi
}

install_lessons() {
    local dst="$CURSOR_HOME/lessons.md"
    if [ -e "$dst" ]; then
        info "lessons.md exists — preserving your corrections (never overwritten)"
        mf_add "lessons:preexisted"
        return 0
    fi
    copy_file "$SCRIPT_DIR/lessons.md" "$dst"
    mf_add "lessons:seeded"
    # Sentinel survives re-runs so --uninstall --purge-lessons knows it was ours.
    $DRY_RUN || { [ -d "$SNAPSHOT_DIR" ] && : > "$SNAPSHOT_DIR/.lessons-seeded"; }
}

# Record the installed version so the `update` skill can compare against remote.
stamp_version() {
    local ver; ver="$(source_version)"
    [ "$ver" != "unknown" ] || { warn "no VERSION file in source — skipping version stamp"; return 0; }
    if $DRY_RUN; then
        info "would write version stamp: $ver -> $VERSION_STAMP_FILE"
        return 0
    fi
    echo "$ver" > "$VERSION_STAMP_FILE"
    ok "version stamped: $ver"
}

# --- Snapshot + manifest (enable a clean --uninstall) -------------------
# On the FIRST install, copy any pre-existing managed file into the snapshot dir
# verbatim. Re-runs/updates keep the original snapshot untouched so uninstall
# always restores the true pre-install state.
snapshot_originals() {
    if [ -d "$SNAPSHOT_DIR" ]; then
        info "snapshot exists — keeping the original pre-install backup"
        return 0
    fi
    if $DRY_RUN; then
        local rel
        for rel in $(managed_files); do
            [ -e "$CURSOR_HOME/$rel" ] && warn "would snapshot original: $rel"
        done
        info "would create snapshot dir: $SNAPSHOT_DIR"
        return 0
    fi
    mkdir -p "$SNAPSHOT_DIR"
    local rel
    for rel in $(managed_files); do
        if [ -e "$CURSOR_HOME/$rel" ]; then
            mkdir -p "$SNAPSHOT_DIR/$(dirname "$rel")"
            cp -p "$CURSOR_HOME/$rel" "$SNAPSHOT_DIR/$rel"
            warn "snapshotted original $rel (for a clean uninstall)"
        fi
    done
}

# Write the line-based manifest used by --uninstall. Rewritten every run; the
# file: lines are derived from snapshot presence so they stay correct across
# updates without needing to parse the old manifest.
write_manifest() {
    if $DRY_RUN; then info "would write manifest -> $MANIFEST_FILE"; return 0; fi
    {
        echo "# awesome-claude-code-config (Cursor) install manifest"
        echo "# Used by 'install-cursor.sh --uninstall'. Do not edit by hand."
        echo "version=$(source_version)"
        echo "installed_at=$(date +%Y-%m-%dT%H:%M:%S%z 2>/dev/null || date)"
        echo "cursor_home=$CURSOR_HOME"
        local rel
        for rel in $(managed_files); do
            if [ -e "$SNAPSHOT_DIR/$rel" ]; then echo "file:$rel:preexisted"; else echo "file:$rel:created"; fi
        done
        printf '%s' "$MANIFEST_BODY"
    } > "$MANIFEST_FILE"
    ok "manifest written -> $MANIFEST_FILE"
}

# --- Uninstall ----------------------------------------------------------

confirm_uninstall() {
    $FORCE && return 0
    $DRY_RUN && return 0
    if [ ! -t 0 ] && [ ! -r /dev/tty ]; then
        error "Non-interactive shell — re-run with --force to confirm uninstall."
        exit 1
    fi
    local ans=""
    if [ -t 0 ]; then
        printf "%bProceed with uninstall? [y/N] %b" "$YELLOW" "$NC"; read -r ans
    else
        printf "%bProceed with uninstall? [y/N] %b" "$YELLOW" "$NC" > /dev/tty; read -r ans < /dev/tty
    fi
    case "$ans" in [Yy]|[Yy][Ee][Ss]) return 0 ;; *) info "Cancelled."; exit 0 ;; esac
}

# Restore a managed file from the snapshot, or delete it if we created it.
restore_or_delete_managed() {
    # NOTE: assign dst on its own line — referencing $rel inside the same `local`
    # statement expands it before rel is set, which fails under `set -u`.
    local rel="$1" dst
    dst="$CURSOR_HOME/$rel"
    if [ -e "$SNAPSHOT_DIR/$rel" ]; then
        if $DRY_RUN; then info "would restore original: $rel"; return 0; fi
        ensure_dir "$(dirname "$dst")"
        cp -p "$SNAPSHOT_DIR/$rel" "$dst"
        ok "restored original: $rel"
    elif [ -e "$dst" ]; then
        if $DRY_RUN; then info "would remove: $rel (installer-created)"; return 0; fi
        rm -f "$dst"
        ok "removed: $rel"
    fi
}

# Best-effort removal when no snapshot exists: only delete a file if it is
# byte-identical to what this repo ships (i.e. unmodified and clearly ours).
degraded_remove_if_ours() {
    local rel="$1" dst src
    dst="$CURSOR_HOME/$rel"
    src="$(source_path_for "$rel")"
    [ -e "$dst" ] || return 0
    if [ -f "$src" ] && cmp -s "$src" "$dst"; then
        if $DRY_RUN; then info "would remove (matches shipped): $rel"; return 0; fi
        rm -f "$dst"; ok "removed (unmodified): $rel"
    else
        warn "kept $rel — modified, merged, or pre-existing (remove manually if unwanted)"
    fi
}

# Surgically drop our keys from a merged JSON in degraded mode (needs jq).
degraded_clean_json() {
    local rel="$1" filter="$2" dst
    dst="$CURSOR_HOME/$rel"
    [ -e "$dst" ] || return 0
    if ! $HAVE_JQ; then warn "kept $rel — jq unavailable for surgical cleanup"; return 0; fi
    if $DRY_RUN; then info "would surgically clean $rel"; return 0; fi
    local tmp; tmp="$(mktemp)"
    if jq "$filter" "$dst" >"$tmp" 2>/dev/null && jq empty "$tmp" >/dev/null 2>&1; then
        # If nothing meaningful is left, remove the file entirely.
        if [ "$(jq -S 'if . == {} or . == {"version":1} then "empty" else "keep" end' "$tmp" 2>/dev/null)" = '"empty"' ]; then
            rm -f "$dst" "$tmp"; ok "removed (now empty): $rel"
        else
            mv "$tmp" "$dst"; ok "cleaned our entries from: $rel"
        fi
    else
        rm -f "$tmp"; warn "kept $rel — surgical cleanup failed"
    fi
}

run_uninstall() {
    local mode="normal"
    if [ ! -f "$MANIFEST_FILE" ] || [ ! -d "$SNAPSHOT_DIR" ]; then mode="degraded"; fi

    echo "  target: $CURSOR_HOME"
    if [ "$mode" = "degraded" ]; then
        warn "No install manifest/snapshot found under $CURSOR_HOME."
        warn "This config was likely installed with an older installer that did not record one."
        warn "Falling back to best-effort removal: only files identical to the shipped"
        warn "versions are removed; anything you modified or that pre-existed is LEFT IN PLACE."
        if [ ! -f "$VERSION_STAMP_FILE" ] && [ ! -d "$CURSOR_HOME/rules" ] && [ ! -d "$CURSOR_HOME/skills" ]; then
            error "Nothing here looks installed by this config. Aborting."
            exit 1
        fi
    fi
    $DRY_RUN && warn "DRY RUN — nothing will be removed"
    echo ""
    confirm_uninstall

    if [ "$mode" = "normal" ]; then
        # 1) Managed single files: restore originals or delete what we created.
        local rel
        for rel in $(managed_files); do restore_or_delete_managed "$rel"; done

        # 2) Installed rules / skills / hook scripts (by manifest record).
        local line name
        while IFS= read -r line; do
            case "$line" in
                rule:*) name="${line#rule:}"
                    if $DRY_RUN; then info "would remove rule: $name"
                    else rm -f "$CURSOR_HOME/rules/$name"; fi ;;
                skill:*) name="${line#skill:}"
                    if $DRY_RUN; then info "would remove skill: $name"
                    else rm -rf "$CURSOR_HOME/skills/$name"; fi ;;
            esac
        done < "$MANIFEST_FILE"
        $DRY_RUN || ok "removed installed rules and skills"
    else
        # Degraded: remove only unmodified-ours files; surgically clean JSON.
        degraded_remove_if_ours "AGENTS.md"
        degraded_remove_if_ours "statusline.sh"
        degraded_remove_if_ours "hooks/load-lessons.sh"
        degraded_remove_if_ours "hooks/statusline.sh"
        degraded_clean_json "mcp.json" 'del(.mcpServers.context7, .mcpServers.playwright) | if (.mcpServers // {}) == {} then del(.mcpServers) else . end'
        degraded_clean_json "hooks.json" '(.hooks.sessionStart) |= (map(select(.command != "./hooks/load-lessons.sh")) // []) | if (.hooks.sessionStart // []) == [] then del(.hooks.sessionStart) else . end | if (.hooks // {}) == {} then del(.hooks) else . end'
        degraded_clean_json "cli-config.json" "del(.statusLine)"
        # Rules/skills: remove only those byte-identical to the shipped copy.
        local f base
        if [ -d "$SCRIPT_DIR/.cursor/rules" ]; then
            for f in "$SCRIPT_DIR"/.cursor/rules/*.mdc; do
                [ -e "$f" ] || continue; base="$(basename "$f")"
                if [ -f "$CURSOR_HOME/rules/$base" ] && cmp -s "$f" "$CURSOR_HOME/rules/$base"; then
                    $DRY_RUN && info "would remove rule: $base" || rm -f "$CURSOR_HOME/rules/$base"
                fi
            done
        fi
        if [ -d "$SCRIPT_DIR/skills" ]; then
            for f in "$SCRIPT_DIR"/skills/*/; do
                [ -d "$f" ] || continue; base="$(basename "$f")"
                if [ -d "$CURSOR_HOME/skills/$base" ] && diff -rq "$f" "$CURSOR_HOME/skills/$base" >/dev/null 2>&1; then
                    $DRY_RUN && info "would remove skill: $base" || rm -rf "$CURSOR_HOME/skills/$base"
                else
                    [ -d "$CURSOR_HOME/skills/$base" ] && warn "kept skill $base — modified or pre-existing"
                fi
            done
        fi
    fi

    # 3) lessons.md — preserved unless it was seeded by us and --purge-lessons.
    if [ -e "$SNAPSHOT_DIR/.lessons-seeded" ] && $PURGE_LESSONS; then
        $DRY_RUN && info "would remove seeded lessons.md" || { rm -f "$CURSOR_HOME/lessons.md"; ok "removed seeded lessons.md"; }
    elif [ -e "$CURSOR_HOME/lessons.md" ]; then
        info "kept lessons.md (your corrections; use --purge-lessons to drop a seeded one)"
    fi

    # 4) Bootstrapped jq.
    if [ -e "$SNAPSHOT_DIR/.jq-bootstrapped" ] || { [ "$mode" = "degraded" ] && [ -x "$CURSOR_HOME/bin/jq" ]; }; then
        if [ -e "$SNAPSHOT_DIR/.jq-bootstrapped" ]; then
            $DRY_RUN && info "would remove bootstrapped jq" || { rm -f "$CURSOR_HOME/bin/jq"; ok "removed bootstrapped jq"; }
        fi
    fi

    # 5) Version stamp + manifest + snapshot.
    if ! $DRY_RUN; then
        rm -f "$VERSION_STAMP_FILE"
        rm -f "$MANIFEST_FILE"
        rm -rf "$SNAPSHOT_DIR"
        # Remove now-empty installer-managed dirs (never the Cursor home itself).
        rmdir "$CURSOR_HOME/rules" "$CURSOR_HOME/hooks" "$CURSOR_HOME/skills" "$CURSOR_HOME/bin" 2>/dev/null || true
    fi

    echo ""
    if $DRY_RUN; then
        ok "Dry run complete — nothing was changed."
    else
        ok "Uninstalled. Restart Cursor (or reload the window) to apply."
    fi
    echo ""
}

# --- Main ---------------------------------------------------------------
main() {
    echo ""
    echo -e "${BOLD}=== Awesome Claude Code Config — Cursor Installer ===${NC}"

    if $UNINSTALL; then
        # Only fetch the repo source if we need it for degraded-mode comparison.
        if [ ! -f "$MANIFEST_FILE" ] || [ ! -d "$SNAPSHOT_DIR" ]; then
            ensure_jq || true
            detect_script_dir || true
        fi
        run_uninstall
        exit 0
    fi

    detect_script_dir

    echo "  source: $SCRIPT_DIR"
    echo "  target: $CURSOR_HOME"
    $DRY_RUN && warn "DRY RUN — no changes will be made"
    echo ""

    if [ ! -e "$SCRIPT_DIR/AGENTS.md" ]; then
        error "Source is missing AGENTS.md — cannot continue."
        exit 1
    fi

    ensure_dir "$CURSOR_HOME"
    snapshot_originals
    ensure_jq

    install_agents
    install_rules
    install_skills
    install_mcp
    install_hooks
    install_statusline
    install_cli_config
    install_lessons
    write_manifest
    stamp_version

    echo ""
    if $DRY_RUN; then
        ok "Dry run complete — nothing was changed."
    else
        ok "Cursor configuration installed to $CURSOR_HOME"
    fi
    echo ""
    info "Installed:"
    echo "  - AGENTS.md, lessons.md          (global instructions + corrections)"
    echo "  - rules/*.mdc                    (coding standards)"
    echo "  - skills/<name>/                 (bundled skills)"
    echo "  - mcp.json                       (MCP servers, merged)"
    echo "  - hooks.json + hooks/            (sessionStart -> load-lessons)"
    echo "  - statusline.sh + cli-config.json (status line, merged)"
    echo ""
    info "Next steps:"
    echo "  1. Restart Cursor (or reload the window) so it picks up the new config."
    echo "  2. Enable MCP servers from Cursor Settings if prompted."
    $HAVE_JQ || echo "  3. Install jq for JSON merges on future re-runs (see warnings above)."
    echo ""
    info "To undo later: ./install-cursor.sh --uninstall  (restores the pre-install state)"
    echo ""
}

main "$@"
