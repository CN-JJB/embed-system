# Challenge — `fdcopy --limit N INPUT OUTPUT`

**Objective:** 在 FD copy 上增加 bounded transfer，同时保持 EOF、short write、integer parsing 与 ownership 正确。  
**Prerequisites:** M02 Labs 01–04。  
**Environment:** Linux/WSL, GCC, Make。  
**Estimated Time:** 40–50 min。  
**AI Mode:** first implementation **AI-Free**；official docs allowed。

## Contract

实现 `copy_fd_limit()`：最多复制 `N` bytes；如果 input 在 N 之前 EOF，正常成功并报告实际 copied bytes。禁止 `fopen/fread/fwrite/system`。

必须满足：

- parsing `N` 能识别 invalid/overflow，且负数（例如 `-1`）必须拒绝；
- `remaining` 与 buffer request 的计算不 overflow；
- `read()==0` 是 normal EOF；
- short read 不丢数据；short write 必须写完当前 read chunk；
- `-` 使用 borrowed stdin/stdout；只 close 自己 open 的 descriptors；
- error cleanup 不覆盖最初 errno；
- `*copied` 表示**实际已经成功写入 output 的 byte 数**；即使随后发生 write error，也不能把已经成功完成的 partial write 从计数中“抹掉”。

## Build / Procedure

starter 会编译但功能预期失败：

```sh
make clean && make
printf '0123456789abcdef' > input.bin
./fdcopy-limit --limit 5 input.bin out.bin
wc -c out.bin
./fdcopy-limit --limit 999 input.bin out.bin
cmp input.bin out.bin
./fdcopy-limit --limit 999999999999999999999999999 input.bin out.bin
./fdcopy-limit --limit -1 input.bin out.bin
```

自己再写 stdin/stdout、zero limit、empty input tests。

## Expected Observation

limit 是 API extent/quantity contract，不应通过“读完整块再事后截断”制造 overflow/extra output。EOF before limit 不等于 error。

## Actual Verification Status

**VERIFIED (reference solution only)** on GCC 14.2.0：limit smaller/larger than input、zero、stdin/stdout、overflow parse 与 copy regression 已执行。Learner starter intentionally incomplete。

## Questions / Failure Modes / Debug Strategy

1. 为什么 `remaining = limit - copied` 比 `copied + n <= limit` 更容易写成 overflow-safe logic？
2. 谁 owns FD 0/1？
3. 如果 write partial success，`copied` 什么时候增加才准确？

Failure modes: ignored short write、double close `-`、overflow parse、把 early EOF 当失败。Debug 时记录每次 read/write return 和 remaining；GDB path **UNVERIFIED** in authoring environment。

## Challenge

在不改变 public contract 的情况下，把 buffer 降到 3 bytes，证明 output correctness 不依赖 chunk boundary。

## Cleanup / Sources

```sh
make clean
```

Sources: `read(2)`, `write(2)`, `errno(3)`；chapter `SOURCE_LEDGER.md`。Hints/solution 在 `../reviewer/`。
