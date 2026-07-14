---
name: paper-reading
description: Read, summarize, critically analyze, or reproduce an academic paper from a PDF, official HTML page, URL, or pasted full text. Use for requests such as "read this paper", "快速看懂", "精读论文", "analyze this paper", "paper summary", strict paper critique, or method reproduction. Produces evidence-traceable Markdown or a portable interactive HTML report at brief, compact close-reading, or deep-reproduction scope.
---

# Paper reading

Treat a paper report as an argument with inspectable evidence, not a longer abstract. Preserve the familiar paper-type structure while spending words only on mechanism, evidence, comparison, limitation, or implication.

Resolve `<skill-dir>` as the directory containing this file before using bundled scripts or assets.

In examples, `PYTHON_EXE` means the actual interpreter of the compatible active or isolated environment—for example `python3`, `python`, `py -3`, or an absolute venv executable. Resolve it for the current platform; do not run the token literally or assume one command name exists.

## 1. Resolve the two choices

Honor choices already stated or clearly implied. Otherwise ask in this order and wait after each question.

1. Ask for **Markdown or HTML**. Explain briefly: Markdown is light and editable; HTML adds the designed reading surface, evidence tracing, and click-to-enlarge visuals.
2. Ask for one scope: **brief**, **compact close-reading (recommended)**, or **deep reproduction**.

Map intent without asking when it is unambiguous:

- “快速看懂” or an executive overview → `brief`.
- “默认”, ordinary close-reading, or “精读” → `compact`.
- reproduce, deeply inspect the method, or perform strict critique → `deep`.

Selecting `deep` authorizes the read-only code/artifact audit, not an unbounded run. Execution has its own gate in step 7.

**Gate:** record `format` and `level`. Do not silently choose or downgrade either.

## 2. Ground the source

Accept a local/remote PDF, official full-text HTML, or complete pasted text. Prefer PDF when available because page and figure anchors are stable; do not make PDF mandatory.

For a PDF, keep the source unchanged and extract into a new directory:

```bash
uv run --isolated --no-project --with pymupdf4llm==1.28.0 \
  python <skill-dir>/scripts/extract_paper.py PAPER.pdf EXTRACTED_DIR
```

If `uv` is unavailable, use an isolated standard `venv`. Reuse an already-compatible environment when possible. Never require Conda or install into a base, system, or global environment.

The extractor writes page-anchored text, source hashes, and an immutable `assets/raw/` manifest. Copy chosen visuals into the report; never delete raw extraction to “clean” it.

For official HTML or pasted text, preserve section names and stable URLs as anchors. State when page-level anchors are unavailable.

**Gate:** the full source needed by the selected level is locally readable, provenance is recorded, and every retained visual can be traced back to it.

## 3. Classify the paper

Read the title, abstract, introduction, contribution statement, and section outline. Choose the primary branch:

- **Empirical:** new method/model with baseline experiments → read [empirical.md](references/empirical.md).
- **Theoretical:** theorem/proof is the contribution → read [theoretical.md](references/theoretical.md).
- **Survey:** taxonomy or synthesis across a field → read [survey.md](references/survey.md).
- **Systems:** system design, implementation, and benchmarks → read [systems.md](references/systems.md).

Always read [shared-sections.md](references/shared-sections.md). A cross-type paper still receives one of these four primary branches; add only the necessary modules from one named secondary branch. Pass the primary type to the scaffold—`hybrid` is not a fifth catch-all type. Do not default an unclear paper to empirical; inspect its contribution and evidence first.

**Gate:** record the primary type, any secondary module, and the evidence for that classification.

## 4. Read to the chosen scope

Read [levels.md](references/levels.md), then execute only the chosen scope. The levels differ by coverage and verification work, not by permission to add filler.

Build the report while reading; do not postpone all synthesis until the end. Track assumptions, equations, experimental conditions, failure cases, and open questions beside their source locations.

**Gate:** satisfy every completion row for the selected level and do not imply coverage you did not perform.

## 5. Build the claim-evidence spine

Read [evidence.md](references/evidence.md). Maintain `C` (claim), `E` (evidence), `L` (limitation), and, in deep mode, `R` (reproduction) coordinates.

Separate:

- what the authors claim;
- what the report infers;
- what external primary evidence shows.

Brief mode anchors the decisive claims. Compact and deep modes anchor every material result and criticism. A criticism without a named assumption, comparison, failure case, or missing test is not finished.

**Gate:** every material statement required at this level resolves to an exact paper/code/run/URL anchor, and inference is visibly labelled.

## 6. Audit and render visuals

For HTML, read both [visuals.md](references/visuals.md) and [html-report.md](references/html-report.md). Run the diagram-opportunity audit before drawing anything.

There is no SVG quota. Use prose, a table, an original figure, HTML/CSS, or SVG according to explanatory gain. Draw SVG only when it unlocks non-obvious structure, flow, contrast, or interaction; render-inspect every SVG. Every image and SVG in HTML must open in the lightbox.

Preserve important equations as LaTeX source and render them to static MathML with `scripts/render_math.py` as specified in the HTML reference. Keep code styling for executable code, paths, and identifiers.

For Markdown, use the same content and evidence model, with selected original figures placed next to the claims they support.

**Gate:** every comprehension bottleneck has the best available treatment, every visual is faithful and sourced, and no decorative scientific content is invented.

## 7. Reproduce only in deep mode

Read [reproduction.md](references/reproduction.md). First perform the read-only audit: locate authoritative artifacts, pin the repository and revision, choose the smallest representative central claim, and estimate dependencies, downloads, and compute.

Then present one execution confirmation containing the exact repository, revision, target claim, command/entry point, environment, downloads, expected compute, and any compatibility risk. Wait for approval unless the user has already authorized that exact bounded run. Reconfirm any expansion.

Preserve pristine upstream code. Apply compatibility changes only in a separate copy and record the diff. Never label a patched or independent implementation as an unmodified official reproduction.

**Gate:** produce an executed, evidence-bearing minimal reproduction or a concrete blocker audit. Never convert “code was found” or “the demo launched” into a reproduced paper claim.

## 8. Write and validate the deliverable

Use the user's language; retain technical terms, equations, commands, and identifiers where translation would reduce precision.

- Markdown: write `summary.md` plus local `assets/` when needed.
- HTML: scaffold, replace every placeholder, then validate:

```bash
PYTHON_EXE <skill-dir>/scripts/scaffold_report.py REPORT_DIR \
  --title "..." --title-focus "..." --authors "..." \
  --paper-type empirical --level compact --thesis "..."
PYTHON_EXE <skill-dir>/scripts/validate_report.py REPORT_DIR/summary.html
```

Deep HTML also includes `reproduction/manifest.json` and its local logs/artifacts. Keep HTML CSS and JavaScript inline; keep high-resolution paper/run assets in `assets/` with relative paths.

Before delivery:

1. Remove scaffold markers and any sentence that adds no mechanism, evidence, comparison, limitation, or implication.
2. Check all local links, evidence coordinates, captions, equations, and asset paths.
3. For HTML, render at desktop and narrow-mobile widths; verify the single reader navigation, title hierarchy, MathML, every visual, wheel/pinch zoom, keyboard close, lenses, print, and reduced-motion behavior.
4. Run the validator until it passes.
5. State the selected level, source boundaries, and reproduction status without overstating certainty.

**Done:** the requested scope is complete, evidence is traceable, the output works offline from its directory, and limitations are as easy to inspect as headline claims.
