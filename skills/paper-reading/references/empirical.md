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

- Define inputs, outputs, modules, and data/signal flow.
- Write the essential equations and define symbols immediately.
- Explain why the proposed organization addresses the stated bottleneck.
- Distinguish the core idea from scale, representation, data, or engineering recipe.

### Components and objective

- Give architecture details only when they affect the claim: dimensions, layers, parameterization, schedules, or interfaces.
- State each loss/objective and its operational effect.
- Record training data, preprocessing, sampling, and supervision source.
- For each key choice, label the motivation as author-stated, experimentally supported, or report inference.

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

### Interpretation

- Separate authors' explanation from what the experiments isolate.
- Identify where the method is strongest and weakest.
- Ask whether improvements come from the proposed mechanism or confounded recipe changes.
- State which central claim each table/figure actually supports.

In brief mode, collapse these modules into mechanism plus `headline-evidence`; do not imply full experimental coverage.
