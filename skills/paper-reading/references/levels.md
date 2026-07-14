# Reading levels

Choose one work scope before reading. A higher level means more source coverage and verification, not padded prose.

| Dimension | Brief | Compact close-reading | Deep reproduction |
|---|---|---|---|
| Reader intent | Fast, defensible orientation | Understand and evaluate the whole paper | Verify the method and one central claim |
| Paper coverage | Decisive sections | Full paper and relevant appendices | Full paper, appendices, code, artifacts, and run evidence |
| External scope | Paper and supplied source only | Official project/code availability and paper-cited primary sources as needed | Official repo, data, checkpoints, issues, upstream docs, and run dependencies |
| Code | Do not inspect beyond availability | Read-only availability/structure check; do not execute | Audit, pin, then execute after the reproduction gate |
| Evidence ledger | Decisive C/E/L coordinates | Every material result and critique | Every material result and critique plus R coordinates |
| Visual work | Only the visual needed to unlock the thesis | Cover every major comprehension bottleneck | Add visuals needed to explain or audit reproduction |

## Brief

Read at least the abstract, introduction/contribution statement, the method overview needed to explain the mechanism, the headline result, conclusion, and decisive limitation/failure evidence. Read another section only when one of those cannot be judged without it.

Deliver:

1. Basic information and one-sentence thesis.
2. The specific research problem.
3. The mechanism or insight that changes the problem.
4. One or two headline evidence items with conditions, not naked metrics.
5. The decisive limitation and a calibrated reading verdict.

Do not perform an open-ended literature search, broad code audit, or execution. Say “brief reading” rather than implying full-paper coverage.

**Complete when:** a reader can explain the problem, mechanism, best evidence, and strongest caveat, and every decisive statement has an anchor.

## Compact close-reading

Read the paper in full, including appendices that materially qualify the method or results. Cover the shared sections and the primary paper-type modules.

In addition to brief coverage, resolve:

- notation, key equations, assumptions, and what each design choice buys;
- experimental conditions, baselines, main tables, ablations, negative results, and failure cases;
- related-work positioning as argued by the paper, checking cited primary sources only when necessary to avoid a misleading comparison;
- code/data/checkpoint availability and whether the described recipe appears implementable.

Inspect official project and repository surfaces read-only. A shallow clone into a temporary directory is allowed when web inspection is insufficient; record its revision, leave the upstream checkout unchanged, and do not install, import, or run its code.

**Complete when:** all material claims and criticisms are anchored, the paper's full argument is represented, and omissions from appendices/failure evidence are explicitly justified.

## Deep reproduction

Complete the compact close-reading first. Then follow `reproduction.md` to locate authoritative artifacts and test the smallest representative result that bears on at least one central claim.

Prefer, in order:

1. an official minimal example that exercises the proposed mechanism;
2. official checkpoint inference/evaluation on a bounded sample;
3. a minimal training or theorem/numerical check;
4. full training/evaluation only after separate cost confirmation.

The minimal result must test a claim, not merely import a package or render a sample. Keep full-paper metrics and the smaller reproduced claim visibly separate.

**Complete when:** the report identifies exact provenance and either records a bounded executed result with logs/artifacts or explains a specific blocker after an evidence-bearing audit.

## Scope control

- Treat “default” as compact only after the user has been offered the choice or explicitly delegates the default.
- Do not silently turn compact into brief because the paper is long.
- Do not silently turn deep into compact because compute is expensive. Finish the audit, propose the smallest viable run, and report the blocker if no representative run is feasible.
- Broader novelty or prior-art search is a separate task unless explicitly requested.
