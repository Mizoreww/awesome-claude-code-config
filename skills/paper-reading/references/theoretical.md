# Theoretical paper modules

Use the shared backbone and insert these modules after Key Insight.

## Report order

1. Basic Information
2. Research Problem and Formalization
3. Key Insight
4. Theoretical Framework (`data-section="theoretical-framework"`)
5. Theoretical Analysis (`data-section="theoretical-analysis"`)
6. Critical Analysis
7. Summary and Evaluation

## Theoretical Framework

- Define the objects, notation, assumptions, and quantifiers needed for the main result.
- State the main theorem precisely enough to distinguish existence, convergence, consistency, optimality, and bounds.
- Translate the theorem into plain language without dropping conditions.
- Identify the new proof device, decomposition, invariant, or reduction.

## Theoretical Analysis

For each central theorem:

1. State the result and exact assumptions.
2. Give the proof spine: key lemma, transformation, and final implication.
3. Explain why the non-obvious step works.
4. Compare the bound/assumption to the closest result named in the paper.
5. Discuss tightness, pathological cases, and what is not established.

When experiments exist, add a bounded validation subsection: do observations test the theorem's regime, or merely illustrate behavior? Keep empirical support distinct from proof.

Do not restate every algebraic step. Preserve steps that carry novelty or expose a limitation. Inspect official proof artifacts or symbolic-check code read-only when available; do not invent or run a software benchmark as part of the reading workflow.
