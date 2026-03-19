<!-- 翻译同步自 README.md（source of truth）。更新英文版后请同步此文件。 -->

[English](./README.md) | **中文** | [Codex 分支](https://github.com/Mizoreww/awesome-claude-code-config/tree/codex)

# Awesome Claude Code 配置

![Statusline](assets/statusline.png)

[Claude Code](https://claude.com/claude-code) 的生产级配置——一键安装全局指令、多语言编码规则（Python / TypeScript / Go）、20 个精选插件、自定义技能（paper-reading、[adversarial-review](https://github.com/poteto/noodle/tree/main/.agents/skills/adversarial-review)、[humanizer](https://github.com/blader/humanizer)、update_config）、自定义状态栏、MCP 集成，以及跨 session 自动记忆纠正的自我改进循环。

## 展示

![Claude Code 演示](images/claude-code-demo.png)

**论文阅读技能实战** — 使用 `paper-reading` 技能进行结构化论文分析。查看完整总结：[Attention Is All You Need — 论文总结](docs/Attention_Is_All_You_Need.zh-CN.md)

**对抗式代码审查实战** — 跨模型对抗式代码审查。Claude 通过 Codex CLI 生成多个审查者，分别使用不同批判视角（怀疑者、架构师、极简主义者），合成结构化裁决（PASS / CONTESTED / REJECT）。查看完整展示：[Adversarial Review 效果展示](docs/adversarial-review-showcase.md)

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
├── skills/                # 自定义技能（paper-reading、adversarial-review、humanizer、update_config）
├── docs/                  # 论文阅读总结
├── images/                # 展示截图
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

自动弹出交互式选择器。添加 `--all` 可跳过选择直接安装全部。

**本地安装**（从 clone）：

```bash
git clone https://github.com/Mizoreww/awesome-claude-code-config.git
cd awesome-claude-code-config
./install.sh              # 交互式选择器
./install.sh --all        # 安装全部（非交互）
```

### Windows

**一行远程安装**（PowerShell，无需 clone）：

```powershell
irm https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/main/install.ps1 | iex
```

自动弹出交互式选择器。如需非交互安装全部，请从本地 clone 运行 `.\install.ps1 -All`。

**CMD 环境**：

```cmd
powershell -c "irm https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/main/install.ps1 | iex"
```

**本地安装**（从 clone）：

```powershell
git clone https://github.com/Mizoreww/awesome-claude-code-config.git
cd awesome-claude-code-config
.\install.ps1             # 交互式选择器
```

### 交互式安装

直接运行 `./install.sh`（不带参数）会启动交互式菜单，自由选择要安装的组件。语言规则和重型插件**默认关闭**，减少上下文占用：

```
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    Awesome Claude Code Config Installer  1.9.2
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ↑/↓ Navigate   Space Toggle   Enter Submit
  a All   n None   d Defaults   q Quit

  Core
  > [*] CLAUDE.md                全局指令模板
    [*] settings.json            智能合并 Claude Code 设置
    [*] Common rules             编码规范、git、安全、测试
    [*] Hooks                    StatusLine 状态栏
    [*] Lessons template         跨 session 学习框架
    [*] Custom skills            adversarial-review, paper-reading, humanizer, update_config

  Language Rules（按需选择）
    [ ] Python                   PEP 8, pytest, type hints, bandit
    [ ] TypeScript               Zod, Playwright, immutability
    [ ] Go                       gofmt, 表驱动测试, gosec

  Plugins
    [*] Plugins (13)             superpowers, code-review, playwright, feature-dev...
    [ ] claude-mem               跨 session 记忆（~3k tokens/session）
    [ ] AI Research plugins      fine-tuning, inference, optimization...
    [ ] claude-health            健康检查 & 状态面板

  MCP Servers
    [ ] Lark                     飞书/Lark 集成

  >  [ Submit ]
```

使用 ↑↓ 导航，Enter 切换选项，移到 Submit 按 Enter 开始安装。

### 插件分组

| 分组 | 包含插件 | 默认 | Context 开销 |
|------|----------|------|-------------|
| Essential（13 个） | everything-claude-code, superpowers, code-review, context7, commit-commands, document-skills, playwright, feature-dev, code-simplifier, ralph-loop, frontend-design, example-skills, github | 开启 | 低 |
| claude-mem（1 个） | claude-mem | 关闭 | **~3k tokens/session**（观测索引 + session 摘要） |
| AI Research（6 个） | tokenization, fine-tuning, post-training, inference-serving, distributed-training, optimization | 关闭 | 低 |
| claude-health（1 个） | health | 关闭 | 低 |

### CLI 参数

```bash
# Bash（macOS / Linux）
./install.sh              # 交互式选择器（自由选择要安装的组件）
./install.sh --all        # 安装全部（非交互）
./install.sh --dry-run    # 预览会安装什么
./install.sh --uninstall  # 删除全部
./install.sh --version    # 显示版本信息
```

```powershell
# PowerShell（Windows）
.\install.ps1              # 交互式选择器
.\install.ps1 -All         # 安装全部（非交互）
.\install.ps1 -Uninstall   # 删除全部
.\install.ps1 -Version     # 显示版本信息
```

### 卸载

```bash
./install.sh --uninstall          # 删除全部（含插件和 MCP）
./install.sh --uninstall --force  # 跳过确认（CI/非交互环境）
```

```powershell
.\install.ps1 -Uninstall         # 删除全部（含插件和 MCP）
.\install.ps1 -Uninstall -Force  # 跳过确认
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

- **模型** + **目录** + **虚拟环境**（conda/venv/poetry/pipenv） + **git 分支**
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

21 个插件，6 个市场，分为多组：

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

**AI 研究插件**（6 个）— 在交互式菜单中选择，或通过 `--all` 安装：

| 插件 | 市场 | 功能 |
|------|------|------|
| [**tokenization**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | HuggingFace Tokenizers、SentencePiece |
| [**fine-tuning**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | Axolotl、LLaMA-Factory、PEFT、Unsloth |
| [**post-training**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | GRPO、RLHF、DPO、SimPO |
| [**inference-serving**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | vLLM、SGLang、TensorRT-LLM、llama.cpp |
| [**distributed-training**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | DeepSpeed、FSDP、Megatron-Core、Ray Train |
| [**optimization**](https://github.com/Orchestra-Research/AI-Research-SKILLs) | ai-research-skills | AWQ、GPTQ、GGUF、Flash Attention、bitsandbytes |

**健康插件**（1 个）— 在交互式菜单中选择，或通过 `--all` 安装：

| 插件 | 市场 | 功能 |
|------|------|------|
| [**health**](https://github.com/tw93/claude-health) | claude-health | Claude Code 会话健康检查和状态面板 |

详见 [`plugins/README.md`](plugins/README.md) 了解安装方式。

### 版本变更日志策略

CLAUDE.md 包含 **版本变更日志** 规则：在做版本级改动（新功能、重大重构、Breaking Change）时，Claude 会主动在项目根目录维护 `CHANGELOG.md`，每条记录包含功能、设计理念和注意细节。使设计决策与代码同步可追溯。

### 自定义技能

| 技能 | 说明 |
|------|------|
| **paper-reading** | 结构化论文阅读与总结，自动截图关键图表。优先使用 ar5iv HTML 版本，Playwright 截图，输出标准化 Markdown（问题、方法、实验、洞见）。 |
| **[adversarial-review](https://github.com/poteto/noodle/tree/main/.agents/skills/adversarial-review)** | 跨模型对抗式代码审查。在对立 AI 模型（Claude ↔ Codex）上生成审查者，使用不同批判视角（怀疑者、架构师、极简主义者），合成结构化裁决（PASS/CONTESTED/REJECT）。 |
| **[humanizer](https://github.com/blader/humanizer)** | 检测并去除文本中的 AI 写作痕迹。基于维基百科"AI 写作特征"指南，识别内容、语言、风格、沟通 4 大类共 24 种模式（意义膨胀、AI 高频词、破折号滥用、谄媚语气等），将文本改写为自然人类风格。 |
| **update_config** | Session 内更新命令。在 Claude Code 中输入 `/update_config` 即可检查新版本并重新运行交互式安装器，无需离开当前会话。 |

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
- [**Anthropic Engineering**](https://www.anthropic.com/engineering) by Anthropic — 工程博客，涵盖 Agent 开发、评估方法与构建可靠 AI 系统
- [**OpenAI Engineering**](https://openai.com/news/engineering/) by OpenAI — 工程博客，分享构建和扩展 AI 系统的技术洞察
- [**Claude Code Best Practice**](https://github.com/shanraisshan/claude-code-best-practice) by shanraisshan — Claude Code 最佳实践、工作流与实现模式的全面知识库

## 许可证

MIT
