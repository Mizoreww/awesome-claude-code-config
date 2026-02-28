[Main English](https://github.com/Mizoreww/claude-code-config/blob/main/README.md) | [Main 中文](https://github.com/Mizoreww/claude-code-config/blob/main/README.zh-CN.md) | [Codex English](./README.md) | **Codex 中文**

# Codex 配置

面向生产使用的 Codex 配置：全局指令、基于 lessons 的自我纠正、通过技能实现分层编码规范、MCP 集成，以及一键安装。

## 目录结构

```
.
├── AGENTS.md              # 全局指令
├── config.toml            # Codex 设置（模型、权限、MCP、lessons 注入）
├── lessons.md             # 自我纠正源日志
├── skills/                # 可选自定义技能
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

### 自我改进循环（仅 lessons）

1. 用户纠正会记录到 `~/.codex/lessons.md`
2. 新会话自动加载 `~/.codex/lessons.md`
3. 稳定模式沉淀到 `~/.codex/AGENTS.md`

### lessons 自动注入

`config.toml` 使用：

```toml
model_instructions_file = "~/.codex/lessons.md"
```

这样在会话开始时就会加载纠错规则。

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

- [**我给 10 个 Claude Code 打工**](https://mp.weixin.qq.com/s/9qPD3gXj3HLmrKC64Q6fbQ) by 胡渊明 — 多个编码 Agent 并行协作的实践经验
- [**Harness Engineering**](https://openai.com/zh-Hans-CN/index/harness-engineering/) by OpenAI — 从“写代码”转向“设计系统并驾驭 Agent”
- [**Claude Code in Action**](https://anthropic.skilljar.com/claude-code-in-action) by Anthropic Academy — 官方工作流课程

## 许可证

MIT
