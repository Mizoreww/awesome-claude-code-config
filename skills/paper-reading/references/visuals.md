# Visual reasoning policy

## Diagram-opportunity audit

Before composing HTML, list the paper's genuine comprehension bottlenecks. For each, record:

| Bottleneck | Why prose is hard | Candidate medium | Chosen treatment | Source anchor | Render checked |
|---|---|---|---|---|---|

Audit at least the core mechanism, experimental comparison, and decisive limitation. “No visual needed” is a valid treatment when prose or a compact table is clearer.

There is no general minimum or maximum SVG count. Empirical/systems module anatomy is the one explicit exception: every load-bearing module needs one full-width horizontal local-interface SVG above its detail fields. These diagrams are not decoration; they let the reader scan exact inputs → transformation → outputs before reading implementation detail. Give distinct inputs and outputs separate nodes, and never force the diagram into a narrow side rail. All other SVG decisions remain explanatory rather than quota-driven.

## Choose the medium

| Need | Prefer | Avoid |
|---|---|---|
| Exact quantitative result | Original table/plot or an accurate HTML table | Redrawing values by eye |
| Non-obvious pipeline or state change | Concise SVG or HTML/CSS flow | A paragraph that forces mental simulation |
| Equation and symbol relation | Equation plus an immediate plain-language explanation; small SVG only for geometry | A formula wall, or turning ordinary algebra into a poster |
| Method A vs B | Two-column comparison or paired schematic | Two unrelated decorative illustrations |
| Exact architecture/detail | Original paper figure with evidentiary caption | Oversimplifying away the evaluated mechanism |
| Small set of categorical facts | Table or aligned list | SVG boxes with no added relationship |
| Failure case or qualitative evidence | Original examples with labels and conditions | Generic icons |

When the original figure supplies fidelity and a simplified visual supplies intuition, show both in a bounded comparison component. State what was simplified.

For empirical work, the central result visual is mandatory when the paper provides one. Copy the original plot or qualitative panel into the local report assets, place it beside the relevant result interpretation, and mark its figure `data-original-result`. HTML tables and redrawn summaries help scan exact values; they do not substitute for the original visual evidence.

## SVG admission test

Draw an SVG only when all are true:

1. It explains non-obvious structure, flow, contrast, or interaction.
2. The relationships are grounded in exact paper/code anchors.
3. Prose, a table, or the original figure would impose more cognitive work.
4. It can remain legible without cramming labels.
5. Its caption states the abstraction boundary.

Do not use SVG for decorative headings, copied plots, metric tiles, or scientific-looking filler. A required module interface map may use a simple one-direction flow, but it must carry the module's real symbols, tensor/data names, and transformation boundary rather than generic “input/model/output” boxes. Its connectors may merge only after each distinct input has appeared in its own node; arrows and labels must not overlap.

## Visual grammar

Use the report's semantic colors consistently:

- blue for claims or proposed components;
- teal for observed evidence/data;
- red for limitation/failure;
- purple only for a clearly labelled report inference or unresolved implementation discrepancy.

Use rounded rectangles for components, circles only for states/entities that benefit from that distinction, solid arrows for actual flow, and dashed arrows for optional/feedback/uncertain relationships. Label arrows when the transformation is not obvious. Prefer fewer than roughly ten nodes in one view; split a dense diagram rather than shrinking it.

Spend the expressive treatment on the verified title focus. Limit the hero to title, authors, and thesis; below it, keep visuals quiet and evidence-led.

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
6. the lightbox opens the whole visual at a restrained initial size;
7. desktop wheel zoom and mobile pinch zoom work without scrolling the page, and panning starts only after zooming;
8. the caption stays visible inside the viewer and its source anchor matches what is drawn.

If the SVG fails, simplify it, choose another medium, or remove it. Never keep a weak diagram merely because HTML mode “should have SVG.”
