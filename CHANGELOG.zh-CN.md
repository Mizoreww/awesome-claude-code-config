# 更新日志

## [2.6.1] - 2026-05-25

### 新功能
- **新增内置 skill：`handoff`**（来自 [`mattpocock/skills`](https://github.com/mattpocock/skills/blob/main/skills/productivity/handoff/SKILL.md)）—— 把当前对话压缩成一份交接文档并写入操作系统的临时目录，方便下一个 agent 直接接手而无须继承完整上下文。文档包含 `suggested skills` 章节、用路径/URL 引用已有制品（PRD、计划、ADR、issue、commit、diff）而非重复粘贴、并对密钥与隐私敏感信息做脱敏。已注册到两个安装器的 **Workflow** 分组，**默认开启**。

### 注意事项
- skill 会把交接文档写入用户操作系统的临时目录（如 `/tmp` 或 `%TEMP%`），不会污染当前仓库。
- 原作者归属以 HTML 注释形式保留在 `skills/handoff/SKILL.md` 顶部。

## [2.6.0] - 2026-05-22

### 新功能
- **`paper-reading` skill 新增 HTML 输出模式。** 当用户未指明时，skill 会先询问要 Markdown 总结（轻量、省 token，适合归档与再编辑）还是 HTML 总结（更好看、更费 token）。HTML 模式复用与 Markdown 完全相同的内容骨架（论文类型模板、深度优先写法、抽取的图表），但配以整洁的阅读排版，并在关键理解点处**手绘内联 SVG 示意图**（架构/流水线、算法流程、朴素 vs 改进方案对比）。新增 `Step 0: Choose Output Format` 作为流程入口；`HTML Output Mode` 小节说明页面骨架、可选的 MathJax（CDN 渲染公式）以及 SVG 绘图规范。

### 设计取舍
- **询问而非猜测**：md 与 html 的 token 成本差异真实存在，意图不明确时让 skill 把权衡摆给用户，而非静默走默认。
- **用内联 SVG 而非 Mermaid/CDN** 画图：为了完全离线自包含与最大可控性；唯一的网络依赖是可选的 MathJax 公式渲染，且离线时优雅降级为原始 LaTeX。
- **HTML 用相对路径引用 `./images/`**（而非 base64 内嵌）：保持文件精简，并复用 md 路径已经抽取的同一批图。
- **同样的实质、更好的呈现**：HTML 被明确定位为"同一份分析、呈现得让人更快读懂"，绝非更单薄的总结——并由新增的 Common Mistakes 条目守住这一点。

### 注意事项
- HTML 产物随其同级 `images/` 目录一起移动；单独搬走 `.html` 会丢失论文原图（重绘的 SVG 仍可显示）。
- 仓库源文件 `skills/paper-reading/SKILL.md` 与已安装副本 `~/.claude/skills/paper-reading/SKILL.md` 同步更新并校验一致。

## [2.5.2] - 2026-04-21

### 重构
- **将 `env.CLAUDE_CODE_NO_FLICKER` 替换为顶层 `"tui": "fullscreen"`**：`tui` 是官方 schema 为"无闪烁全屏渲染"提供的原生字段。Schema 明确说明 `tui: "fullscreen"` "equivalent to `CLAUDE_CODE_NO_FLICKER=1`"。使用 schema 字段在配置上更规范、可被 JSON Schema 校验，并让 `env` 只保留没有原生字段对应的环境变量。

### 注意事项
- 行为完全一致——同样的全屏渲染器、同样的虚拟滚动缓冲。
- `env` 仍保留 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 和 `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING`，因为二者目前没有原生 schema 字段对应（`alwaysThinkingEnabled: false` 会完全禁用 thinking，语义不同）。

## [2.5.1] - 2026-04-21

### 错误修复
- **`effortLevel` 默认值由 `max` 改为 `xhigh`**：`max` 不能作为持久默认值——Claude Code 的 `settings.json` 中 `effortLevel` 字段（以及环境变量 `CLAUDE_CODE_EFFORT_LEVEL`）仅接受 `low` / `medium` / `high` / `xhigh`。`max` 档位被官方刻意设计为会话级，只能通过 `/effort max` 每次会话手动开启。此前默认的 `max` 会被静默忽略。
- **移除 `betas: ["extended-cache-ttl-2025-04-11"]`**：1 小时提示缓存 TTL 已正式发布（GA），该 beta header 已不再需要。保留过期的 beta ID 只是无效配置。

### 注意事项
- 如需 `max` 推理强度，请每次会话手动执行 `/effort max`——这是 Anthropic 对最高档位的刻意设计。
- 移除 beta header 后，1h 缓存 TTL 仍原生支持。

## [2.5.0] - 2026-04-21

### 新特性
- **新增插件 `andrej-karpathy-skills`**（marketplace `karpathy-skills`，仓库 `forrestchang/andrej-karpathy-skills`），默认启用。提供 Karpathy 风格的编码行为指引（Think-Before-Coding、Simplicity-First、Surgical Changes、Goal-Driven Execution），用于降低常见 LLM 编码失误。
- **`everything-claude-code` 改为默认关闭**。从 essentials 组移动到新的 optional 组，仅在使用 `--all` 或手动勾选时安装。
- **安装器尊重未选中状态**：运行安装器时，未在菜单中勾选但本地 `settings.json` 已有（或属于我方插件目录）的插件，会在 `enabledPlugins` 中写为 `false`。此前由于 merge 逻辑偏好已有值，未选中的插件可能仍处于启用状态。
- **菜单重新分组**：取消旧的 "Plugins — Official" / "Plugins — Community" / "Skills" 分组，按用途重排。插件与 skill 不再按来源区分，而是按用途并列展示：
  - **Workflow**（8）：andrej-karpathy-skills、superpowers、feature-dev、ralph-loop、commit-commands、code-simplifier、everything-claude-code、`update-config`（skill）
  - **Integrations**（3）：context7、github、playwright
  - **Design & Content**（5）：document-skills、example-skills、frontend-design、`humanizer`（skill）、`humanizer-zh`（skill）
  - **Memory & Lifestyle**（3）：claude-mem、claude-health、PUA
  - **Academic Research**（10）：`paper-reading`（skill）+ 6 个 AI-Research 插件 + 3 个 DeepXiv skill（原 9 项）
  分组标签不再带冗余的 "Plugins —" 前缀。

### 设计理由
- Karpathy 的指引偏通用，适合大多数编码会话，故纳入 essentials。而 everything-claude-code 覆盖面广且风格强烈，改为默认关闭以减少与用户自选标准的冲突。
- 新的 enabledPlugins 规则让交互式菜单具有"最终决定权"：选中即启用，未选中即关闭。本地 `settings.json` 中我方目录之外的键仍然保留，避免误删用户自行添加的插件。

### Bug 修复（复审后）
- **`enabledPlugins` catalogue 现在包含当前选择**。此前菜单里选中但未在 shipped `settings.json` 中声明的插件（`codex@openai-codex`、`health@claude-health`、`pua@pua-skills`）会被 `claude plugin install` 装好但被 filter 丢掉——Claude Code 视其为未启用。现在 catalogue = base keys ∪ `$selected`。
- **Fallback 合并顺序纠正**。未交互插件时的 union 合并改为 existing 值胜出（jq 里 `$base * $over`，PowerShell 里 `$mergeHt $incoming $existing`）。此前运算对象写反，会让 v2.4.x 的用户在"只升级不动插件"时把 `everything-claude-code: true` 静默翻成 `false`。
- **`install_jq` 提到 `install_settings` 顶部**。无 jq 的机器上，fresh install 且保留 statusline+lessons 时不再静默跳过插件 filter。
- **Dry-run 横幅文案与实际语义一致**。此前 `--dry-run` 一律打印 "enabledPlugins: union (new plugins added, existing preserved)"，哪怕真跑时走的是 selection-aware rebuild；现在按 `$INSTALL_PLUGINS` 分支显示。

### Windows 菜单对齐
- install.ps1 现在支持 **→（右方向键）** 打开分组子菜单、**←（左方向键）** 返回主菜单，与 install.sh 对齐。两脚本提示文案同步更新。
- README 列出完整快捷键：主菜单（↑↓ / Enter 或 → / q）、子菜单（↑↓ / Space / ← 或 Esc）、快捷（a / n / d）。

### 注意事项
- 在 `install.sh` 和 `install.ps1` 中新增 `PLUGINS_OPTIONAL` 组，`--all` 模式会同时展开 `PLUGINS_ESSENTIAL + PLUGINS_OPTIONAL`。
- 选择感知的 enabledPlugins 合并仅在安装器处理了插件（`INSTALL_PLUGINS=true`）时生效；若本次只安装 `settings.json` 而未进入插件选择，沿用 fallback union 合并以保留现状。
- 已有用户：之前启用的插件，只有在菜单中再次勾选才会保持启用。建议跑一遍交互式菜单复核。
- README.md 与 README.zh-CN.md 大幅精简（从 349 → 约 195 行）：与 `plugins/README.md` 重复的逐插件细节被合并，同时保留交互菜单对应的完整链接与默认值表格。

## [2.4.0] - 2026-04-21

### 新特性
- **默认权限模式 `auto`**：`settings.json` 默认使用 `permissions.defaultMode = "auto"`，让 Claude 自动批准安全操作、拦截高风险操作。安装器自动检测 Claude Code 版本，低于 2.1.80 时自动降级为 `bypassPermissions`（原有逻辑，保持不变）。
- **最大推理强度**：在 `settings.json` 顶层新增 `effortLevel: "max"`，让 `/effort` 默认固定在最高档。旧版 CLI 不识别 `max` 时会自动回退到 `xhigh` / `high`。
- **1 小时提示缓存 TTL**：`betas: ["extended-cache-ttl-2025-04-11"]` 启用扩展提示缓存（1 小时），替代默认的 5 分钟 TTL，显著降低长会话的缓存 churn。
- **无闪烁渲染**：`env.CLAUDE_CODE_NO_FLICKER = "1"` 切换到全屏渲染模式（等价于 `/tui fullscreen`）。
- **默认关闭 adaptive thinking**：`env.CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING = "1"` 把思考预算固定到 `MAX_THINKING_TOKENS`，不再按轮自适应。Opus 4.7 不受此开关影响（始终自适应）。

### 设计理由
- 把这些"一键开启"的默认集中到一处，简化上手——想要原版行为的用户只需改一行，其余人直接享受高配。
- 未知键（`effortLevel`、`betas`）在旧版 Claude Code 中会被静默忽略，因此无需为它们写版本门控。
- 只有 `auto` 模式真正需要降级，`install.sh` 中已有的 `_supports_auto_mode` 检测足够。

### 注意事项
- `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING` 和 `CLAUDE_CODE_NO_FLICKER` 需要 Claude Code 2.1.104+。在更早的版本中是无害的空操作。
- Opus 4.7 始终开启 adaptive thinking，不受该开关控制——如需严格固定预算，请切换到其他模型。

## [2.3.1] - 2026-04-12

### 错误修复
- **Windows 远程安装崩溃**：修复 PowerShell 5.x 中通过 `irm URL | iex` 安装时报 `ParameterBindingException` 的问题。内部令牌（如 `"adversarial-review"`）泄漏到 `$args` 并作为位置参数传给 `Invoke-Expression`。现在通过过滤 `$args`，仅传递以 `-` 开头的 switch 参数。

### 设计理由
- `$_safeArgs` 过滤器替代原始 `@args` splatting——本地 `.\install.ps1 -All` 仍然正常工作，同时防止 `irm | iex` 管道模式下的垃圾令牌泄漏。

## [2.3.0] - 2026-04-10

### 新特性
- **自适应状态栏换行**：状态栏根据终端宽度动态换行，而非截断。使用 ANSI 感知的可见宽度计算。
- **自适应进度条缩放**：Context 和 5h usage 进度条在空间不足时自动缩短（最小 8 字符），尽量保持在同一行。
- **智能终端宽度检测**：通过 `/proc/$PID/fd/` 遍历祖先进程文件描述符，在管道环境中找到真实终端宽度。
- **DeepXiv SDK 集成**：新增学术研究分组，内含 `deepxiv_sdk` 插件，支持学术论文搜索与分析。

### 错误修复
- **管道环境 COLUMNS=0**：Claude Code 向状态栏子进程传递空/零 COLUMNS，现已检测并回退到 fd 探测。
- **macOS `wc -L` 兼容**：`visible_len()` 在 `wc -L` 不可用的平台（BSD/macOS）上回退到 `${#stripped}`。
- **负值进度条缩放修复**：前置段超出可用空间时，自适应缩放现在正确 clamp 而非静默使用 20 字符全宽。
- **宽度缓存**：段宽度缓存到并行数组，每次渲染的子 shell fork 从 ~13 次降至 ~7 次。

### 设计理由
- 段数组架构替代字符串拼接，清晰分离布局关注点
- PPID fd 遍历比 `/dev/pts/*` glob 更准确，后者可能读到其他会话的终端
- `visible_len()` 使用 `wc -L`（GNU）处理 emoji/CJK 双宽字符，`${#}` 作为可移植性回退

### 注意事项
- 换行仅在段边界处发生；单个段宽于终端时自然溢出
- 硬编码标签开销估计（18/14 字符）在极端情况下可能偏差 1-2 字符

## [2.2.0] - 2026-04-02

### 新特性
- **二级交互式菜单**：主菜单显示分组摘要（`[已选/总数]`），Enter/→ 进入子菜单，←/Esc 返回。分组：Core、Language Rules、Review、Skills、Plugins — Official/Community/AI Research、MCP Servers。
- **Review 工具选择器**：新增 "Review" 分组——`code-review` 插件（开）、`adversarial-review` skill（开）、Codex CLI（关）。adversarial-review 和 Codex 互斥，自动联动。
- **恢复 adversarial-review skill**：跨模型审查（Claude↔Codex），怀疑者/架构师/极简主义者三重视角，来自 [poteto/noodle](https://github.com/poteto/noodle)。
- **新增 humanizer-zh skill**：来自 [op7418/Humanizer-zh](https://github.com/op7418/Humanizer-zh) 的中文去 AI 痕迹 skill。
- **单插件粒度选择**：23 个插件可单独选择/取消（之前按组捆绑）。
- **CLAUDE.md Code Review 段动态生成**：安装器根据选择的审查工具动态修改 CLAUDE.md 中的 Code Review 规则。
- **方向键导航**：←/→ 支持子菜单进入/退出，与 Enter/Esc 并行。

### Bug 修复（bash 5.x / Linux）
- **根因**：`(( var++ ))` 从 0 自增时返回 exit code 1，bash 5.x `set -e` 下直接杀掉脚本（macOS bash 3.2 不受影响）。全部修复：`(( flat_idx++ ))` → `(( ++flat_idx ))`，`(( fixed++ ))` → `(( ++fixed ))`，`(( cnt++ ))` 加 `|| true`。
- **`[[ ]] && cmd` 缺少 `|| true`**：`_enforce_review_mutex` 和主菜单 ALL 模式中，循环最后一次迭代不匹配时返回 1 导致崩溃。全部加了 `|| true`。
- **`local _menu_active`**：bash 5.x 下 trap handler 无法访问 local 变量，改为全局变量。
- **install.ps1**：删除残留的 `$groups` 覆盖，修复 Windows 交互式菜单崩溃。
- **终端 fd 探测**：检测 `/dev/tty` 断开（EOF）时自动降级为非交互安装。仅拒绝 EOF (ret=1)，不误杀残留输入 (ret=0)。
- **EXIT trap**：`_menu_cleanup` 加入 EXIT trap，异常退出时恢复终端。

### 设计考量
- 二级菜单紧凑且细粒度可控
- 互斥机制防止审查工具冲突
- 所有 `(( ))` 算术和 `[[ ]] && cmd` 模式已系统性加固 `set -e` 防护
- fd 探测提供纵深防御，不产生误报

### 注意事项
- `--all` 安装全部内容，默认使用 adversarial-review（非 Codex）
- 选择 Codex CLI 会自动安装 `codex@openai-codex` 插件
- adversarial-review skill 需要 `codex` CLI 以实现跨模型审查

## [2.1.0] - 2026-04-02

### 新特性
- **Codex adversarial-review 插件**：用官方 [Codex 插件](https://github.com/openai/codex-plugin-cc)（`codex@openai-codex`）替代内置 `adversarial-review` skill。代码审查使用 `/codex:adversarial-review`，Codex 不可用时自动回退到 Claude 的 `code-reviewer` agent。插件已包含在默认安装中。
- **技能重命名**：将 `/update` 恢复为 `/update-config`——目录从 `skills/update/` 重命名为 `skills/update-config/`。安装器升级时自动清理旧的 `skills/update` 和 `skills/adversarial-review` 目录。
- **Smart-merge enabledPlugins 策略变更**：从"existing wins"改为"union"——新插件会自动补充到现有配置中，确保升级用户自动获得 `codex@openai-codex` 等新插件。

### 设计理念
- Codex 插件提供官方维护的对抗式审查实现，共享运行时，集成度更高
- 带命名空间的技能命令（`update-config`）防止在所有仓库中意外覆盖项目级 `/update` 命令
- enabledPlugins 的 union 合并确保升级用户自动获得新插件，同时保留现有配置
- 回退审查路径（`code-reviewer` agent）确保没有 Codex CLI 也能正常审查代码

### 注意事项
- Codex 插件需要通过 `codex login` 认证（运行 `/codex:setup` 检查状态）
- `docs/adversarial-review-showcase.md` 作为历史参考保留
- CHANGELOG 中 `update_config` 和 `adversarial-review` 的历史条目保持原样
- 安装器迁移逻辑自动删除旧的 `skills/update` 和 `skills/adversarial-review` 目录

## [2.0.0] - 2026-03-27

### 新特性
- **Auto 模式默认启用**：`settings.json` 现在默认使用 `defaultMode: "auto"` 替代 `bypassPermissions`。Auto 模式（于 2026-03-24 发布）让 Claude 能自主批准安全操作同时拦截高风险操作——更适合高级用户的安全中间地带。安装器会自动检测 Claude Code 版本，低于 2.1.80 的版本自动降级为 `bypassPermissions`。

### 设计理念
- Auto 模式在执行前对每个工具调用进行风险分类，安全操作自动执行，高风险操作被拦截
- `install.sh` 中的版本检测（`_supports_auto_mode`）确保向后兼容，无需用户干预
- 区分"Claude Code 未安装"和"版本过旧"两种情况，提供不同的警告信息

### 注意事项
- Auto 模式需要 Claude Sonnet 4.6 或 Opus 4.6 模型，Haiku、claude-3 系列及第三方服务商（Bedrock、Vertex、Foundry）不支持
- Auto 模式在 Team 计划中为研究预览版，Enterprise 和 API 支持正在逐步推出
- `sed -i` 回退方案替换为可移植的 `sed > tmp && mv`，兼容 macOS

## [1.9.4] - 2026-03-27

### 新特性
- **paper-reading 技能**：用纯 PDF + pymupdf4llm 自动提取流程替换了不稳定的 ar5iv HTML + Playwright 截图方案。图表、矢量图和表格现在通过 `pymupdf4llm.to_markdown(write_images=True)` 直接从 PDF 提取，并自动过滤和重命名。

### 设计理念
- ar5iv 覆盖率不完整——很多论文没有 HTML 版本，导致截图流程完全失败
- pymupdf4llm 将 `get_images()`、`cluster_drawings()` 和 `get_pixmap(clip=...)` 封装为单次调用，自动处理栅格图和矢量图
- 添加优雅降级：纯理论类论文（无实质图表）只输出纯文字摘要

### 注意事项
- 需要安装 `pymupdf4llm` 包（会自动安装 `pymupdf` 作为依赖）
- OCR 默认关闭（`use_ocr=False`），避免对 tesseract 的依赖
- 模板图片占位符从硬编码的 `figure_X.png` 改为 HTML 注释引导

## [1.9.3] - 2026-03-26

### 新特性
- **PUA 插件**：新增 [tanweai/pua](https://github.com/tanweai/pua) 作为新插件组——AI Agent 生产力倍增器，支持多语言（中/英/日），强制穷举式问题解决和系统化调试

### 设计理念
- PUA 是社区热门插件，显著提升 Agent 的持续性和问题解决深度
- 作为可选组（默认关闭）加入，保持轻量安装，不影响不需要的用户

### 注意事项
- 新增市场 `pua-skills`（共 7 个市场，22 个插件）
- install.sh 和 install.ps1 均已更新，支持新插件组、菜单项、调度和卸载
- README.md 和 README.zh-CN.md 均已更新插件表格

## [1.9.2] - 2026-03-20

### 新特性
- **内置 MesloLGS NF 字体**：将在线下载 JetBrainsMono Nerd Font（GitHub ~30MB zip）替换为内置 4 个 MesloLGS NF .ttf 文件（总计约 10MB）——字体安装即时完成，无网络依赖

### 设计理念
- GitHub Release 下载在网络差的环境中缓慢且不稳定，会阻塞整个安装流程
- MesloLGS NF 是成熟的 Nerd Font（Powerlevel10k 使用），提供状态栏所需的相同 Powerline/图标字形
- 将约 10MB 字体内置到仓库是可接受的权衡，优于安装时需要网络访问

### 注意事项
- 字体文件来自 romkatv/powerlevel10k-media（Apache 2.0 许可）
- install.sh 和 install.ps1 均已更新，不再使用 curl/wget/Invoke-WebRequest 下载字体
- 终端字体提示从 'JetBrainsMono Nerd Font' 改为推荐 'MesloLGS NF'

## [1.9.1] - 2026-03-17

### 新特性
- **paper-reading pymupdf 修复**：修复对抗式代码审查发现的 5 个问题——移除阻塞 PDF 图表提取的 Step 1/Step 3 矛盾描述，添加矢量图检测引导（`get_drawings()`/`get_text("dict")`），修复输出路径一致性，明确 `extract_image` 与基于 clip 渲染方式的区别，添加 pymupdf 可用性预检
- **对抗式审查展示**：添加 adversarial-review 技能展示，4 张截图演示跨模型审查工作流（范围分析 → 审查者召集 → 裁决综合 → 主导判断）

### 设计理念
- Step 1 的"无法截图图表"提示与新的 Path B pymupdf 工作流矛盾——按流程操作的 Agent 会在到达图表提取步骤前就停下来
- 矢量图检测至关重要，因为许多研究论文将折线图、图表和表格编码为矢量/文本对象而非栅格图
- `extract_image(xref)` 返回不带页面级注释的原始嵌入图片——基于 clip 的渲染对大多数图表类型更安全，应作为默认方式

### 注意事项
- Path B PDF 图表提取需要 pymupdf（`pip install pymupdf`）
- 对抗式审查展示截图来自真实审查 session

## [1.9.0] - 2026-03-14

### 新特性
- **claude-health 插件**：在交互式安装器中新增 [claude-health](https://github.com/tw93/claude-health) 作为独立插件组——为 Claude Code 会话提供健康检查和状态面板
- **状态栏 Bug 修复**：修复 context 大小为空时 `fmt_ctx()` 的整数比较错误——`local s=$1` 改为 `local s=${1:-0}`，防止 `[: : integer expression expected` 警告

### 设计理念
- claude-health 作为独立组（类似 claude-mem）而非 Essential 的一部分——它是可选的，用户可能不希望有健康监控开销
- 状态栏修复使用 shell 参数展开默认值（`${1:-0}`），POSIX 兼容，同时处理空值和未设置的变量

### 注意事项
- claude-health 市场来源：`tw93/claude-health`（GitHub）
- 插件总数：6 个市场 21 个（之前是 5 个市场 20 个）

## [1.8.2] - 2026-03-13

### 新特性
- **StatusLine 和 Lessons 现在是独立菜单选项**：原来的"Hooks"项拆分为"StatusLine"（渐变进度条 & 用量显示）和"Lessons"（lessons.md 模板 + SessionStart 自动加载 hook）。用户可以单独安装任一项
- **条件式 settings.json 合并**：`statusLine` 和 `hooks.SessionStart` 字段只在对应菜单项被选中时才合并/包含
- **自动启用 settings.json**：选择 StatusLine 或 Lessons 但尚无 settings.json 时会自动启用（配置所必需）
- **jq 不可用警告**：全新安装时没有 jq 会提示无法从 settings.json 中去除未选中字段

### 设计理念
- 解决 issue #12：不想要状态栏的用户现在可以单独取消选择
- 原"Hooks"项将两个不相关的功能捆绑在一起——状态栏显示和 lessons 自动加载，使用场景不同
- `install_statusline()` 现在只复制 `statusline.sh`（而非 hooks/ 下的所有文件），避免未来的 hook 文件被错误捆绑

### 注意事项
- 已有用户重新运行安装器且取消选择 StatusLine/Lessons 时，现有配置保持不变（安全升级——安装器不会删除之前安装的设置）
- 在没有 jq 的系统上，带有部分选择的全新安装会复制完整的 settings.json 模板并警告包含了额外字段

## [1.8.0] - 2026-03-11

### 新特性
- **`/update_config` 技能**：会话内更新命令——在 Claude Code 中输入 `/update_config`，即可检查新版本并重新运行交互式安装器，无需离开当前会话。对比已安装版本和远程 VERSION，下载最新 `install.sh` 并启动交互式选择器。

### 设计理念
- 基于技能的方案（相比独立脚本）让用户只需一个斜杠命令就能在任意 Claude Code 会话中更新，无需切换终端
- 复用现有的 `install.sh` 远程模式和智能合并——无需维护新的更新逻辑

### 注意事项
- 需要网络访问以获取远程 VERSION 和安装器
- 安装器的智能合并会保留现有 `settings.json` 自定义，且永不覆盖 `lessons.md`

## [1.7.0] - 2026-03-11

### 新特性
- **状态栏显示所有虚拟环境**：状态栏现在可检测 conda（包括 `base`）、Python venv、poetry 和 pipenv 环境。优先级：conda > venv/poetry/pipenv
- **README 文档修复**：交互式菜单示例现在列出 humanizer 技能；状态栏描述现在提及虚拟环境显示
- **字体安装改进**：优先使用 `fc-list` 检测而非文件名 glob（可捕获系统安装的字体）；添加明确的下载超时（连接 10s，总计 120s），防止卡住
- **更新状态栏截图**：替换为当前外观的展示图

### 设计理念
- 显示 conda `base` 是有用的——用户希望确认当前激活的环境，即使是默认环境
- `fc-list` 比文件名 glob 更可靠，因为系统打包的字体可能使用不同的命名规范
- 120s 的下载超时与 Nerd Font zip 大小（约 30MB）在慢速连接下匹配，同时避免无限期挂起

### 注意事项
- 虚拟环境检测依赖环境变量（`CONDA_DEFAULT_ENV`、`VIRTUAL_ENV`）；未设置这些变量的手动激活环境不会被检测到
- conda 和 venv 同时激活时，conda 优先

## [1.6.0] - 2026-03-11

### 新特性
- **jq 自动安装（bash）**：`install.sh` 现在通过包管理器（brew/apt/dnf/yum/pacman/apk）自动安装 jq，或将预构建二进制下载到 `~/.claude/bin/jq`——settings.json 智能合并不再静默跳过
- **状态栏显示 conda 环境**：在目录和 git 分支段之间显示当前激活的 conda 环境名
- **重新安装时跳过市场**：安装器在重试前检查 `~/.claude/plugins/marketplaces/{name}` 是否存在，节省重复安装的约 75 秒
- **Emoji 检测 + 文字回退**：状态栏检测 UTF-8 locale、终端类型和 Nerd Font 可用性——在不支持的终端上回退为文字标签（`M:`、`D:`、`py:`、`br:`）
- **Nerd Font 自动安装**：安装器下载并安装 JetBrainsMono Nerd Font 以支持 Powerline git 分支图标；提示用户设置终端字体

### 设计理念
- jq 安装采用分层方案：先检查 PATH，再检查 `~/.claude/bin/`，然后是包管理器（带 sudo），最后是静态二进制下载（无需 sudo）——覆盖 CI、macOS、Linux 桌面和最小化容器
- conda 显示包括所有环境（含 `base`），增强环境感知
- 市场目录检查是"已注册"的最快可靠指标——避免 `claude plugin marketplace add` 在重复添加时报错导致的 5×3s 重试超时
- 图标回退链：emoji（UTF-8 终端）> Nerd Font（fc-list 检测到）> 文字标签（哑终端/非 UTF-8 终端）——确保状态栏始终可读

### 注意事项
- jq 二进制下载需要 `curl` 或 `wget` 及网络访问；包管理器安装可能需要 `sudo`
- Nerd Font 下载约 30MB；用户安装后需手动设置终端字体
- conda 显示读取 `$CONDA_DEFAULT_ENV`——适用于 conda activate，但不适用于直接操作 `python` 路径

## [1.5.1] - 2026-03-09

### 新特性
- **远程安装现在默认交互式**：一行安装（`curl | bash`、`bash <(curl ...)`）会启动交互式选择器——当 stdin 是管道时从 `/dev/tty` 读取键盘，当 stdin 是 tty 时直接从 stdin 读取
- **`confirm()` 提示也支持管道 stdin**：卸载确认提示现在通过相同设备配对输出和输入（管道时用 `/dev/tty`，正常时用 stdout+stdin）
- **集中式终端检测**：单一 `can_interact()` 函数替代了 `parse_args`、`interactive_menu` 和 `confirm` 中的重复检查

### 设计理念
- `bash <(curl ...)` 已保留终端 stdin；`/dev/tty` 回退专门处理 stdin 携带脚本的 `curl URL | bash` 情况
- 当 fd 0 是 tty 时，交互式菜单优先使用 stdin，只将 `/dev/tty` 作为回退——不会影响缺少 `/dev/tty` 的容器
- 只在 stdin 和 `/dev/tty` 均不可用时（如无头 CI）回退到默认安装（仅 essential 插件）

## [1.5.0] - 2026-03-09

### 新特性
- **Windows 交互式安装器**：`install.ps1` 现在与 bash 版本具有相同的方向键交互菜单，使用 `[Console]::ReadKey()` 进行导航
- **Windows CLI 简化**：PowerShell 参数精简为 `-All`、`-Uninstall`、`-Version`、`-DryRun`、`-Force`（与 bash 对齐）
- **Windows 插件组对齐**：Essential（13 个）+ claude-mem（1 个）+ AI Research（6 个）结构现在与 bash 安装器一致
- **Windows 语言规则清理**：取消选择的语言目录会自动删除，与 bash 行为一致

## [1.4.0] - 2026-03-09

### 新特性
- **交互式安装器**：不带参数运行 `./install.sh` 会启动多选菜单——按数字切换组件，Enter 确认
- **插件组简化**：13 个通用插件合并为一个 Essential 组（默认开启）；claude-mem 单独拆出作为独立切换项（默认关闭）
  - Essential（13 个）：everything-claude-code, superpowers, code-review, context7, commit-commands, document-skills, playwright, feature-dev, code-simplifier, ralph-loop, frontend-design, example-skills, github
  - claude-mem（1 个）：独立分出——每 session 注入约 3k tokens（观测索引 + session 摘要）
- **语言规则按需安装**：在交互模式下，Python/TypeScript/Go 规则默认关闭——只安装项目需要的
- **自动清理**：选择特定语言规则时，之前安装的未选中语言目录会自动删除
- **方向键交互菜单**：↑↓ 导航，Enter 切换，Submit 按钮确认
- **CLI 简化**：删除 8 个组件选择标志（`--rules`、`--plugins`、`--mcp`、`--skills`、`--lessons`、`--hooks`、`--claude-md`、`--settings`）；只保留 `--all`、`--uninstall`、`--version`、`--dry-run`、`--force`
- **`--all` 现在安装全部**：包括 MCP 和所有插件组（之前不包括 MCP）

### 设计理念
- 解决 context 累积问题（#7）：默认安装会将约 9k tokens 的规则（包括未使用的语言）+ 大量插件技能列表注入每个 session
- 交互式菜单取代了记忆 CLI 标志的需要——用户一目了然看到所有选项及合理默认值
- CLI 标志删除：组件选择标志与交互式菜单冗余；`--all` 是唯一需要的非交互式安装路径
- claude-mem 单独分出——它是唯一在 SessionStart 时注入约 3k tokens 的插件（观测索引 + session 摘要）；其他 Extended 插件只注册工具/技能名称
- 保留非交互式回退：无 tty 的无头/CI 安装只安装 essential 插件（不含 MCP）；显式 `--all` 安装全部包括 MCP 和所有插件组
- 未知/已删除的 CLI 标志现在报错退出，而非静默降级

### 注意事项
- `--all` 现在安装全部（所有插件、MCP、所有语言规则）
- 远程安装（`bash <(curl ...)`）现在默认显示交互式菜单（v1.5.1+）；添加 `--all` 可非交互式完整安装

## [1.3.0] - 2026-03-09

### 新特性
- 完整卸载现在默认包括插件和 MCP（之前省略）
- 安装警告追踪：合并或插件安装失败时跳过版本戳记并报告警告数
- 卸载前将 `settings.json` 备份为 `settings.json.bak`
- `--all` 标志现在可与其他标志组合（如 `--all --mcp` 安装全部加 MCP）
- Windows 安装器检查 bash 可用性并在缺失时警告（状态栏和 hooks 需要）
- 对抗式审查技能不再需要缺失的 `brain/principles.md`；改用 `reviewer-lenses.md` 作为自包含来源

### Bug 修复
- VERSION 环境变量经过净化，防止远程安装中的命令注入
- 重复安装不再创建嵌套目录（如 `paper-reading/paper-reading/`）
- `stat` 回退顺序修复：优先尝试 Linux `stat -c %Y`，macOS `stat -f %m` 作为回退
- Windows 安装器 AI Research 组中缺少 `tokenization` 插件（5/6 → 6/6）

### 文档
- 自我改进循环措辞说明："auto-saved" → "Claude 根据 CLAUDE.md 指令驱动的纠错写入"
- 卸载示例注释更新为"（含插件和 MCP）"
- 手动插件安装文档更新，包含所有市场 `add` 命令和 `name@marketplace` 语法

### 设计理念
- 警告追踪防止用户误以为部分失败的安装是最新版本
- 卸载时备份 settings 防止意外丢失安装器合并的用户配置
- VERSION 净化关闭了远程安装路径中的真实攻击向量（`bash -c` 接受不可信输入）

### 注意事项
- `bypassPermissions` 默认保持不变（按设计为高级用户配置）
- 对抗式审查仍需要对立 CLI（`codex`/`claude`）——这是设计行为，不是 bug

## [1.2.0] - 2026-03-07

### 新特性
- Windows 支持，带 PowerShell 安装器（`install.ps1`）
- 对抗式代码审查技能（通过对立 AI CLI 进行跨模型审查）
- AI Research 技能组新增 tokenization 插件（huggingface-tokenizers、sentencepiece）
- 跨平台网页搜索日期指令（系统命令 + 回退方案）
- README 导航中新增 Codex 分支链接

### Bug 修复
- 第三方 API 用户的状态栏非阻塞处理
- Bash 3.2 兼容性（用字符串匹配替换关联数组）
- 安装器网络操作重试逻辑（5 次）
- 用量 API 限速时回退到过期缓存

### 设计理念
- PowerShell 安装器镜像 bash 安装器逻辑，实现 Windows 对等
- 对抗式审查替代 codex-cli MCP——跨模型挑战比同模型委派产出更高质量的审查
- 网页搜索日期指令通过优先验证系统时钟确保查询包含当前年份

### 注意事项
- PowerShell 安装器需要 `winget` 安装 `jq`/`gh` 依赖
- 对抗式审查需要安装对立 CLI（Claude 用户需要 `codex`，Codex 用户需要 `claude`）
- 旧仓库名（`claude-code-config`）的 GitHub 重定向仍有效，但规范 URL 现在是 `awesome-claude-code-config`

## [1.1.0] - 2026-03-05

### 新特性
- 渐变状态栏，显示模型、费用和 context 用量
- CLAUDE.md 中的版本变更日志策略
- 项目重命名为 `awesome-claude-code-config`
- 安装器中移除备份逻辑（由智能合并替代）

### 设计理念
- 状态栏提供会话状态的即时感知，不打断工作流
- 变更日志策略确保设计决策与代码同步可追溯

### 注意事项
- 状态栏从 OS 密钥链读取 API 凭证——需要密钥链访问权限
- 重命名可能导致现有书签失效；GitHub 重定向透明处理

## [1.0.0] - 2026-03-02

### 新特性
- 安装器重构：远程安装、智能合并、插件组、卸载、版本管理
- 增强 paper-reading 技能，含深度优先分析和多视角评估
- CLAUDE.md 中的 Code Review 规则
- Codex CLI MCP 服务器集成

### 设计理念
- 插件优先架构：从开源生态安装技能，而非内置捆绑
- 智能合并在升级时保留用户自定义配置
- paper-reading 技能使用 Andrew Ng 的三视角框架进行平衡评估

### 注意事项
- 插件安装器需要 Python 3 和网络访问 GitHub
- MCP 服务器需要单独配置凭证（Lark、GitHub PAT）

## [0.1.0] - 2026-02-25

### 新特性
- 初始版本，包含 CLAUDE.md 全局指令
- 基于 lessons 的自我纠正循环记忆系统
- 插件市场，含 AI 研究、MCP 服务器和 paper-reading 技能
- 飞书/Lark MCP 和 Context7 集成
- 支持插件组的安装器

### 设计理念
- Lessons 驱动的自我改进：记录纠正 → 自动注入 → 稳定模式提升至 CLAUDE.md
- 插件市场分离关注点：CLAUDE.md 管理行为，插件提供领域技能

### 注意事项
- 首个公开版本——API 和配置格式可能变更
