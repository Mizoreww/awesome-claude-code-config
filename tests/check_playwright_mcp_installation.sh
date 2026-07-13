#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_SH="$ROOT_DIR/install.sh"
INSTALL_PS1="$ROOT_DIR/install.ps1"
CONFIG_TEMPLATE="$ROOT_DIR/config.toml"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local expected="$2"
  grep -Fq -- "$expected" "$file" || fail "$file does not contain: $expected"
}

assert_not_contains() {
  local file="$1"
  local unexpected="$2"
  if grep -Fq -- "$unexpected" "$file"; then
    fail "$file unexpectedly contains: $unexpected"
  fi
}

run_installer_case() {
  local case_name="$1"
  local node_version="$2"
  local npx_exit_code="${3:-0}"
  local npx_response="${4:-success}"
  local expected_installer_status="${5:-0}"
  local case_dir="$TEMP_DIR/$case_name"
  local mock_bin="$case_dir/bin"

  mkdir -p "$mock_bin" "$case_dir/home"

  cat > "$mock_bin/node" <<'MOCK_NODE'
#!/usr/bin/env bash
printf '%s\n' "${MOCK_NODE_VERSION:?}"
MOCK_NODE

  cat > "$mock_bin/npx" <<'MOCK_NPX'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${MOCK_NPX_LOG:?}"
request="$(cat)"
printf '%s\n' "$request" >> "${MOCK_NPX_STDIN_LOG:?}"
if [[ "${MOCK_NPX_EXIT_CODE:-0}" -ne 0 ]]; then
  exit "$MOCK_NPX_EXIT_CODE"
fi
if [[ "${MOCK_NPX_RESPONSE:-success}" == success && "$request" == *'"method":"initialize"'* ]]; then
  printf '%s\n' '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18","capabilities":{"tools":{}},"serverInfo":{"name":"Playwright","version":"test"}}}'
fi
MOCK_NPX

  cat > "$mock_bin/codex" <<'MOCK_CODEX'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${MOCK_CODEX_LOG:?}"
MOCK_CODEX

  chmod +x "$mock_bin/node" "$mock_bin/npx" "$mock_bin/codex"
  : > "$case_dir/codex.log"
  : > "$case_dir/npx.log"
  : > "$case_dir/npx-stdin.log"

  set +e
  HOME="$case_dir/home" \
      GITHUB_PERSONAL_ACCESS_TOKEN="test-only-token" \
      MOCK_NODE_VERSION="$node_version" \
      MOCK_NPX_EXIT_CODE="$npx_exit_code" \
      MOCK_NPX_RESPONSE="$npx_response" \
      MOCK_NPX_LOG="$case_dir/npx.log" \
      MOCK_NPX_STDIN_LOG="$case_dir/npx-stdin.log" \
      MOCK_CODEX_LOG="$case_dir/codex.log" \
      PATH="$mock_bin:$PATH" \
      bash "$INSTALL_SH" --mcp > "$case_dir/output.log" 2>&1
  local installer_status=$?
  set -e
  if [[ "$installer_status" -ne "$expected_installer_status" ]]; then
    fail "$case_name installer status was $installer_status, expected $expected_installer_status"
  fi
}

# Node 18 is the reported failure environment. The installed command must use
# an isolated supported runtime and must pass a startup smoke check first.
run_installer_case node18 v18.19.1
assert_contains "$TEMP_DIR/node18/npx.log" \
  "-y --loglevel=error --package=node@24 --package=@playwright/mcp@0.0.78 -- playwright-mcp"
assert_not_contains "$TEMP_DIR/node18/npx.log" "--version"
assert_contains "$TEMP_DIR/node18/npx-stdin.log" '"method":"initialize"'
assert_contains "$TEMP_DIR/node18/codex.log" \
  "mcp add playwright -- npx -y --loglevel=error --package=node@24 --package=@playwright/mcp@0.0.78 -- playwright-mcp"
assert_contains "$TEMP_DIR/node18/output.log" \
  "Node.js 18 detected; using an isolated Node.js 24 runtime for Playwright MCP"

# Supported Node installations should keep the upstream command shape while
# pinning the tested MCP version so a later npm latest release cannot regress it.
run_installer_case node24 v24.12.0
assert_contains "$TEMP_DIR/node24/npx.log" \
  "-y @playwright/mcp@0.0.78"
assert_not_contains "$TEMP_DIR/node24/npx.log" "--version"
assert_contains "$TEMP_DIR/node24/npx-stdin.log" '"method":"initialize"'
assert_contains "$TEMP_DIR/node24/codex.log" \
  "mcp add playwright -- npx -y @playwright/mcp@0.0.78"
assert_not_contains "$TEMP_DIR/node24/codex.log" "--package=node@24"
assert_contains "$TEMP_DIR/node24/output.log" \
  "MCP setup complete (selected entries are refreshed)"

# A launcher that cannot start must not be registered as a successful MCP.
run_installer_case smoke_failure v24.12.0 1 success 1
assert_not_contains "$TEMP_DIR/smoke_failure/codex.log" "mcp add playwright"
assert_contains "$TEMP_DIR/smoke_failure/output.log" \
  "Playwright MCP initialize check failed; not registering a broken server"

# A zero exit without an initialize result is still a failed handshake.
run_installer_case missing_initialize v24.12.0 0 missing 1
assert_not_contains "$TEMP_DIR/missing_initialize/codex.log" "mcp add playwright"
assert_contains "$TEMP_DIR/missing_initialize/output.log" \
  "Playwright MCP initialize check failed; not registering a broken server"

# Core-only installs copy config.toml without running the MCP installer. The
# template itself must therefore carry a Node-18-safe Playwright command.
core_home="$TEMP_DIR/core-only/home"
mkdir -p "$core_home"
HOME="$core_home" bash "$INSTALL_SH" --core > "$TEMP_DIR/core-only/output.log" 2>&1
installed_config="$core_home/.codex/config.toml"
assert_contains "$installed_config" \
  'args = ["-y", "--loglevel=error", "--package=node@24", "--package=@playwright/mcp@0.0.78", "--", "playwright-mcp"]'
assert_not_contains "$installed_config" '@playwright/mcp@latest'

# Bash and PowerShell installers must stay behaviorally aligned.
assert_contains "$INSTALL_SH" 'PLAYWRIGHT_MCP_VERSION="0.0.78"'
assert_contains "$INSTALL_SH" 'PLAYWRIGHT_NODE_FALLBACK_VERSION="24"'
assert_contains "$INSTALL_SH" 'add_playwright_mcp_server'
assert_contains "$INSTALL_SH" '"method":"initialize"'
assert_contains "$INSTALL_PS1" '$script:PLAYWRIGHT_MCP_VERSION = "0.0.78"'
assert_contains "$INSTALL_PS1" '$script:PLAYWRIGHT_NODE_FALLBACK_VERSION = "24"'
assert_contains "$INSTALL_PS1" 'function Add-PlaywrightMcpServer'
assert_contains "$INSTALL_PS1" '"method":"initialize"'
assert_not_contains "$INSTALL_SH" '@playwright/mcp@latest'
assert_not_contains "$INSTALL_PS1" '@playwright/mcp@latest'
assert_not_contains "$CONFIG_TEMPLATE" '@playwright/mcp@latest'

echo "Playwright MCP installer checks passed"
