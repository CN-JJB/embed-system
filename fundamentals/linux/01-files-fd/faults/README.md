# M02 Fault Injection — FD Evidence Required

**Objective:** 对 leak、close ownership、short write、permission/error propagation 四类 fault 收集 runtime evidence。  
**Prerequisites:** M02 Labs 01–04。  
**Environment:** Linux/WSL, GCC, Make；`/proc` required；strace optional。  
**Estimated Time:** 40–55 min。  
**AI Mode:** initial diagnosis **AI-Free**。

## Build

```sh
make clean && make
printf '0123456789abcdef\n' > input.bin
```

## F1 — FD leak

```sh
./fd-faults leak input.bin
# in another terminal:
ls -l /proc/<pid>/fd
```

不要用“process exit 后 OS 会收掉”替代 ownership diagnosis。指出本函数结束前哪些 FD 仍 owned/open。

## F2 — incorrect close ownership

```sh
./fd-faults ownership input.bin
```

Evidence 至少包含 caller 的 failing return value + `errno`。解释 helper contract 是 borrowed，却在内部 close，为什么 caller 后续得到 `EBADF`。

## F3 — short-write handling bug

```sh
./fd-faults short input.bin out.bin
wc -c input.bin out.bin
cmp input.bin out.bin
```

`capped_write()` deterministic 地让每次 successful write 最多 3 bytes。不要“修”这个 injection helper；修 consumer 对 returned count 的处理。

## F4 — permissions / error propagation

先制造一个 non-root 用户无法读的 file，再运行：

```sh
./fd-faults propagation /tmp/m02-perm-demo/data.txt
```

程序在原始 `open` failure 后错误执行 cleanup，导致报告的 errno 被 `EBADF` 覆盖。Evidence 要同时包含 expected permission setup 与实际 reported errno。可用 strace 时对照最早失败的 syscall。

## Expected Observation

- F1: `/proc/<pid>/fd` 能看到额外 open entries；
- F2: caller 使用被 helper 关闭的 FD，得到 bad descriptor evidence；
- F3: program 可 exit 0 但 output 被截短，证明“positive write == full write”错误；
- F4: cleanup 若不保存 original errno，会破坏 root-cause error propagation。

## Actual Verification Status

**PARTIALLY VERIFIED** on Linux 6.18.35 / GCC 14.2.0：F1 `/proc` leak、F2 `EBADF`、F3 deterministic truncation、F4 在 `nobody` + permission-denied setup 下的 errno masking 已执行。strace evidence **UNVERIFIED**（authoring environment 未安装 strace）。

## Questions / Failure Modes / Debug Strategy

每个 fault 写 `Symptom/Hypotheses/Evidence/Root Cause/Fix/Regression`。至少用 `/proc`、return+errno、strace 三类中的一类；F1 必须 `/proc`，F3 必须 byte-count/cmp evidence。

常见失败：看到 `EBADF` 就只改 caller；把 output “有内容”当 copy correct；error cleanup 后才保存 errno。

## Challenge

为 F3 写一个 `write_all` 修复，但不改 `capped_write`；把 cap 从 3 改成 1/7/16 都要通过同一 regression。

## Cleanup / Sources

```sh
make clean
```

Sources: Linux man-pages `write(2)`, `close(2)`, `errno(3)`, `proc_pid_fd(5)`；chapter `SOURCE_LEDGER.md`。
