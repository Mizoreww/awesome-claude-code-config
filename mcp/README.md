# MCP Servers

> **Note**: Context7 and Playwright now have official plugin equivalents. Use plugins instead — see [`plugins/README.md`](../plugins/README.md). Lark-MCP remains here as a standalone MCP server.

## Included Servers

| Server | Transport | Purpose |
|--------|-----------|---------|
| **[Lark-MCP](https://github.com/larksuite/lark-openapi-mcp)** | stdio | Official Feishu/Lark OpenAPI — call Lark platform APIs from AI assistants |

## Installation

```bash
./install.sh --mcp

# Or manually:
claude mcp add --scope user --transport stdio lark-mcp -- npx -y @larksuiteoapi/lark-mcp mcp -a YOUR_APP_ID -s YOUR_APP_SECRET
```

Replace `YOUR_APP_ID` and `YOUR_APP_SECRET` with your Feishu app credentials ([open.feishu.cn](https://open.feishu.cn/)).
