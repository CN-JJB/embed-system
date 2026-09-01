# M08 Challenge Solution Reasoning

`challenge_fixed.c` is a runnable repaired reference for all four learner-facing modes. It lets a reviewer check repair and regression behavior, but it does **not** replace the learner's evidence-selection report.

| Domain | Repaired reference | Regression / reviewer check |
|---|---|---|
| memory | retained pointer remains owned until its last use, then is freed and cleared | repaired `memory` mode exits cleanly; exercised ASan build must produce no memory-safety diagnostic |
| endian | `get_u32_le()` decodes the declared little-endian bytes explicitly | `78 56 34 12` deterministically decodes to `0x12345678` |
| state | initialization creates the valid sequence and later processing observes rather than overwrites it | `sequence` remains `0x90abcdef` after processing |
| file | `open` → read-until-exact with EINTR handling → EOF/error classification → `close` | full 12-byte input succeeds; missing path and short input fail coherently |

## Evidence-selection reasoning still required

- **memory:** ASan is a strong first source because the question is whether later access crosses the allocation lifetime. The root cause is the broken ownership/lifetime contract, not the words in an ASan report. Evidence that all accesses occur before `free()` would falsify the UAF hypothesis.
- **endian:** start from the declared bytes and LE contract. ASan-clean execution cannot prove byte order. A deterministic golden mismatch falsifies the current decoder semantics without requiring a memory-safety failure.
- **state:** the debugging question is “who wrote this memory location?” After the record is initialized, `record.sequence` is the specific watchpoint target. A reasonable GDB workflow is to stop after initialization and `watch record.sequence` (using the actual in-scope object name in the learner's code). If no unexpected write occurs, the overwrite hypothesis is falsified. GDB runtime execution remains **UNVERIFIED** when GDB is unavailable; no transcript should be invented.
- **file:** inspect the program's `open`/`read` return values and `errno` first. Missing-file and short-input behavior are program-level contracts. strace is supplementary OS-boundary evidence, not a replacement for checking those returns. strace runtime remains **UNVERIFIED** when unavailable.

A correct code fix without the learner's symptom → hypotheses → first evidence → observation → falsification → root contract → minimal fix → regression chain is incomplete for M08.
