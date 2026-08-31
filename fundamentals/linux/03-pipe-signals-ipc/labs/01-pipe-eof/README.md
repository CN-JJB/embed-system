# P1-M06 Lab 01 — Pipe EOF

## Objective

用最小 pipe 证明：bytes 先被读出；writer descriptor 关闭且 buffer drain 后，下一次 `read()` 返回 0。

## Prerequisites

M02 `read/write/close`。

## Environment

Linux/WSL；GCC；GNU Make；`/proc` where noted。

## Estimated Time

25–30 min。

## AI Mode

首次预测、FD matrix、root-cause explanation **AI-Free**；evidence chain 完成后可 AI Review。

## Build

```sh
make clean && make
./pipe_eof
```

## Procedure

先画 single-process FD table：`p[0]` read end，`p[1]` write end。预测两次 read 的类别（data / EOF），再运行。不要记录某个具体 FD number 作为答案。

## Expected Observation

第一次 read 得到已写入 bytes；第二次在 write end 已关闭、bytes 已 drain 后返回 0。这个实验不把 EOF 解释成特殊 byte。

## Actual Verification Status

Strict build + run: **VERIFIED**.

## Questions

1. 若 `p[1]` 仍 open 且无数据，为什么不能把“当前没数据”误当 EOF？
2. pipe 为什么不提供 message boundaries？

## Failure Modes

把 `read()==0` 写成“读到 byte 0”；忘关 read end；把一次 read size 当 message length guarantee。

## Debug Strategy

return value → endpoint state → lifetime。先看谁还握 write end。

## Challenge

把 write payload 改成超过 read buffer，证明多次 positive reads 后才得到 EOF。

## Cleanup

```sh
make clean
```

## Sources

Chapter `SOURCE_LEDGER.md`.
