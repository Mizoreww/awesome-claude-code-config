# Empirical paper modules

Use the shared backbone and insert these modules after Key Insight.

## Report order

1. Basic Information
2. Research Problem
3. Key Insight
4. Technical Method (`data-section="technical-method"`)
5. Experimental Results (`data-section="experimental-results"`)
6. Critical Analysis
7. Summary and Evaluation

## Technical Method

### Overall framework

- Define the end-to-end inputs, outputs, module boundaries, and data/signal flow before describing local details.
- Write the essential equations and define symbols immediately.
- Explain why the proposed organization addresses the stated bottleneck.
- Distinguish the core idea from scale, representation, data, or engineering recipe.

### Module anatomy — required

Create one module card for every load-bearing component. Preserve the original technical template by filling every field:

1. **Purpose:** the module's responsibility and why it exists.
2. **Exact inputs:** assign every paper/code symbol explicitly; render symbols, shapes, dimensions, and ranges with LaTeX-derived inline MathML; use an unordered list when there is more than one input.
3. **Exact outputs:** assign every paper/code symbol explicitly; render symbols, shapes, dimensions, and ranges with LaTeX-derived inline MathML; use an unordered list when there is more than one output and name each downstream consumer.
4. **Architecture and parameters:** layers, dimensions, parameterization, routing, frozen/trainable state, and key defaults.
5. **Training data and supervision:** dataset, split, scale, sampling, augmentation, labels/targets, and supervision source.
6. **Training method:** objectives and loss weights, optimizer, schedule, batch size, steps/epochs, stopping rule, and joint/frozen training relationship.
7. **Inference-time role:** what runs, what remains frozen, and how behavior differs from training.
8. **Interfaces:** assumptions/contracts between this module and adjacent modules.
9. **Code evidence:** pinned repository revision plus paths/symbols; state `public code not found`, `not reported`, or `not applicable` when necessary.

Label each material detail as paper-stated, code-confirmed, paper/code discrepancy, or report inference. Do not omit a field merely because the module is pretrained or frozen; explain its provenance and role.

Place one full-width SVG directly below every module title and above its fields. Its overall flow is horizontal—named inputs → core transformation → named outputs—and every distinct input/output gets its own node. Do not merge inputs or squeeze the SVG into a side column. Use the same symbols as the input/output lists, keep connectors and labels non-overlapping, and make the SVG a lightbox visual.

### Algorithm and complexity

- Describe the actual training/inference loop and stopping condition.
- State network evaluations, asymptotic or practical cost, memory, and important implementation tricks.
- Identify what changes between training and evaluation.

## Experimental Results

### Setup and facts

- Dataset/split, sample count, hardware where reported, hyperparameters, metric implementation, and uncertainty.
- Baselines with comparable data, compute, tuning, and evaluation protocol; flag mismatches.
- Main result values and margins with directionality.
- Ablations, negative results, qualitative examples, and failure regimes.
- Place the paper's original load-bearing result plots or qualitative panels next to the claims they support. Mark at least one central original result figure `data-original-result` in HTML; a recreated table or metric card is only a supplement.
- Preserve axes, legends, compared methods, uncertainty, and failure panels required to interpret the figure. If the paper has no result figure, mark the section `data-original-result-unavailable="paper-has-no-result-figure"` and retain the original result table.

### Interpretation

- Separate authors' explanation from what the experiments isolate.
- Identify where the method is strongest and weakest.
- Ask whether improvements come from the proposed mechanism or confounded recipe changes.
- State which central claim each table/figure actually supports.
