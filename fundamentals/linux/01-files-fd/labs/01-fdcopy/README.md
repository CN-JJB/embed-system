# Lab 01 — `fdcopy`: `open/read/write/close`

## Objective

只用 FD-level I/O 实现 `fdcopy INPUT OUTPUT`；`-` 表示 stdin/stdout。正确处理 open/read/write failure、partial write、EOF 与 close ownership。

## Prerequisites

M01 ownership/extent；M02 FD mental model 与 `errno` basics。

## Environment

Linux/WSL；GCC；GNU Make。禁止 `fopen/fread/fwrite/system`。

## Estimated Time

50–65 min。

## AI Mode

第一次实现/修改 **AI-Free**；official man pages allowed。

## Build

```sh
make clean && make
```

## Procedure

```sh
printf 'alpha\nbeta\n' > input.bin
./fdcopy input.bin output.bin
cmp input.bin output.bin

printf 'stdin path\n' | ./fdcopy - output.bin
./fdcopy input.bin -

./fdcopy does-not-exist output.bin
```

代码阅读时圈出 `write_all()`：如果一次 `write()` 只完成 prefix，下一次必须从 `buf + off` 写 remaining bytes，而不是重写全部或丢弃 remainder。

## Expected Observation

- existing input 可逐块读取到 EOF；EOF 是 `read()==0`；
- stdout/stdin case 使用既有 FD 0/1，helper 不 ownership-close 它们；
- failed `open` 先由 return value 表示，再解释 `errno`；
- output bytes 应与 input 相同，不能假设一次 `write` 完成全部 requested count。

## Actual Verification Status

**VERIFIED** on Linux 6.18.35 / GCC 14.2.0：file→file、stdin→file、file→stdout、missing-input failure 与 `cmp` regression 已执行。真实 kernel/filesystem 本次未自然产生 short write；short-write loop 的 deterministic fault coverage 在 `../../faults/` 验证。

## Questions

1. 为什么 `-` case 不能在 cleanup 无条件 `close(0/1)`？
2. 为什么 copy error 后要先保存 `errno` 再 cleanup？
3. `write_all` 为什么检查 returned byte count，而不是只检查 `<0`？
4. 如果 `read` 返回 137，下一次 read 应从哪里继续？谁维护普通文件的 offset？

## Failure Modes

- `write(fd, buf, n);` 后直接认为完成；
- `errno != 0` 就判错；
- error path 忘记 close owned input；
- helper 把 borrowed stdin/stdout close 掉；
- 把 EOF 当作 buffer 中某个 byte。

## Debug Strategy

先记录 failing call 的 return value 和 saved errno。若逻辑涉及 partial write，breakpoint 放在 `write_all`，观察 `off/len`；GDB command path 在 authoring 环境 **UNVERIFIED**。Lab 03 再用 strace 把 source-level call 与 syscall evidence 对齐。

## Challenge

把 buffer size 改成 7，重新 copy 一个 10 KiB 文件；证明 correctness 不依赖“一个 read == 一个 write == 整个文件”。

## Cleanup

```sh
make clean
```

## Sources

`open(2)`, `read(2)`, `write(2)`, `close(2)`, `errno(3)`；chapter `SOURCE_LEDGER.md`。
