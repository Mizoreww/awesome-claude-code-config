# Shared report backbone

Keep this sequence recognizable in every paper type. Use the same complete, concise close-reading depth in every report.

## 1. Basic information

Follow the original compact list shape rather than a table or metadata grid:

- **Title**
- **Authors** — link each principal author to an official or personal homepage.
- **Corresponding author / paper contact** — link the explicitly named corresponding author; when the public paper does not identify one, say so and link a verified paper contact such as the official submitter instead of guessing.
- **Affiliation / lab** — link each represented lab or research group to its authoritative homepage. Prefer the group that actually hosts the named authors, not the university root. Use a department or institution homepage only when no authoritative lab/group page can be verified, and label that fallback explicitly.
- **Published** — venue, version, and date when available.
- **Link** — canonical paper page; add project/code links only when useful.
- **Paper Type** — primary type and any named secondary module.
- **One-line summary** — one sentence containing the problem, mechanism, and demonstrated result.

Keep PDF hashes, physical-page conventions, extraction directories, raw-asset counts, and other implementation provenance in internal manifests or working notes, never in this visible section.

## 2. Research problem

- Name the precise gap, not the whole field.
- State the formal task or system goal when it clarifies the gap.
- Surface assumptions and constraints early.
- Explain why the obvious or incumbent approach is insufficient.
- Position the paper against its two or three closest comparisons using the paper's own framing; distinguish checked comparison from author framing.

## 3. Key insight

State the enabling observation in two or three dense sentences:

1. what the paper notices;
2. what operation or representation follows from that observation;
3. why that changes the bottleneck.

“The paper proposes a new method” is not an insight. Name the causal or mathematical mechanism.

## 4. Type-specific analysis

Insert the modules from the selected primary type in the order specified by its reference. For a cross-type paper, retain that primary backbone and add only necessary modules from one named secondary type; do not replace both with a generic hybrid outline.

## 5. Critical analysis

Separate these headings:

- **What the evidence supports:** strongest claim justified by the reported setup.
- **Author-acknowledged limitations:** quote only short necessary phrases and anchor them.
- **Report assessment:** assumption failures, missing comparisons, metric blind spots, compute/data dependence, generalization gaps, or proof/measurement gaps.
- **Implementation audit:** availability and sufficiency of code, data, checkpoints, specifications, and environment details; identify what the pinned public code confirms or contradicts without executing it.

Pair every criticism with the evidence or missing test that makes it consequential. Avoid generic “more experiments are needed.”

## 6. Summary and evaluation

Use three explicitly separated perspectives:

1. **Authors' conclusion:** the claim the paper makes.
2. **Report assessment:** whether the presented evidence reaches that claim.
3. **Overall evaluation:** core idea, real advance, most useful takeaway, and next falsifying or extending experiment.

If a rating helps the user, choose `Breakthrough`, `Important`, `Valuable`, or `Incremental` and justify it with one concrete comparison. A rating is optional; its evidence is not.

End by checking:

- What were the authors trying to accomplish?
- What mechanism carries the contribution?
- Which evidence is decisive, and under what conditions?
- What can be reused in the reader's own research?
- Which unresolved reference or experiment matters next?
