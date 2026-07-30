# Changelog

## [3.1.0] - 2026-07-30

### Features
- Added a new **Storage** group to both installers with a single item, `storage-analyzer`, **off by default**. It performs a read-only disk-usage scan, classifies what is eating space into three tiers, and produces an interactive HTML report with a guarded one-click cleanup endpoint.
- Vendored the skill from [KKKKhazix/khazix-skills](https://github.com/KKKKhazix/khazix-skills) at baseline commit [`fcba3ad`](https://github.com/KKKKhazix/khazix-skills/tree/fcba3adcf5def1ccd4bb688de93060227471b129/storage-analyzer) (MIT, license included alongside the skill).
- **Unlike `neat-freak`, this copy is modified, not byte-for-byte upstream.** Roughly +998/-63 lines were added here: Linux support (the upstream supports macOS and Windows only) and a hardened safety model. Every change is itemised in `skills/storage-analyzer/UPSTREAM.md` and was submitted back upstream as [khazix-skills#50](https://github.com/KKKKhazix/khazix-skills/pull/50).
- Added `tests/test_storage_analyzer_integration.py`: asserts provenance and local modifications stay declared, the runtime is stdlib-only, the scanner contains no filesystem-mutating call, the five destructive-operation guards remain present, and both installers register the item as default-off.

### Design Rationale
- **A separate group rather than folding it into Workflow.** Disk cleanup is not part of a coding loop; it is an occasional operation with real destructive capability. Its own group keeps it visible in the menu without implying it belongs in an everyday workflow.
- **Default off.** The other bundled skills are read-only or advisory. This one ships an HTTP endpoint that can delete files, so it should be an explicit opt-in rather than something a user discovers already installed. `--all` still installs it, matching the existing "install everything" semantics of that flag.
- **Provenance recorded in-tree, not only in the README.** `neat-freak` preserves upstream byte-for-byte, so a README link suffices. This skill diverges substantially, so `UPSTREAM.md` sits next to the code and states the baseline commit, what was changed and why, where the changes went back to, and what has not been verified.
- **Linux could not be a path-table swap.** Three failure modes are specific to it: `du` silently under-reports unreadable root-owned directories while exiting 0; hard-linked caches (uv/pnpm/conda) are counted more than once across separate `du` invocations; and the XDG trash requires writing both `files/` and `info/*.trashinfo` or the file manager cannot restore. Each needed its own mechanism — per-filesystem reconciliation, overlap reporting, and a three-tier trash fallback.

### Notes & Caveats
- The skill is Python 3 stdlib only; there is nothing to `pip install`. On Linux the trash prefers `gio` or `trash-put` when present and otherwise writes the XDG `.trashinfo` itself.
- Verified on Ubuntu 24.04.4 / ext4 / GNOME. **Not** verified on Arch, Fedora, NixOS, multi-partition layouts, or a real headless server; the package-cache paths for pacman/dnf/nix were written from documentation. The upstream Windows branch is untouched and remains unverified, as upstream already notes.
- The vendored copy carries a fix that also affects macOS: `du` now runs with `-x` and compares `st_dev` explicitly, so an external drive mounted under `$HOME` is no longer counted as part of the system disk.
- Four rounds of adversarial review ran against the Linux work and fixed 8 high-severity and 26 medium/low findings; three of the high-severity ones were introduced by the fix for the previous round. A fifth round could not be completed — the review tool failed to produce output four times — so `_rmtree_at` (rewritten from recursion to an explicit stack) carries author testing only. This is stated in the upstream PR as well.

## [3.0.0] - 2026-07-29

### Features
- Removed five plugins from the shipped configuration: `feature-dev`, `ralph-loop`, `commit-commands`, and `github` (all `claude-plugins-official`), plus the default-off `pua@pua-skills`. This also drops the `pua-skills` marketplace, which no remaining plugin used.
- Added all five packages to `PLUGINS_REMOVED`, so an upgrade deletes their keys from an existing `enabledPlugins` and `--uninstall` also attempts to uninstall them.
- Switched `mattpocock/skills` from the `npx skills` installer to the official `mattpocock-skills@mattpocock` plugin. This drops the Node.js/npx dependency, the 3× retry wrapper, and the per-skill `--skill` scoping; upgrading removes the previously npx-copied skill directories (tracked by our own manifest) so nothing is duplicated.
- Fixed two pre-existing bugs in the Bash `settings.json` merge that this release surfaced:
  - Tombstoned plugins were deleted before the final recursive `*` merge, which then restored them from the user's existing file. On Linux/macOS **no** tombstone had ever taken effect; the strip now runs on the final object.
  - Missing parentheses around the `env` merge caused `env` keys to also be written to the top level of `settings.json`.

### Design Rationale
- These four official plugins overlap with capability already provided by built-in tooling and bundled skills, so they were removed to keep the shipped catalogue smaller. `pua` was shipped default-off; removing it lets the `pua-skills` marketplace go with it.
- Tombstoning rather than silently dropping the keys: without it, an upgrade would leave the entries enabled in the user's `settings.json` forever, since the merge preserves keys it doesn't recognize.
- Major version bump because this changes the result of upgrading an existing installation, not only a fresh one.
- mattpocock now publishes a real plugin, and upstream states the plugin and the npx install are mutually exclusive ("installing both leaves you with every skill twice"). Taking the plugin removes an entire optional-dependency code path — the npx install was already failing on Node 18, where `node:util` has no `styleText` export.

### Notes & Caveats
- **Tombstones apply on every settings merge, not just once.** If you deliberately reinstall one of these plugins, re-running the installer will remove its `enabledPlugins` entry again. Restore with `claude plugin install <name>@claude-plugins-official`; for PUA you must first re-add its marketplace (`claude plugin marketplace add https://github.com/tanweai/pua`) and then install `pua@pua-skills`.
- The mattpocock plugin ships 22 skills, up from the 17 the npx path installed. `to-prd`/`to-issues` were renamed upstream to `to-spec`/`to-tickets`; `code-review`, `implement`, `research`, `resolving-merge-conflicts`, and `wayfinder` are new. Because a plugin is an all-or-nothing bundle, individual skills can no longer be cherry-picked.
- A normal upgrade only removes the `enabledPlugins` entries. It does not run `claude plugin uninstall`, and it does not unregister the `pua-skills` marketplace — remove that yourself with `claude plugin marketplace remove pua-skills` if you want it gone.

## [2.9.2] - 2026-07-23

### Features
- Added [`neat-freak`](https://github.com/KKKKhazix/khazix-skills/tree/2b4a645cfdc894156ae347d897723562f719ce95/neat-freak) to the Workflow group as a default-on bundled skill in both Bash and PowerShell installers. It closes out project knowledge by reconciling documentation, agent rules, authorized memory, and workspace residue with current code and runtime facts.
- Vendored the six-file runtime closure from upstream commit `2b4a645cfdc894156ae347d897723562f719ce95`: `SKILL.md`, four references, and the read-only inventory script. Upstream evaluation fixtures are not shipped.

### Design Rationale
- Pin and review the runtime instead of fetching mutable code during installation, while preserving every upstream runtime file byte-for-byte. The upstream MIT license is included alongside the skill, and the README links to the exact audited commit.
- Keep `neat-freak` in Workflow and enabled by default because it is a project closeout workflow, not a background cleanup process; its own trigger and authorization rules continue to control when it runs and what it may change.

### Notes & Caveats
- The skill has no required third-party package dependency. Its optional inventory helper uses Bash; when Bash, Git, or `rg` is unavailable, the unchanged upstream workflow directs the agent to perform equivalent checks manually.
- The installer copies the snapshot to `~/.claude/skills/neat-freak/`. No alias skill is created.

## [2.9.1] - 2026-07-14

### Features
- Rebuilt `paper-reading` as a portable layered skill with an explicit Markdown/HTML choice and one complete, concise close-reading depth; removed the reading-level chooser and reproduction mode.
- Added a shared claim/evidence/limitation ledger, paper-type references, immutable PDF extraction, and a tested bilingual Proof Spine HTML scaffold with one left outline navigation, title-focus hierarchy, static MathML, and structural report validation.
- Restored the original technical template as mandatory per-module anatomy for empirical and systems papers: purpose, exact inputs/outputs, architecture, training data, training method, inference role, interfaces, and pinned code evidence.
- Made each load-bearing module visually reconstructable with a full-width horizontal interface SVG above its fields, separate nodes for every listed input/output, MathML symbols in the matching field lists, and validator checks for visual order and interface-node coverage.
- Required empirical reports to retain the paper's original load-bearing result plots or qualitative panels alongside numerical summaries; recreated tables and explanatory SVGs no longer satisfy the central-result evidence gate.
- Added a mandatory read-only audit of authoritative public code when available, without installing, importing, downloading weights/data, or executing the project.
- Restored the original concise basic-information list, with verified homepage links for principal authors, corresponding authors or paper contacts, and the labs/research groups that host them; institution-level links are explicit fallbacks and technical extraction provenance stays internal.
- Added restrained fit-to-view lightboxes with pointer-centered desktop wheel zoom, touch pinch zoom, zoom-only panning, bounded controls, and captions that remain inside the viewer.
- Normalized converter-emitted named mathematical operators such as `TopK` and `softmax` to upright MathML identifiers with explicit function-application semantics.

### Design Rationale
- Keep the familiar Empirical/Theoretical/Survey/Systems report backbone while loading only type-, code-audit-, HTML-, and visual-specific guidance as needed.
- Use one article-first visual system and one analytical depth so core engineering detail cannot disappear through mode selection. Keep the type scale compact and limit the left rail to the section outline and source link.
- Require diagrams to earn their place through explanatory gain, with module interface maps as the one systematic exception; keep every original figure and explanatory SVG inspectable in the same accessible lightbox.
- Preserve LaTeX source while emitting offline MathML, require natural prose under every display equation that defines every symbol before interpreting the relation, keep inline math atomic and free of scroll controls, and split overlong equations into explained, paper-faithful subexpressions instead of shrinking them or fragmenting the surrounding prose.

### Notes & Caveats
- Released to `main` after user approval. Paper-specific acceptance reports, extracted figures, screenshots, and other generated paper assets remain external and are not part of this release.
- PDF extraction pins `pymupdf4llm==1.28.0` in a project-independent isolated environment and records that version while preserving raw assets/graphics metadata; final visual selection still requires human/agent render inspection.
- The validator rejects duplicate/removed navigation surfaces, reading-lens and evidence-index controls, metadata tables or visible extraction bookkeeping, missing author/contact/lab homepage links, unmarked institution-level affiliation fallbacks, incomplete module anatomy, module visuals placed after their fields, merged interface nodes, missing original empirical result figures, vague code evidence, unexplained display equations, code-styled or legacy-script mathematics, unwrapped visuals, remote `srcset`/SVG image fetches, and unsafe or escaping local links. The enforced browser test covers the single outline, inline-math overflow, local equation explanations, initial image size, wheel/pinch zoom without scroll leakage, and contained captions.
- Math rendering pins `latex2mathml==3.78.1`, parses converter output with `defusedxml==0.7.1`, enforces a shared inert presentation-MathML tag/attribute allowlist, and reserializes the checked tree before HTML embedding. Reports admit exactly one marked inline enhancement script, preventing XML/HTML parser differences from reactivating converter text; generated equations have no network dependency.
- Code inspection is deliberately read-only and must distinguish paper-stated, code-confirmed, discrepant, inferred, and unavailable details. Reproduction remains outside this report workflow.

## [2.9.0] - 2026-07-13

### Features
- **New `ResearchStudio` item in the Academic Research group (default OFF):** installs Microsoft's [ResearchStudio](https://github.com/microsoft/ResearchStudio) *Idea* skills — `idea-spark`, `paper-search`, `scoop-check` — via the official npx installer (`npx github:microsoft/ResearchStudio`). The skills land in `~/.claude/skills/` for Claude Code, alongside the existing DeepXiv and paper-reading entries. Available in both `install.sh` and `install.ps1`, and turned on by an explicit `--all` / `-All`.

### Design Rationale
- **npx over vendoring, like `mattpocock/skills`.** ResearchStudio ships its own Node.js installer, so the repo stays free of vendored skill directories. The installer is invoked with `DO_NOT_TRACK=1` (telemetry off), `RS_PLUGINS=idea` (Idea bundle only), `RS_SCOPE=global`, and `RS_AGENTS=claude` so files are written into Claude Code's global skills dir.
- **`RS_PIP=1` for out-of-the-box use, matching the codex branch.** The Idea skills call Python helper scripts, so the installer lets ResearchStudio `pip install --user` their dependencies at install time. `--user` keeps this out of system Python / conda, and a pip failure does not abort the install.
- **Default OFF, in Academic Research.** Like the DeepXiv skills, ResearchStudio is opt-in (menu pick or explicit `--all`), not part of the default install.

### Notes & Caveats
- Requires Node.js / `npx` and network access at install time. If `npx` is missing the installer prints a Node.js hint and the exact command, then skips it without blocking the rest of the install or the version stamp (optional add-on).
- After install, a quickstart hint points to a connector self-check: `python3 ~/.claude/skills/idea_spark/scripts/run.py check_connectors`. Credentials the upstream installer collects are stored in `~/.claude/skills/.env` — never paste them into chat.
- The current npx release contains the Idea bundle only; ResearchStudio-Reel is not installed.
- `--uninstall` removes only the skills recorded in an install manifest (`~/.claude/.researchstudio-skills`, written on a successful install) and **preserves `~/.claude/skills/.env`** (it may hold user credentials), warning the user to remove it manually if unused.

## [2.8.0] - 2026-06-29

### Features
- **Replaced the bundled `handoff` / `teach` skills with the `mattpocock/skills` collection, installed via npx.** The two vendored skills (`skills/handoff/`, `skills/teach/`) are removed. The **Workflow** group now offers a single `mattpocock/skills` item (default **on**) that runs `skills add mattpocock/skills` scoped to the 17 skills declared in the collection's `plugin.json` (via explicit `--skill` flags), installing them into `~/.claude/skills/` for Claude Code.
- **New `Slides` group with two AI-presentation plugins, both default OFF:** [`frontend-slides`](https://github.com/zarazhangrui/frontend-slides) (zero-dependency HTML slide generator with PPT conversion) and [`ppt-master`](https://github.com/hugohe3/ppt-master) (editable PPTX from PDF/DOCX/URL/Markdown). They install only via explicit `--all` or a manual pick.
- **`superpowers` is now default OFF.** It moved from the essential plugin tier to the optional tier (`PLUGINS_OPTIONAL`), so it installs only via explicit `--all` or a manual pick. It coexists with `mattpocock/skills` — the two are **not** mutually exclusive.
- **Removed the `everything-claude-code` plugin** entirely: Workflow menu entry, optional-plugin slot, the `affaan-m/everything-claude-code` marketplace, the id→package mapping, and its `settings.json` entry. A tombstone (`PLUGINS_REMOVED`) strips it from an upgrading user's `enabledPlugins` and uninstalls it on `--uninstall`, so it does not linger.

### Design Rationale
- **npx over vendoring.** Installing the collection through the `skills` CLI keeps the repo free of vendored skill directories. `DO_NOT_TRACK=1` disables the CLI's anonymous telemetry; `--copy` writes real files (not symlinks) so uninstall can delete them; `--agent claude-code` scopes the install to Claude Code only.
- **Scoped to the 17 plugin.json skills, not `--skill '*'`.** The repo actually contains 35 `SKILL.md` files (including personal/in-progress ones); `--skill '*'` would install all 35. The installer passes the exact 17 names from a single `MATTPOCOCK_SKILLS` array, which also seeds the install manifest that drives uninstall, so install / docs / uninstall stay consistent.
- **superpowers and mattpocock/skills are not mutually exclusive.** They overlap in spirit but can be installed together; `mattpocock/skills` is simply the new default and `superpowers` becomes opt-in, mirroring the optional tier `everything-claude-code` previously occupied.

### Notes & Caveats
- Installing `mattpocock/skills` requires Node.js / `npx` and network access at install time. If `npx` is missing the installer prints a Node.js install hint and the exact command, then skips it without blocking the rest of the install or the version stamp (it is an optional add-on).
- `ppt-master` needs `pip install -r requirements.txt` inside its installed plugin directory for its Python post-processing scripts to work.
- Upgraders' vendored `~/.claude/skills/{handoff,teach}` are **not** force-deleted: when `mattpocock/skills` is selected its `--copy` install overwrites them with the upstream versions; when it is deselected (or `npx` is unavailable) the old copies keep working. The legacy-skill migration is also `--dry-run` safe.
- `--uninstall` removes only the mattpocock skills recorded in an install manifest (`~/.claude/.mattpocock-skills`, written on a successful install), so a user-authored skill that merely shares a generic name (e.g. `tdd`, `handoff`) is never deleted.
- README plugin / marketplace / bundled-skill counts updated to 25 / 10 / 5.

## [2.7.1] - 2026-06-09

### Features
- **New bundled skill: `teach`** (from [`mattpocock/skills`](https://github.com/mattpocock/skills/blob/main/skills/productivity/teach/SKILL.md)) — a stateful, multi-session learning-workspace skill. It treats the current directory as a teaching workspace grounded in a `MISSION.md`, producing self-contained HTML lessons that sit in the user's zone of proximal development, plus reference docs, sequential learning records, and a curated resources list. Ships 5 files (`SKILL.md` + `MISSION-` / `LEARNING-RECORD-` / `GLOSSARY-` / `RESOURCES-FORMAT.md` templates). Registered in the **Workflow** group of both installers and **enabled by default**.

### Notes & Caveats
- `teach` is user-invoked only (`disable-model-invocation: true` → `/teach`); "default on" refers to installer selection, not model auto-invocation.
- First multi-file bundled skill — no installer logic changes were needed since skills are copied recursively (`cp -r` / `Copy-Item -Recurse`).
- Source attribution preserved as an HTML comment in `skills/teach/SKILL.md`.

## [2.7.0] - 2026-06-08

### Features
- **Fork-friendly installers: repository metadata is now configurable** (#41, thanks @Yastruhank). `install.sh` and `install.ps1` no longer hard-code `Mizoreww/awesome-claude-code-config/main`. The owner, name, and branch are read from `REPO_OWNER` / `REPO_NAME` / `REPO_BRANCH` (defaulting to the upstream values) and composed into every download URL — tarball/zip source, the remote `VERSION` check, and the `Show-Help` remote-install one-liner. This lets a fork or mirror run the installer (including the `curl | bash` / `irm | iex` remote forms) without editing source.

### Bug Fixes
- **Validate repository-metadata overrides to prevent command injection.** In remote mode `install.sh` builds the download command from `REPO_URL` and executes it via `bash -c`. The new env-controlled `REPO_OWNER`/`REPO_NAME`/`REPO_BRANCH` are now validated against a safe charset (`^[A-Za-z0-9._-]+$`, plus `/` for branch refs) before use, mirroring the existing `VERSION` guard. The remote `version` sanitizer also now permits `/` so `feature/*` branches work as a `REPO_BRANCH` override.
- **Remove invalid `mcp__*` wildcard from `permissions.allow`**: Claude Code's `/doctor` rejects a bare `mcp__*` in *allow* rules. In allow rules a glob is only valid in the **tool position** after a literal `mcp__<server>__` prefix (e.g. `mcp__github__*`) — the server-name segment itself cannot be globbed. The entry was silently skipped, so removing it is behaviour-preserving (MCP tools already fell through to the `auto` permission prompt). To pre-allow MCP tools, add valid per-server entries such as `mcp__github` or `mcp__github__*`. (Deny/ask rules still accept wildcards anywhere.)

### Design Rationale
- **One override per field, not two.** The contributed PR shipped both `REPO_OWNER` and a parallel `REPO_OWNER_OVERRIDE` (×3 fields, ×2 scripts) with a hidden precedence rule. These were collapsed to a single variable per field — same capability, no ambiguity about which one wins.
- **Validate at the boundary.** The override values cross a trust boundary (environment → shell-evaluated URL), so they are checked the moment they are read, consistent with the project's existing input-validation stance.

### Notes & Caveats
- The PR's experimental `--dry-run` directory guard was reverted: it only covered the top-level `$CLAUDE_DIR` `mkdir`, while component installers still create subdirectories (and remove legacy skills) before their dry-run checks — so it gave a false sense of safety. Making `--dry-run` fully non-mutating is tracked as a separate follow-up.
- Comment-based help blocks in both scripts still reference the upstream URL literally; PowerShell's `<# … #>` help is static text parsed by `Get-Help` and cannot interpolate runtime variables.

## [2.6.1] - 2026-05-25

### Features
- **New bundled skill: `handoff`** (from [`mattpocock/skills`](https://github.com/mattpocock/skills/blob/main/skills/productivity/handoff/SKILL.md)) — compacts the current conversation into a handoff document written to the OS temp directory, so a fresh agent can pick up the work without inheriting the full context. Includes a `suggested skills` section, references existing artifacts by path/URL rather than duplicating them, and redacts sensitive data. Registered in the **Workflow** group of both installers and **enabled by default**.

### Notes & Caveats
- The skill writes to the user's OS temp directory (e.g. `/tmp` or `%TEMP%`), not the current workspace — handoff docs do not pollute the repo.
- Source attribution preserved as an HTML comment in `skills/handoff/SKILL.md`.

## [2.6.0] - 2026-05-22

### Features
- **`paper-reading` skill gains an HTML output mode.** The skill now asks, when the user hasn't specified, whether to produce a Markdown summary (lightweight, token-cheap) or a styled HTML summary (richer, more tokens). HTML mode reuses the exact same content backbone (paper-type templates, depth-first writing, extracted figures) but presents it with a clean reading layout and **hand-drawn inline SVG diagrams** at key comprehension moments (architecture/pipeline, algorithm flow, naive-vs-proposed contrast). A new `Step 0: Choose Output Format` gates the workflow; an `HTML Output Mode` section documents the page scaffold, optional MathJax-via-CDN for equations, and SVG diagram conventions.

### Design Rationale
- **Ask, don't guess**: the token cost gap between md and html is real, so when intent is ambiguous the skill surfaces the trade-off rather than defaulting silently.
- **Inline SVG over Mermaid/CDN** for diagrams: chosen for full offline self-containment and maximum visual control; the only network dependency is optional MathJax for equation rendering, which degrades gracefully to raw LaTeX.
- **HTML references `./images/` with relative paths** (not base64-embedded): keeps the file lean and shares the same extracted figures the md path already produces.
- **Same substance, better presentation**: HTML is explicitly framed as the same analysis presented for faster comprehension, never a thinner summary — guarded by new Common Mistakes rows.

### Notes & Caveats
- HTML output travels with its sibling `images/` folder; moving the `.html` alone drops the paper's figures (redrawn SVGs still render).
- Both `skills/paper-reading/SKILL.md` (repo source) and `~/.claude/skills/paper-reading/SKILL.md` (installed copy) were updated and verified identical.

## [2.5.2] - 2026-04-21

### Refactor
- **Swap `env.CLAUDE_CODE_NO_FLICKER` for top-level `"tui": "fullscreen"`**: the `tui` setting is the schema-native way to select the flicker-free alt-screen renderer. Per the official schema it is "equivalent to `CLAUDE_CODE_NO_FLICKER=1`". Using the schema field is more discoverable, validates against settings.json's JSON Schema, and keeps `env` reserved for variables that have no native setting.

### Notes & Caveats
- Behaviour is identical — same fullscreen renderer, same virtualized scrollback.
- `env` still carries `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` and `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING` because neither has a schema-native equivalent (`alwaysThinkingEnabled: false` disables thinking entirely, which is not what we want).

## [2.5.1] - 2026-04-21

### Bug Fixes
- **`effortLevel` default changed from `max` to `xhigh`**: `max` is not accepted as a persistent default — Claude Code only allows `low`/`medium`/`high`/`xhigh` for `effortLevel` in `settings.json` (and for `CLAUDE_CODE_EFFORT_LEVEL`). The `max` tier is intentionally session-scoped and must be set per session via `/effort max`. The previous default was silently ignored.
- **Removed `betas: ["extended-cache-ttl-2025-04-11"]`**: the 1-hour prompt cache TTL is now generally available, so the beta header is no longer required. The expired beta ID was dead configuration.

### Notes & Caveats
- If you want `max` reasoning effort, invoke `/effort max` per session — this is Anthropic's deliberate design for the top tier.
- 1h cache TTL continues to work natively after removing the beta header.

## [2.5.0] - 2026-04-21

### Features
- **New plugin: `andrej-karpathy-skills`** (marketplace `karpathy-skills` at `forrestchang/andrej-karpathy-skills`) enabled by default. Adds Karpathy-inspired behavioural guidelines (Think-Before-Coding, Simplicity-First, Surgical Changes, Goal-Driven Execution) to reduce common LLM coding mistakes.
- **`everything-claude-code` now default disabled**. Moved out of the essential plugin group into an optional group; only installed via explicit `--all` or manual opt-in.
- **Installer respects plugin de-selection**: when running the installer, any plugin that the user did NOT select but that already exists in their local `settings.json` (or is known to the installer catalogue) is now written as `false` in `enabledPlugins`. Previously, unselected plugins could silently remain enabled because the merge logic preferred existing values.
- **Menu reorganisation**: the "Plugins — Official" and "Plugins — Community" groups have been replaced with four usage-oriented groups and the old "Skills" group has been dissolved into them. Plugins and skills now live side-by-side in the same category, since they serve the same workflow:
  - **Workflow** (8): andrej-karpathy-skills, superpowers, feature-dev, ralph-loop, commit-commands, code-simplifier, everything-claude-code, `update-config` (skill)
  - **Integrations** (3): context7, github, playwright
  - **Design & Content** (5): document-skills, example-skills, frontend-design, `humanizer` (skill), `humanizer-zh` (skill)
  - **Memory & Lifestyle** (3): claude-mem, claude-health, PUA
  - **Academic Research** (10): `paper-reading` (skill) + 6 AI-Research plugins + 3 DeepXiv skills (previously 9)
  Group labels no longer carry the redundant "Plugins —" prefix.

### Design Rationale
- Karpathy's guidelines are general-purpose heuristics that apply to most coding sessions, so they belong in the essentials group. Everything-claude-code is broad and opinionated; making it opt-in reduces surprise overlap with user-selected standards.
- The new enabledPlugins rule makes the interactive menu authoritative: what you pick is what's enabled. Unknown keys from the existing settings.json that are not in our catalogue are still preserved so manually-added plugins aren't clobbered.

### Bug Fixes (post-review)
- **`enabledPlugins` catalogue now includes the current selection**. Previously, plugins selected in the menu but not declared in the shipped `settings.json` (e.g. `codex@openai-codex`, `health@claude-health`, `pua@pua-skills`) were installed by `claude plugin install` but silently omitted from `enabledPlugins` — Claude Code treated them as disabled. The selection-aware rebuild now unions base keys with `$selected`.
- **Fallback merge order corrected**. When plugins aren't interacted with this run, the union merge now has existing values winning on conflict (`$base * $over` in jq, `$mergeHt $incoming $existing` in PowerShell). Previously the operands were swapped, silently flipping v2.4.x users' `everything-claude-code: true` to `false` on any upgrade that didn't touch plugins.
- **`install_jq` hoisted in `install_settings`**. Fresh installs on jq-less machines with statusline+lessons both on no longer silently skip the plugin selection filter.
- **Dry-run banner now reflects actual semantics**. Previously `--dry-run` printed "enabledPlugins: union (new plugins added, existing preserved)" even when the real run would do a selection-aware rebuild — now branches on `$INSTALL_PLUGINS`.

### Windows Menu Parity
- Install.ps1 now accepts **→ (Right arrow)** to open a group's sub-menu and **← (Left arrow)** to return, matching install.sh. Hint strings updated in both scripts.
- README documents the full key bindings: main menu (↑↓ / Enter or → / q), sub-menu (↑↓ / Space / ← or Esc), and shortcuts (a / n / d).

### Notes & Caveats
- `PLUGINS_OPTIONAL` group added alongside `PLUGINS_ESSENTIAL` (install.sh and install.ps1). `--all` mode expands to include both.
- The selection-aware enabledPlugins merge only activates when the installer touches plugins (`INSTALL_PLUGINS=true`). If you install only `settings.json` without any plugin selection, the fallback union merge preserves existing state.
- Existing users: your previously-enabled plugins stay enabled only if re-selected in the menu. Run the interactive menu to adjust.
- README.md and README.zh-CN.md significantly trimmed (from 349 → ~195 lines): the per-plugin duplication that overlapped with `plugins/README.md` has been collapsed, while the full interactive-menu catalogue is kept inline with links and defaults.

## [2.4.0] - 2026-04-21

### Features
- **Default permission mode `auto`**: `settings.json` ships with `permissions.defaultMode = "auto"` so Claude autonomously approves safe actions and blocks risky ones. Installer auto-detects Claude Code version and downgrades to `bypassPermissions` on versions older than 2.1.80 (existing logic, unchanged).
- **Max reasoning effort default**: `effortLevel: "max"` at the top level of `settings.json`. Pins `/effort` to the highest tier by default; fall back to `xhigh` / `high` automatically on older CLIs that reject `max`.
- **1-hour prompt cache TTL**: `betas: ["extended-cache-ttl-2025-04-11"]` enables extended prompt caching (1h) instead of the default 5-minute TTL, reducing cache churn on long sessions.
- **Flicker-free rendering**: `env.CLAUDE_CODE_NO_FLICKER = "1"` switches to fullscreen rendering mode (equivalent to `/tui fullscreen`).
- **Adaptive thinking disabled by default**: `env.CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING = "1"` pins thinking budget to `MAX_THINKING_TOKENS` instead of adapting per-turn. No effect on Opus 4.7 (always adaptive).

### Design Rationale
- Keeping these as a single "one knob on" default set simplifies onboarding — users who want the stock behaviour change one value; users who don't care get the fast path.
- Unknown keys (`effortLevel`, `betas`) are silently ignored by older Claude Code versions, so no version gating needed in the installer.
- `auto` mode is the only default that genuinely needs fallback; the existing `_supports_auto_mode` check in `install.sh` handles that.

### Notes & Caveats
- `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING` and `CLAUDE_CODE_NO_FLICKER` are recognised by Claude Code 2.1.104+. On earlier versions they are harmless no-ops.
- Adaptive thinking is always on for Opus 4.7 regardless of the env var — change `model` if you need strict fixed-budget behaviour.

## [2.3.1] - 2026-04-12

### Bug Fixes
- **Windows remote install crash**: Fixed `ParameterBindingException` when running `irm URL | iex` on PowerShell 5.x. Internal tokens like `"adversarial-review"` leaked into `$args` and were splatted as positional arguments to `Invoke-Expression`. Now filters `$args` to only pass recognized switch-style arguments (starting with `-`).

### Design Rationale
- `$_safeArgs` filter replaces raw `@args` splatting — keeps `.\install.ps1 -All` working locally while preventing garbage token leakage in `irm | iex` piped mode.

## [2.3.0] - 2026-04-10

### Features
- **Adaptive statusline wrapping**: Statusline now dynamically wraps segments to the next line based on terminal width instead of being truncated. Uses visible-width calculation with ANSI-aware measurement.
- **Adaptive progress bar sizing**: Context and 5h usage progress bars shrink (min 8 chars) when terminal space is tight, staying on the same line when possible.
- **Smart terminal width detection**: Walks ancestor process file descriptors via `/proc/$PID/fd/` to find the real terminal in pipe contexts where `$COLUMNS` and `tput cols` are unreliable.
- **DeepXiv SDK integration**: New Academic Research group with `deepxiv_sdk` plugin for academic paper search and analysis.

### Bug Fixes
- **COLUMNS=0 in pipe context**: Claude Code passes empty/zero `COLUMNS` to statusline subprocess; now detected and falls back to fd probing.
- **macOS `wc -L` fallback**: `visible_len()` falls back to `${#stripped}` on platforms where `wc -L` is unavailable (BSD/macOS).
- **Negative bar sizing clamp**: When preceding segments exceed available space, adaptive bar sizing now correctly clamps instead of silently using full 20-char width.
- **Width cache**: Segment widths cached in parallel array, reducing subshell forks from ~13 to ~7 per render.

### Design Rationale
- Segment array architecture replaces string concatenation for clean separation of layout concerns
- PPID fd walk is more correct than `/dev/pts/*` glob which could read another session's terminal
- `visible_len()` uses `wc -L` (GNU) for emoji/CJK double-width accuracy with `${#}` fallback for portability

### Notes & Caveats
- Wrapping only occurs at segment boundaries; a single segment wider than terminal will overflow naturally
- Hardcoded label overhead estimates (18/14 chars) may drift by 1-2 chars on edge cases

## [2.2.0] - 2026-04-02

### Features
- **Two-level interactive menu**: Main menu shows group summaries (`[selected/total]`); Enter/→ opens sub-menus, ←/Esc returns. Groups: Core, Language Rules, Review, Skills, Plugins — Official/Community/AI Research, MCP Servers.
- **Review tool selector**: New "Review" group — `code-review` plugin (ON), `adversarial-review` skill (ON), Codex CLI (OFF). adversarial-review and Codex are mutually exclusive with auto-toggle.
- **Restored adversarial-review skill**: Cross-model reviewers (Claude↔Codex) with Skeptic/Architect/Minimalist lenses from [poteto/noodle](https://github.com/poteto/noodle).
- **New humanizer-zh skill**: Chinese AI writing pattern removal from [op7418/Humanizer-zh](https://github.com/op7418/Humanizer-zh).
- **Per-plugin granularity**: All 23 plugins individually selectable (previously bundled into groups).
- **Dynamic CLAUDE.md Code Review section**: Installer rewrites the Code Review rule based on selected review tool.
- **Arrow key navigation**: ←/→ supported for sub-menu entry/exit in addition to Enter/Esc.

### Bug Fixes (bash 5.x / Linux)
- **Root cause**: `(( var++ ))` from 0 returns exit code 1 under bash 5.x `set -e`, silently killing the script. macOS bash 3.2 does not trigger `set -e` on this. Fixed all instances: `(( flat_idx++ ))` → `(( ++flat_idx ))`, `(( fixed++ ))` → `(( ++fixed ))`, `(( selected[j] )) && (( cnt++ ))` → added `|| true`.
- **`[[ ]] && cmd` without `|| true`**: `_enforce_review_mutex` and main menu ALL handler crashed when the last loop iteration didn't match. Added `|| true` guards to all `[[ test ]] && assignment` patterns.
- **`local _menu_active`**: Trap handlers couldn't access local variables under bash 5.x; changed to global.
- **install.ps1**: Removed stale `$groups` override that destroyed menu data, causing Windows interactive menu crash.
- **Terminal fd probe**: Detects broken `/dev/tty` (EOF) and falls back to non-interactive default install. Only rejects EOF (ret=1), not stray input bytes (ret=0).
- **EXIT trap**: Added `_menu_cleanup` to EXIT trap to restore terminal on unexpected exit (prevents stuck alternate screen).

### Design Rationale
- Two-level menu keeps the main view compact while allowing fine-grained control
- Mutual exclusion prevents conflicting review tools from being installed simultaneously
- All `(( ))` arithmetic and `[[ ]] && cmd` patterns now systematically protected against `set -e`
- fd probe provides defense-in-depth without false positives

### Notes & Caveats
- `--all` installs everything with adversarial-review (not Codex) as default
- Codex CLI selection automatically installs `codex@openai-codex` plugin
- adversarial-review skill requires `codex` CLI for cross-model review

## [2.1.0] - 2026-04-02

### Features
- **Codex adversarial-review plugin**: Replaced the built-in `adversarial-review` skill with the official [Codex plugin](https://github.com/openai/codex-plugin-cc) (`codex@openai-codex`). Code reviews now use `/codex:adversarial-review` with automatic fallback to Claude's `code-reviewer` agent when Codex is unavailable. Plugin is included in the default installation.
- **Skill rename**: Reverted `/update` back to `/update-config` — directory renamed from `skills/update/` to `skills/update-config/` to match. Installer cleans up legacy `skills/update` and `skills/adversarial-review` paths on upgrade.
- **Smart-merge enabledPlugins strategy**: Changed from "existing wins" to "union" — new plugins from incoming config are now added alongside existing ones, ensuring upgrades pick up new plugins like `codex@openai-codex` automatically.

### Design Rationale
- The Codex plugin provides a maintained, official adversarial review implementation with shared runtime and better integration
- Namespaced skill commands (`update-config`) prevent accidental shadowing of project-level `/update` commands across all repositories
- Union merge for `enabledPlugins` ensures upgrade users automatically get new plugins without losing their existing configuration
- Fallback review path (`code-reviewer` agent) ensures code review works even without Codex CLI or OpenAI API key

### Notes & Caveats
- Codex plugin requires authentication via `codex login` (run `/codex:setup` to check status)
- The `docs/adversarial-review-showcase.md` is preserved as historical reference
- CHANGELOG history entries for `update_config` and `adversarial-review` are preserved as-is
- Installer migration automatically removes legacy `skills/update` and `skills/adversarial-review` directories

## [2.0.0] - 2026-03-27

### Features
- **Auto mode default**: `settings.json` now ships with `defaultMode: "auto"` instead of `bypassPermissions`. Auto mode (announced 2026-03-24) lets Claude approve safe actions autonomously while blocking risky ones — a safer middle ground for power users. Installer auto-detects Claude Code version and falls back to `bypassPermissions` for versions < 2.1.80.

### Design Rationale
- Auto mode classifies each tool call for risk before execution; safe operations proceed, risky ones are blocked
- Version detection in `install.sh` (`_supports_auto_mode`) ensures backward compatibility without user intervention
- Distinguishes "Claude Code not installed" vs "version too old" in warning messages

### Notes & Caveats
- Auto mode requires Claude Sonnet 4.6 or Opus 4.6 model; not available on Haiku, claude-3 models, or third-party providers (Bedrock, Vertex, Foundry)
- Auto mode is a research preview on Team plans; Enterprise and API support rolling out
- `sed -i` fallback replaced with portable `sed > tmp && mv` for macOS compatibility

## [1.9.4] - 2026-03-27

### Features
- **paper-reading skill**: Replaced unreliable ar5iv HTML + Playwright screenshot pipeline with pure PDF + pymupdf4llm automatic extraction. Figures, vector graphics, and tables are now extracted directly from PDF with `pymupdf4llm.to_markdown(write_images=True)`, then filtered and renamed automatically.

### Design Rationale
- ar5iv coverage is incomplete — many papers lack HTML versions, causing the screenshot flow to fail entirely
- pymupdf4llm wraps `get_images()` + `cluster_drawings()` + `get_pixmap(clip=...)` into a single call, handling both raster and vector figures automatically
- Added graceful degradation: theoretical papers with no meaningful figures produce text-only summaries

### Notes & Caveats
- Requires `pymupdf4llm` package (auto-installs `pymupdf` as dependency)
- OCR disabled by default (`use_ocr=False`) to avoid tesseract dependency
- Template image placeholders changed from hardcoded `figure_X.png` to HTML comment guides

## [1.9.3] - 2026-03-26

### Features
- **PUA plugin**: Added [tanweai/pua](https://github.com/tanweai/pua) as a new plugin group — AI agent productivity booster with multi-language support (CN/EN/JA), forces exhaustive problem-solving and systematic debugging

### Design Rationale
- PUA is a popular community plugin that significantly improves agent persistence and problem-solving thoroughness
- Added as an opt-in group (default off) to keep the install lightweight for users who don't need it

### Notes & Caveats
- New marketplace `pua-skills` added (total: 7 marketplaces, 22 plugins)
- Both install.sh and install.ps1 updated with new plugin group, menu item, dispatch, and uninstall support
- Both README.md and README.zh-CN.md updated with plugin tables

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
