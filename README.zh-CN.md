<!-- 翻译同步自 README.md（source of truth）。更新英文版后请同步此文件。 -->

[English](./README.md) | **中文** | [Codex 分支](https://github.com/Mizoreww/awesome-claude-code-config/tree/codex)

# Awesome Claude Code 配置

![Statusline](assets/statusline.png)

[Claude Code](https://claude.com/claude-code) 的生产级配置——一键安装全局指令、多语言编码规则（Python / TypeScript / Go）、20 个精选插件、自定义技能（paper-reading、[adversarial-review](https://github.com/poteto/noodle/tree/main/.agents/skills/adversarial-review)）、自定义状态栏、MCP 集成，以及跨 session 自动记忆纠正的自我改进循环。

## 目录结构

```
.
├── CLAUDE.md              # 全局指令
├── settings.json          # 设置（权限、插件、hooks、模型）
├── lessons.md             # 自我纠正日志模板（通过 hook 自动加载）
├── rules/                 # 多语言编码标准（common + python/typescript/golang）
├── hooks/                 # 状态栏：渐变进度条（context + 5h 用量）
├── mcp/                   # MCP 服务器配置（Lark-MCP）
├── plugins/               # 插件安装指南（20 个插件，5 个市场）
├── skills/                # 自定义技能（paper-reading、adversarial-review）
├── VERSION                # 语义化版本号
├── install.sh             # 一键安装脚本（macOS / Linux）
└── install.ps1            # 一键安装脚本（Windows PowerShell）
```

## 快速开始

### macOS / Linux

**一行远程安装**（无需 clone）：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/main/install.sh)
```

**本地安装**（从 clone）：

```bash
git clone https://github.com/Mizoreww/awesome-claude-code-config.git
cd awesome-claude-code-config
./install.sh              # 安装全部
```

### Windows

**一行远程安装**（PowerShell，无需 clone）：

```powershell
irm https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/main/install.ps1 | iex
```

**CMD 环境**：

```cmd
powershell -c "irm https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/main/install.ps1 | iex"
```

**本地安装**（从 clone）：

```powershell
git clone https://github.com/Mizoreww/awesome-claude-code-config.git
cd awesome-claude-code-config
.\install.ps1             # 安装全部
```

### 默认安装（`--all`）

| 组件 | 是否包含 | 单独安装 |
|------|----------|----------|
| CLAUDE.md | 是 | `--claude-md` |
| settings.json | 是（智能合并） | `--settings` |
| Rules（所有语言） | 是 | `--rules [LANG...]` |
| Skills | 是 | `--skills` |
| lessons.md | 是（已存在则跳过） | `--lessons` |
| Plugins（core，14 个） | 是 | `--plugins` |
| Plugins（ai-research，6 个） | 否 | `--plugins ai-research` |
| MCP（Lark） | 否 | `--mcp` |

### 选择性安装

```bash
# Bash（macOS / Linux）
./install.sh --rules python typescript  # 仅规则
./install.sh --plugins                  # 仅核心插件（14 个）
./install.sh --plugins all              # 全部插件（20 个）
./install.sh --plugins ai-research      # 仅 AI 研究类插件（6 个）
./install.sh --mcp                      # MCP（Lark）
```

```powershell
# PowerShell（Windows）
.\install.ps1 -Rules python,typescript         # 仅规则
.\install.ps1 -Plugins                         # 仅核心插件（14 个）
.\install.ps1 -Plugins -PluginGroup all        # 全部插件（20 个）
.\install.ps1 -Plugins -PluginGroup ai-research # 仅 AI 研究类插件（6 个）
.\install.ps1 -Mcp                             # MCP（Lark）
```

### 卸载

```bash
# Bash（macOS / Linux）
./install.sh --uninstall                # 删除全部（含插件和 MCP）
./install.sh --uninstall --rules        # 仅删除规则
./install.sh --uninstall --force        # 跳过确认（CI/非交互环境）
```

```powershell
# PowerShell（Windows）
.\install.ps1 -Uninstall                            # 删除全部（含插件和 MCP）
.\install.ps1 -Uninstall -UninstallComponents rules  # 仅删除规则
.\install.ps1 -Uninstall -Force                      # 跳过确认
```

### 版本信息

```bash
./install.sh --version                  # 显示源版本 / 已安装版本 / 远程最新版本
```

```powershell
.\install.ps1 -Version                  # 显示源版本 / 已安装版本 / 远程最新版本
```

## 核心特性

### 自我改进循环

双层记忆，按作用域路由：

1. 用户纠正 Claude → Claude 判断作用域：**跨项目通用**的纠正写入 `~/.claude/lessons.md`；**仅当前项目**的偏好写入项目的 `MEMORY.md`
2. 下次 session → `SessionStart` hook 自动注入全局 lessons；项目 `MEMORY.md` 由 Claude Code 自动加载
3. 模式确认后 → 规则提升至 `CLAUDE.md`

### SessionStart Hook

`settings.json` 中配置了两个 `SessionStart` hook：
- **startup**：新 session 启动时注入 lessons.md
- **compact**：上下文压缩后重新注入 lessons.md

取代了以前在 CLAUDE.md 中要求手动 Read lessons.md 的方式（更可靠）。

### 状态栏

单行状态栏，渐变进度条，由 `hooks/statusline.sh` 驱动：

- **模型** + **目录** + **git 分支**
- **Context 窗口**：渐变进度条（绿 → 黄 → 红），显示百分比和大小
- **5 小时用量**：从 `api.anthropic.com/api/oauth/usage` 拉取（60s 缓存），显示重置倒计时
- 进度条固定 20 字符宽，16 级颜色渐变

通过 `settings.json` 中的 `statusLine` 配置：

```json
"statusLine": {
  "type": "command",
  "command": "bash $HOME/.claude/hooks/statusline.sh"
}
```

### settings.json 智能合并

当 `settings.json` 已存在时，安装器会执行智能合并（Bash 版需要 `jq`，PowerShell 版使用内置 JSON 支持）：

- **env**：新值作为默认值，已有值优先
- **permissions.allow**：两个数组取并集（去重）
- **enabledPlugins**：合并，已有键优先
- **hooks.SessionStart**：按 `matcher` 字段去重
- **statusLine**：新配置优先

没有 `jq` 时，会显示手动合并提示。

### 分层规则

```
common/       → 通用原则（始终加载）
  ↓ extended by
python/       → PEP 8、pytest、black、bandit
typescript/   → Zod、Playwright、Prettier
golang/       → gofmt、表驱动测试、gosec
```

### 插件优先

20 个插件，5 个市场，分为两组：

**核心插件**（14 个）— 默认安装：

| 插件 | 市场 | 功能 |
|------|------|------|
| [**superpowers**](https://github.com/obra/superpowers) | claude-plugins-official | 头脑风暴、调试、代码审查、Git worktree、计划编写 |
| [**everything-claude-code**](https://github.com/affaan-m/everything-claude-code) | everything-claude-code | TDD、安全审查、数据库模式、Go/Python/Spring Boot |
| [**document-skills**](https://github.com/anthropics/skills) | anthropic-agent-skills | PDF、DOCX、PPTX、XLSX 创建和操作 |
| [**example-skills**](https://github.com/anthropics/skills) | anthropic-agent-skills | 前端设计、MCP 构建器、画布设计、算法艺术 |
| [**claude-mem**](https://github.com/thedotmack/claude-mem) | thedotmack | 持久化记忆，智能搜索、时间线、AST 感知代码搜索 |
| **frontend-design** | claude-plugins-official | 生产级前端界面设计 |
| [**context7**](https://github.com/upstash/context7) | claude-plugins-official | 最新库文档查询 |
| **code-review** | claude-plugins-official | 基于置信度的代码审查 |
| [**github**](https://github.com/github/github-mcp-server) | claude-plugins-official | GitHub 集成（Issue、PR、工作流） |
| [**playwright**](https://github.com/microsoft/playwright-mcp) | claude-plugins-official | 浏览器自动化、E2E 测试、截图 |
| **feature-dev** | claude-plugins-official | 引导式功能开发 |
| **code-simplifier** | claude-plugins-official | 代码简化和重构 |
| **ralph-loop** | claude-plugins-official | 会话感知 AI 助手 REPL |
| **commit-commands** | claude-plugins-official | Git 提交、清理分支、提交-推送-PR |

**AI 研究插件**（6 个）— 用 `--plugins ai-research` 或 `--plugins all` 安装：

| 插件 | 市场 | 功能 |
|------|------|------|
| [**tokenization**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | HuggingFace Tokenizers、SentencePiece |
| [**fine-tuning**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | Axolotl、LLaMA-Factory、PEFT、Unsloth |
| [**post-training**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | GRPO、RLHF、DPO、SimPO |
| [**inference-serving**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | vLLM、SGLang、TensorRT-LLM、llama.cpp |
| [**distributed-training**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | DeepSpeed、FSDP、Megatron-Core、Ray Train |
| [**optimization**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | AWQ、GPTQ、GGUF、Flash Attention、bitsandbytes |

详见 [`plugins/README.md`](plugins/README.md) 了解安装方式。

### 版本变更日志策略

CLAUDE.md 包含 **版本变更日志** 规则：在做版本级改动（新功能、重大重构、Breaking Change）时，Claude 会主动在项目根目录维护 `CHANGELOG.md`，每条记录包含功能、设计理念和注意细节。使设计决策与代码同步可追溯。

### 自定义技能

| 技能 | 说明 |
|------|------|
| **paper-reading** | 结构化论文阅读与总结，自动截图关键图表。优先使用 ar5iv HTML 版本，Playwright 截图，输出标准化 Markdown（问题、方法、实验、洞见）。 |
| **[adversarial-review](https://github.com/poteto/noodle/tree/main/.agents/skills/adversarial-review)** | 跨模型对抗式代码审查。在对立 AI 模型（Claude ↔ Codex）上生成审查者，使用不同批判视角（怀疑者、架构师、极简主义者），合成结构化裁决（PASS/CONTESTED/REJECT）。 |

自定义技能放在 `skills/<name>/SKILL.md`。

### 通过 Codex CLI 进行对抗式代码审查

CLAUDE.md 包含 **Code Review** 规则：无论是用户要求还是 skill（如 `code-reviewer`、`simplify`）触发的代码审查，Claude 都会调用 `adversarial-review` skill（来自 [poteto/noodle](https://github.com/poteto/noodle/tree/main/.agents/skills/adversarial-review)）。该 skill 在**对立 AI 模型的 CLI** 上生成审查者（Claude 用户调用 `codex exec`，Codex 用户调用 `claude -p`），产出跨模型对抗分析和结构化裁决（PASS / CONTESTED / REJECT）。

需要安装 Codex CLI 并设置环境变量 `OPENAI_API_KEY`。

## 安全提示

`settings.json` 默认使用 `bypassPermissions` 模式（适合高级用户）。如需更安全的默认值，将 `defaultMode` 改为 `"default"`，并将 `skipDangerousModePermissionPrompt` 设为 `false`。

## 自定义

- **添加语言**：创建 `rules/<lang>/` 目录，扩展 common 规则
- **添加技能**：放到 `skills/<name>/SKILL.md`
- **调整 CLAUDE.md**：根据你的 shell、包管理器、项目上下文定制

## 致谢

- [**Claude Code in Action**](https://anthropic.skilljar.com/claude-code-in-action) by Anthropic Academy — 官方课程，涵盖 Claude Code 工具集成、MCP 服务器、GitHub 自动化等开发工作流
- [**我给 10 个 Claude Code 打工**](https://mp.weixin.qq.com/s/9qPD3gXj3HLmrKC64Q6fbQ) by 胡渊明 — 多 Claude Code 实例并行协作的实践经验分享
- [**Harness Engineering**](https://openai.com/zh-Hans-CN/index/harness-engineering/) by OpenAI — "驾驭工程"理念：工程师从代码编写者转变为系统设计者，用 Agent 生成百万行代码
- [**Claude Code Best Practice**](https://github.com/shanraisshan/claude-code-best-practice) by shanraisshan — Claude Code 最佳实践、工作流与实现模式的全面知识库

## 许可证

MIT
