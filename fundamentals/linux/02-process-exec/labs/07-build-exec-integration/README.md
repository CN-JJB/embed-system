# Lab 07 — Integration: Build ELF → Exec → Inspect Process

## Objective

把 M03 与 M04 串成同一 evidence chain：build `child_image.o` + final ELF，inspect binary，再由 parent fork/exec，并用 `/proc` inspect running process。

## Prerequisites

全部 M03；M04 Labs 01–06。

## Environment

Linux/WSL；GCC/binutils/Make；`/proc`。

## Estimated Time

45–60 min。

## AI Mode

AI-Free integration questions。

## Build

```sh
make clean && make
file child_image.o child_image
nm child_image.o | grep build_id
readelf -S child_image
./parent
```
在 child checkpoint 时不要按 Enter。

## Procedure

第二 terminal：

```sh
tr '\0' ' ' < /proc/<child>/cmdline; echo
readlink /proc/<child>/exe
```

再回 first terminal Enter。对照 parent output 中 `child-before-exec pid` 与 child-image PID。

## Expected Observation

`child_image.o` 是 relocatable object，不是正常 executable image；`child_image` 是 link 后的 ELF executable。exec 选择的是 final executable。successful exec 前后 child PID same；`/proc/<pid>/cmdline` 显示 new argv，`/proc/<pid>/exe` 指向 linked executable。

## Actual Verification Status

**VERIFIED.** authoring run：before-exec PID 与 child-image PID 都为 1245；`/proc/.../cmdline` contained `child_image`, `from-parent`; `/proc/.../exe` resolved to lab final `child_image`; parent exit 0。Binary addresses/PIDs非 golden。

## Questions

1. M03 中哪个 artifact 被 exec？
2. `.o` 能不能作为这个 normal executable image 直接使用？为什么？
3. link 解决 symbol/relocation relation，与 exec 做的事情有什么区别？
4. ELF file 与 running process 有什么不同？
5. child PID 为什么 exec 前后不变？

## Failure Modes

对 `.o` 直接 `execv` 并把 failure 误解成 permissions；把 linker 与 loader/exec 合成“启动程序”；认为 `/proc/exe` 就是 process 本身。

## Debug Strategy

先在 process 启动前 inspect file/object evidence；再运行并 inspect PID/cmdline/exe。把 file evidence 与 runtime evidence 分栏。

## Challenge

修改 `build_id`，只重建 child image；重新 exec 并证明新的 binary content 体现在 process output，但 process model 不变。

## Cleanup

```sh
make clean
```

## Sources

M03 source ledger + `execve(2)` + `/proc/pid/cmdline`。
