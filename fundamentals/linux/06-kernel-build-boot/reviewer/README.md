# P3-M02 Reviewer Guide & Assessment Anchors

> **Reviewer Only** — Keep isolated from learner-facing directories.

## Assessment Matrix (fresh variant)

| Area | Passing Criteria | Scoring Anchors |
|---|---|---|
| **Effective Kernel Config** | Full audit against the canonical Phase 3 delta; every seeded deviation detected with exact config-line evidence | 30 pts. Deduct full points if learner only inspects the fragment instead of the effective config. |
| **Artifact Inspection** | `vmlinux` Machine is `ARM`, entry consistent with the configured `PAGE_OFFSET`, `System.map` synchronization verdict correct | 35 pts. Deduct full points if learner fails to prove symbol synchronization or drift with evidence. |
| **Canonical QEMU Contract** | Exact command line with `virt`, `highmem=off`, `gic-version=2`, `cortex-a7`, `512M`, `1`, `nographic` | 35 pts. Deduct 15 pts if `highmem=off` explanation misses LPAE constraint. |

## Assessment Oracle & Regression
- Grading oracle: `reviewer/oracle_m02.sh` (single source of truth for the seeded assessment design).
  Config grading uses exact Kconfig effective states: exactly one full-line state
  per constrained symbol (`CONFIG_X=<value>` or `# CONFIG_X is not set`);
  contradictory duplicates and decoy/comment text are rejected. Drift grading
  first proves each audited symbol exists exactly once in `vmlinux` and in
  `System.map`; missing symbols are rejected, never accepted as drift.
- Oracle reference + mutation regression: `reviewer/test_m02_oracle_mutations.sh`
  (reference PASS; decoy-comment REJECT; contradictory-duplicate REJECT;
  missing-drift-symbol REJECT; missing-non-drift-symbol REJECT;
  duplicate-non-drift-symbol REJECT; profile/zImage mutations REJECT;
  unrelated-failure guard). Existence failures are recorded in the parent
  shell so a missing/duplicate MATCH symbol cannot false-pass when the
  remaining drift set still matches.
- Fixture generators: `reviewer/scripts/generate_m02_challenge_fixtures.sh`, `reviewer/scripts/generate_m02_gate_fixtures.sh`.
  Materialized opaque fixtures are committed under `challenge/fixtures/` and `gate/fixtures/` for learner consumption.

## Component Negative Control Mutations
`test_m02_mutations.sh` maintains production-validator negative controls (platform decoy, LPAE enabled, wrong memory split, console disabled, stale System.map drift, wrong/truncated/offset zImage magic).
