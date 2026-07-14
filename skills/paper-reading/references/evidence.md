# Evidence and writing discipline

## Contents

1. Coordinate model
2. Claim-evidence ledger
3. Anchors and source boundaries
4. Critique discipline
5. Density edit

## Coordinate model

Assign stable coordinates in reading order:

- `C1`, `C2`, ... — a material claim or inference.
- `E1`, `E2`, ... — paper, code, external-primary-source, or run evidence.
- `L1`, `L2`, ... — a limitation, failed assumption, or evidence gap.

Do not create coordinates for decorative metadata or every sentence. Create them for every material result and criticism.

Coordinates are local to the report. Never imply that `C1` is the paper's own claim number unless it actually is.

## Claim-evidence ledger

Maintain a working ledger before writing polished prose:

| ID | Statement | Voice | Anchor(s) | Support status | Report use |
|---|---|---|---|---|---|
| C1 | Exact proposition being assessed | author / report inference / external | E1, E3 | supported / partial / unsupported | thesis, method |
| E1 | Observation, theorem, result, or code fact | source | exact location | direct / indirect | supports C1 |
| L1 | Boundary or missing test | author / report assessment | E2 or named absence | consequential because... | critique |

The final report may present the ledger as marginal coordinates rather than a literal table, but the mapping must remain recoverable.

### Voice labels

- **Author claim:** the source explicitly asserts it.
- **Report inference:** a reasoned interpretation not stated verbatim by the authors.
- **External evidence:** a primary source outside the paper.
- **Code-confirmed fact:** behavior directly established by the pinned authoritative implementation.

Never slide from one voice to another inside a sentence. “This proves” is rarely justified when the source only reports an experiment.

## Anchors and source boundaries

Use the narrowest stable anchor available:

- Paper: `§3.2, Eq. 4, p. 6`, `Fig. 2`, `Table 3`, `Appendix B.1`.
- Official HTML: section heading plus canonical URL fragment.
- Code: repository, exact revision, file path, and line range or symbol.
- External source: direct primary-source URL and accessed version/date when it can change.

If PDF page numbering and printed page numbering differ, state which convention the report uses. If only HTML/full text is available, do not invent page numbers.

### Permitted external scope

Inspect the official project and authoritative code repository read-only. Check paper-cited primary sources only when needed to avoid a misleading material comparison. Do not perform open-ended literature search, install or execute code, or download datasets/checkpoints as part of the reading workflow.

Broader prior-art or novelty checking requires a separately stated scope.

### Evidence strength

Match wording to evidence:

- A table supports performance in its reported setup, not universal superiority.
- An ablation supports contribution under the ablation design, not a unique causal explanation.
- A fixed point or equilibrium property does not by itself establish convergence to that point.
- A released checkpoint supports bounded inference/evaluation; it does not reproduce training.
- A toy example can verify mechanism behavior; it does not reproduce a large-scale benchmark.

## Critique discipline

Interrogate the link between claim and evidence:

1. What assumption makes the argument work?
2. What observation would falsify the mechanism?
3. Do baselines isolate the claimed difference?
4. Does the metric capture the user-relevant failure mode?
5. Are compute, data, representation, or tuning confounded with the core idea?
6. Which failure cases are reported, and which important regime is absent?
7. For theory, which assumption or bound limits the practical interpretation?
8. For systems, does the benchmark represent deployment conditions?

Write the consequence, not just the defect. Example: “The comparison changes both the objective and training budget, so Table 2 cannot isolate the proposed objective's contribution.”

## Density edit

Keep a sentence only if it adds at least one of:

- mechanism;
- evidence or source condition;
- comparison;
- limitation;
- implication.

Cut generic field introductions, repeated mini-summaries, promotional adjectives, obvious transitions, and sentences that merely rename a section. Prefer one precise sentence over a three-item rhetorical list.

Use numbers with conditions: dataset/split, sample count, metric direction, baseline, evaluation protocol, and uncertainty when available. Preserve equations that carry the method; define symbols immediately and explain what the equation changes operationally.
