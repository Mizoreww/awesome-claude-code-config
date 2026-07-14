# Visual reasoning policy

## Diagram-opportunity audit

Before composing HTML, list the paper's genuine comprehension bottlenecks. For each, record:

| Bottleneck | Why prose is hard | Candidate medium | Chosen treatment | Source anchor | Render checked |
|---|---|---|---|---|---|

Audit at least the core mechanism, experimental comparison, and decisive limitation. “No visual needed” is a valid treatment when prose or a compact table is clearer.

There is no minimum or maximum SVG count. A report with zero SVGs can pass; a report with several can pass. The decision is explanatory, not decorative.

## Choose the medium

| Need | Prefer | Avoid |
|---|---|---|
| Exact quantitative result | Original table/plot or an accurate HTML table | Redrawing values by eye |
| Non-obvious pipeline or state change | Concise SVG or HTML/CSS flow | A paragraph that forces mental simulation |
| Equation and symbol relation | Equation plus nearby prose; small SVG only for geometry | Turning ordinary algebra into a poster |
| Method A vs B | Two-column comparison or paired schematic | Two unrelated decorative illustrations |
| Exact architecture/detail | Original paper figure with evidentiary caption | Oversimplifying away the evaluated mechanism |
| Small set of categorical facts | Table or aligned list | SVG boxes with no added relationship |
| Failure case or qualitative evidence | Original examples with labels and conditions | Generic icons |

When the original figure supplies fidelity and a simplified visual supplies intuition, show both in a bounded comparison component. State what was simplified.

## SVG admission test

Draw an SVG only when all are true:

1. It explains non-obvious structure, flow, contrast, or interaction.
2. The relationships are grounded in exact paper/code anchors.
3. Prose, a table, or the original figure would impose more cognitive work.
4. It can remain legible without cramming labels.
5. Its caption states the abstraction boundary.

Do not use SVG for decorative headings, familiar one-direction sequences, copied plots, metric tiles, or scientific-looking filler.

## Visual grammar

Use the report's semantic colors consistently:

- blue for claims or proposed components;
- teal for observed evidence/data;
- red for limitation/failure;
- purple for reproduction.

Use rounded rectangles for components, circles only for states/entities that benefit from that distinction, solid arrows for actual flow, and dashed arrows for optional/feedback/uncertain relationships. Label arrows when the transformation is not obvious. Prefer fewer than roughly ten nodes in one view; split a dense diagram rather than shrinking it.

The hero may be expressive, but its fingerprint labels must come from the paper. Below the hero, keep visuals quiet and evidence-led.

## Asset handling

- Keep `assets/raw/` immutable.
- Copy selected figures into the report's `assets/` with descriptive names.
- Preserve sufficient resolution for the lightbox; do not upscale a blurry crop and call it high-resolution.
- Record the source figure/table/page in the caption or evidence ledger.
- Do not crop away axes, legends, comparison rows, failure examples, or qualifications needed to interpret the result.
- Use meaningful alt text that communicates the visual's role, not “image” or the filename.

## Mandatory render inspection

Inspect every new SVG in the rendered report, not just its source. Check:

1. hierarchy is visible in three seconds;
2. labels fit and are readable at mobile width;
3. arrows terminate at the intended object and do not cross ambiguously;
4. spacing makes groups and sequence obvious;
5. colors retain their semantic meaning and contrast;
6. the lightbox opens the whole visual;
7. the caption and source anchor match what is drawn.

If the SVG fails, simplify it, choose another medium, or remove it. Never keep a weak diagram merely because HTML mode “should have SVG.”
