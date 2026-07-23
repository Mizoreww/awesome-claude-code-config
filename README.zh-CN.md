[Source English](https://github.com/Mizoreww/awesome-claude-code-config/blob/main/README.md) | [Source 中文](https://github.com/Mizoreww/awesome-claude-code-config/blob/main/README.zh-CN.md) | [Codex English](./README.md) | **Codex 中文**

# Codex 配置

[Codex CLI](https://github.com/openai/codex) 的生产级配置——带交互式安装器，并支持一键完整安装全局指令、多 Agent 角色、通过技能实现分层编码规范、MCP 集成，以及基于 lessons 的自我改进循环。该分支以 Codex 为默认目标，同时为从 [Claude Code 主配置](https://github.com/Mizoreww/awesome-claude-code-config/tree/main) 迁移的用户保留最小兼容层。

## 目录结构

```
.
├── AGENTS.md              # 全局指令
├── config.toml            # Codex 设置（模型、权限、MCP、lessons 注入）
├── agents/                # Multi-agent 角色配置
├── docs/                  # 迁移说明与支持文档
├── lessons.md             # 当前项目的纠正日志（按需创建/维护）
├── templates/             # 安装到 ~/.codex 的空白全局 lessons 模板
├── skills/                # 仓库自带本地技能（paper-reading、neat-freak、handoff、humanizer、update 等）
├── VERSION                # 安装器版本
└── install.sh / install.ps1
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

## 交互式安装器

Codex 分支在 Bash 和 PowerShell 上都使用同样的两层交互选择器，但菜单分组、默认值和安装目标都是 Codex 原生的。

### Bash

```bash
bash install.sh
bash install.sh --all
bash install.sh --dry-run
```

### PowerShell

```powershell
pwsh -NoProfile -File .\install.ps1
pwsh -NoProfile -File .\install.ps1 -All
pwsh -NoProfile -File .\install.ps1 -DryRun
```

行为说明：

- Bash 的纯无参运行在可用终端中会进入交互模式；如果无法打开终端，就会警告并回退到标准非交互式安装，仍不包含默认关闭的 ResearchStudio 与 PPT Master。
- PowerShell 的纯无参运行在可用控制台 I/O 下会进入交互模式；如果无法使用控制台，就会警告并回退到标准非交互式安装，仍不包含默认关闭的 ResearchStudio 与 PPT Master。
- Bash 的 `--dry-run` 会以非交互式方式预览标准安装，不会主动选择 ResearchStudio 或 PPT Master。
- PowerShell 的 `-DryRun` 单独使用时，会以非交互式方式预览标准安装，不会主动选择 ResearchStudio 或 PPT Master。
- 交互菜单对安装器拥有的 skills 具有最终决定权：重复安装时，之前已安装但本次未勾选的 owned skill 会被移除；未被安装器拥有的自定义 skill 即使与清单条目同名也会保留。所有权记录在 `~/.codex/.awesome-claude-code-config-managed-skills`；首次升级只接管未改动的内置副本、与 canonical 副本内容一致且 lock 来源匹配的旧副本，或来源已验证的 superpowers fallback。已退役 `coding-foundations` 包中来源可验证的残留属于 cleanup-only，因为菜单已无对应选项，会被清理。
- 如果没有选择任何 skill 且存在待删除的 owned skill，安装器会先二次确认；它不会删除 `.system`、共享 agent 或自定义 skill、Core 文件及 MCP 配置。
- 显式非交互参数（`--all`、`--core`、`--mcp`、`--skills` 及其 PowerShell 对应参数）仍是增量安装，不会按本次选择清理既有 skill。

### Codex 菜单分组与默认值

| 分组 | 条目 | 默认值 |
|------|------|--------|
| Core | `AGENTS.md`、`config.toml`、`StatusLine`、全局 `lessons.md`、`explorer`、`reviewer`、`docs-researcher` | 开启 |
| Review | `code-review`、`adversarial-review` | `code-review` 开启；`adversarial-review` 关闭 |
| Workflow | `andrej-karpathy-skills`、`superpowers`、`mattpocock/skills`、`handoff`、`neat-freak`、`update-config` | 除 `superpowers` 外均开启 |
| Development Tools | `context7`、`github`、`playwright`、`openaiDeveloperDocs` | 开启；`github` 需要 `GITHUB_PERSONAL_ACCESS_TOKEN` |
| Design & Content | `document-skills`、`example-skills`、`frontend-design`、`humanizer`、`humanizer-zh` | 除 `humanizer-zh` 外开启 |
| Lifestyle | `PUA` | 关闭 |
| Academic Research | `paper-reading`、`ResearchStudio Idea`、`ResearchStudio Reel`、`tokenization`、`fine-tuning`、`post-training`、`distributed-training`、`inference-serving`、`optimization`、`deepxiv` | `paper-reading` 开启，其余关闭 |
| Slides | `frontend-slides`、`ppt-master` | 均关闭 |
| MCP Servers | `lark-mcp` | 关闭（需凭据） |

## 安装器参数

```bash
./install.sh                         # 终端可用时进入交互式选择器
./install.sh --all                   # 非交互式全量安装
./install.sh --core                  # AGENTS.md / 空白全局 lessons.md / config.toml / agents/*
./install.sh --mcp                   # 仅 MCP 服务
./install.sh --skills core           # 仅核心技能集
./install.sh --skills ai-research    # 仅 AI 研究技能集
./install.sh --version               # 查看 source/installed/remote 版本
./install.sh --uninstall --skills    # 仅卸载受管技能
./install.sh --dry-run               # 非交互式完整预览
./install.sh --force                 # 跳过卸载 / 空 skill 批量删除确认
```

## 核心特性

### 自我改进循环（按作用域分流 lessons）

1. 与当前仓库相关的纠正写入 `<project-root>/lessons.md`；第一次项目级纠正发生时由 agent 创建，和按需创建 `CHANGELOG.md` 类似。
2. 只有真正跨项目适用的纠正才写入 `~/.codex/lessons.md`。
3. 新会话自动加载全局日志；`AGENTS.md` 同时要求 Codex 定位当前项目根目录，并在存在时读取项目 `lessons.md`。
4. 稳定的跨项目模式可以沉淀到 `~/.codex/AGENTS.md`。

### lessons 自动注入

`config.toml` 使用：

```toml
model_instructions_file = "lessons.md"
```

这里只注入由安装器初始化为空白的全局纠正日志。项目 lessons 不会复制进 `~/.codex`，而是从当前项目根目录发现。

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
| mattpocock/skills | [mattpocock/skills](https://github.com/mattpocock/skills) | 固定 v1.1 的 `ask-matt`、grilling/design、research、specs/tickets、wayfinding、implementation、triage、TDD、架构和领域建模工作流 |
| superpowers | [obra/superpowers](https://github.com/obra/superpowers) | 完整原生 superpowers 集合，含 brainstorming、计划执行、review handoff、worktree 等；优先通过 `npx skills` 安装，失败时回退到 git/junction |
| andrej-karpathy-skills | [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills) | 通过 `npx skills` 安装 Karpathy 风格编码指南 |
| anthropic skills packs | [anthropics/skills](https://github.com/anthropics/skills) | 文档处理、前端设计、画布/艺术、MCP builder |
| DeepXiv skills | [DeepXiv/deepxiv_sdk](https://github.com/DeepXiv/deepxiv_sdk) | 安装时始终拉取最新 DeepXiv 研究工作流（`deepxiv-cli`、`deepxiv-baseline-table`、`deepxiv-trending-digest`） |
| ResearchStudio Idea | [microsoft/ResearchStudio](https://github.com/microsoft/ResearchStudio) | 默认关闭；从官方源码树复制研究创意、论文搜索与新颖性检查 skills |
| ResearchStudio Reel | [microsoft/ResearchStudio](https://github.com/microsoft/ResearchStudio/tree/main/ResearchStudio-Reel) | 默认关闭；从官方源码树复制 paper-to-assets、poster、video、blog 与 interactive-reel 工作流 |
| neat-freak | [`2b4a645` 的 KKKKhazix/khazix-skills](https://github.com/KKKKhazix/khazix-skills/tree/2b4a645cfdc894156ae347d897723562f719ce95/neat-freak) | 默认开启；固定 vendored 的项目知识与治理收尾工作流 |
| AI research skills | [zechenzhangAGI/AI-research-SKILLs](https://github.com/zechenzhangAGI/AI-research-SKILLs) | 分词、微调、后训练、推理服务、分布式训练、优化 |
| frontend-slides | [zarazhangrui/frontend-slides](https://github.com/zarazhangrui/frontend-slides) | 通过 `npx skills` 安装幻灯片生成 skill；默认关闭 |
| ppt-master | [hugohe3/ppt-master](https://github.com/hugohe3/ppt-master) | 默认关闭；生成原生可编辑 PPTX，只安装 skill 定义，runtime 留到第一次使用时处理 |
| PUA | [tanweai/pua](https://github.com/tanweai/pua) | 可选的 productivity coaching skills，通过 `npx skills` 安装；默认关闭 |

远程 skills 默认使用：

```bash
npx -y skills@latest add <repo> --global --agent codex --copy --yes --full-depth --skill <name>
```

Matt Pocock skills 是例外：两个安装器都会先下载不可变的 v1.1.0 release commit，再把该本地快照交给 `skills@latest`。这样可以避开可变的 `main` 内容，以及当前 CLI 对远程 tag/commit 后缀处理不可靠的问题。只有全部请求的 skill 目录与快照一致时才算安装成功；匹配的远程 lock 条目会被移除，避免之后的通用 `skills update` 覆盖固定内容。迁移时还会跨共享 agent 关联移除来源已验证的旧名称（`to-prd`、`to-issues`、`decision-mapping`、`review`）。

`mattpocock/skills` 安装成功后，安装器会显示一段 30 秒 Codex Quickstart。当前版本的 `skills` CLI 即使指定 `--agent codex --copy`，全局 Codex skill 也可能放在共享目录 `~/.agents/skills`，Codex 会直接发现它们。在 Codex 中输入 `/skills` 并选择 **List skills**，或直接按 `@`，然后搜索 `setup-matt-pocock-skills`。已安装的 skill 不会变成 `/setup-matt-pocock-skills` 这样的根级 slash command。

每个通过 npx 请求的 skill，只有在规范目录中实际出现对应 `SKILL.md`，且本次安装确实刷新了与请求上游一致、hash 非空的共享 skill lock 记录后，才算安装成功；缺少这份本次运行产生的 provenance 时，即使 npx 返回 0 也会判定为未完成。对于按路径安装的技能包，安装器会把仓库目录名映射到 skill 声明名，并仅对本次 npx 未验证的条目使用内置 `skill-installer` Python helper 重试。Codex 安装器不会显示没有可安装 Codex target 的 Claude-only plugin 工作流。

ResearchStudio Idea、ResearchStudio Reel 与 `ppt-master` 是互相独立、默认关闭的菜单条目。显式选择后只安装受限的上游 skill 源码，以及 Idea 在 Codex 中必需的指令/路径适配。安装器不会创建 Python 或 Conda 环境，不会安装 Python 包、浏览器或原生工具，也不会执行 runtime 依赖检查。第一次真正调用时，skill 可以自行建立项目局部环境，或向用户说明缺少哪些依赖。

本仓库内置本地技能：
- `paper-reading`（`skills/paper-reading/SKILL.md`）— 结构化论文阅读与总结
- `adversarial-review`（`skills/adversarial-review/SKILL.md`）— 跨模型对抗式代码审查，通过对立 AI CLI 执行（来自 [poteto/noodle](https://github.com/poteto/noodle/tree/main/.agents/skills/adversarial-review)）
- `handoff`（`skills/handoff/SKILL.md`）— 将当前对话压缩成交接文档
- [`neat-freak`](https://github.com/KKKKhazix/khazix-skills/tree/2b4a645cfdc894156ae347d897723562f719ce95/neat-freak)（`skills/neat-freak/SKILL.md`）— 来自固定上游快照的项目知识与治理收尾工作流
- `humanizer`（`skills/humanizer/SKILL.md`）— 检测并去除文本中的 AI 写作痕迹（来自 [blader/humanizer](https://github.com/blader/humanizer)）
- `humanizer-zh`（`skills/humanizer-zh/SKILL.md`）— 移除中文文本中的 AI 写作痕迹
- `update`（`skills/update/SKILL.md`）— 将已安装的 Codex 配置更新到最新 `codex` 分支版本

DeepXiv 技能会在每次执行 `install.sh` 时像 superpowers 一样从上游刷新安装：
- `deepxiv-cli`
- `deepxiv-baseline-table`
- `deepxiv-trending-digest`

对于 Codex 用户，不需要单独安装本地 `deepxiv` CLI。只要把这些技能持续刷新到 Codex 中，就满足本仓库支持的使用方式。

### 版本变更日志策略

AGENTS.md 包含 **版本变更日志** 规则：在做版本级改动（新功能、重大重构、Breaking Change）时，agent 会主动在项目根目录维护 `CHANGELOG.md`，每条记录包含功能、设计理念和注意细节。使设计决策与代码同步可追溯。

### MCP 集成

`config.toml` 默认包含以下 MCP 服务：

| 服务 | 用途 |
|------|------|
| Lark MCP | 飞书文档、表格、群聊、Base 等——默认注释关闭，需填入凭据（[repo](https://github.com/larksuite/lark-openapi-mcp)） |
| Context7 | 最新库文档检索（[repo](https://github.com/upstash/context7)） |
| GitHub | Issue / PR / 仓库工作流——默认注释关闭，需要 PAT（[repo](https://github.com/github/github-mcp-server)） |
| Playwright | 浏览器自动化与 E2E 测试（[repo](https://github.com/microsoft/playwright-mcp)） |
| OpenAI Developer Docs | OpenAI 官方文档 MCP 端点（`https://developers.openai.com/mcp`） |

安装器会固定已验证的 Playwright MCP 版本，并在写入 Codex 前完成 MCP `initialize` 握手。Node.js 20 或更高版本会使用上游标准 `npx` 命令；旧版 Node.js 会显示警告，并为 Playwright MCP 与 `npx skills` 使用隔离的 Node.js 24 runtime，不替换系统 Node.js。静态 `config.toml` 模板也使用兼容的 Playwright launcher。仍建议安装受支持的 Node.js 24 LTS；兼容 runtime 依赖 `npx`，首次使用时需要下载对应 package。

## 安装说明

1. Lark 与 GitHub MCP 条目在 `config.toml` 中默认被注释关闭。启用前请填入你自己的凭据并取消注释：
   - `YOUR_APP_ID` / `YOUR_APP_SECRET`（Lark）
   - `YOUR_GITHUB_PAT`（GitHub MCP）
2. 该配置使用当前 Codex 配置风格（例如顶层 `web_search = "live"`）。
3. 如果 `~/.codex/config.toml` 已存在，安装器会跳过覆盖；如需更新请手动合并。

### 代码审查

AGENTS.md 规定需要代码审查时使用 Matt Pocock 的 `code-review` Standards/Spec 工作流。`adversarial-review` 仍作为独立可选 skill 保留，但默认关闭，也不是 Codex 的默认 review policy。

## 面向 Claude Code 主分支迁移用户的兼容说明

参见 [`docs/claude-main-to-codex-migration.md`](./docs/claude-main-to-codex-migration.md)，其中整理了以下映射关系：

- `CLAUDE.md` → `AGENTS.md`
- `settings.json` → `config.toml`
- Claude 时代的插件 → Codex skills / MCP / 内建能力
- `mcp/mcp-servers.json` → `config.toml` 中的 `[mcp_servers.*]`

## 安全提示

这个分支为新 Codex 配置提供的模板默认值有意偏自主：
- `model = "gpt-5.6-sol"`
- `model_reasoning_effort = "max"`
- `approval_policy = "never"`
- `sandbox_mode = "danger-full-access"`
- `[tui].status_line = ["model", "reasoning", "project-name", "git-branch", "context-used", "five-hour-limit", "weekly-limit"]`
- `[tui].status_line_use_colors = true`

重复安装会保留已有的 `model` 和 `model_reasoning_effort`；勾选 StatusLine 时会刷新为上面的托管 footer 字段。

请只在可信仓库使用这套配置。如果希望保留审批提示和 workspace sandbox，可在 `~/.codex/config.toml` 中改回 `approval_policy = "on-request"` 和 `sandbox_mode = "workspace-write"`。

如果 `~/.codex/config.toml` 已有 `[tui].status_line` 但当前 TUI 底边栏没有变化，请重启 Codex，或在 TUI 内运行 `/statusline` 检查并保存当前 footer 项。

## 自定义

- **调整全局行为**：编辑 `AGENTS.md`
- **扩展本地规则**：在 `~/.codex/skills` 扩展技能
- **调整模型与运行参数**：编辑 `config.toml`
- **启用/禁用 MCP**：编辑 `config.toml` 的 MCP 配置，或使用 `codex mcp` 命令

## 致谢

- [**Harness Engineering**](https://openai.com/zh-Hans-CN/index/harness-engineering/) by OpenAI — 从”写代码”转向”设计系统并驾驭 Agent”
- [**Anthropic Engineering**](https://www.anthropic.com/engineering) by Anthropic — 工程博客，涵盖 Agent 开发、评估方法与构建可靠 AI 系统
- [**OpenAI Engineering**](https://openai.com/news/engineering/) by OpenAI — 工程博客，分享构建和扩展 AI 系统的技术洞察

## 许可证

MIT
