# Systems paper modules

Use the shared backbone and insert these modules after Key Insight.

## Report order

1. Basic Information
2. Research Problem and Design Goals
3. Key Insight
4. System Design (`data-section="system-design"`)
5. Performance Evaluation (`data-section="performance-evaluation"`)
6. Deployment Experience when available
7. Critical Analysis
8. Summary and Evaluation

## System Design

### Architecture and interfaces

- Define components, ownership, interfaces, and control/data paths.
- Connect each design goal to the component that satisfies it.
- State consistency, fault, security, or scheduling model where relevant.
- For every load-bearing component, fill the same nine module-anatomy fields required for empirical work: purpose, exact inputs, exact outputs, architecture/parameters, training or construction data when applicable, training/build/configuration method, runtime role, adjacent interfaces, and pinned code evidence. Use `not applicable` rather than omitting training fields for non-ML components.

### Design decisions

For each consequential decision, record the chosen alternative, rejected alternative, trade-off, and evidence. Separate a novel system insight from implementation craftsmanship and hardware-specific optimization.

### Implementation

- Key runtime, storage, network, hardware, and dependency assumptions.
- Optimizations that materially affect reported performance.
- Failure recovery, scalability boundaries, and operational complexity.

## Performance Evaluation

- Benchmark environment, hardware, workload, scale, warm-up, repetitions, and metric definition.
- Compared systems and whether configuration/tuning is fair.
- Throughput, latency distribution, resource use, scalability, and failure behavior as relevant.
- Conditions where performance reverses or degrades.
- Whether the benchmark isolates the claimed design decision and resembles deployment.

If deployment evidence exists, distinguish measured production behavior from anecdote. Do not extrapolate a paper microbenchmark to production behavior, and do not run a new benchmark as part of the reading workflow.
