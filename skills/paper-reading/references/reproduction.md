# Deep reproduction

## Contents

1. Define the claim
2. Audit authoritative artifacts
3. Request bounded execution approval
4. Preserve provenance and environments
5. Run the smallest representative test
6. Interpret and record the result

## 1. Define the claim

Select at least one central claim from the paper ledger. Rewrite it as a falsifiable bounded check with conditions:

- mechanism behavior on an official toy/example setting;
- a released-checkpoint output or metric on a bounded sample;
- one ablation/design effect under the official recipe;
- a theorem, numerical property, or systems behavior with a minimal check.

State what the check does **not** reproduce. Importing a package, loading a checkpoint, or rendering an unscored sample is a smoke test, not yet a paper-claim reproduction.

## 2. Audit authoritative artifacts

Use this source order:

1. repository linked by the paper or official project page;
2. author/project organization repository;
3. implementation explicitly referenced by the paper;
4. independent minimal implementation, clearly labelled, only when no authoritative implementation exists.

Record before execution:

- canonical repository URL and exact commit/release revision;
- license and artifact provenance;
- entry point for the target claim;
- required data, checkpoints, credentials, and their sizes;
- runtime stack and version constraints;
- stated hardware versus locally available hardware;
- expected wall time, memory/accelerator needs, and paid-service implications;
- repository issues or upstream documentation that materially affect the run.

Do not treat an unpinned default branch as stable provenance.

## 3. Request bounded execution approval

Choosing deep mode authorizes this read-only audit. Before running, show one compact execution brief:

```text
Repository/revision:
Target claim and why this is representative:
Command or entry point:
Environment/dependencies:
Downloads and credentials:
Expected compute/time:
Expected artifacts:
Known compatibility risk:
```

Wait for approval unless the user already authorized this exact repository, command, dependency/download footprint, and compute bound. Ask again before escalating from toy/checkpoint evaluation to training, increasing sample count materially, using paid compute, or downloading substantially more data.

## 4. Preserve provenance and environments

- Keep the upstream checkout pristine and pinned.
- Reuse a compatible existing environment when safe.
- Otherwise prefer `uv`; fall back to an isolated standard `venv`.
- Treat an already-existing compatible Conda environment as optional, never required.
- Never install into base, system Python, or the user's global site packages.
- Capture interpreter, package, accelerator/driver, and platform versions.
- Store commands and stdout/stderr in `reproduction/`.

If compatibility changes are necessary:

1. copy or branch from the pristine checkout;
2. make the smallest patch;
3. store a diff and rationale;
4. label the result **compatibility-patched**, not **official unmodified**.

If no authoritative code exists, an independent implementation must identify each behavior inferred from the paper and may verify only the bounded claim it implements.

## 5. Run the smallest representative test

Use this ladder, stopping at the first rung that tests the target claim:

1. Official toy/minimal example with a quantitative or trajectory assertion.
2. Official checkpoint inference/evaluation on a bounded sample.
3. Minimal training or numerical/proof check that isolates the mechanism.
4. Full benchmark or training only with explicit resource approval.

Define acceptance before running. Include seed/sample count, tolerance, metric code, expected direction/value, and failure conditions. Prefer one central claim tested well over several superficial commands.

Keep three evidence layers distinct:

- **smoke:** the software/environment runs;
- **representative reproduction:** a bounded central claim is observed;
- **full reproduction:** the paper's principal setup and metric are recreated.

Never report the second as the third.

## 6. Interpret and record the result

Classify the run:

- `passed`: the predeclared bounded acceptance criterion was met;
- `partial`: the run completed but only part of the criterion or setup matched;
- `blocked`: execution could not test the claim after the bounded audit.

Explain discrepancies before attributing them: code revision, data subset, checkpoint, precision, seed, hardware, dependency patch, metric implementation, or paper/code drift.

Write `reproduction/manifest.json`:

```json
{
  "status": "passed",
  "repository": "https://github.com/org/repo",
  "commit": "full-or-unambiguous-hex-revision",
  "claim": "C1",
  "command": "uv run ...",
  "environment": "Python ..., device ..., key packages ...",
  "result": "Observed result and acceptance comparison",
  "artifacts": ["run.log", "result.json"]
}
```

All artifact paths are relative to `reproduction/` and must exist. For `partial`, use the same fields and state the mismatch in `result`.

For `blocked`, replace execution fields that cannot exist with:

```json
{
  "status": "blocked",
  "repository": "https://github.com/org/repo",
  "commit": "full-or-unambiguous-hex-revision",
  "claim": "C1",
  "environment": "audited local environment",
  "artifacts": ["audit.log"],
  "blocker": "Specific missing access, artifact, compatibility, or resource condition",
  "audited_sources": ["authoritative URL or local audit record"]
}
```

A blocker is a result only when the audit evidence makes it specific and actionable. “Too hard” or “no GPU” without checking the smallest representative alternative is not sufficient.

If the authoritative-source audit establishes that no implementation was released or linked, do not invent repository provenance. Use the same blocked fields and artifacts, omit `repository`/`commit`, and add:

```json
"code_status": "not-found"
```

Reserve this exception for a documented no-code result. Missing data, credentials, dependencies, hardware, or runtime compatibility still requires the audited repository and pinned commit in the ordinary blocked manifest.
