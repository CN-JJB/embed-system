# Review Policy

Root `AGENTS.md` defines the current resource-first operating model.

## Review priority

```text
Technical Correctness
> Source Authority
> Mental Model / Learning Dependency
> Evidence Honesty
> Practical Transfer Value
> Scope Efficiency
> Prose Polish
```

## Review axes

### 1. Technical correctness
Are mechanisms, APIs, registers, source interpretations and learning claims correct?

### 2. Source quality
Does the contribution prefer official specifications/vendor manuals/upstream documentation and exact source code for version-sensitive details?

### 3. Learning dependency
Does the learner encounter prerequisites before advanced topics? Are optional specializations kept out of the critical path?

### 4. Mental model quality
Does the roadmap teach a transferable mechanism rather than one accidental implementation detail?

### 5. Evidence honesty
When runtime/hardware/source evidence is claimed, is the evidence class explicit and truthful?

### 6. Resource efficiency
Is each recommended resource doing a clear job? Could five links be replaced by two better links?

### 7. Practical transfer
Does the roadmap suggest a realistic experiment/project/source-reading target that forces the learner to use the concept?

### 8. Version integrity
For version-sensitive topics, are the relevant release/source assumptions clear? Is a stale tutorial being used as authority over current upstream material?

### 9. Licensing/originality
Are links, quotations, code excerpts and diagrams handled appropriately?

### 10. Scope discipline
Is the contribution solving the roadmap/resource problem rather than generating a large unnecessary framework?

## Assessment/lab review

Custom labs, Gates, hidden seeds and mutation oracles are **optional**, not default curriculum requirements.

When such material already exists or is explicitly requested, still review it for:

- answer leakage;
- false-pass behavior;
- evidence fabrication;
- learner/reviewer separation;
- reproducibility.

But lack of a custom Gate is not itself a defect in resource-first phases.

## Severity

### S0 — Cosmetic
Typo, formatting, minor broken link.

### S1 — Minor
Small source metadata issue, local ambiguity, minor stale wording.

### S2 — Major
Wrong mechanism, weak/stale primary source, wrong learning order, misleading evidence, important resource gap, or unnecessary scope explosion.

### S3 — Critical
Fabricated evidence, fake citation/source, unsafe instruction, plagiarism, fundamentally false mechanism, or assessment answer leakage presented as valid.

## Research/resource PR handoff

A research/resource contribution does not need the historical long-form implementation handoff.

It should make clear:

- scope;
- sources consulted;
- important conclusions;
- files changed;
- known uncertainty;
- remote revision / merge status when relevant.

Implementation-heavy work should additionally state what was actually built/run and what remains unverified.

## Existing historical assessments

Earlier Phase 1–3 assessment infrastructure can remain as optional reference material. Review future fixes proportionally; do not spend large amounts of time perfecting obsolete scaffolding unless it contains a material technical or safety error.
