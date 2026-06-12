#!/usr/bin/env bash
# Lightweight check that README.md and README.zh-CN.md stay structurally in sync.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EN="$DIR/README.md"
ZH="$DIR/README.zh-CN.md"

ok=true
compare() {
    local label="$1" en_count="$2" zh_count="$3"
    if [[ "$en_count" != "$zh_count" ]]; then
        echo "MISMATCH $label: EN=$en_count ZH=$zh_count"
        ok=false
    else
        echo "OK       $label: $en_count"
    fi
}

compare "Headings"    "$(grep -c '^#' "$EN")" "$(grep -c '^#' "$ZH")"
compare "Code blocks" "$(grep -c '^\`\`\`' "$EN")" "$(grep -c '^\`\`\`' "$ZH")"
compare "Table rows"  "$(grep -c '^|' "$EN")" "$(grep -c '^|' "$ZH")"
# ERE instead of PCRE (-P) so the check also works with BSD/macOS grep.
compare "Links"       "$(grep -oE '\[[^][]*\]\([^()]*\)' "$EN" | wc -l)" "$(grep -oE '\[[^][]*\]\([^()]*\)' "$ZH" | wc -l)"

$ok && echo "All checks passed." || { echo "Structural differences found."; exit 1; }
