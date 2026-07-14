# Read-only code audit

Use this audit for every paper. Its purpose is to verify technical claims against authoritative implementation artifacts, not to reproduce results.

## 1. Locate authoritative code

Check, in order:

1. repository linked by the paper or official project page;
2. author or project-organization repository explicitly naming the paper;
3. implementation explicitly cited by the paper.

Do not silently treat a third-party reimplementation as the paper's code. If no authoritative implementation is found, record the exact paper/project/author surfaces checked and report `public code not found`.

## 2. Pin and preserve provenance

Record the canonical repository URL and an exact commit or release revision. Prefer a stable release or the revision named by the paper. If web inspection is insufficient, make a shallow clone in a temporary directory and keep the checkout pristine.

Do not install, import, execute, patch, or benchmark project code. Do not download datasets, checkpoints, or model weights. Reading source, configuration, manifests, documentation, and static metadata is allowed.

## 3. Trace the implementation

Follow the implemented path rather than listing filenames. Map each load-bearing paper module to:

- entry point and configuration;
- exact input fields, shapes, types, preprocessing, and batching;
- output fields, shapes, ranges, and downstream consumers;
- model class, layers, dimensions, routing, and frozen/trainable state;
- dataset loader, split, sampling, augmentation, labels, and supervision source;
- objectives, loss weights, optimizer, schedule, batch size, step/epoch count, and stopping rule;
- inference or evaluation path and any training/inference difference;
- defaults or implementation tricks omitted from the prose.

Use file paths plus symbols or line ranges. A repository homepage alone is not code evidence.

## 4. Reconcile paper and code

Label implementation statements with one of these bases:

- **Paper-stated:** explicit in the paper, not independently confirmed in code.
- **Code-confirmed:** the pinned implementation directly establishes it.
- **Paper/code discrepancy:** wording, default, shape, sign convention, module boundary, or training recipe differs.
- **Report inference:** a reasoned explanation not stated directly by either source.
- **Not reported / not applicable:** the field is unavailable or does not apply; explain which.

Do not resolve a discrepancy by choosing the more convenient source. State both versions and the consequence for understanding or implementation.

## 5. Report the audit compactly

Put code evidence inside the relevant module card rather than adding a long repository tour. For each module, cite the pinned revision and the narrowest useful path/symbol. Add one short implementation-status paragraph only when it helps explain repository scope, missing components, or paper/code drift.

The audit is complete when a reader can distinguish paper description, code-confirmed behavior, discrepancies, and inference for every load-bearing module without any code having been executed.
