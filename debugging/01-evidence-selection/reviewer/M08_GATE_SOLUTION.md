# M08 Gate Solution / Reasoning

Reviewer should reject tool-shotgun workflows even if the final code works. `gate_fixed.c` is a runnable repaired reference for every seeded Gate domain; it exists so repair/regression claims can be checked, not so the learner can skip the evidence chain.

| Domain | Repaired reference | Regression / reviewer check |
|---|---|---|
| memory | owner keeps allocation alive through borrower access, then frees and clears it | repaired `memory` mode is clean on the exercised ASan path |
| bytes | explicit `get_u32_le()` implements the declared LE contract | `78 56 34 12` → `0x12345678` deterministically |
| FD | child closes unused writer; parent closes unused reader, writes intended payload, closes final writer, then reaps | child reads until EOF, exits successfully, and parent `waitpid()` reaps it without a hang |
| file | caller checks `open` and `close` results and reports OS errors coherently | valid path succeeds; missing path returns a clear expected program-level error |

## Domain reasoning

1. **memory:** ASan can localize an invalid heap access and the allocation/free chain, but the root cause is a lifetime contract violation. ASan silence only says the exercised repaired memory path produced no ASan diagnostic; it is not whole-program correctness proof.
2. **bytes:** compare known bytes with the declared LE decoder. **ASan clean ≠ byte order correct.** A semantic golden-vector regression is the relevant proof for this contract.
3. **FD:** the seeded hang is explained by the close graph: a reader cannot observe EOF while any writer for that pipe remains open. `/proc/<pid>/fd` can provide a current ownership snapshot; strace, when available, can add event ordering. The repaired reference instead demonstrates the contract directly by closing the final writer, observing child completion after EOF, and reaping the child. On `fork()` failure both pipe descriptors are closed and no child exists.
4. **file:** return value + `errno` are the first API-boundary evidence. A missing path is an expected OS error path, not internal corruption. strace is supplementary and remains **UNVERIFIED** if unavailable.

For each domain, the learner must still explain why the chosen evidence was highest-information, what it observed, which hypothesis it eliminated, what evidence would falsify the leading hypothesis, and which ownership/byte-order/FD-close/file-error contract was violated. Code repair alone is not an M08 pass.
