[Main English](https://github.com/Mizoreww/awesome-claude-code-config/blob/main/README.md) | [Main 中文](https://github.com/Mizoreww/awesome-claude-code-config/blob/main/README.zh-CN.md) | [Codex English](./README.md) | **Codex 中文**

# Codex 配置

[Codex CLI](https://github.com/openai/codex) 的生产级配置——一键安装全局指令、多 Agent 角色、通过技能实现分层编码规范、MCP 集成、自定义状态栏，以及基于 lessons 的自我改进循环。与 [Claude Code 主配置](https://github.com/Mizoreww/awesome-claude-code-config/tree/main)互为姐妹分支。

## 目录结构

```
.
├── AGENTS.md              # 全局指令
├── config.toml            # Codex 设置（模型、权限、MCP、lessons 注入）
├── agents/                # Multi-agent 角色配置
├── lessons.md             # 自我纠正源日志
├── skills/                # 仓库自带本地技能（paper-reading、adversarial-review、humanizer）
├── VERSION                # 安装器版本
└── install.sh             # 一键安装脚本
```

## 快速开始

一行远程安装：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/codex/install.sh)
```

本地安装：

```bash
git clone -b codex https://github.com/Mizoreww/awesome-claude-code-config.git
cd awesome-claude-code-config
bash install.sh
```

然后重启 Codex。

## 安装器参数

```bash
./install.sh                         # 安装全部（core + mcp + 全部技能）
./install.sh --core                 # 仅 AGENTS.md / lessons.md / config.toml / agents/*
./install.sh --mcp                  # 仅 MCP 服务
./install.sh --skills core          # 仅核心技能集
./install.sh --skills ai-research   # 仅 AI 研究技能集
./install.sh --version              # 查看 source/installed/remote 版本
./install.sh --uninstall --skills   # 仅卸载受管技能
./install.sh --dry-run              # 预览变更
```

## 核心特性

### 自我改进循环（仅 lessons）

1. 用户纠正会记录到 `~/.codex/lessons.md`
2. 新会话自动加载 `~/.codex/lessons.md`
3. 稳定模式沉淀到 `~/.codex/AGENTS.md`

### lessons 自动注入

`config.toml` 使用：

```toml
model_instructions_file = "lessons.md"
```

这样在会话开始时就会加载纠错规则。

### 开箱即用 Multi-Agent

`config.toml` 默认开启实验特性 `multi_agent`，并预置 3 个角色：

- `explorer`：代码路径探索与证据归纳
- `reviewer`：正确性/回归/安全风险审查
- `docs_researcher`：通过 OpenAI docs MCP + Context7 做 API/文档核验

角色配置文件位于 `agents/*.toml`，安装后会落到 `~/.codex/agents/`。

### 通过技能实现分层规则

```
核心行为       → AGENTS.md
  ↓ 由技能强化
skills/rules  → python-patterns、golang-patterns、frontend-patterns
```

保证通用原则与语言特定实践一致。

### Skill-First 安装

`install.sh` 会从开源生态安装一组实用技能：

| 技能集 | 来源 | 覆盖范围 |
|-------|------|----------|
| superpowers | [obra/superpowers](https://github.com/obra/superpowers) | 完整原生 superpowers 集合，含 brainstorming、计划执行、review handoff、worktree 等 |
| everything-claude-code | [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) | 语言模式、测试、安全、验证 |
| anthropic skills packs | [anthropics/skills](https://github.com/anthropics/skills) | 文档处理、前端设计、画布/艺术、MCP builder |
| AI research skills | [zechenzhangAGI/AI-research-SKILLs](https://github.com/zechenzhangAGI/AI-research-SKILLs) | 分词、微调、后训练、推理服务、分布式训练、优化 |

Superpowers 采用仓库当前的原生发现安装方式：
- clone 到 `~/.codex/superpowers`
- 将 `~/.codex/superpowers/skills` 符号链接到 `~/.agents/skills/superpowers`
- 清理 `~/.codex/skills` 下旧的局部复制安装（`using-superpowers`、`systematic-debugging`、`writing-plans`、`test-driven-development`）

本仓库内置本地技能：
- `paper-reading`（`skills/paper-reading/SKILL.md`）— 结构化论文阅读与总结
- `adversarial-review`（`skills/adversarial-review/SKILL.md`）— 跨模型对抗式代码审查，通过对立 AI CLI 执行（来自 [poteto/noodle](https://github.com/poteto/noodle/tree/main/.agents/skills/adversarial-review)）
- `humanizer`（`skills/humanizer/SKILL.md`）— 检测并去除文本中的 AI 写作痕迹（来自 [blader/humanizer](https://github.com/blader/humanizer)）

### 版本变更日志策略

AGENTS.md 包含 **版本变更日志** 规则：在做版本级改动（新功能、重大重构、Breaking Change）时，agent 会主动在项目根目录维护 `CHANGELOG.md`，每条记录包含功能、设计理念和注意细节。使设计决策与代码同步可追溯。

### MCP 集成

`config.toml` 默认包含以下 MCP 服务：

| 服务 | 用途 |
|------|------|
| Lark MCP | 飞书文档、表格、群聊、Base 等（[repo](https://github.com/larksuite/lark-openapi-mcp)） |
| Context7 | 最新库文档检索（[repo](https://github.com/upstash/context7)） |
| GitHub | Issue / PR / 仓库工作流（[repo](https://github.com/github/github-mcp-server)） |
| Playwright | 浏览器自动化与 E2E 测试（[repo](https://github.com/microsoft/playwright-mcp)） |
| OpenAI Developer Docs | OpenAI 官方文档 MCP 端点（`https://developers.openai.com/mcp`） |

## 安装说明

1. 请填入你自己的凭据：
   - `YOUR_APP_ID` / `YOUR_APP_SECRET`（Lark）
   - `YOUR_GITHUB_PAT`（GitHub MCP）
2. 该配置使用当前 Codex 配置风格（例如顶层 `web_search = "live"`）。
3. 如果 `~/.codex/config.toml` 已存在，安装器会跳过覆盖；如需更新请手动合并。

### 对抗式代码审查

AGENTS.md 包含 **Code Review** 规则：需要代码审查时，调用 `adversarial-review` skill（来自 [poteto/noodle](https://github.com/poteto/noodle/tree/main/.agents/skills/adversarial-review)）。该 skill 在**对立 AI 模型的 CLI** 上生成审查者（Codex 用户调用 `claude -p`，Claude 用户调用 `codex exec`），产出跨模型对抗分析和结构化裁决（PASS / CONTESTED / REJECT）。

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

- [**Claude Code Best Practice**](https://github.com/shanraisshan/claude-code-best-practice) by shanraisshan — Claude Code 最佳实践、工作流与实现模式的全面知识库
- [**我给 10 个 Claude Code 打工**](https://mp.weixin.qq.com/s/9qPD3gXj3HLmrKC64Q6fbQ) by 胡渊明 — 多个编码 Agent 并行协作的实践经验
- [**Harness Engineering**](https://openai.com/zh-Hans-CN/index/harness-engineering/) by OpenAI — 从”写代码”转向”设计系统并驾驭 Agent”
- [**Anthropic Engineering**](https://www.anthropic.com/engineering) by Anthropic — 工程博客，涵盖 Agent 开发、评估方法与构建可靠 AI 系统
- [**OpenAI Engineering**](https://openai.com/news/engineering/) by OpenAI — 工程博客，分享构建和扩展 AI 系统的技术洞察
- [**Claude Code in Action**](https://anthropic.skilljar.com/claude-code-in-action) by Anthropic Academy — 官方工作流课程

## 许可证

MIT
