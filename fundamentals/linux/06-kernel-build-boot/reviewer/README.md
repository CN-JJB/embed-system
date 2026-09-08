# P3-M02 Reviewer Guide & Assessment Anchors

> **Reviewer Only** — Keep isolated from learner-facing directories.

## Assessment Matrix

| Area | Passing Criteria | Scoring Anchors |
|---|---|---|
| **Effective Kernel Config** | `CONFIG_ARCH_VIRT=y`, `CONFIG_ARM_LPAE=n`, `CONFIG_VMSPLIT_3G=y`, `PAGE_OFFSET=0xC0000000` | 30 pts. Deduct full points if learner only inspects fragment instead of effective config. |
| **Artifact Inspection** | `vmlinux` Machine is `ARM`, Entry is `0xC0008024` (or `0xC0008000`), `System.map` matches `vmlinux` | 35 pts. Deduct full points if learner fails to prove symbol synchronization. |
| **Canonical QEMU Contract** | Exact command line with `virt`, `highmem=off`, `gic-version=2`, `cortex-a7`, `512M`, `1`, `nographic` | 35 pts. Deduct 15 pts if `highmem=off` explanation misses LPAE constraint. |

## Negative Control Mutations
The reviewer maintains five adversarial mutations in `mutations/` to test validator integrity:
1. `mut1_vexpress_decoy`: Config using `CONFIG_ARCH_VEXPRESS=y` instead of `CONFIG_ARCH_VIRT=y`.
2. `mut2_lpae_enabled`: Config with `CONFIG_ARM_LPAE=y` active.
3. `mut3_vmsplit_wrong`: Config with `CONFIG_VMSPLIT_2G=y` (PAGE_OFFSET = 0x80000000) instead of 3G.
4. `mut4_stale_map_unmatched`: System.map with shifted symbol addresses tested against semantic validator.
5. `mut5_qemu_missing_virt_args`: QEMU launch command omitting `highmem=off` or `-cpu cortex-a7`.
