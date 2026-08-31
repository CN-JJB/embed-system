
# P1-M06 Challenge — `capture_exec COMMAND [ARGS...]`

## Objective

实现一个最小 stdout-capture launcher：

```text
child stdout → pipe → parent reads until EOF
```

并正确 reap/decode child status。

## Prerequisites

M04 process/wait；M06 Labs 01–05。

## Environment

Linux/WSL；GCC；GNU Make。

## Estimated Time

55–70 min。

## AI Mode

首次实现 **AI-Free**；Linux man-pages/upstream source allowed。

## Contract

1. parent `pipe()`；
2. `fork()`；
3. child:
   - stdout → pipe write end with `dup2`;
   - close unused/original pipe FDs;
   - `execvp(argv[1], &argv[1])`;
   - exec failure diagnostic + `_exit(127)`;
4. parent:
   - close write end immediately;
   - **drain read end until EOF**;
   - write captured bytes to its own stdout (or an explicitly documented sink);
   - obtain/decode child status;
   - close/reap on every error path.

Do not use `system()`, `popen()`, shell `|`, threads, poll/select, temporary files。

## Build

```sh
make clean && make
```

Starter intentionally returns TODO.

Helper:

```sh
./burst
```

writes about 2 MiB in repeated blocks and exits 7. This is deliberately much larger than the parent's single read buffer. The learning claim is only **finite kernel buffering + producer/consumer progress**; do not assert a fixed pipe capacity.

## Procedure

Implement then test:

```sh
./capture_exec /bin/printf 'abc\n' > captured.out
cat captured.out

./capture_exec ./burst > captured.out
wc -c captured.out
```

Record child status separately from captured payload so a target exit 7 remains visible.

Before coding, explain why this order is dangerous:

```text
wait child completely
↓
then read pipe
```

Do not need to force a permanent deadlock to pass; explain the progress cycle and use `burst` as pressure test.

## Expected Observation

Correct implementation drains while child can continue producing; large helper completes and parent later reports decoded status 7 without assuming pipe capacity.

## Actual Verification Status

- Starter strict build: **VERIFIED**.
- `burst` strict build + > single-buffer output: **VERIFIED**.
- Reviewer reference: strict build, small capture, ~2 MiB drain, decoded exit 7, missing-exec reserved 127: **VERIFIED**.
- A deliberately wait-before-drain implementation's permanent deadlock: **UNVERIFIED** as a numeric/capacity guarantee; fault reasoning is source/progress based.

## Questions

1. 为什么 parent 应尽早 close its write end？
2. 为什么 drain-before-final-wait avoids one progress cycle？
3. pipe read 返回 0 后，你能得出哪些 writer-lifetime facts？
4. reserved 127 与 general-purpose unambiguous exec-failure protocol 有什么限制？

## Failure Modes

wait first；parent forgets write close；child original pipe fd left open after `dup2`；exec failure `return`；raw wait status；single `read()` assumes whole output。

## Debug Strategy

`FD matrix → progress graph → read/write returns → /proc → wait status → regression`.

## Challenge

额外运行一个 target legitimate `exit 127`，说明它与 child-side reserved exec-failure code 在当前 one-pipe protocol 中仍可能 ambiguous；不要偷偷增加第二协议 pipe，因为本 challenge 不要求解决该 ambiguity。

## Cleanup

```sh
make clean
```

## Sources

`pipe(2/7)`, `dup(2)`, `read(2)`, `wait(2)`, chapter ledger。
