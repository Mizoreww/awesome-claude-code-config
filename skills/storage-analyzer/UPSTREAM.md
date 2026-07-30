# 来源与修改说明

## 上游

本 skill 源自 [KKKKhazix/khazix-skills](https://github.com/KKKKhazix/khazix-skills) 的 `storage-analyzer`，
基线提交 [`fcba3ad`](https://github.com/KKKKhazix/khazix-skills/tree/fcba3adcf5def1ccd4bb688de93060227471b129/storage-analyzer)。
原作者：数字生命卡兹克。许可证 MIT，见同目录 `LICENSE`。

## 本仓库所做的修改

**与 `neat-freak` 不同，这份 skill 不是原样保留** —— 在上游基线之上增加了 Linux 支持并加固了安全模型，
相对基线约 +998/−63 行（`scripts/scan.py`、`scripts/server.py` 为主）。

这些修改已提交回上游：[KKKKhazix/khazix-skills#50](https://github.com/KKKKhazix/khazix-skills/pull/50)。
若上游合并，本目录应重新对齐到合并后的提交。

### 一、Linux 支持（上游仅支持 macOS / Windows）

- `scan.py` 新增 `scan_linux` 分支：XDG 目录布局、`/opt` 与 `/usr/local`、snap/flatpak，
  以及 `sudo_targets`（`/var/lib/docker`、`/var/log`、各发行版包缓存）和 `uncategorized`（兜底下钻）两组。
- `server.py` 新增 XDG Trash 三级回退：`gio trash` → `trash-put` → 纯标准库手写 `.trashinfo`。
- 无头环境（无 `DISPLAY`/`WAYLAND_DISPLAY`）不启动浏览器，改为打印 `ssh -L` 转发提示；
  `SKILL.md` 指示 agent 跳过报告渲染，直接在对话里给出诊断。
- `references/linux.md` 为新增文件。

### 二、Linux 特有的正确性问题

- **逐文件系统缺口对账**：Linux 上 `du` 对读不到的 root 目录静默返回偏小值且退出码为 0。
  新增 `reconcile_linux`，按 `st_dev` 分别对账（`/home` 独立分区极常见，合并计算会捏造巨额假重叠）。
- **硬链接重复计数**：`du` 只在单次调用内按 inode 去重，uv/pnpm/conda 的硬链接缓存会被多次计入。
  超出实际已用时输出 `overlap_kb`，要求报告注明实际释放量更小。
- **`du_kb`**：判读 `du` 的退出码与 stderr，读不全的条目标 `partial`，不再把残缺小计当作完整测量。

### 三、安全模型加固

破坏性操作（`rm` / `trash`）现有五道由代码强制的防线：白名单 → 准入过滤（`needs_sudo` 项、
`$HOME` 本身、跨文件系统、bind mount 一律排除）→ 严格子孙检查 → `/proc/self/mountinfo`
挂载穿透检查 → 父目录 fd 锚定与 inode 复核。批量请求先全量校验再执行，任一路径非法即整批拒绝。

`_rmtree_at` 采用 fd 相对的显式栈迭代删除（递归实现会在深目录树上抛 `RecursionError`
并留下半删状态）。

### 四、同时修复的跨平台缺陷（影响 macOS）

- `du` 全线加 `-x`，并显式比对 `st_dev`：上游未加时，`~/data` 之类的外置盘挂载点
  会被整块算进主盘占用。
- `build_report.py` 的打开提示按平台输出 `open` / `start` / `xdg-open`。

## 验证状态

实测于 Ubuntu 24.04.4 / ext4 / GNOME：扫描、逐盘对账、XDG 废纸篓写入与还原闭环、
无头降级、跨文件系统拒绝、安全护栏（真实 HTTP 请求）。

未覆盖：Arch / Fedora / NixOS、多分区、真实无头服务器；上游的 Windows 分支未经触碰也未验证。
`_rmtree_at` 的迭代实现仅经作者自测，未获独立代码审查（详见上游 PR 描述）。
