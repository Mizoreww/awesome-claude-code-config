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

Use relative paths. Do not load fonts, scripts, styles, images, or equation renderers from the network. Prefer native MathML plus an adjacent readable source form for important equations; otherwise retain clear LaTeX source in a styled equation block.

HTML and Markdown use the same report model. HTML changes presentation and inspection speed, not the analytical claims.

## Scaffold workflow

After the thesis and at least two content-derived fingerprint concepts are verified, run the commands below. Replace `PYTHON_EXE` with the actual interpreter in the compatible active or isolated environment (`python3`, `python`, `py -3`, or an absolute venv executable); it is a prose placeholder, not a literal executable.

```bash
PYTHON_EXE <skill-dir>/scripts/scaffold_report.py REPORT_DIR \
  --title "PAPER TITLE" \
  --authors "AUTHORS" \
  --paper-type empirical \
  --level compact \
  --thesis "ONE EVIDENCE-BOUND THESIS" \
  --fingerprint "CONCEPT 1" \
  --fingerprint "CONCEPT 2" \
  --source "CANONICAL URL"
```

The scaffold deliberately fails final validation until its visible replacement markers are replaced. Edit the generated `summary.html`; keep its semantic attributes and inline design/interaction layer.

Use the **Proof Spine** shell:

- expressive large-title hero and verified paper fingerprint;
- linear, recognizable report sections in the center;
- compact outline and evidence coordinates at the margins;
- optional local visual comparison inside a method/evidence section;
- reading lenses that dim unrelated material but never hide or reorder it.

Do not turn the report into a dashboard of interchangeable cards.

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

### Native disclosure

Put secondary derivations, hyperparameter detail, or long logs in `<details>`. Keep the claim, evidence outcome, and limitation visible without opening it.

## Interaction and offline behavior

The bundled script progressively enhances:

- active outline position;
- Method / Evidence / Critique / Reproduction lenses;
- evidence-coordinate tracing;
- click/Enter/Space lightbox opening and Escape/close-button dismissal.

The article remains complete and readable with JavaScript disabled. Lenses may de-emphasize content, never remove it. Do not make hover the only way to reveal evidence.

The paper fingerprint is content, not stock decoration: derive its two to four labels from verified notation, entities, stages, or contrasts in this paper. Decorative geometry may connect them; it must not imply a relationship the source does not support.

## Render verification

Run the structural validator:

```bash
PYTHON_EXE <skill-dir>/scripts/validate_report.py REPORT_DIR/summary.html
```

Then inspect a real browser render at desktop and about 390 px width:

1. Long title and bilingual author lines do not overflow.
2. Outline, lenses, evidence links, details, and keyboard focus are usable.
3. Every image and SVG opens at a useful size and returns focus when closed.
4. SVG labels/arrows remain legible at both widths.
5. No section becomes inaccessible after selecting a lens.
6. Print preview keeps the article and removes interaction chrome.
7. Reduced-motion preference does not trigger movement.

Fix the page and rerun both structural and visual checks. A validator pass cannot substitute for looking at the render.
