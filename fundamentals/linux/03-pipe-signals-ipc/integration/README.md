# M05 ↔ M06 Integration — Pipe Input → Synchronous Callback → Stats

## Objective

Connect the two contracts without introducing M07–M10 mechanisms:

```text
owned pipe/process resources
        ↓
input FD byte stream
        ↓
line buffer (normal control flow)
        ↓
local parsed record
        ↓ borrowed for this call only
record_sink_fn(record, ctx)
        ↓
caller-owned stats_ctx
```

On SIGINT/SIGTERM:

```text
handler: stop_requested = 1
        ↓
normal read loop exits
        ↓
close FD / stop child / waitpid / report stats
```

## Prerequisites

M05 callback/ctx lifetime contract; M06 pipe/FD/signal lifecycle.

## Environment

Linux/WSL; GCC.

## Estimated Time

25–35 min, included in the combined M05/M06 MUST budget.

## AI Mode

First reconstruction AI-Free; official docs allowed.

## Build

```sh
make clean && make
./m05_m06_integration
```

For a shutdown experiment:

```sh
./m05_m06_integration --slow
# another shell:
kill -TERM <pid>
```

## Procedure

1. Before running, mark owner/borrower/lifetime for pipe endpoints, producer PID, local `record`, and `stats_ctx`.
2. Explain why `emit_line()` may pass `&record` synchronously but the callback may not retain it.
3. Run normal mode and verify all records reach `stats_sink` before EOF.
4. Run `--slow`, send SIGTERM, and verify the handler only records intent while main control flow closes/reaps.
5. Draw the combined lifecycle: **resource lifetime + callback lifetime + process/FD lifetime + shutdown ownership**.

## Expected Observation

Normal mode emits four parsed records and final stats. Slow mode can be interrupted; the number of processed records depends on signal timing and is intentionally not a golden literal. Cleanup still occurs in normal context.

## Actual Verification Status

- Strict build + normal four-record EOF path: **VERIFIED**.
- `--slow` + external SIGTERM + normal-context close/kill/wait/report path: **VERIFIED**.
- Exact signal timing and processed-record count: deliberately **non-golden**; they depend on delivery timing.

## Questions

1. Who owns `stats_ctx` and how long must it remain alive?
2. Why is `record` borrowed even though the callback receives a pointer?
3. Which object/resource lifetime is ended by `close`, which by block return, and which by `waitpid`?
4. Why would retaining `record *` for later use violate this synchronous callback contract?
5. Why is a signal flag enough here but not a substitute for future pthread synchronization?

## Failure Modes

Global stats state; callback retaining `record *`; handler calling callback/stdio/free; parent leaving a pipe endpoint open; child not reaped; adding threads, ring buffers, framing, sockets, `select/poll`, or serialization.

## Debug Strategy

Use the same workflow: symptom → own description → hypotheses → ownership/FD table → evidence → root cause → fix → regression.

## Challenge

Change the producer values and add a second synchronous observer context without globals. Do not change ownership/retain/mutation contracts.

## Cleanup

```sh
make clean
```

## Sources

M05 and M06 `SOURCE_LEDGER.md` files.
