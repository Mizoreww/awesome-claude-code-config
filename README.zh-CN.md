<!-- 本文件与 README.md 同步维护。README.md 为主，本文件为翻译。 -->

[English](./README.md) | **中文** | [Codex 分支](https://github.com/Mizoreww/awesome-claude-code-config/tree/codex) | [更新日志](./CHANGELOG.zh-CN.md)

# Awesome Claude Code Configuration

![Statusline](assets/statusline.png)

[Claude Code](https://claude.com/claude-code) 的生产级配置。一条命令安装：全局指令、多语言编码规则（Python / TypeScript / Go）、10 个 marketplace 下的 25 个精选插件、6 个内置 skill（外加通过 npx 安装的 [mattpocock/skills](https://github.com/mattpocock/skills) 集合）、渐变状态栏，以及能跨会话记住纠正的自我改进回路。

## 示例

![Claude Code Demo](images/claude-code-demo.png)

- [paper-reading skill 实战 — *Attention Is All You Need*](docs/Attention_Is_All_You_Need.md)
- [adversarial-review skill 实战](docs/adversarial-review-showcase.md)

## 快速开始

**macOS / Linux**:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/main/install.sh)
```

**Windows (PowerShell)**:

```powershell
irm https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/main/install.ps1 | iex
```

启动两级交互菜单。追加 `--all` / `-All` 跳过菜单全量安装。其他参数：`--dry-run`、`--uninstall`、`--version`（PowerShell 对应 `-DryRun`、`-Uninstall`、`-Version`）。

```
  > [5/5] Core                   全局指令、设置、规则...
    [0/3] Language Rules          Python / TypeScript / Go
    [2/3] Review                  code-review + adversarial-review
    [8/9] Workflow                karpathy、mattpocock/skills、neat-freak...
    [3/3] Integrations            context7、github、playwright
    [4/5] Design & Content        document-skills、frontend-design、humanizer...
    [0/2] Slides                  frontend-slides、ppt-master
    [0/3] Memory & Lifestyle      claude-mem、claude-health、PUA
    [1/11] Academic Research      paper-reading、deepxiv-cli、researchstudio...
    [0/1] MCP Servers             Lark/飞书
```

- **主菜单**：↑↓ 切换分组，**Enter 或 →** 打开分组的子菜单，**q** 退出。光标移到 *Submit* 按 Enter 开始安装。
- **子菜单**：↑↓ 切换项目，**Space** 切换选中，**← 或 Esc** 返回主菜单（与在 *[ Back ]* 上按 Enter 等价）。
- 快捷键（任意层）：**a** 全选、**n** 全不选、**d** 恢复默认；在子菜单中只影响当前分组。
- Review 分组内 `adversarial-review` 与 `codex` 互斥 — 勾选一个会自动取消另一个。

**Core (5)** — 基础文件，默认全部开启。

| 项目 | 功能 | 默认 |
|------|------|------|
| CLAUDE.md | 全局指令模板 | 开启 |
| settings.json | 智能合并 Claude Code 设置 | 开启 |
| Common rules | `rules/common/` — 编码风格、git、安全、测试 | 开启 |
| StatusLine | 渐变进度条 & 5 小时用量（`hooks/statusline.sh`） | 开启 |
| Lessons | `lessons.md` 模板 + `SessionStart` hook | 开启 |

**Language Rules (3)** — 默认全部关闭，仅启用项目用到的语言。

| 项目 | 功能 | 默认 |
|------|------|------|
| Python rules | PEP 8、pytest、类型注解、bandit | 关闭 |
| TypeScript rules | Zod、Playwright、不可变性 | 关闭 |
| Go rules | gofmt、表驱动测试、gosec | 关闭 |

**Review (3)** — `adversarial-review` 与 `codex` 互斥。

| 项目 | 来源 | 功能 | 默认 |
|------|------|------|------|
| **code-review** | claude-plugins-official（插件） | 基于置信度的 PR 代码审查 | 开启 |
| [**adversarial-review**](https://github.com/poteto/noodle/blob/main/.agents/skills/adversarial-review/SKILL.md) | 内置 skill | 跨模型审查（Skeptic / Architect / Minimalist 视角） | 开启 |
| [**codex**](https://github.com/openai/codex-plugin-cc) | openai-codex（插件） | Codex CLI 驱动的对抗式审查 | 关闭 |

**Workflow (9)** — 规划、迭代、代码质量、元配置。

| 项目 | 来源 | 功能 | 默认 |
|------|------|------|------|
| [**andrej-karpathy-skills**](https://github.com/forrestchang/andrej-karpathy-skills) | karpathy-skills（插件） | Karpathy 编码守则：Think-First、Simplicity、Surgical、Goal-Driven | 开启 |
| [**superpowers**](https://github.com/obra/superpowers) | claude-plugins-official（插件） | 头脑风暴、调试、代码审查、Git worktree、计划编写 | 关闭 |
| [**mattpocock/skills**](https://github.com/mattpocock/skills) | npx `skills` | 17 个 agent skill（tdd、to-prd、to-issues、diagnosing-bugs、handoff、teach、grilling…），通过 `skills` CLI 安装到 `~/.claude/skills/` | 开启 |
| [**neat-freak**](https://github.com/KKKKhazix/khazix-skills/tree/2b4a645cfdc894156ae347d897723562f719ce95/neat-freak) | 内置 skill | 对齐项目文档、Agent 规则、获准维护的记忆与工作区残留，完成知识和治理收尾 | 开启 |
| **feature-dev** | claude-plugins-official | 引导式功能开发 | 开启 |
| **ralph-loop** | claude-plugins-official | 自动化迭代循环（会话感知 REPL） | 开启 |
| **commit-commands** | claude-plugins-official | Git 提交 / 推送 / PR 工作流 | 开启 |
| **code-simplifier** | claude-plugins-official | 代码简化与重构 | 开启 |
| [**update-config**](skills/update-config/) | 内置 skill | `/update-config` — 在会话内重新运行安装器 | 开启 |

**Integrations (3)** — 外部工具与服务。

| 项目 | 来源 | 功能 | 默认 |
|------|------|------|------|
| [**context7**](https://github.com/upstash/context7) | claude-plugins-official | 最新库文档查询 | 开启 |
| [**github**](https://github.com/github/github-mcp-server) | claude-plugins-official | GitHub 集成（Issue、PR、工作流） | 开启 |
| [**playwright**](https://github.com/microsoft/playwright-mcp) | claude-plugins-official | 浏览器自动化、E2E 测试、截图 | 开启 |

**Design & Content (5)** — 文档、UI、创意与文本"人化"。

| 项目 | 来源 | 功能 | 默认 |
|------|------|------|------|
| [**document-skills**](https://github.com/anthropics/skills) | anthropic-agent-skills | PDF、DOCX、PPTX、XLSX 创建和操作 | 开启 |
| [**example-skills**](https://github.com/anthropics/skills) | anthropic-agent-skills | 前端设计、MCP 构建器、画布、算法艺术 | 开启 |
| **frontend-design** | claude-plugins-official | 生产级前端界面设计 | 开启 |
| [**humanizer**](https://github.com/blader/humanizer) | 内置 skill | 去除 AI 写作特征（英文） | 开启 |
| [**humanizer-zh**](https://github.com/op7418/Humanizer-zh) | 内置 skill | 去除 AI 写作特征（中文） | 关闭 |

**Slides (2)** — AI 幻灯片 / PPTX 生成，默认全部关闭。

| 项目 | 来源 | 功能 | 默认 |
|------|------|------|------|
| [**frontend-slides**](https://github.com/zarazhangrui/frontend-slides) | frontend-slides | 零依赖 HTML 幻灯片生成器，支持 PPT 转换与 bold 模板风格 | 关闭 |
| [**ppt-master**](https://github.com/hugohe3/ppt-master) | ppt-master | 从 PDF/DOCX/URL/Markdown 生成可编辑 PPTX——真实形状与动画（安装后需 `pip install -r requirements.txt`） | 关闭 |

**Memory & Lifestyle (3)** — 会话记忆与个人生产力，默认全部关闭。

| 项目 | 来源 | 功能 | 默认 |
|------|------|------|------|
| [**claude-mem**](https://github.com/thedotmack/claude-mem) | thedotmack | 持久化记忆，智能搜索、时间线、AST 感知代码搜索 | 关闭 |
| [**claude-health**](https://github.com/tw93/claude-health) | claude-health | Claude Code 会话健康检查与状态面板 | 关闭 |
| [**PUA**](https://github.com/tanweai/pua) | pua-skills | AI Agent 生产力倍增器（中 / 英 / 日） | 关闭 |

**Academic Research (11)** — 训练 / 推理插件 + 论文阅读、DeepXiv、ResearchStudio skill，默认除 `paper-reading` 外全部关闭。

| 项目 | 来源 | 功能 | 默认 |
|------|------|------|------|
| [**paper-reading**](skills/paper-reading/) | 内置 skill | 论文结构化摘要，支持自动抽图 | 开启 |
| [**tokenization**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | HuggingFace Tokenizers、SentencePiece | 关闭 |
| [**fine-tuning**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | Axolotl、LLaMA-Factory、PEFT、Unsloth | 关闭 |
| [**post-training**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | GRPO、RLHF、DPO、SimPO | 关闭 |
| [**inference-serving**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | vLLM、SGLang、TensorRT-LLM、llama.cpp | 关闭 |
| [**distributed-training**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | DeepSpeed、FSDP、Megatron-Core、Ray Train | 关闭 |
| [**optimization**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | AWQ、GPTQ、GGUF、Flash Attention、bitsandbytes | 关闭 |
| [**deepxiv-cli**](https://github.com/DeepXiv/deepxiv_sdk) | DeepXiv (GitHub) | arXiv/PMC 论文搜索与阅读 CLI（BM25+Vector 混合，200 万+ 论文） | 关闭 |
| [**deepxiv-trending-digest**](https://github.com/DeepXiv/deepxiv_sdk) | DeepXiv (GitHub) | 近 7 天热门论文 Markdown 摘要 | 关闭 |
| [**deepxiv-baseline-table**](https://github.com/DeepXiv/deepxiv_sdk) | DeepXiv (GitHub) | 从论文构建 Baseline 对比表 | 关闭 |
| [**researchstudio**](https://github.com/microsoft/ResearchStudio) | ResearchStudio（微软，npx） | 研究选题 Idea skill：idea-spark、paper-search、scoop-check | 关闭 |

**MCP Servers (1)** — 非插件的 MCP 集成，默认关闭。

| 项目 | 来源 | 功能 | 默认 |
|------|------|------|------|
| [**Lark MCP server**](https://github.com/larksuite/lark-openapi-mcp) | `mcp/` | 飞书 / Lark 集成（安装后替换 `YOUR_APP_ID`/`YOUR_APP_SECRET`） | 关闭 |

## 目录结构

```
.
├── CLAUDE.md              # 全局指令
├── settings.json          # 权限、插件、hook、模型
├── lessons.md             # 自我纠正日志模板（通过 hook 自动加载）
├── rules/                 # 编码规范（common + python/typescript/golang）
├── hooks/                 # 带渐变进度条的状态栏
├── mcp/                   # MCP 服务器配置（Lark-MCP）
├── plugins/               # 插件目录与安装指南
├── skills/                # 内置自定义 skill
├── docs/                  # 论文摘要、实战示例
└── install.sh / install.ps1
```

## 核心机制

- **分层规则** — `rules/common/`（通用）被各语言目录扩展，每个文件引用一个更深的 skill（模式、测试、安全）。
- **状态栏** — 模型、目录、venv、git 分支、上下文窗口（渐变条）、5 小时用量倒计时。脚本在 `hooks/statusline.sh`。
- **自我改进回路** — 纠正按范围路由到 `~/.claude/lessons.md`（跨项目）或项目 `MEMORY.md`（本地）。`SessionStart` hook 在启动与压缩后自动注入。
- **插件目录与 marketplace 地址** — 完整列表和安装命令见 [plugins/README.md](plugins/README.md)。

## 默认设置

`settings.json` 预置了一组高性能默认值。旧版 Claude Code 会静默忽略未识别键；只有 `auto` 模式做版本门控（低于 2.1.80 时安装器自动降级为 `bypassPermissions`）。

| 键 | 值 | 作用 |
|----|-----|-----|
| `permissions.defaultMode` | `auto` | 自动批准安全操作、拦截高风险操作 |
| `effortLevel` | `max` | `/effort` 固定最高推理档 |
| `betas` | `extended-cache-ttl-2025-04-11` | 1 小时提示缓存（替代默认 5 分钟） |
| `env.CLAUDE_CODE_NO_FLICKER` | `1` | 全屏渲染 |
| `env.CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING` | `1` | 固定思考预算（Opus 4.7 不受影响） |

重新安装时会智能合并 `env`、`permissions.allow`、`enabledPlugins`、`hooks.SessionStart`、`statusLine`，保留你的改动。你在 `enabledPlugins` 中手动添加的本目录之外的插件会原样保留。

## 自定义

- **新增语言**：创建 `rules/<lang>/` 扩展 `rules/common/`
- **新增 skill**：放入 `skills/<name>/SKILL.md`
- **改造 CLAUDE.md**：按你的 shell、包管理器、项目情境调整

## 致谢

- [Claude Code in Action](https://anthropic.skilljar.com/claude-code-in-action) — Anthropic Academy 官方课程
- [为 10 个 Claude Code 打工](https://mp.weixin.qq.com/s/9qPD3gXj3HLmrKC64Q6fbQ) by 胡渊鸣 — 多实例并行实践
- [Harness Engineering](https://openai.com/index/harness-engineering/) by OpenAI
- [Anthropic Engineering](https://www.anthropic.com/engineering) / [OpenAI Engineering](https://openai.com/news/engineering/)
- [Claude Code Best Practice](https://github.com/shanraisshan/claude-code-best-practice) by shanraisshan
- [Claude How To](https://github.com/luongnv89/claude-howto) by luongnv89

## License

MIT
