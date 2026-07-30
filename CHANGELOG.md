# Changelog

## [Unreleased] - 2026-07-30

### Features
- Added a separate **Storage** group to the Codex Bash and PowerShell installers with one item, `storage-analyzer`, off by default. It performs a read-only disk-usage scan, classifies cleanup candidates into three tiers, and can produce an interactive HTML report with guarded cleanup actions.
- Vendored the same ten-file package released on the Claude/main line in `v3.1.0`, based on [KKKKhazix/khazix-skills commit `fcba3ad`](https://github.com/KKKKhazix/khazix-skills/tree/fcba3adcf5def1ccd4bb688de93060227471b129/storage-analyzer) (MIT). This is a modified copy with Linux support and security hardening, not a byte-for-byte upstream snapshot; provenance and every local change are recorded in `skills/storage-analyzer/UPSTREAM.md` and were submitted upstream as [khazix-skills#50](https://github.com/KKKKhazix/khazix-skills/pull/50).
- Integrated the skill into Codex-managed ownership, reconciliation, uninstall, and local-copy paths so the authoritative installation lives at `~/.codex/skills/storage-analyzer/`, never `~/.agents/skills/storage-analyzer/`.

### Design Rationale
- Keep disk cleanup outside Workflow because it is an occasional operation with real destructive capability, not part of an everyday coding loop. The separate group keeps it visible without making it default-on.
- Preserve the Codex line's explicit opt-in semantics: interactive users must select it; `--all` / `-All` and an explicit `--skills all` / `-Skills -SkillGroup all` include it; bare `--skills` / `-Skills` and standard dry runs do not.
- Reuse the already reviewed main-line runtime unchanged, while adapting only Codex installer, ownership, documentation, and release surfaces.

### Notes & Caveats
- The runtime uses only Python 3's standard library. Linux trash prefers `gio` or `trash-put` and otherwise writes an XDG `.trashinfo` entry itself.
- Platform evidence is unchanged from the main-line release: verified on Ubuntu 24.04.4 / ext4 / GNOME, not on Arch, Fedora, NixOS, multi-partition layouts, a real headless server, or Windows. The vendored macOS path also carries the `du -x` / `st_dev` external-mount fix.
- The Linux work previously completed four adversarial-review rounds. A fifth review attempt did not produce a conclusion, so the iterative `_rmtree_at` implementation still has author testing only; this limitation remains disclosed in `UPSTREAM.md` and the upstream PR.

## [2.10.2] - 2026-07-23

### Features
- Added [`neat-freak`](https://github.com/KKKKhazix/khazix-skills/tree/2b4a645cfdc894156ae347d897723562f719ce95/neat-freak) to the Workflow group as a default-on bundled skill in both Bash and PowerShell installers.
- Vendored the six-file runtime closure from upstream commit `2b4a645cfdc894156ae347d897723562f719ce95`: `SKILL.md`, four references, and the read-only inventory script. Upstream evaluation fixtures are not shipped.

### Design Rationale
- Pin and review the runtime instead of fetching mutable code during installation, while preserving every upstream runtime file byte-for-byte. The exact upstream MIT license is included alongside the skill.
- Keep the canonical `neat-freak` name and its unchanged upstream semantics; attribution and installer integration remain outside the runtime snapshot.

### Notes & Caveats
- The bundled snapshot installs only to `~/.codex/skills/neat-freak/`; no alias or shared `~/.agents/skills` copy is created.
- The skill has no required third-party package dependency. Its optional inventory helper uses Bash; when Bash, Git, or `rg` is unavailable, the unchanged upstream workflow directs the agent to perform equivalent checks manually.

## [2.10.1] - 2026-07-14

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
- Released to `codex` after user approval. Paper-specific acceptance reports, extracted figures, screenshots, and other generated paper assets remain external and are not part of this release.
- PDF extraction pins `pymupdf4llm==1.28.0` in a project-independent isolated environment and records that version while preserving raw assets/graphics metadata; final visual selection still requires human/agent render inspection.
- The validator rejects duplicate/removed navigation surfaces, reading-lens and evidence-index controls, metadata tables or visible extraction bookkeeping, missing author/contact/lab homepage links, unmarked institution-level affiliation fallbacks, incomplete module anatomy, module visuals placed after their fields, merged interface nodes, missing original empirical result figures, vague code evidence, unexplained display equations, code-styled or legacy-script mathematics, unwrapped visuals, remote `srcset`/SVG image fetches, and unsafe or escaping local links. The enforced browser test covers the single outline, inline-math overflow, local equation explanations, initial image size, wheel/pinch zoom without scroll leakage, and contained captions.
- Math rendering pins `latex2mathml==3.78.1`, parses converter output with `defusedxml==0.7.1`, enforces a shared inert presentation-MathML tag/attribute allowlist, and reserializes the checked tree before HTML embedding. Reports admit exactly one marked inline enhancement script, preventing XML/HTML parser differences from reactivating converter text; generated equations have no network dependency.
- Code inspection is deliberately read-only and must distinguish paper-stated, code-confirmed, discrepant, inferred, and unavailable details. Reproduction remains outside this report workflow.

## [2.10.0] - 2026-07-13

### Features
- Upgraded the managed Matt Pocock workflow set to v1.1.0: `to-prd`/`to-issues` are replaced by `to-spec`/`to-tickets`, `wayfinder` is added, and the retired `decision-mapping`/`review` names are migration-only cleanup entries.
- Made Matt Pocock installs reproducible in both Bash and PowerShell by downloading release commit `d574778f94cf620fcc8ce741584093bc650a61d3` and installing from the local snapshot; added per-skill content verification, CLI-compatible home/XDG lock discovery, explicit retirement of matching current and legacy lock entries, provenance-gated cleanup across shared agent associations, and fail-closed ownership handling.
- Migrated the latest Claude main installer categories into the Codex branch as Codex-native groups: Review, Workflow, Development Tools, Design & Content, Lifestyle, Academic Research, Slides, and MCP Servers.
- Added `npx skills@latest add ... --agent codex --copy --yes --full-depth` as the first-choice installer path for compatible upstream skill packs, with the Python `skill-installer` kept as fallback for path-based packs.
- Set the Codex template defaults to `model = "gpt-5.6-sol"`, `model_reasoning_effort = "max"`, `approval_policy = "never"`, `sandbox_mode = "danger-full-access"`, and a `[tui].status_line` footer showing model, reasoning, project, branch, context use, five-hour quota, and weekly quota.
- Made repeat interactive installs selection-authoritative for installer-owned skills in both Bash and PowerShell: unchecked owned skills are removed, while an empty skill selection requires confirmation before bulk removal.
- Added persistent managed-skill ownership state plus safe adoption of legacy lock sources only when Codex/canonical copies match, unchanged bundled copies, and the verified `obra/superpowers` fallback; retired `coding-foundations` names remain provenance-gated cleanup-only entries, and `handoff` is restored as a visible default-on Workflow choice.
- Updated both installers to ensure statusline settings inside `[tui]`, removing misplaced top-level or project-scoped `status_line` entries during the merge.
- Removed Codex installer entries that have no practical Codex install target, including Claude-only command workflow plugins, `claude-mem`, and `claude-health`.
- Enabled the GitHub MCP menu item by default; installation uses `GITHUB_PERSONAL_ACCESS_TOKEN` when present and skips GitHub MCP without writing a placeholder token when absent.
- Hardened installer edge cases found in review: removed orphaned managed skill names, restored npx-first AI/DeepXiv paths, and made statusline merging handle missing or multi-line config safely.
- Added a conditional Matt Pocock post-install quickstart to both installers: after the full pack succeeds, it points users to Codex `/skills` or `@`, names `setup-matt-pocock-skills`, and explains that installed skills are not individual root slash commands.
- Changed the installed Codex review policy and menu default to Matt Pocock's `code-review` Standards/Spec workflow; `adversarial-review` remains opt-in and Codex no longer spawns `claude -p` reviewers by default.
- Made Playwright MCP runtime-safe across both installers and the static `config.toml` template: pin `@playwright/mcp@0.0.78`, use an isolated Node.js 24 launcher when the host Node.js is older than 20, and refuse to register the server unless it returns an MCP `initialize` result.
- Added separate, default-off Microsoft ResearchStudio Idea and Reel entries to **Academic Research**. Both installers use a temporary official source checkout: Idea copies `idea_spark`, `paper_search`, and `scoop_check`; Reel copies `paper2assets`, `paper2poster`, `paper2video`, `paper2blog`, and `paper2reel`. Only the allowlisted skill source is installed, with Idea's Claude-only instructions and project paths adapted for Codex.
- Added `hugohe3/ppt-master` as a separate, default-off **Slides** item. Explicit selection installs the official skill definition through `npx skills`; runtime dependencies remain a first-use concern of the skill workflow.
- Made all `npx skills` installs work on Node.js 18 hosts by supplying an isolated Node.js 24 launcher.
- Made remote npx skill completion depend on an installed canonical `SKILL.md` plus a matching nonempty source/hash lock fingerprint freshly updated by the current invocation, rather than the `skills` CLI exit code alone. Path-based AI research entries map repository folder names to their declared skill names, and removed Matt Pocock entries that current upstream no longer exposes.
- Kept ResearchStudio Idea, ResearchStudio Reel, and PPT Master deliberately skill-only: the installers do not create environments, install Python packages or browsers, probe native tools, or run runtime dependency self-checks.
- Kept completion output concise by removing the separate ResearchStudio Idea, ResearchStudio Reel, and PPT Master post-install Quickstart blocks; each skill carries its own first-use instructions.
- Made optional bundle selection truly explicit: bare `--skills` / `-Skills` keeps ResearchStudio and PPT Master off, while an explicit `all`, `ai-research`, full-install flag, or interactive selection opts in as documented.
- Made incomplete installs return a non-zero status and leave the installed-version stamp unchanged.
- Split correction memory by scope: the installed `~/.codex/lessons.md` is seeded from a dedicated blank global template, while project-specific corrections live in an on-demand `<project-root>/lessons.md` that Codex is instructed to discover and read.

### Design Rationale
- A successful `skills@latest` exit does not prove that every requested name was installed, and remote tag/commit suffixes currently resolve inconsistently. A prevalidated immutable local snapshot plus explicit directory checks prevents partial or mixed-version installs.
- Omitting `--agent` is the current reliable all-agent removal path: `skills@1.5.16` rejects its documented `--agent '*'` value. Explicit matching-source lock cleanup also covers retired entries that no longer have an installed directory for the CLI to discover, and mirrors the CLI's `$XDG_STATE_HOME/skills/.skill-lock.json` override when configured.
- Codex does not have Claude Code's plugin runtime, so the migration preserves user-facing categories while mapping installable capabilities to Codex skills, MCP servers, or explicit skipped items.
- `npx skills` is the most direct cross-agent skill installer for repositories that expose valid `SKILL.md` entries, while the existing Python installer remains useful as a fallback for nested path installs.
- Codex's `/statusline` command persists footer fields under `[tui]`; writing a top-level `status_line` can silently land inside the previous TOML table when appended to an existing config.
- The Codex installer now favors a clean selectable surface over migration parity for items that would only warn or require heavy manual setup.
- A validated ownership file bounds reconciliation so a generic catalogue name is never treated as deletion authority by itself. `npx skills remove --global --agent codex` updates Codex/global metadata before Codex-local fallback cleanup, and generic `~/.agents/skills` children are never scanned or deleted except by an explicit provenance-verified retired-source migration.
- Current `skills@latest` global Codex installs can use the canonical shared `~/.agents/skills` directory even with `--agent codex --copy`; Codex discovers that directory, while its root `/` menu remains a command menu and exposes installed skills through `/skills` or `@`.
- `codex mcp add` proves that configuration was written, not that the stdio process can initialize. Sending the exact launcher a JSON-RPC `initialize` request first prevents an incompatible Node.js/Playwright combination from being reported as a successful install, while pinning the MCP version prevents a later `latest` release from silently changing a validated command.
- One source-based ResearchStudio path avoids maintaining separate npx and checkout behavior. The installers validate a fixed skill allowlist, reject links, and copy only the selected bundle without executing the upstream installer or granting it `sudo`; dependency setup is deferred to the skill's first-use instructions.
- Keeping ResearchStudio and PPT Master skill-only avoids coupling the configuration installer to platform-specific Python, browser, and native-tool environments that the upstream workflows already know how to establish or explain.
- The current `skills` CLI can exit successfully after silently ignoring an unknown requested name. Requiring the requested directory plus a matching nonempty lock hash freshly written by the current installer run closes that false-success and accidental-ownership path, while using declared frontmatter names handles upstream repositories whose folder basename is not the install name.
- Keeping project lessons out of the global seed prevents one repository's corrections from silently affecting unrelated work. The same on-demand principle used for project changelogs applies: no project log is required until the first project-scoped correction occurs.

### Notes & Caveats
- Matt Pocock legacy cleanup removes all agent associations and matching-source lock entries only when installer ownership or a `mattpocock/skills` lock source proves provenance; unknown same-name skills and unrelated lock entries are preserved.
- `github` and `lark-mcp` remain credential-gated; GitHub uses `GITHUB_PERSONAL_ACCESS_TOKEN`, while lark-mcp stays manual because it needs app credentials.
- Both Slides entries are default off. Selecting `ppt-master` installs only its skill definition; browser confirmation, live preview, and any runtime setup occur only when a real deck workflow reaches those stages.
- The autonomous YOLO defaults should only be used in trusted repositories.
- Existing Codex TUI sessions may need a restart or `/statusline` refresh before the new footer fields appear.
- Skill reconciliation runs only after a real interactive menu submission. Explicit non-interactive flags remain additive, and core files, MCP configuration, shared-agent skills, unowned/custom skills, and ambiguous legacy entries are not removed.
- Repeat installs preserve existing `model` and `model_reasoning_effort` values; the new defaults apply only when creating `config.toml`, while a selected StatusLine is refreshed to the managed footer layout.
- The Matt Pocock quickstart is suppressed for dry-runs and failed installs, and an already-open Codex TUI may need to be restarted before newly installed skills appear.
- The Node.js 24 compatibility launcher covers Playwright MCP and all `npx skills` operations and requires `npx` plus a first-use package download. Installing a supported Node.js 24 LTS runtime remains preferable.
- Installer ownership is recorded for npx skills only when the canonical `SKILL.md` is present and the current invocation refreshes the matching shared-lock source/hash entry. An incomplete `npx` result retries only path-based entries not verified by that invocation and remains visible in the final skipped-components report if fallback also fails.
- Both ResearchStudio entries are default off. They install independently after explicit menu selection; an explicit AI-research group request or `--all` / `-All` selects both. Bare `--skills` / `-Skills` does not select them. The upstream npx package still omits Reel, which no longer affects this integration because both bundles come from the official source tree.
- When first invoked, Idea may need Python and optional connector credentials; Reel may need Python, browser, and native document/media tools; PPT Master may need its own Python/browser stack. The installer neither provisions nor validates those runtimes. Paper2Video's advanced deck route needs the separately selectable `ppt-master` or an existing PPTX. Deselect/uninstall preserves `~/.codex/skills/.env` to avoid deleting user-managed secrets.

## [1.7.3] - 2026-04-09

### Features
- Removed DeepXiv runtime-missing warnings from both installers so Codex installs no longer tell users to install a separate local `deepxiv` CLI
- Updated English and Chinese README guidance to describe DeepXiv as skills refreshed into Codex on each install run
- Extended the active cleanup spec/plan docs with the corrected DeepXiv installation model

### Design Rationale
- In this repo's supported Codex workflow, DeepXiv is consumed as an installed skill set inside Codex rather than as a separately managed local CLI runtime
- Warning users about a missing standalone runtime created false setup friction and implied an unnecessary manual `pip install` step
- Keeping the install model aligned across scripts and docs reduces confusion and avoids reintroducing the same misconception later

### Notes & Caveats
- This change removes the standalone `deepxiv` CLI requirement only for the Codex workflow documented by this repo
- Upstream DeepXiv skills are still refreshed from `DeepXiv/deepxiv_sdk` during install
- Historical changelog/spec documents may still mention the older runtime-warning behavior as part of the project record

## [1.7.2] - 2026-04-09

### Features
- Standardized installer internals from Claude-oriented names to Codex-first names, including skill selector state variables and menu identifiers
- Updated Codex-branch README navigation labels from `Main` to `Source` to reduce branch ambiguity while keeping links unchanged
- Refreshed the active cleanup spec/plan docs so they document the deeper internal naming pass as well as the user-visible cleanup

### Design Rationale
- User-facing labels are not enough when the active implementation still encodes old naming in variables and menu IDs; consistent internals reduce future drift
- Changing active implementation names is safer now that the compatibility boundary is explicit: preserve legacy file paths, but simplify current code paths
- Historical migration docs and changelog entries remain factual records and should not be rewritten as if the old names never existed

### Notes & Caveats
- Legacy compatibility paths such as `~/.codex/.claude-code-config-version` are still preserved intentionally
- Upstream source identifiers such as `affaan-m/everything-claude-code` are still unchanged where required for installation
- Historical migration/design docs may still mention Claude-specific names when they are recording past decisions or migration mappings

## [1.7.1] - 2026-04-09

### Features
- Reframed README and README.zh-CN so Codex is the default audience, while Claude-related material is limited to migration and compatibility notes
- Renamed the user-facing recommended skill-pack label from `everything-claude-code` to `coding-foundations` in both installer UIs and docs, while keeping the upstream source path intact
- Updated bundled `update_config` and `adversarial-review` skill docs to describe Claude-era paths as compatibility details instead of the main workflow

### Design Rationale
- Codex users should not need to parse Claude-first branding or menu labels to understand what to install; neutral presentation reduces migration friction
- Preserving upstream repo names and legacy version-file fallback avoids breaking installs while still cleaning up the default user experience
- Keeping a single migration document is clearer than scattering Claude-specific explanations throughout the primary setup docs

### Notes & Caveats
- Upstream install sources still include names such as `affaan-m/everything-claude-code`; only the user-facing display labels were changed
- The legacy `~/.codex/.claude-code-config-version` path is still read for compatibility with older installs
- `docs/claude-main-to-codex-migration.md` remains in the repo as the dedicated migration reference

## [1.7.0] - 2026-04-08

### Features
- Added interactive Bash and PowerShell installer UIs for plain no-arg runs when a usable terminal/console is available; explicit dry-run preview paths remain non-interactive where implemented
- Added Codex-native selectable groups for Core, Agents, Skills — Recommended, Skills — AI Research, and MCP Servers
- Kept explicit CLI flags backward-compatible for non-interactive installs and previews (`--all` / `-All`, `--core` / `-Core`, `--mcp` / `-Mcp`, `--skills` / `-Skills`, `--dry-run` / `-DryRun`)

### Design Rationale
- The main-style menu flow gives Codex users a familiar selector while still presenting Codex-specific defaults and install targets
- Preserving explicit flags avoids breaking scripts and automation that already depend on the installer’s non-interactive paths
- Grouping the UI around core files, agents, recommended skills, AI research skills, and MCP servers matches the actual Codex distribution surface instead of a generic all-or-nothing install

### Notes & Caveats
- `~/.codex/config.toml` is still never overwritten automatically; users must merge template changes manually if they want them
- Bash plain no-arg runs fall back to a non-interactive full install with a warning when no terminal is available
- PowerShell plain no-arg runs fall back to a non-interactive full install with a warning when console I/O is unavailable
- PowerShell explicitly treats an empty interactive submission as a no-op

## [1.6.0] - 2026-04-08

### Features
- Installer now refreshes `deepxiv-cli`, `deepxiv-baseline-table`, and `deepxiv-trending-digest` directly from `DeepXiv/deepxiv_sdk` on every install run
- Bash and PowerShell installers now remove existing DeepXiv skill directories before reinstalling them from upstream
- Installers now warn when the `deepxiv` CLI runtime is missing instead of attempting to install it automatically
- Documentation now describes DeepXiv as an install-time upstream dependency instead of a bundled local skill copy

### Design Rationale
- DeepXiv changes frequently enough that mirroring superpowers-style upstream installs is a better fit than snapshotting local copies in this repo
- Reinstalling the managed DeepXiv skills ensures repeat installs actually refresh to the latest upstream version instead of silently keeping stale copies

### Notes & Caveats
- DeepXiv skill refresh still depends on the skill installer being available and GitHub being reachable during install
- The `deepxiv` CLI itself is still a separate runtime dependency and must be installed on PATH by the user

## [1.5.0] - 2026-04-08

### Features
- Added bundled DeepXiv skills: `deepxiv-cli`, `deepxiv-baseline-table`, and `deepxiv-trending-digest`
- Installer uninstall tracking now includes the three DeepXiv skills on both bash and PowerShell paths
- README, Chinese README, and migration notes now document the new DeepXiv skill set and its CLI dependency

### Design Rationale
- DeepXiv's progressive paper-reading workflows complement the existing research-oriented Codex setup without requiring a separate plugin system
- Bundling the upstream skills directly in this repo keeps local installs reproducible and ensures the installer can copy them like other repo-local skills

### Notes & Caveats
- These skills expect the `deepxiv` CLI to already be installed and available on PATH, typically via `pip install deepxiv-sdk`

## [1.4.0] - 2026-03-20

### Features
- Added a bundled `update_config` skill for refreshing the installed Codex configuration from the `codex` branch
- Added a `docs/claude-main-to-codex-migration.md` reference mapping Claude Code main-branch concepts to Codex equivalents
- Normalized version-stamp handling so the PowerShell installer now writes the Codex-native stamp path while still reading the legacy fallback

### Design Rationale
- A dedicated migration document is clearer than restoring Claude-era top-level plugin/rules structures that no longer match the Codex branch architecture
- The update skill needs consistent version-stamp behavior across platforms to report installed vs remote versions correctly

### Notes & Caveats
- Existing Windows installs using the old `.claude-code-config-version` file continue to work because the installer and update skill now read both paths during transition

## [1.3.0] - 2026-03-11

### Features
- Installer now installs the full `obra/superpowers` repo via native skill discovery instead of copying only four skills
- Installer creates `~/.agents/skills/superpowers` symlink and removes the legacy partial superpowers copies from `~/.codex/skills`
- README and README.zh-CN now document the full superpowers installation model and native discovery paths

### Design Rationale
- Superpowers upstream now expects repo-level installation plus skill-directory symlinking; mirroring that upstream flow avoids partial installs such as missing `brainstorming`
- Keeping superpowers as its own cloned repo makes updates straightforward with `git pull` and preserves the full upstream skill set without curating individual directories

### Notes & Caveats
- Existing users with a non-git directory at `~/.codex/superpowers` will need to resolve that path manually before the installer can manage it
- If `~/.agents/skills/superpowers` already exists as a normal directory instead of a symlink, the installer warns and skips replacing it automatically

## [1.2.0] - 2026-03-09

### Features
- Tokenization skill added to AI Research group (huggingface-tokenizers, sentencepiece)
- Web search date instruction in AGENTS.md Workflow section
- Repo URLs updated from `claude-code-config` to `awesome-claude-code-config`

### Design Rationale
- Synced from main branch to keep shared content consistent across Claude Code and Codex configurations
- Web search date instruction uses `date '+%Y-%m-%d'` with web time API fallback (no Windows variant needed since Codex CLI is Linux/macOS only)

### Notes & Caveats
- One-line install URL also updated to canonical repo name
- Skill installer is best-effort: network failures downgrade to warnings rather than blocking install

## [1.1.0] - 2026-03-05

### Features
- Adversarial code review skill (cross-model review via opposite AI CLI)
- Version changelog policy in AGENTS.md
- Multi-agent roles (explorer, reviewer, docs_researcher)

### Design Rationale
- Adversarial review spawns reviewers on the opposite model's CLI for genuine cross-model challenge
- Changelog policy keeps design decisions traceable

### Notes & Caveats
- Adversarial review requires `claude` CLI installed for Codex users

## [1.0.0] - 2026-03-02

### Features
- Initial Codex branch with AGENTS.md, config.toml, and lessons-based self-improvement loop
- Skill-first installer with open-source ecosystem skills
- Paper-reading skill for structured research paper analysis
- MCP integration (Lark, Context7, GitHub, Playwright, OpenAI docs)

### Design Rationale
- Companion branch to Claude Code main config — shared principles, Codex-specific tooling
- `config.toml` + `model_instructions_file` for lessons injection at session start

### Notes & Caveats
- Requires Codex CLI; power-user defaults (`approval_policy = "never"`, `sandbox_mode = "danger-full-access"`)
- MCP credentials must be filled in manually
