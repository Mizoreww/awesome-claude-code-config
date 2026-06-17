# Cursor MCP configuration (`mcp.json`)

This file is the Cursor port of `mcp/mcp-servers.json`. Cursor reads MCP servers
from `~/.cursor/mcp.json` (global) or `.cursor/mcp.json` (project), using the
format:

```json
{ "mcpServers": { "<name>": { "command": "...", "args": [...], "env": {...} } | { "url": "..." } } }
```

The installer (Worker C) **merges** the `mcpServers` block from this repo's
`mcp.json` into `~/.cursor/mcp.json` (it must not clobber servers the user
already has).

## Servers shipped active (zero-config, no secrets)

These run out of the box via `npx` — no credentials needed:

| Server | Package | Purpose |
|---|---|---|
| `context7` | `@upstash/context7-mcp` | Up-to-date library/framework docs lookup |
| `playwright` | `@playwright/mcp@latest` | Browser automation / web testing |

## Servers that need secrets (NOT shipped active — enable manually)

Strict JSON has **no comments**, so we cannot ship these "commented out" the way
the `codex` branch does in its TOML `config.toml`. To avoid Cursor repeatedly
spawning servers with bogus credentials every session, these are **documented
here instead of being placed in the active `mcp.json`**. To enable one, copy its
block into the `mcpServers` object of your `~/.cursor/mcp.json` and replace the
placeholders with real values.

### GitHub (needs a Personal Access Token)

```json
"github": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-github"],
  "env": {
    "GITHUB_PERSONAL_ACCESS_TOKEN": "YOUR_GITHUB_PAT"
  }
}
```

Create a token at <https://github.com/settings/tokens> and paste it in place of
`YOUR_GITHUB_PAT`.

### Lark / Feishu (needs an app id + secret)

This is the server from the original `mcp/mcp-servers.json`:

```json
"lark-mcp": {
  "command": "npx",
  "args": ["-y", "@larksuiteoapi/lark-mcp", "mcp", "-a", "YOUR_APP_ID", "-s", "YOUR_APP_SECRET"],
  "env": {}
}
```

Replace `YOUR_APP_ID` / `YOUR_APP_SECRET` with your Lark/Feishu app credentials.

## Notes

- The `codex` branch also ships an OpenAI-specific docs server
  (`openaiDeveloperDocs` → `https://developers.openai.com/mcp`). That is
  Codex-specific and has no Cursor equivalent, so it is intentionally omitted.
- Cursor toggles servers on/off in its Settings UI (there is no documented
  per-server `disabled` flag inside `mcp.json`), which is the other reason the
  secret-requiring servers are kept out of the active file rather than disabled
  inline.

## Related: status line (`cli-config.json`)

The companion `cli-config.json` in this repo is a **sample** holding the
`statusLine` entry. The installer merges it into `~/.cursor/cli-config.json`:

```json
{ "statusLine": { "type": "command", "command": "~/.cursor/statusline.sh", "padding": 2 } }
```
