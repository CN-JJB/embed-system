# P1-M06 Gate — Pipe Lifecycle & Shutdown Audit

> **AI-Free.** Official man-pages, `/proc`, `ps`, and tool documentation are allowed. Do not open `../reviewer/` before submitting your evidence chain.

## Objective

Audit an unfamiliar `producer → pipe → consumer` supervisor. The seeded program mixes descriptor-lifetime, process-reaping, `dup2` cleanup, and signal-handler faults. Passing means you can prove the lifecycle, not merely make the hang disappear.

## Prerequisites

M02 FD ownership, M04 fork/exec/waitpid, M06 Labs 01–06 and fault campaign.

## Environment

Linux/WSL; GCC; `ps`; `/proc/<pid>/fd`; `strace -f` when installed.

## Estimated Time

75–100 min.

## AI Mode

First attempt **AI-Free**. Documentation is allowed.

## Build

```sh
make clean && make
./pipe_gate
```

The fixture prints supervisor/producer/consumer PIDs, then reaches a state where the consumer does not receive EOF.

## Procedure

### Station A — draw the process × FD matrix first

Before editing code, record for parent, producer, consumer:

| Process | read endpoint | write endpoint | FD 0/1 binding after `dup2` | should survive exec? |
|---|---|---|---|---|
| supervisor | ? | ? | n/a | ? |
| producer | ? | ? | ? | ? |
| consumer | ? | ? | ? | ? |

Do not assume descriptor numbers other than standard 0/1/2.

### Station B — save the symptom

Record your own description of the hang: which process is waiting, which process has already exited, and which expected event has not happened.

### Station C — 3–5 hypotheses

Include at least one hypothesis from each family:

- extra writer / inherited endpoint;
- wrong or incomplete `dup2` cleanup;
- wait/reap lifecycle;
- signal shutdown design.

### Station D — collect evidence

Use the printed PIDs rather than guessing them:

```sh
ps -o pid,ppid,stat,cmd -p <supervisor>,<producer>,<consumer>
ls -l /proc/<supervisor>/fd
ls -l /proc/<consumer>/fd
```

If `strace` exists:

```sh
strace -f -o gate.trace ./pipe_gate
```

Trace evidence must be from your run. Exact syscall spellings are not golden literals.

### Station E — repair pipe / `dup2` lifecycle

Your fixed version must make every process close every unused endpoint and close the original descriptor after successful `dup2` when no longer needed. Explain why each close changes the descriptor graph.

### Station F — repair signal handling

Handler contract:

```text
SIGINT/SIGTERM
→ stop_requested = 1
→ return
→ normal context performs close/termination/reap/application cleanup
```

Do not keep stdio, allocator calls, callback dispatch, or application cleanup in the handler.

### Station G — reap every child

Normal path and partial-success path (for example consumer fork succeeds but producer fork fails) must not abandon a child. Decode child statuses with wait macros.

### Station H — regression

Pass requires:

- pipeline completes without hang;
- consumer observes EOF;
- no unintended pipe write endpoint remains in consumer after exec;
- original descriptors duplicated onto 0/1 are closed when no longer needed;
- both children are reaped;
- SIGTERM requests shutdown and normal context performs cleanup;
- repeated runs are stable.

## Expected Observation

Seeded program is expected to show a completed producer while the consumer remains blocked waiting for EOF. The exact PID/FD values are runtime-specific.

## Actual Verification Status

- Seeded strict build: **VERIFIED**.
- Seeded hang + `/proc` inspection: **VERIFIED**; authoring run showed supervisor and consumer both retaining a write-end reference to the same pipe while producer had exited. Exact FD/PID values are intentionally not frozen.
- Seeded SIGTERM delivery: **VERIFIED**; the unsafe handler ran, supervisor exited, and the consumer remained alive, reinforcing that handler-side ad-hoc cleanup is not a coherent shutdown lifecycle. No claim is made that the unsafe calls must crash.
- Reviewer fixed strict build + normal EOF/reap regression: **VERIFIED**.
- Reviewer fixed SIGTERM stop-request → normal-context child termination/reap: **VERIFIED** using the fixture-controlled `GATE_SLOW=1` path.
- `strace -f`: **UNVERIFIED** on the authoring host because the tool is not installed.

## Questions

1. Why is “producer exited” insufficient evidence that EOF should already have arrived?
2. Which process still refers to a write endpoint before the fix?
3. Why does successful `dup2` not close `oldfd` for you?
4. Why can runtime survival of the seeded signal handler not prove that its design is valid?
5. On a failed second `fork`, what resources/processes already exist and who must clean them up?

## Failure Modes

Adding sleeps/timeouts as the “fix”; killing the consumer instead of repairing EOF; hard-coding FD numbers; closing only the parent copy while consumer retains another; using `system()`/`popen()`; doing cleanup from the signal handler; waiting only one child.

## Debug Strategy

```text
Symptom → Own Description → 3–5 Hypotheses → FD matrix → /proc/strace evidence
→ Narrow Scope → Root Cause → minimal lifecycle fix → Regression
```

## Challenge

Write an 8–10 line postmortem separating **descriptor reference lifetime**, **descriptor binding (`dup2`)**, **process lifetime/reaping**, and **signal shutdown ownership**.

## Cleanup

```sh
make clean
```

## Sources

Chapter `SOURCE_LEDGER.md`.
