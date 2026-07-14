# Portable HTML report

## Contents

1. Output contract
2. Scaffold workflow
3. Semantic components
4. Interaction and offline behavior
5. Render verification

## Output contract

Write one movable directory:

```text
report/
├── summary.html        # inline CSS and JavaScript
├── assets/             # high-resolution paper and run visuals
└── reproduction/       # deep mode only: manifest, logs, small artifacts
```

Use relative paths and an offline shell: inline the report CSS/JavaScript and keep visual assets local. Render mathematics to static MathML before delivery so equations need no network runtime.

HTML and Markdown use the same report model. HTML changes presentation and inspection speed, not the analytical claims.

## Scaffold workflow

After verifying the thesis, choose one consequential phrase that occurs exactly once in the paper title. This phrase becomes the restrained title focus. Replace `PYTHON_EXE` with the actual interpreter in the compatible active or isolated environment (`python3`, `python`, `py -3`, or an absolute venv executable); it is a prose placeholder, not a literal executable.

```bash
PYTHON_EXE <skill-dir>/scripts/scaffold_report.py REPORT_DIR \
  --title "PAPER TITLE" \
  --title-focus "CONSEQUENTIAL TITLE PHRASE" \
  --authors "AUTHORS" \
  --paper-type empirical \
  --level compact \
  --thesis "ONE EVIDENCE-BOUND THESIS" \
  --language "zh-CN" \
  --source "CANONICAL URL"
```

The scaffold deliberately fails final validation until its visible replacement markers are replaced. It localizes section names, controls, and accessible names for Chinese (`zh*`) or English (`en*`) and rejects unsupported language tags rather than declaring a mismatched document language. For another language, translate the shell and report prose explicitly before changing the document `lang`. Edit the generated `summary.html`; keep its semantic attributes and inline design/interaction layer.

Use the **Proof Spine** shell:

- compact hero with one emphasized title phrase, authors, and thesis;
- exactly one reader navigation on the left, containing lenses, outline, evidence coordinates, and source link;
- linear, recognizable report sections in the center;
- optional local visual comparison inside a method/evidence section;
- reading lenses that dim unrelated material but never hide or reorder it.

On narrow screens, collapse that same navigation above the article; keep one navigation instance rather than duplicating links. Use the bundled type tokens: title no larger than 2.6× body text, hero supporting text at least 0.82× body text, and section headings close enough to body size for sustained reading.

## Semantic components

### Argument block

Use one coordinate and one kind per material block. Link claims and limitations to evidence:

```html
<section id="C2" class="argument-block"
         data-section="key-insight" data-kind="claim"
         data-coordinate="C2" data-supports="E1 E2"
         data-lenses="method critique">
  <div class="section-mark"><span>C2</span><small>Key insight</small></div>
  <h2>Specific insight</h2>
  <p>Dense explanation with inline evidence references.</p>
</section>
```

Use `C`, `E`, `L`, and `R` prefixes only for their defined meanings. Keep IDs unique and make every local link resolve.

### Original image

Every visual is a keyboard-operable lightbox trigger in the static markup:

```html
<figure data-lightbox tabindex="0" role="button"
        aria-label="Figure 2, click to enlarge">
  <img src="assets/figure-2.png" alt="Faithful description of Figure 2">
  <figcaption><strong>E3 · Figure 2</strong> What it demonstrates and under which setup.</figcaption>
</figure>
```

Use a high-resolution local asset. A caption must explain evidentiary relevance, not repeat the title.

### Explanatory SVG

Wrap inline SVG in the same lightbox contract. Include an accessible SVG role/label and a responsive `viewBox`:

```html
<figure data-lightbox tabindex="0" role="button"
        aria-label="Training flow, click to enlarge">
  <svg viewBox="0 0 720 260" role="img" aria-label="Verified training flow">
    <!-- paper-grounded shapes, labels, and arrows -->
  </svg>
  <figcaption>Simplified mechanism; source: §3 and Algorithm 1.</figcaption>
</figure>
```

### Mathematics

Keep each important equation in a UTF-8 `.tex` source file and render it before inserting the fragment:

```bash
uv run --isolated --no-project \
  --with latex2mathml==3.78.1 --with defusedxml==0.7.1 \
  python <skill-dir>/scripts/render_math.py equation.tex \
  --display block --output equation.html
```

Use `--display inline` for notation inside prose. In an already-compatible isolated environment, invoke the same script with `PYTHON_EXE`. Insert the emitted `.math-display` or `.math-inline` fragment; it contains rendered MathML plus an `application/x-tex` annotation preserving the source. Reserve `<pre>` and `<code>` for executable code, paths, hashes, and identifiers.

At narrow-mobile width, do not solve an overlong equation by shrinking it into illegibility. Introduce and explain paper-faithful intermediate notation, then render the equivalent relation as two or three shorter display equations. Keep horizontal scrolling only as a fallback for an irreducible expression.

### Native disclosure

Put secondary derivations, hyperparameter detail, or long logs in `<details>`. Keep the claim, evidence outcome, and limitation visible without opening it.

## Interaction and offline behavior

The bundled script progressively enhances:

- active outline position;
- Method / Evidence / Critique / Reproduction lenses;
- bidirectional evidence-coordinate tracing: selecting a claim illuminates its evidence, and selecting evidence illuminates the claims/limitations that cite it;
- click/Enter/Space lightbox opening at a restrained fit-to-view scale with the caption kept inside its own readable row;
- pointer-centered wheel zoom on desktop, bounded pinch zoom on touch screens, and panning only after zooming; wheel input over the viewer changes scale and must not scroll the page or viewer;
- zoom controls plus Escape/close-button dismissal and focus return.

The article remains complete and readable with JavaScript disabled. Lenses may de-emphasize content, never remove it. Do not make hover the only way to reveal evidence.

The title focus is the page signature. Emphasize one phrase already present in the title with color and a restrained trail treatment; keep the remaining hero quiet.

## Render verification

Run the structural validator:

```bash
PYTHON_EXE <skill-dir>/scripts/validate_report.py REPORT_DIR/summary.html
```

The validator treats every static `img` and inline `svg` as a report visual: it must be wrapped by the accessible lightbox figure contract. It also checks local hyperlinks, ordinary asset URLs, `srcset`, SVG `<image>` references, evidence relationships, and deep manifests. A pass is necessary but not sufficient.

Then inspect a real browser render at desktop and about 390 px width:

1. The title has one visible focus phrase, stays within the type-ratio bound, and bilingual author lines do not overflow.
2. Exactly one reader navigation is present; it remains left-aligned on desktop and becomes the same collapsible navigation on mobile.
3. Display and inline equations render as MathML; mathematical notation is absent from code-styled blocks.
4. Every image and SVG opens below 86% viewport width and 78% viewport height, then returns focus when closed.
5. Desktop wheel input changes image scale without scrolling the page or viewer; mobile pinch changes scale; panning activates only above 100%.
6. Outline, lenses, evidence links, details, zoom controls, and keyboard focus are usable.
7. SVG labels/arrows remain legible at both widths.
8. Selecting a lens leaves every section reachable.
9. Print preview keeps the article and removes navigation/interaction chrome.
10. Reduced-motion preference does not trigger movement.

Fix the page and rerun both structural and visual checks. A validator pass cannot substitute for looking at the render.
