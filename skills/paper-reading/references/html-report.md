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
└── assets/             # high-resolution paper visuals
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
  --thesis "ONE EVIDENCE-BOUND THESIS" \
  --language "zh-CN" \
  --source "CANONICAL URL"
```

The scaffold deliberately fails final validation until its visible replacement markers are replaced. It localizes section names, controls, and accessible names for Chinese (`zh*`) or English (`en*`) and rejects unsupported language tags rather than declaring a mismatched document language. For another language, translate the shell and report prose explicitly before changing the document `lang`. Edit the generated `summary.html`; keep its semantic attributes and inline design/interaction layer.

Use the **Proof Spine** shell:

- compact hero with one emphasized title phrase, authors, and thesis;
- exactly one reader navigation on the left, containing only the section outline and source link;
- linear, recognizable report sections in the center;
- optional local visual comparison inside a method/evidence section.

On narrow screens, collapse that same navigation above the article; keep one navigation instance rather than duplicating links. Use the bundled type tokens: title no larger than 2.6× body text, hero supporting text at least 0.82× body text, and section headings close enough to body size for sustained reading.

## Semantic components

### Basic information

Use the original vertical list, not a table or definition-list grid. Keep technical extraction provenance outside the visible report. Link principal authors and the explicitly identified corresponding author (or a clearly labelled verified paper contact when none is identified) to their homepages. For affiliations, link the lab or research group that actually hosts the named authors—not the university root:

```html
<ul class="paper-facts" data-paper-facts>
  <li data-paper-field="title"><strong>Title:</strong> Paper title</li>
  <li data-paper-field="authors"><strong>Authors:</strong>
    <a data-author-homepage href="https://author.example/">Principal Author</a>
  </li>
  <li data-paper-field="contact"><strong>Corresponding author / paper contact:</strong>
    <a data-contact-homepage href="https://contact.example/">Verified contact</a>
  </li>
  <li data-paper-field="affiliation"><strong>Affiliation / lab:</strong>
    <a data-lab-homepage href="https://lab.example/">Research Lab (Institution)</a>
  </li>
  <li data-paper-field="published"><strong>Published:</strong> Venue, version, date</li>
  <li data-paper-field="link"><strong>Link:</strong> <a href="https://paper.example/">Paper</a></li>
  <li data-paper-field="paper-type"><strong>Paper Type:</strong> Empirical</li>
  <li data-paper-field="one-line-summary"><strong>One-line summary:</strong> Problem, mechanism, result.</li>
</ul>
```

Use `data-corresponding-homepage` instead of `data-contact-homepage` when the paper explicitly names a corresponding author. Never infer that role from author order, seniority, or reputation.

Verify lab/group ownership through an authoritative author, lab, department, or paper page. If no authoritative lab or research-group homepage exists, use the narrowest verified department/institution page and mark that exceptional link with both `data-institution-homepage` and `data-affiliation-fallback="no-authoritative-lab-homepage"`. Do not use a university root merely because it is easy to find.

### Argument block

Use one coordinate and one kind per material block. Link claims and limitations to evidence:

```html
<section id="C2" class="argument-block"
         data-section="key-insight" data-kind="claim"
         data-coordinate="C2" data-supports="E1 E2">
  <div class="section-mark"><span>C2</span><small>Key insight</small></div>
  <h2>Specific insight</h2>
  <p>Dense explanation with inline evidence references.</p>
</section>
```

Use only `C`, `E`, and `L` prefixes in the unified reading workflow. Keep IDs unique and make every local link resolve.

### Module anatomy

Empirical and systems reports require one card for every load-bearing module. Keep the overview flow in prose or a useful visual, then put a full-width horizontal local-interface SVG directly below each card title and above its fields. Give every distinct input/output a separate node. Use unordered lists for parallel items. Inputs and outputs must carry the paper/code symbols as LaTeX-derived inline MathML, including shapes or ranges when known:

```html
<div class="module-anatomy" data-module-anatomy>
  <article class="module-card" data-module="visual-encoder">
    <h3>Visual encoder</h3>
    <figure class="module-visual" data-module-visual data-lightbox
            tabindex="0" role="button" aria-label="Visual encoder flow, click to enlarge">
      <svg class="module-diagram" viewBox="0 0 960 240" role="img"
           aria-label="Image tensor passes through the visual encoder to form features">
        <!-- separate verified input nodes → core transform → separate output nodes -->
      </svg>
      <figcaption>Local interface simplified from §3.1 and the pinned implementation.</figcaption>
    </figure>
    <div data-module-field="purpose"><h4>Purpose</h4><p>...</p></div>
    <div data-module-field="inputs"><h4>Exact inputs</h4>
      <ul class="module-io-list"><li>
        <span class="math-inline"><math display="inline"><semantics>
          <mi>x</mi><annotation encoding="application/x-tex">x</annotation>
        </semantics></math></span> normalized image tensor with its verified shape.
      </li></ul>
    </div>
    <div data-module-field="outputs"><h4>Exact outputs</h4>
      <ul class="module-io-list"><li>
        <span class="math-inline"><math display="inline"><semantics>
          <mi>h</mi><annotation encoding="application/x-tex">h</annotation>
        </semantics></math></span> feature tensor consumed by the prediction head.
      </li></ul>
    </div>
    <div data-module-field="architecture"><h4>Architecture</h4><p>...</p></div>
    <div data-module-field="training-data"><h4>Training data</h4><p>...</p></div>
    <div data-module-field="training-method"><h4>Training method</h4><p>...</p></div>
    <div data-module-field="inference-role"><h4>Inference role</h4><p>...</p></div>
    <div data-module-field="interfaces"><h4>Interfaces</h4><p>...</p></div>
    <div data-module-field="code-evidence"><h4>Code evidence</h4><p>...</p></div>
  </article>
</div>
```

Use compact cards or aligned rows rather than one enormous table. On both desktop and mobile the SVG remains above the fields; never use a left-diagram/right-fields split. The SVG and the input/output lists must reuse the same symbols, and every distinct list-level interface value needs its own node. Every field must contain a concrete answer, `not applicable`, `not reported`, or a documented no-code result. Cite the pinned file/symbol inside `code-evidence`; a repository homepage alone is insufficient.

### Original image

Every visual is a keyboard-operable lightbox trigger in the static markup:

```html
<figure data-original-result data-lightbox tabindex="0" role="button"
        aria-label="Figure 2, click to enlarge">
  <img src="assets/figure-2.png" alt="Faithful description of Figure 2">
  <figcaption><strong>E3 · Figure 2</strong> What it demonstrates and under which setup.</figcaption>
</figure>
```

Use a high-resolution local asset. A caption must explain evidentiary relevance, not repeat the title.

Use `data-original-result` only for a result visual copied faithfully from the paper. Every empirical report needs at least one such figure inside an `experimental-results` section unless the paper genuinely has no result figure; in that case add `data-original-result-unavailable="paper-has-no-result-figure"` to the section and preserve the paper's original result table. Recreated HTML tables and metric summaries never satisfy this requirement.

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
  --display block \
  --explanation "What this equation says and why it matters here." \
  --output equation.html
```

Use `--display inline` for notation inside prose; inline mode does not accept `--explanation`. In an already-compatible isolated environment, invoke the same script with `PYTHON_EXE`. Block mode emits one `.equation-block` containing one `.math-display` and one immediately following `.equation-explanation`. Write that explanation as ordinary prose with no label or badge: define every letter, operator, index, superscript/subscript role, and non-obvious symbol present in that equation, then give the intuitive action of the full relation and its relevance here. Do not use one generic note for a stack. Inline mode emits an atomic `.math-inline`, which must remain ordinary inline content without internal line breaks, scrollbars, or native overflow controls. If several relations form a causal chain or an expression is too long to sit comfortably in a sentence, use one or more display blocks instead of allowing the surrounding prose to collapse into one-token lines. Both modes contain rendered MathML plus an `application/x-tex` annotation preserving the source. The renderer and validator share an inert presentation-MathML allowlist: active/embedded elements and attributes such as `style`, event handlers, or `href` are rejected. Reserve `<pre>` and `<code>` for executable code, paths, hashes, and identifiers; do not fall back to HTML `<sub>/<sup>` for mathematical notation. HTML `<sub>/<sup>` is allowed only for narrow non-mathematical semantics such as an ordinal or chemical formula. Mark any other intentional semantic use on the script element with `data-semantic-script`; unmarked ambiguous scripts are rejected so approximated mathematics cannot slip through.

At narrow-mobile width, do not solve an overlong equation by shrinking it into illegibility. Introduce and explain paper-faithful intermediate notation, then render the equivalent relation as two or three shorter display equations. Keep horizontal scrolling only as a fallback for an irreducible expression.

### Native disclosure

Put secondary derivations, hyperparameter detail, or long logs in `<details>`. Keep the claim, evidence outcome, and limitation visible without opening it.

## Interaction and offline behavior

The bundled script progressively enhances:

- active outline position;
- click/Enter/Space lightbox opening at a restrained fit-to-view scale with the caption kept inside its own readable row;
- pointer-centered wheel zoom on desktop, bounded pinch zoom on touch screens, and panning only after zooming; wheel input over the viewer changes scale and must not scroll the page or viewer;
- zoom controls plus Escape/close-button dismissal and focus return.

The article remains complete and readable with JavaScript disabled. Keep evidence coordinates in the article where useful, but do not add a second evidence-index or reading-lens control surface. Do not make hover the only way to reveal evidence.

The title focus is the page signature. Emphasize one phrase already present in the title with color and a restrained trail treatment; keep the remaining hero quiet.

## Render verification

Run the structural validator:

```bash
PYTHON_EXE <skill-dir>/scripts/validate_report.py REPORT_DIR/summary.html
```

The validator treats every static `img` and inline `svg` as a report visual: it must be wrapped by the accessible lightbox figure contract. It also checks title-focus ancestry/text, safe MathML, legacy math markup, local hyperlinks, ordinary asset URLs, `srcset`, SVG `<image>` references, evidence relationships, and required module anatomy. A pass is necessary but not sufficient.

Then inspect a real browser render at desktop and about 390 px width:

1. The title has one visible focus phrase, stays within the type-ratio bound, and bilingual author lines do not overflow.
2. Exactly one reader navigation is present; it remains left-aligned on desktop and becomes the same collapsible navigation on mobile.
3. Display and inline equations render as MathML; every display equation has its own immediately following natural explanation that defines all symbols before interpreting the relation, inline math stays atomic with no scroll controls or one-token line fragmentation, and mathematical notation is absent from code-styled blocks.
4. Every image and SVG opens below 86% viewport width and 78% viewport height, then returns focus when closed.
5. Desktop wheel input changes image scale without scrolling the page or viewer; mobile pinch changes scale; panning activates only above 100%.
6. The outline, in-article evidence links, details, zoom controls, and keyboard focus are usable; no reading-lens or evidence-index controls are present.
7. SVG labels/arrows remain legible at both widths.
8. Basic information uses the vertical list, contains verified author/contact/lab-or-group homepage links, and exposes no extraction bookkeeping; any institution-level affiliation fallback is explicitly marked.
9. Every load-bearing empirical/systems module exposes exact inputs, outputs, architecture, training data/method, inference role, interfaces, and pinned code evidence; one full-width horizontal local-interface SVG sits above the fields with separate non-overlapping input/output nodes; parallel items use unordered lists; input/output symbols and shapes are static inline MathML.
10. Print preview keeps the article and removes navigation/interaction chrome.
11. Reduced-motion preference does not trigger movement.

Fix the page and rerun both structural and visual checks. A validator pass cannot substitute for looking at the render.
