# Shared report backbone

Keep this sequence recognizable in every paper type. The selected level controls coverage inside each section.

## 1. Basic information

- Title, authors, affiliations when relevant, venue/version/date, canonical paper link, and code/project links.
- Primary paper type and any secondary module.
- One sentence containing the problem, mechanism, and demonstrated result.
- Reading level, source version, and coverage boundary.

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
- **Reproducibility:** availability and sufficiency of code, data, checkpoints, specifications, and environment details.

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
