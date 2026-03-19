# Changelog

## [1.9.2] - 2026-03-20

### Features
- **Bundled MesloLGS NF font**: Replaced online JetBrainsMono Nerd Font download (~30MB zip from GitHub) with 4 bundled MesloLGS NF .ttf files (~10MB total) — font installation is now instant with no network dependency

### Design Rationale
- GitHub releases download was slow/unreliable in poor network environments, blocking the entire install flow
- MesloLGS NF is a well-established Nerd Font (used by Powerlevel10k) that provides the same Powerline/icon glyphs needed for statusline
- Bundling ~10MB of fonts in the repo is an acceptable trade-off vs requiring network access during install

### Notes & Caveats
- Font files sourced from romkatv/powerlevel10k-media (Apache 2.0 license)
- Both install.sh and install.ps1 updated — no more curl/wget/Invoke-WebRequest for fonts
- Terminal font setting prompt now recommends 'MesloLGS NF' instead of 'JetBrainsMono Nerd Font'

## [1.9.1] - 2026-03-17

### Features
- **paper-reading pymupdf fixes**: Fixed 5 issues from adversarial code review — removed Step 1/Step 3 contradiction blocking PDF figure extraction, added vector figure detection guidance (`get_drawings()`/`get_text("dict")`), fixed output path consistency, clarified `extract_image` vs clip-based rendering usage, added pymupdf availability pre-check
- **Adversarial Review showcase**: Added adversarial-review skill showcase with 4 screenshots demonstrating the cross-model review workflow (scope analysis → reviewer spawning → verdict synthesis → lead judgment)

### Design Rationale
- The Step 1 "Cannot screenshot figures" message contradicted the new Path B pymupdf workflow — agents following the acquisition flow would stop before reaching figure extraction
- Vector figure detection is essential because many research papers encode plots, diagrams, and tables as vector/text objects rather than raster images
- `extract_image(xref)` returns raw embedded images without page-level annotations — clip-based rendering is safer as the default for most figure types

### Notes & Caveats
- pymupdf (`pip install pymupdf`) is required for Path B PDF figure extraction
- Adversarial review showcase screenshots are from a real review session

## [1.9.0] - 2026-03-14

### Features
- **claude-health plugin**: Added [claude-health](https://github.com/tw93/claude-health) as a new standalone plugin group in the interactive installer — provides health check and wellness dashboard for Claude Code sessions
- **Statusline bugfix**: Fixed `fmt_ctx()` integer comparison error when context size is empty — `local s=$1` → `local s=${1:-0}` prevents `[: : integer expression expected` warnings

### Design Rationale
- claude-health is a standalone group (like claude-mem) rather than part of Essential — it's optional and users may not want health monitoring overhead
- The statusline fix uses shell parameter expansion default (`${1:-0}`) which is POSIX-compatible and handles both empty and unset variables

### Notes & Caveats
- claude-health marketplace source: `tw93/claude-health` (GitHub)
- Total plugin count: 21 across 6 marketplaces (was 20 across 5)

## [1.8.2] - 2026-03-13

### Features
- **StatusLine and Lessons are now independent menu options**: The former "Hooks" item has been split into "StatusLine" (gradient progress bar & usage display) and "Lessons" (lessons.md template + SessionStart auto-load hook). Users can now install either without the other.
- **Conditional settings.json merge**: `statusLine` and `hooks.SessionStart` fields are only merged/included when their corresponding menu option is selected
- **Auto-enable settings.json**: Selecting StatusLine or Lessons without settings.json will auto-enable settings.json (required for config)
- **jq-unavailable warning**: Fresh installs without jq now warn when unselected fields cannot be stripped from settings.json

### Design Rationale
- Addresses issue #12: users who don't want the statusline can now deselect it independently
- The old "Hooks" item bundled two unrelated concerns — statusline display and lessons auto-loading — that have different use cases
- `install_statusline()` now only copies `statusline.sh` (not all files in hooks/), preventing future hook files from being bundled incorrectly

### Notes & Caveats
- Existing users who re-run the installer with StatusLine/Lessons unchecked will keep their existing config (safe upgrade — the installer never removes previously installed settings)
- On systems without jq, fresh installs with partial selections will copy the full settings.json template and warn about included extra fields

## [1.8.0] - 2026-03-11

### Features
- **`/update_config` skill**: In-session update command — type `/update_config` in Claude Code to check for new versions and re-run the interactive installer without leaving the session. Compares installed vs remote VERSION, downloads latest `install.sh`, and launches the interactive selector.

### Design Rationale
- Skill-based approach (vs. a standalone script) lets users update from within any Claude Code session with a single slash command, no terminal switching needed
- Reuses the existing `install.sh` remote mode and smart merge — no new update logic to maintain

### Notes & Caveats
- Requires internet access to fetch remote VERSION and installer
- The installer's smart merge preserves existing `settings.json` customizations and never overwrites `lessons.md`

## [1.7.0] - 2026-03-11

### Features
- **All virtual environments in statusline**: Statusline now detects conda (including `base`), Python venv, poetry, and pipenv environments. Priority: conda > venv/poetry/pipenv
- **README documentation fixes**: Interactive menu example now lists humanizer skill; statusline description now mentions virtual environment display
- **Font install improvements**: Prioritized `fc-list` detection over filename glob (catches system-installed fonts); added explicit download timeouts (connect 10s, total 120s) to prevent hanging
- **Updated statusline screenshot**: Replaced showcase image with current statusline appearance

### Design Rationale
- Showing conda `base` is useful — users want to confirm which environment is active, even if it's the default
- `fc-list` is more reliable than filename globbing because system-packaged fonts may use different naming conventions
- Download timeout of 120s matches the Nerd Font zip size (~30MB) on slow connections while preventing indefinite hangs

### Notes & Caveats
- Virtual environment detection relies on environment variables (`CONDA_DEFAULT_ENV`, `VIRTUAL_ENV`); manually activated environments without these vars won't be detected
- Conda takes priority when both conda and venv are active simultaneously

## [1.6.0] - 2026-03-11

### Features
- **jq auto-install (bash)**: `install.sh` now auto-installs jq via package managers (brew/apt/dnf/yum/pacman/apk) or downloads a pre-built binary to `~/.claude/bin/jq` — settings.json smart merge no longer silently skips
- **Conda environment in statusline**: Shows active conda environment name between directory and git branch segments
- **Marketplace skip on re-install**: Installer checks if `~/.claude/plugins/marketplaces/{name}` exists before retrying, saving ~75s on repeated installs
- **Emoji detection + text fallback**: Statusline detects UTF-8 locale, terminal type, and Nerd Font availability — falls back to text labels (`M:`, `D:`, `py:`, `br:`) on unsupported terminals
- **Nerd Font auto-install**: Installers download and install JetBrainsMono Nerd Font for Powerline git branch icon; prompts user to set terminal font

### Design Rationale
- jq install uses a layered approach: check PATH first, then `~/.claude/bin/`, then package managers (with sudo), then static binary download (no sudo needed) — covers CI, macOS, Linux desktop, and minimal containers
- Conda display shows all environments including `base` for environment awareness
- Marketplace directory check is the fastest reliable indicator of "already registered" — avoids 5x3s retry timeout from `claude plugin marketplace add` returning errors on duplicates
- Icon fallback chain: emoji (UTF-8 terminal) > Nerd Font (fc-list detected) > text labels (dumb/non-UTF-8 terminals) — ensures statusline is always readable

### Notes & Caveats
- jq binary download requires `curl` or `wget` and internet access; package manager installs may require `sudo`
- Nerd Font download is ~30MB; users must manually set their terminal font after installation
- Conda display reads `$CONDA_DEFAULT_ENV` — works with conda activate but not with direct `python` path manipulation

## [1.5.1] - 2026-03-09

### Features
- **Remote install now interactive by default**: One-line installs (`curl | bash`, `bash <(curl ...)`) launch the interactive selector — reads keyboard from `/dev/tty` when stdin is piped, or from stdin directly when it's a tty
- **`confirm()` prompt also supports piped stdin**: Uninstall confirmation prompts now pair output and input through the same device (`/dev/tty` when piped, stdout+stdin when normal)
- **Centralized terminal detection**: Single `can_interact()` function replaces duplicated checks across `parse_args`, `interactive_menu`, and `confirm`

### Design Rationale
- `bash <(curl ...)` already preserves terminal stdin; the `/dev/tty` fallback specifically enables `curl URL | bash` where stdin carries the script
- Interactive menu prefers stdin (fd 0) when it's a tty, only opening `/dev/tty` as fallback — no regression for containers missing `/dev/tty`
- Only falls back to default install (essential plugins only) when neither stdin nor `/dev/tty` is available (e.g., headless CI)

## [1.5.0] - 2026-03-09

### Features
- **Windows interactive installer**: `install.ps1` now has the same arrow-key interactive menu as bash, using `[Console]::ReadKey()` for navigation
- **Windows CLI simplified**: PowerShell params reduced to `-All`, `-Uninstall`, `-Version`, `-DryRun`, `-Force` (matching bash)
- **Windows plugin groups aligned**: Essential (13) + claude-mem (1) + AI Research (6) structure now matches bash installer
- **Windows language rule cleanup**: Unselected language dirs are auto-removed, matching bash behavior

## [1.4.0] - 2026-03-09

### Features
- **Interactive installer**: `./install.sh` with no args launches a multi-select menu — toggle components by number, confirm with Enter
- **Plugin groups simplified**: All 13 general plugins merged into one Essential group (on by default); claude-mem separated as standalone toggle (off by default)
  - Essential (13): everything-claude-code, superpowers, code-review, context7, commit-commands, document-skills, playwright, feature-dev, code-simplifier, ralph-loop, frontend-design, example-skills, github
  - claude-mem (1): separated — injects ~3k tokens/session (observation index + session summary)
- **Language rules opt-in**: Python/TypeScript/Go rules are off by default in interactive mode — only install what your projects need
- **Automatic cleanup**: When selecting specific language rules, previously installed unselected language dirs are removed
- **Arrow-key interactive menu**: ↑↓ navigate, Enter to toggle, Submit button to confirm
- **CLI simplified**: Removed 8 component-selection flags (`--rules`, `--plugins`, `--mcp`, `--skills`, `--lessons`, `--hooks`, `--claude-md`, `--settings`); only `--all`, `--uninstall`, `--version`, `--dry-run`, `--force` remain
- **`--all` now installs everything**: Including MCP and all plugin groups (previously excluded MCP)

### Design Rationale
- Addresses context accumulation issue (#7): default install was injecting ~9k tokens of rules (including unused languages) + heavy plugin skill lists into every session
- Interactive menu replaces the need to remember CLI flags — users see all options at a glance with sensible defaults
- CLI flag removal: component-selection flags are redundant with the interactive menu; `--all` is the only non-interactive install path needed
- claude-mem separated as standalone toggle — it's the only plugin injecting ~3k tokens at SessionStart (observation index + session summary); other Extended plugins only register tool/skill names
- Non-interactive fallback preserved: headless/CI installs (no tty at all) install essential plugins only (no MCP); explicit `--all` installs everything including MCP and all plugin groups
- Unknown/removed CLI flags now exit with error instead of silently degrading

### Notes & Caveats
- `--all` now installs everything (all plugins, MCP, all language rules)
- Remote install (`bash <(curl ...)`) now shows interactive menu by default (v1.5.1+); add `--all` for non-interactive full install

## [1.3.0] - 2026-03-09

### Features
- Full uninstall now includes plugins and MCP by default (previously omitted)
- Install warning tracking: failed merges or plugin installs now skip version stamp and report warning count
- Uninstall backs up `settings.json` to `settings.json.bak` before removal
- `--all` flag now composes with other flags (e.g., `--all --mcp` installs everything plus MCP)
- Windows installer checks bash availability and warns if missing (required by statusline and hooks)
- Adversarial review skill no longer requires missing `brain/principles.md`; uses `reviewer-lenses.md` as self-contained source

### Bug Fixes
- VERSION environment variable sanitized to prevent command injection in remote install
- Repeated install no longer creates nested directories (e.g., `paper-reading/paper-reading/`)
- `stat` fallback order fixed: Linux `stat -c %Y` tried first, macOS `stat -f %m` as fallback
- Windows installer missing `tokenization` plugin in AI Research group (5/6 → 6/6)

### Documentation
- Self-improvement loop wording clarified: "auto-saved" → "Claude writes corrections driven by CLAUDE.md instructions"
- Uninstall examples annotated with "(incl. plugins & MCP)"
- Manual plugin install docs updated with all marketplace `add` commands and `name@marketplace` syntax

### Design Rationale
- Warning tracking prevents users from believing a partially-failed install is current
- Settings backup on uninstall prevents accidental loss of user-owned config merged by the installer
- VERSION sanitization closes a real attack vector in the remote install path (`bash -c` with untrusted input)

### Notes & Caveats
- `bypassPermissions` default unchanged (power-user config by design)
- Adversarial review still requires opposite CLI (`codex`/`claude`) — this is by design, not a bug

## [1.2.0] - 2026-03-07

### Features
- Windows support with PowerShell installer (`install.ps1`)
- Adversarial code review skill (cross-model review via opposite AI CLI)
- Tokenization plugin added to AI Research skill group (huggingface-tokenizers, sentencepiece)
- Cross-platform web search date instruction (system command with fallback)
- Codex branch link in README navigation

### Bug Fixes
- Statusline non-blocking for third-party API users
- Bash 3.2 compatibility (replace associative array with string matching)
- Retry logic (5 attempts) for network operations in installer
- Fallback to expired cache when usage API is rate-limited

### Design Rationale
- PowerShell installer mirrors bash installer logic for Windows parity
- Adversarial review replaces codex-cli MCP — cross-model challenge produces higher quality reviews than same-model delegation
- Web search date instruction ensures queries include current year by verifying system clock first

### Notes & Caveats
- PowerShell installer requires `winget` for `jq`/`gh` dependencies
- Adversarial review requires the opposite CLI installed (`codex` for Claude users, `claude` for Codex users)
- GitHub redirect from old repo name (`claude-code-config`) still works but canonical URL is now `awesome-claude-code-config`

## [1.1.0] - 2026-03-05

### Features
- Gradient statusline showing model, cost, and context usage
- Version changelog policy in CLAUDE.md
- Project renamed to `awesome-claude-code-config`
- Backup logic removed from installer (replaced by smart merge)

### Design Rationale
- Statusline provides at-a-glance session awareness without interrupting workflow
- Changelog policy ensures design decisions are traceable alongside code

### Notes & Caveats
- Statusline reads from OS keychain for API credentials — requires keychain access
- Rename may break existing bookmarks; GitHub redirect handles this transparently

## [1.0.0] - 2026-03-02

### Features
- Installer overhaul: remote install, smart merge, plugin groups, uninstall, version management
- Enhanced paper-reading skill with depth-first analysis and multi-perspective evaluation
- Code Review rule in CLAUDE.md
- Codex CLI MCP server integration

### Design Rationale
- Plugin-first architecture: skills installed from open-source ecosystems rather than bundled
- Smart merge preserves user customizations during upgrades
- Paper-reading skill uses Andrew Ng's three-perspective framework for balanced evaluation

### Notes & Caveats
- Plugin installer requires Python 3 and network access to GitHub
- MCP servers require separate credential configuration (Lark, GitHub PAT)

## [0.1.0] - 2026-02-25

### Features
- Initial release with CLAUDE.md global instructions
- Memory system with lessons-based self-correction loop
- Plugin marketplace with AI research, MCP servers, and paper-reading skill
- Feishu/Lark MCP and Context7 integration
- Installer with plugin group support

### Design Rationale
- Lessons-driven self-improvement: corrections recorded → auto-injected → stable patterns promoted to CLAUDE.md
- Plugin marketplace separates concern: CLAUDE.md manages behavior, plugins provide domain skills

### Notes & Caveats
- First public release — API and configuration format may change
