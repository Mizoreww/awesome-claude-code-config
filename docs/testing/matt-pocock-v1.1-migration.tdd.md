# Matt Pocock v1.1 Migration TDD Evidence

Date: 2026-07-13

Branch: PR #49, `fix/matt-skills-v1-1-migration`

Source plan: the review task supplied the user journey and acceptance criteria; no standalone plan file was provided.

## User journeys

- As an existing installer user, I want retired Matt Pocock skills removed from every shared agent association so the v1.1 install can proceed.
- As a user with a stale Matt Pocock lock entry but no remaining skill directory, I want the matching lock retired so a later generic update cannot restore retired content.
- As a PowerShell user, I want every failed pinned install to clear ownership recorded during the attempt so unverified content is never treated as installer-owned.
- As a user with `XDG_STATE_HOME`, I want the installer to read and retire the same global skill lock that the Skills CLI updates.
- As a maintainer, I want the same migration guarantees executed by both Bash and PowerShell tests.

## RED and GREEN evidence

| Stage | Commit | Command | Result | Evidence |
|---|---|---|---|---|
| RED | `ffd06d5` | `bash tests/check_codex_skill_reconciliation.sh` | Expected failure | `skills@latest remove ... --agent '*'` was rejected and the test ended with `legacy Matt Pocock cleanup failed`. |
| RED | `ffd06d5` | `/tmp/pr49-pwsh/runtime/pwsh -NoProfile -File tests/install_ps1_skill_reconciliation.Tests.ps1` | Expected failure | After making the fixture cross-platform, PowerShell reached the same legacy-cleanup failure. |
| GREEN | `225a7c4` | `bash tests/check_codex_skill_reconciliation.sh` | PASS | Output ended with `Codex skill reconciliation checks passed`. |
| GREEN | `225a7c4` | `/tmp/pr49-pwsh/runtime/pwsh -NoProfile -File tests/install_ps1_skill_reconciliation.Tests.ps1` | PASS | Output: `install.ps1 skill reconciliation tests passed`. |
| XDG RED | `a101f90` | `bash tests/check_codex_skill_reconciliation.sh` | Expected failure | Output: `global skill lock path did not honor XDG_STATE_HOME`. |
| XDG RED | `a101f90` | `bash tests/check_codex_migration.sh` | Expected failure | The Bash/PowerShell parity contract found no XDG lock-path handling in the installers. |
| XDG GREEN | `fabd70c` | `bash tests/check_codex_migration.sh && bash tests/check_codex_skill_reconciliation.sh` | PASS | Both migration and XDG-backed runtime lock scenarios passed. |
| XDG GREEN | `fabd70c` | `/tmp/pr49-pwsh/runtime/pwsh -NoProfile -File tests/install_ps1_skill_reconciliation.Tests.ps1` | PASS | PowerShell lock and ownership scenarios passed against an XDG-backed lock path. |
| Resolver RED | `072437a` | `/tmp/pr49-pwsh/runtime/pwsh -NoProfile -File tests/install_ps1_skill_reconciliation.Tests.ps1` | Expected failure | Production did not expose `Get-GlobalSkillLockFile`, so the XDG/HOME conditions could not be tested directly. |
| Resolver GREEN | `8570566` | `/tmp/pr49-pwsh/runtime/pwsh -NoProfile -File tests/install_ps1_skill_reconciliation.Tests.ps1 && bash tests/check_codex_migration.sh` | PASS | Tests directly executed the production resolver's XDG and HOME fallback branches; the parity contract also passed. |

## Test specification

| # | What is guaranteed | Test target | Type | Result |
|---|---|---|---|---|
| 1 | Legacy cleanup omits the invalid wildcard agent and uses the CLI's default all-agent removal path | Bash and PowerShell npx fakes | Integration/regression | PASS |
| 2 | Matching `mattpocock/skills` lock entries for retired names are deleted while unrelated lock entries remain unchanged | legacy cleanup fixtures | Integration/error state | PASS |
| 3 | A PowerShell exception after npx records ownership returns failure and clears ownership for every requested skill | injected lock-cleanup exception | Unit/error path | PASS |
| 4 | The PowerShell reconciliation fixture initializes every selection flag and uses a platform-neutral temporary directory | full PowerShell test script | Cross-platform regression | PASS |
| 5 | Both installers use `$XDG_STATE_HOME/skills/.skill-lock.json` when configured and the home fallback otherwise | Bash runtime fixture plus direct `Get-GlobalSkillLockFile` branch tests | Cross-platform integration/unit | PASS |

## External CLI reproduction

An isolated HOME with `skills@1.5.16` under Node.js 24 reproduced the upstream behavior directly:

- `skills remove to-prd --global --agent '*' --yes` exited 1 with `Invalid agents: *` and preserved the skill.
- `skills remove to-prd --global --yes` exited 0 and removed the skill from the detected agents.

## Coverage and known gaps

This repository has no line-coverage harness for shell installers. The focused tests execute the affected functions and success/error branches in both implementations. PowerShell 7.6.3 was downloaded to a temporary directory from the official Microsoft release, verified against its published SHA-256, and used without a system installation. Native Windows PowerShell 5.1 remains a Windows CI/manual compatibility gate.

## Merge evidence

The RED and GREEN checkpoints are separate commits on the PR branch. Preserve this document or the equivalent command/result summary if the commits are later squashed.
