# M08 Gate Solution / Reasoning

Reviewer should reject tool-shotgun workflows even if final code works.

Expected domain reasoning:

1. **memory:** ASan localizes invalid access plus allocation/free chain;
2. **bytes:** compare known bytes with declared LE decoder; no memory bug required;
3. **FD:** parent retains a writer while waiting; `/proc/<pid>/fd` proves current ownership snapshot, strace (when available) adds event ordering;
4. **file:** return/errno gives immediate API-boundary evidence; strace is supplementary.

Reference `gate_fixed.c` is only a minimal repaired byte regression. The Gate score is mostly the learner's evidence chain, falsification, cleanup, and root-cause wording.
