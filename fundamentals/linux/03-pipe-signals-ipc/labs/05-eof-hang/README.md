# P1-M06 Lab 05 — Deliberate EOF Hang

## Objective

制造最重要的 M06 fault：reader 已无 bytes 但 parent 仍持有 write end，所以 EOF 不到。用 `/proc/<pid>/fd` 找 extra writer，而不是 timeout 后猜。

## Prerequisites

Labs 01–04；`/proc/<pid>/fd`。

## Environment

Linux/WSL；GCC；GNU Make；`/proc` where noted。

## Estimated Time

45–55 min。

## AI Mode

首次预测、FD matrix、root-cause explanation **AI-Free**；evidence chain 完成后可 AI Review。

## Build

```sh
make clean && make
./eof_hang --seeded
```

## Procedure

程序停在 inspection checkpoint；child reader 等 EOF。**先不要按 Enter。**

另一个 shell：

```sh
ps -o pid,ppid,stat,cmd -p <parent>,<child>
ls -l /proc/<parent>/fd
ls -l /proc/<child>/fd
```

根据 symlink target 找同一个 `pipe:[...]` endpoint，更新 process × FD matrix。写 root cause 后按 Enter，让 parent close write end；观察 child 才完成。再运行 `./eof_hang` fixed path。

## Expected Observation

Seeded checkpoint 中 parent 仍有 pipe write descriptor，child 有 read descriptor；reader 不应得到 EOF。Parent close 后 child 打印 EOF 并退出。FD number/PID 都是 runtime evidence，不是 golden literal。

## Actual Verification Status

Strict build: **VERIFIED**. Seeded `/proc` inspection + delayed EOF + post-close EOF: **VERIFIED** on authoring runtime. `strace -f` variant: **UNVERIFIED** (tool absent).

## Questions

1. child 只有 read end，为什么仍可能等不到 EOF？
2. parent “不会再 write” 与 parent “close write descriptor” 有什么差别？
3. `/proc` evidence 如何证明 extra writer，而不是只证明 process alive？

## Failure Modes

先加 sleep；只看 source 不画 matrix；把 pipe capacity 当原因；记录固定 FD number。

## Debug Strategy

Symptom → hypotheses → matrix → `/proc` endpoint identity → close → regression。

## Challenge

增加一个 unrelated child 继承 write end；即使 parent close，reader 仍等到 unrelated child 释放。这个就是 Fault F2 的形状。

## Cleanup

```sh
make clean
```

## Sources

Chapter `SOURCE_LEDGER.md`.
