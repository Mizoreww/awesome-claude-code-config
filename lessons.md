# Project Lessons

> Project-specific corrections for `awesome-claude-code-config`.
> Format: date, context, mistake, rule. Cross-project rules belong in `~/.codex/lessons.md`.

---

<!-- Keep repository-specific corrections here so they travel with this project. -->

<!--
Example lessons (invisible to `cat`, visible in editors):

## 2025-01-15
**Context**: Editing Python files
**Mistake**: Used `print()` for debugging in production code
**Rule**: Always use `logging` module instead of `print()`. Remove all `print()` before committing.

## 2025-02-03
**Context**: Running shell commands on user's machine
**Mistake**: Modified ~/.zshrc without being asked
**Rule**: Never modify shell config files (~/.bashrc, ~/.profile, ~/.zshrc) unless explicitly requested. Prefer project-local or user-space alternatives.
-->

## 2026-07-13 - Keep this task's changes on codex-dev
**Context**: ResearchStudio evaluation and correction-memory routing in `awesome-claude-code-config`.
**Mistake**: Updated only the live `~/.codex/AGENTS.md` and treated the memory-routing request as machine-local, even though the user intended both it and the ResearchStudio work to be versioned Codex-branch changes.
**Rule**: Implement the project/global lessons routing in the repository's Codex AGENTS template and installers, keep the ResearchStudio integration on `codex-dev`, and do not modify Claude `main` or promote formal `codex` before user testing and confirmation.

## 2026-07-13 - Install only a blank global lessons log
**Context**: Separating installed global memory from per-project correction history.
**Mistake**: The old installer treated the repository-root `lessons.md` as the file to copy into every user's global Codex directory, conflating project history with global memory.
**Rule**: Seed `~/.codex/lessons.md` only from a blank global template. A project's root `lessons.md` is created by the agent on the first project-specific correction and then maintained as a project artifact, analogous to an on-demand `CHANGELOG.md`; never install or copy one project's lessons into global state.

## 2026-07-13 - ResearchStudio must be opt-in
**Context**: Adding ResearchStudio to the Codex Academic Research category.
**Mistake**: Although the interactive menu default was off, the first implementation still installed ResearchStudio through generic non-interactive `all` fallback paths, which could make a default no-TTY install opt in implicitly.
**Rule**: ResearchStudio is default-off everywhere. Install it only after an explicit menu selection, explicit `--all` / `-All`, or explicit AI-research skill-group request; ordinary default/fallback installs and dry-run-only mode must not install it.

## 2026-07-13 - Keep the ResearchStudio guide out of the repository
**Context**: Teaching the user how to use the optional ResearchStudio integration.
**Mistake**: Added a multi-file teaching guide under `docs/researchstudio-guide/`, even though the guide is personal reference material rather than a project artifact to upload.
**Rule**: Keep the user-facing ResearchStudio guide outside the repository and explain usage directly to the user. Version only the installer behavior and concise maintainer-facing documentation needed by this project.

## 2026-07-13 - Disclose ResearchStudio's Python dependency step
**Context**: A user explicitly selects the optional ResearchStudio item in the Codex installer.
**Mistake**: The installer requested upstream Python dependency installation with `RS_PIP=1` but did not clearly tell the user that four packages would be installed or that an upstream pip failure could require manual repair.
**Rule**: When ResearchStudio installation starts, display one concise notice naming the automatically requested Python packages and tell the user to run the connector check afterward because upstream pip failure is non-fatal.

## 2026-07-13 - Prefer a post-install ResearchStudio self-check
**Context**: Making ResearchStudio dependency failures actionable after an opt-in install.
**Mistake**: Added only a pre-install dependency notice, leaving the user to run and interpret the connector check manually even though the installer can perform that validation itself.
**Rule**: After the upstream ResearchStudio installer finishes, automatically run its `check_connectors` command. Print the check output and, when dependencies, credentials, or probes are degraded, tell the user exactly how to install the Python packages, where to add missing environment variables, and how to rerun the check.

## 2026-07-13 - Make self-check remediation instructional
**Context**: Reporting a degraded ResearchStudio post-install self-check.
**Mistake**: Summarized categories of corrective action without teaching the user the actual sequence or showing platform-appropriate commands and configuration examples.
**Rule**: Self-check remediation must be a numbered, copyable procedure: install packages with the active interpreter, show concrete Bash or PowerShell venv activation for PEP 668, show the `.env` key/value format without real secrets, protect the file where applicable, and finish with the exact rerun command. Missing Python or skill scripts must likewise include concrete install or reinstall commands.

## 2026-07-13 - Separate ResearchStudio Idea and Reel availability
**Context**: Mapping the official ResearchStudio project into the Codex Academic Research menu.
**Mistake**: Treated Reel's absence from the GitHub npx package as if Reel itself were unreleased, even though the official repository publishes five Reel skills and its full-checkout installer can install them.
**Rule**: Present two independent, default-off Academic Research entries: ResearchStudio Idea through the packaged official npx path, and ResearchStudio Reel through a full official checkout. Keep their ownership, dependencies, self-checks, removal, and quickstarts separate; state clearly that Reel needs native tools and Chromium beyond its Python packages.

## 2026-07-13 - Use one ResearchStudio installation model
**Context**: Installing the independent ResearchStudio Idea and Reel entries in the Codex Academic Research category.
**Mistake**: Mixed the packaged npx path for Idea with a source-checkout path for Reel, creating two installation, update, security-validation, and troubleshooting models for one upstream project.
**Rule**: Install both ResearchStudio entries from the official source repository. For each selected bundle, copy only an explicit skill allowlist after validating required `SKILL.md` files and rejecting links; install known dependencies explicitly, run bundle-specific self-checks, and never execute the upstream installer or use `sudo`.

## 2026-07-13 - Offer ppt-master as a full opt-in setup
**Context**: Restoring `hugohe3/ppt-master` to the Codex Slides category.
**Mistake**: Treated ppt-master's heavy environment as a reason to omit it completely, even though the user wants the complete capability when they explicitly select it.
**Rule**: Add ppt-master as an independent, default-off Slides item on `codex-dev`. A normal/default install must not touch it; an explicit selection must install the Codex skill together with its required runtime dependencies, run an actionable self-check, and explain any remaining platform or credential repair without silently claiming success.

## 2026-07-13 - Keep agent-authored tests out of uploaded branches
**Context**: Preparing the current `codex-dev` installer changes for the user to test and later upload.
**Mistake**: Added agent-authored regression scripts and TDD evidence files to the branch that the user intends to publish.
**Rule**: Use temporary/local tests to validate this repository's installer changes, but do not include agent-authored standalone test files or test-evidence documents in the uploaded branch unless the user explicitly asks for them. Existing tests may receive only the minimum compatibility edits required to remove assertions contradicted by the requested production change or initialize newly managed names; do not add new agent-authored test scenarios. Give the user a direct manual test command instead.

## 2026-07-13 - Prove the real installer works before handoff
**Context**: The user ran the Codex installer on a Node.js 18 / PEP 668 host after the ResearchStudio and PPT Master changes.
**Mistake**: Relied on mocked and structural checks without completing a clean end-to-end installer run on the actual host toolchain. `npx skills` failed under Node.js 18, Python `--user` installs failed under PEP 668, selected skills remained incomplete, and source copies were still reported as installed.
**Rule**: Before presenting or uploading installer changes, run the real installer in an isolated HOME using the host's actual Node/Python constraints and verify every selected component exists and passes its runtime self-check. Provide a runtime path that works on Node.js 18 and PEP 668 systems, and never print an installation-success message when required dependencies failed.
