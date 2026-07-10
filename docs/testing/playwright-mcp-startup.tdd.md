# Playwright MCP Startup TDD Evidence

Date: 2026-07-10

Branch: `codex-dev`
Source plan: the explicit session plan tracked the reproducer, environment audit, installer audit, TDD fix, end-to-end verification, and two-axis review; no standalone plan file was supplied.

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
| Review RED | `9ecae2e` | `bash tests/check_playwright_mcp_installation.sh` | Expected failure | The installer still used `--version`; no JSON-RPC `initialize` request was sent, and the Core-only template path remained unsafe. |
| Review GREEN | `aad73b7` | `bash -n install.sh && bash tests/check_playwright_mcp_installation.sh` | PASS | The test now requires an initialize result, rejects a zero-exit/no-result launcher, and verifies the copied template. |

## Test specification

| # | What is guaranteed | Test target | Type | Result |
|---|---|---|---|---|
| 1 | Node.js 18 installs a Playwright command that runs pinned MCP `0.0.78` under isolated Node.js 24 | `node18` case | Integration | PASS |
| 2 | Node.js 20+ keeps the direct upstream `npx` launcher while pinning MCP `0.0.78` | `node24` case | Integration | PASS |
| 3 | The installer sends JSON-RPC `initialize` through the exact launcher and does not register on non-zero exit or missing result | `smoke_failure` and `missing_initialize` cases | Integration/error path | PASS |
| 4 | A Core-only install copies a Node-18-safe Playwright command and never restores `@latest` | `core-only` case | Integration | PASS |
| 5 | Bash and PowerShell contain matching policy and neither registers `@latest` | structural assertions | Cross-platform contract | PASS |
| 6 | PowerShell executes the Node 18, Node 24, missing-result, and non-zero-exit branches | `tests/install_ps1_playwright_mcp.Tests.ps1` | Function integration | PASS |

## Coverage and known gaps

This repository has no line-coverage harness for shell installers. The focused integration test runs the real Bash `--mcp` and `--core` paths with mocked Node.js, npx, and Codex boundaries. PowerShell 7.6.2 was downloaded to a temporary directory from the official Microsoft release, verified against its published SHA-256, and used to execute the new function-level test; the temporary runtime was then removed. Native Windows PowerShell 5.1 remains a Windows CI/manual compatibility gate.

## End-to-end verification

- The original launcher on host Node.js 18.19.1 deterministically exited before initialization with `Playwright requires Node.js 20 or higher`.
- The compatibility launcher returned an MCP `initialize` result and successfully handled `browser_navigate` against `https://example.com`, returning the `Example Domain` title.
- A real `bash install.sh --mcp` run refreshed the user's Playwright registration only after the new initialize check passed.
- A fresh `codex exec --ephemeral` run returned `MCP_STARTUP_OK` without either `MCP client for playwright failed to start` or `MCP startup incomplete`.

## Merge evidence

Both RED/GREEN cycles are preserved as separate commits on `codex-dev`. If they are later squashed for promotion, retain the RED/GREEN commands and outcomes above in the resulting commit or release notes.
