# Playwright MCP Startup TDD Evidence

Date: 2026-07-10  
Branch: `codex-dev`  
Source plan: none; journeys were derived from the reported Codex startup failure.

## User journeys

- As a Codex installer user on Node.js 18, I want Playwright MCP to start without changing my system Node.js, so Codex can complete MCP initialization.
- As a user with a supported Node.js runtime, I want the installer to keep the standard Playwright launcher and a reproducible package version.
- As a user running the installer, I want a launcher failure detected before registration, so the installer cannot report a broken MCP entry as successful.
- As a maintainer, I want Bash and PowerShell installers to retain the same Playwright behavior.

## RED and GREEN evidence

| Stage | Commit | Command | Result | Evidence |
|---|---|---|---|---|
| RED | `20f6a51` | `bash tests/check_playwright_mcp_installation.sh` | Expected failure | Node.js 18 case did not contain the isolated Node.js 24 launcher or startup probe. |
| GREEN | `9eb951c` | `bash -n install.sh && bash tests/check_playwright_mcp_installation.sh` | PASS | Output: `Playwright MCP installer checks passed`. |

## Test specification

| # | What is guaranteed | Test target | Type | Result |
|---|---|---|---|---|
| 1 | Node.js 18 installs a Playwright command that runs pinned MCP `0.0.78` under isolated Node.js 24 | `node18` case | Integration | PASS |
| 2 | Node.js 20+ keeps the direct upstream `npx` launcher while pinning MCP `0.0.78` | `node24` case | Integration | PASS |
| 3 | The installer probes the exact launcher and does not call `codex mcp add playwright` after a failed probe | `smoke_failure` case | Integration/error path | PASS |
| 4 | Bash and PowerShell contain matching version/runtime constants and neither registers `@latest` | structural assertions | Cross-platform contract | PASS |

## Coverage and known gaps

This repository has no line-coverage harness for shell installers. The focused integration test runs the real Bash `--mcp` path with mocked Node.js, npx, and Codex boundaries and covers the legacy-runtime, supported-runtime, and startup-failure branches. PowerShell behavior is structurally checked because `pwsh` is not installed in the current Linux environment; native PowerShell/Pester validation remains part of the Windows CI/manual gate.

## Merge evidence

The RED reproducer and GREEN implementation are preserved as separate commits on `codex-dev`. If they are later squashed for promotion, retain the RED/GREEN command and outcomes above in the resulting commit or release notes.
