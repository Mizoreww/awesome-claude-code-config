---
name: paper-reading
description: Read, summarize, and critically analyze an academic paper from a PDF, official HTML page, URL, or pasted full text. Use for requests such as "read this paper", "快速看懂", "精读论文", "analyze this paper", "paper summary", or strict paper critique. Produces evidence-traceable Markdown or a portable interactive HTML report at one complete, concise close-reading depth, with read-only inspection of authoritative source code when available and no reproduction run.
---

# Paper reading

Treat a paper report as an argument with inspectable evidence, not a longer abstract. Preserve the familiar paper-type structure and the original technical template while cutting any sentence that adds no mechanism, evidence, comparison, limitation, or implication.

Resolve `<skill-dir>` as the directory containing this file before using bundled scripts or assets.

In examples, `PYTHON_EXE` means the actual interpreter of a compatible active or isolated environment—for example `python3`, `python`, `py -3`, or an absolute venv executable. Resolve it for the current platform; do not run the token literally or assume one command name exists.

## 1. Choose only the output format

Honor an explicit or clearly implied format. Otherwise ask once whether the user wants **Markdown or HTML**, then wait. Explain briefly: Markdown is light and editable; HTML adds the designed reading surface, one section outline, static mathematics, and click-to-enlarge visuals.

Do not ask for a reading level. Use one standard throughout: read the complete argument, retain all load-bearing technical detail, and write it concisely. Do not run reproduction experiments as part of this workflow.

**Gate:** record `format`; do not silently choose it when genuinely ambiguous.

## 2. Ground the source

Accept a local or remote PDF, official full-text HTML, or complete pasted text. Prefer PDF when available because page and figure anchors are stable; do not make PDF mandatory.

For a PDF, keep the source unchanged and extract into a new directory:

```bash
uv run --isolated --no-project --with pymupdf4llm==1.28.0 \
  python <skill-dir>/scripts/extract_paper.py PAPER.pdf EXTRACTED_DIR
```

If `uv` is unavailable, use an isolated standard `venv`. Reuse an already-compatible environment when possible. Never require Conda or install into a base, system, or global environment.

The extractor writes page-anchored text, source hashes, and an immutable `assets/raw/` manifest. Copy selected visuals into the report; never delete raw extraction to “clean” it.

For official HTML or pasted text, preserve section names and stable URLs as anchors. State when page-level anchors are unavailable.

**Gate:** the full paper and materially relevant appendices are readable, provenance is recorded internally, and every retained visual can be traced to its source.

## 3. Classify the paper

Read the title, abstract, introduction, contribution statement, and section outline. Choose the primary branch:

- **Empirical:** new method/model with baseline experiments → read [empirical.md](references/empirical.md).
- **Theoretical:** theorem/proof is the contribution → read [theoretical.md](references/theoretical.md).
- **Survey:** taxonomy or synthesis across a field → read [survey.md](references/survey.md).
- **Systems:** system design, implementation, and benchmarks → read [systems.md](references/systems.md).

Always read [shared-sections.md](references/shared-sections.md). A cross-type paper still receives one primary branch; add only the necessary modules from one named secondary branch. Pass the primary type to the scaffold—`hybrid` is not a fifth catch-all type. Do not default an unclear paper to empirical; inspect its contribution and evidence first.

**Gate:** record the primary type, any secondary module, and the evidence for that classification.

## 4. Read the complete argument

Read the full paper and appendices that qualify the method, evidence, assumptions, negative results, or limitations. Build the report while reading rather than postponing synthesis.

Resolve:

- the problem, assumptions, closest comparisons, and enabling insight;
- every load-bearing module, its interfaces, and the actual training/inference loop;
- key equations, symbols, objectives, data, preprocessing, supervision, architecture, optimization, and evaluation protocol;
- main results, baselines, ablations, failure cases, and conditions under which the result changes;
- what the authors claim, what the evidence supports, and what remains inference.

For empirical and systems work, preserve the original module-level engineering anatomy. For every load-bearing module state its purpose, exact inputs, exact outputs, architecture and key parameters, training data and supervision, training method/objective/optimization, inference-time role, interfaces to adjacent modules, and code evidence. Put one full-width paper-grounded SVG directly below the module title and above its fields, with a horizontal inputs → core transformation → outputs flow. Give every distinct input and output its own non-overlapping node. Give symbolic inputs and outputs explicit LaTeX notation rendered as static inline MathML, including shapes/ranges when known. Use unordered lists for parallel items instead of packing enumerations into prose. Use `not applicable`, `frozen`, or `not reported` explicitly instead of omitting a field.

**Gate:** a technically literate reader can reconstruct the system boundary and data flow without guessing, and no important field vanished merely to make the report shorter.

## 5. Inspect authoritative code read-only

Read [code-audit.md](references/code-audit.md). Check the official paper/project surfaces for public code. When authoritative code exists, pin a revision and inspect it read-only—even if the user did not request reproduction—to verify module inputs/outputs, tensor or data shapes, architecture, defaults, losses, data pipeline, training schedule, and inference path.

Do not install dependencies, import the project, launch demos, download model weights or datasets, or run training/evaluation in this workflow. A shallow temporary clone is allowed when web inspection is insufficient; keep it pristine and delete or leave it outside the report.

Mark each implementation statement as paper-stated, code-confirmed, paper/code discrepancy, or report inference. If no authoritative implementation can be found, state the checked surfaces and `public code not found`; never substitute an unofficial repository silently.

**Gate:** every module card contains a code anchor or an explicit no-code/not-reported result, and paper/code mismatches are visible.

## 6. Build the claim-evidence spine

Read [evidence.md](references/evidence.md). Maintain `C` (claim), `E` (evidence), and `L` (limitation) coordinates. Anchor every material result and criticism. A criticism without a named assumption, comparison, failure case, or missing test is unfinished.

Separate what the authors claim, what code confirms, what the report infers, and what external primary evidence shows. Broader novelty or prior-art search remains a separate task unless explicitly requested.

**Gate:** every material statement resolves to an exact paper, code, or primary-source anchor, and inference is visibly labelled.

## 7. Audit and render visuals

For HTML, read both [visuals.md](references/visuals.md) and [html-report.md](references/html-report.md). Run the diagram-opportunity audit before drawing anything.

Outside module anatomy there is no SVG quota. Use prose, an aligned list, a table, an original figure, HTML/CSS, or SVG according to explanatory gain. Module anatomy is the explicit exception: every load-bearing module gets one quiet, full-width horizontal interface SVG above its fields so the reader can see the local data flow before reading detail. Never compress it into a narrow side rail or merge distinct interface values merely to save space. Keep those diagrams simple and specific, then render-inspect every SVG. Every image and SVG in HTML must open in the lightbox.

For empirical papers, keep the paper's load-bearing result figures beside the conclusions they support. At minimum include the original plot, qualitative panel, or result visualization that carries the central empirical claim, marked `data-original-result` in HTML. Recreated tables, metric cards, and explanatory SVGs may clarify the evidence but never replace the original result visual. If the paper genuinely contains no result figure, mark the results section `data-original-result-unavailable="paper-has-no-result-figure"` and preserve the original result table instead. Do not crop away axes, legends, baselines, failure cases, or qualifications needed to read the result.

Preserve important equations as LaTeX source and render them to static MathML with `scripts/render_math.py` as specified in the HTML reference. Put natural prose immediately below every display equation: define every letter, operator, index, and non-obvious symbol in that equation, then explain what the complete relation does and why it matters. Do not prefix the prose with a canned label such as “直观解释”. Inline notation must remain one atomic, non-scrollable inline unit; move longer causal chains into display blocks. Keep code styling for executable code, paths, and identifiers.

For Markdown, use the same content and evidence model, with selected original figures placed beside the claims they support.

**Gate:** every comprehension bottleneck has the clearest available treatment, every visual is faithful and sourced, the central empirical result retains its original paper visual when one exists, and no decorative scientific content is invented.

## 8. Write and validate the deliverable

Use the user's language; retain technical terms, equations, commands, and identifiers where translation would reduce precision.

- Markdown: write `summary.md` plus local `assets/` when needed.
- HTML: scaffold, replace every placeholder, then validate:

```bash
PYTHON_EXE <skill-dir>/scripts/scaffold_report.py REPORT_DIR \
  --title "..." --title-focus "..." --authors "..." \
  --paper-type empirical --thesis "..."
PYTHON_EXE <skill-dir>/scripts/validate_report.py REPORT_DIR/summary.html
```

Keep HTML CSS and JavaScript inline; keep high-resolution paper assets in `assets/` with relative paths.

Before delivery:

1. Remove scaffold markers and every sentence that adds no mechanism, evidence, comparison, limitation, or implication.
2. Check local links, coordinates, captions, equations, code anchors, and asset paths. Keep the visible basic-information section to the original concise list: title, linked authors/contact/labs or research groups, publication, link, paper type, and one-line summary. Keep hashes, page conventions, extraction directories, and asset counts internal.
3. For empirical/systems reports, verify that every load-bearing module has all nine anatomy fields, one full-width horizontal input→transform→output SVG above them, a separate node for every distinct input/output, unordered lists for genuine enumerations, and LaTeX-derived inline MathML for symbolic inputs/outputs; the overview still explains module-to-module flow.
4. For HTML, render at desktop and narrow-mobile widths; verify the single outline navigation, title hierarchy, MathML, symbol-complete explanations, atomic inline math, every visual, wheel/pinch zoom, keyboard close, print, and reduced-motion behavior.
5. Run the validator until it passes, then state source boundaries and code-inspection status without overstating certainty.

**Done:** the paper's complete argument is represented concisely, technical modules are reconstructable, evidence is traceable, public code has been inspected read-only when available, the output works offline from its directory, and limitations are as easy to inspect as headline claims.
