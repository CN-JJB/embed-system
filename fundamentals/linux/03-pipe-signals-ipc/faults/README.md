
# P1-M06 Fault Campaign — FD / Pipe / Signal Lifecycle

> First diagnosis **AI-Free**. Use the full Symptom → Hypotheses → Evidence → Root Cause → Fix → Regression chain.

## Build

```sh
make clean && make
```

## F1 — Parent forgets write-end close

```sh
./fd_faults extra-parent
```

Before pressing Enter, inspect parent/reader FDs through `/proc`. Root cause must identify the **extra write-end reference** that prevents EOF, not “read is slow”.

Authoring: strict build + `/proc` endpoint inspection + EOF after Enter **VERIFIED**.

## F2 — Child retains unrelated pipe end across exec

```sh
./fd_faults inherited-exec
```

A holder child execs `./holder` while inheriting a write-end descriptor it never intentionally uses. Inspect:

```sh
ls -l /proc/<holder>/fd
ls -l /proc/<reader>/fd
```

Reader gets EOF only after the inherited writer disappears. Do not freeze the descriptor number.

Authoring: inherited-across-exec delay and reader EOF after holder exit **VERIFIED**; manual `/proc` holder inspection **VERIFIED**.

## F3 — Wrong `dup2` endpoint / direction

```sh
./fd_faults wrong-dup2
```

Use the descriptor binding model: FD 1 is made to reference a **read endpoint**, then code attempts to write. Diagnose from data-flow direction, not from memorized error text.

Authoring: wrong-end write failure **VERIFIED**.

## F4 — Wait-before-drain

```sh
timeout 1 ./wait_before_drain
```

The fixture intentionally waits child completion before parent drains a large output pipe. On the authoring host this blocked until `timeout` terminated it, consistent with the finite-buffer progress cycle. **Do not convert that observation into a fixed numeric pipe-capacity claim.**

Root-cause graph:

```text
parent waits child
child writes until pipe cannot currently accept more
parent not reading
→ no progress
```

Authoring host blocking symptom under `timeout`: **VERIFIED**. Cross-host exact threshold/timing: **UNVERIFIED / non-golden**.

## F5 — Unsafe signal-handler design

```sh
./unsafe_signal
# another shell
kill -TERM <pid>
```

Review the handler against `signal-safety(7)` and course architecture. It performs stdio and application cleanup directly. Runtime crash is **not required** and runtime survival is **not validation**.

Authoring strict build + signal delivery: **VERIFIED**. Deterministic crash claim: **not made**.

## Required evidence

At least one F1/F2 diagnosis must include a saved process × FD matrix plus `/proc/<pid>/fd` evidence. `strace -f` may supplement when installed; authoring runtime has no strace, so trace paths remain **UNVERIFIED**.

## Cleanup

```sh
make clean
```

Sources: chapter `SOURCE_LEDGER.md`.
