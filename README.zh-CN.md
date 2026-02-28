[Claude Main Branch](https://github.com/Mizoreww/claude-code-config/tree/main) | [中文 README（main）](https://github.com/Mizoreww/claude-code-config/blob/main/README.zh-CN.md) | [English](./README.md) | **中文**

# Codex 配置

面向生产使用的 Codex 配置：全局指令、Codex 原生持久记忆、通过技能实现分层编码规范、MCP 集成，以及一键安装。

## 目录结构

```
.
├── AGENTS.md              # 全局指令
├── config.toml            # Codex 设置（模型、权限、MCP、MEMORY.md 注入）
├── lessons.md             # 自我纠正源日志
├── codex-mem/             # Codex 原生记忆 CLI
├── skills/
│   ├── codex-mem/         # 记忆总控技能
│   └── mem-search/        # Codex 兼容的记忆检索技能
└── install.sh             # 一键安装脚本
```

## 快速开始

```bash
git clone -b codex https://github.com/Mizoreww/claude-code-config.git
cd claude-code-config
bash install.sh
```

然后重启 Codex。

## 核心特性

### 自我改进 + 持久记忆循环

1. 用户纠正会记录到 `~/.codex/lessons.md`
2. `codex-mem` 将观察记录到 `~/.codex/memory/codex_mem.db`
3. `codex-mem build-context` 合成 `~/.codex/MEMORY.md`
4. 新会话自动加载 `~/.codex/MEMORY.md`
5. 稳定模式沉淀到 `~/.codex/AGENTS.md`

### MEMORY 自动注入（Codex 原生）

`config.toml` 使用：

```toml
model_instructions_file = "~/.codex/MEMORY.md"
```

这样 lessons 与长期记忆会一起进入自动加载上下文。

### `codex-mem`（按 claude-mem 思路实现，面向 Codex）

安装路径：`~/.codex/bin/codex-mem`

```bash
# 记录观察
~/.codex/bin/codex-mem note --type decision --title \"...\" --details \"...\"

# 检索历史
~/.codex/bin/codex-mem search --project \"$(pwd)\" --query \"auth retry\"
~/.codex/bin/codex-mem timeline --project \"$(pwd)\" --query \"auth retry\"
~/.codex/bin/codex-mem get --ids 12,15

# 刷新自动加载上下文
~/.codex/bin/codex-mem build-context --project \"$(pwd)\" --output ~/.codex/MEMORY.md --lessons ~/.codex/lessons.md
```

### 通过技能实现分层规则

```
核心行为       → AGENTS.md
  ↓ 由技能强化
skills/rules  → claude-rules、python-patterns、golang-patterns、frontend-patterns
```

保证通用原则与语言特定实践一致。

### Skill-First 安装

`install.sh` 会从开源生态安装一组实用技能：

| 技能集 | 来源 | 覆盖范围 |
|-------|------|----------|
| superpowers | [obra/superpowers](https://github.com/obra/superpowers) | 计划、调试、TDD 工作流 |
| everything-claude-code | [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) | 语言模式、测试、安全、验证 |
| anthropic skills packs | [anthropics/skills](https://github.com/anthropics/skills) | 文档处理、前端设计、画布/艺术、MCP builder |
| claude-mem workflows | [thedotmack/claude-mem](https://github.com/thedotmack/claude-mem) | 规划/执行技能（`make-plan`、`do`） |
| codex-mem（本地） | 本仓库 | Codex 原生持久记忆（`codex-mem`、`mem-search`、`MEMORY.md` 同步） |
| AI research skills | [zechenzhangAGI/AI-research-SKILLs](https://github.com/zechenzhangAGI/AI-research-SKILLs) | 微调、后训练、推理服务、分布式训练、优化 |

### MCP 集成

`config.toml` 默认包含以下 MCP 服务：

| 服务 | 用途 |
|------|------|
| Lark MCP | 飞书文档、表格、群聊、Base 等（[repo](https://github.com/larksuite/lark-openapi-mcp)） |
| Context7 | 最新库文档检索（[repo](https://github.com/upstash/context7)） |
| GitHub | Issue / PR / 仓库工作流（[repo](https://github.com/github/github-mcp-server)） |
| Playwright | 浏览器自动化与 E2E 测试（[repo](https://github.com/microsoft/playwright-mcp)） |

## 安装说明

1. 请填入你自己的凭据：
   - `YOUR_APP_ID` / `YOUR_APP_SECRET`（Lark）
   - `YOUR_GITHUB_PAT`（GitHub MCP）
2. 该配置使用当前 Codex 配置风格（例如顶层 `web_search = "live"`）。
3. 如果 `~/.codex/config.toml` 已存在，请手动合并。

## 安全提示

模板默认偏向高级用户：
- `approval_policy = "never"`
- `sandbox_mode = "danger-full-access"`

如果你希望更安全的默认值，请在 `~/.codex/config.toml` 中自行调整。

## 自定义

- **调整全局行为**：编辑 `AGENTS.md`
- **扩展本地规则**：在 `~/.codex/skills` 扩展技能
- **调整模型与运行参数**：编辑 `config.toml`
- **启用/禁用 MCP**：编辑 `config.toml` 的 MCP 配置，或使用 `codex mcp` 命令

## 致谢

- [**AI Agent Workflow Orchestration Guidelines**](https://gist.github.com/OmerFarukOruc/a02a5883e27b5b52ce740cadae0e4d60) by [@OmerFarukOruc](https://github.com/OmerFarukOruc) — 工作流编排灵感来源
- [**Harness Engineering**](https://openai.com/zh-Hans-CN/index/harness-engineering/) by OpenAI — 从“写代码”转向“设计系统并驾驭 Agent”
- [**我给 10 个 Claude Code 打工**](https://mp.weixin.qq.com/s/9qPD3gXj3HLmrKC64Q6fbQ) by 胡渊鸣 — 多个编码 Agent 并行协作的实践经验
- [**Claude Code in Action**](https://anthropic.skilljar.com/claude-code-in-action) by Anthropic Academy — 官方工作流课程
- [**ChatGPT Prompt Engineering for Developers**](https://www.deeplearning.ai/short-courses/chatgpt-prompt-engineering-for-developers/) by DeepLearning.AI & OpenAI — 提示工程基础

## 许可证

MIT
