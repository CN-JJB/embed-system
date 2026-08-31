# P1-M06 Gate Hint Ladder

Open only after writing your own symptom and 3–5 hypotheses.

## Hint 1 — EOF

Count **references to the write endpoint**, not “processes that intend to write”. Which processes still have a descriptor that can refer to the write side?

## Hint 2 — `dup2`

A successful `dup2(oldfd, STDOUT_FILENO)` changes the binding of descriptor 1. It does not automatically remove `oldfd`.

## Hint 3 — `/proc`

Compare `/proc/<supervisor>/fd` with `/proc/<consumer>/fd`. A write endpoint in either place can explain why a reader still has a possible writer.

## Hint 4 — partial failure

After the first `fork()` succeeds, a second `fork()` failure is not “nothing happened”: one child and both parent-side pipe descriptors already exist.

## Hint 5 — signals

Treat the handler as a tiny intent recorder. Move allocation/stdio/process cleanup back to normal control flow.
