# Lab 04 — Permissions: Manufacture `Permission denied`

## Objective

只用必要的 user/group/other + r/w/x 模型制造并定位 `EACCES`，区分 regular-file read permission 与 directory search permission。

## Prerequisites

M02 pathname/open/errno；会用 `ls -l`。

## Environment

Linux/WSL；GCC；GNU Make。Optional: `namei`, `strace`。

## Estimated Time

25–35 min。

## AI Mode

第一次 diagnosis **AI-Free**。

## Build

```sh
make clean && make
```

## Procedure

普通 non-root shell 推荐：

```sh
mkdir -p /tmp/m02-perm-demo
printf 'secret\n' > /tmp/m02-perm-demo/data.txt
chmod 000 /tmp/m02-perm-demo/data.txt
ls -l /tmp/m02-perm-demo/data.txt
./read_path /tmp/m02-perm-demo/data.txt
```

如果你在 root authoring/container 环境，root 可能绕过这类检查，不要据此得出权限无效。可在明确存在 unprivileged account 时用等价方式运行，例如 reviewer verification 使用了 `runuser -u nobody -- ...`。

再恢复 file read bit，然后移除 parent directory 的 search (`x`) permission，在**非特权用户**身份重新测试。可选：

```sh
namei -l /tmp/m02-perm-demo/data.txt
strace -e trace=%file ./read_path /tmp/m02-perm-demo/data.txt
```

## Expected Observation

没有 file read permission，或 pathname 中某级 directory 缺少 search permission，都可能导致 open 失败并报告 `EACCES`/Permission denied。`ls -l` 与 `namei -l` 帮你区分失败边界。

## Actual Verification Status

**PARTIALLY VERIFIED** on Linux 6.18.35：使用 unprivileged `nobody` 实际复现 regular-file mode `000` 导致 `open` → `EACCES`，并验证恢复权限后成功。Directory-search scenario 也用 unprivileged identity 执行。`strace` 路径 **UNVERIFIED**（工具未安装）。

## Questions

1. directory `x` 为什么不应解释成“执行这个目录”？
2. root run 成功能否反证 mode bits？
3. 为什么 pathname resolution permission failure 发生在拿到 FD 之前？

## Failure Modes

- 用 root 身份测试后误判；
- 只看最终 file mode，忽略 parent directories；
- 背 `chmod 644/755` 数字但说不出哪一位影响什么。

## Debug Strategy

按 pathname 从左到右检查 traversal；记录 `open` return + errno；`ls -ld` 检查目录，`ls -l` 检查 file，optional `namei -l` 展开每一级。strace 只作为 syscall evidence，不替代 permission reasoning。

## Challenge

设计两个不同原因都得到 `EACCES` 的 setup：一个是 file mode，一个是 parent directory search mode。只给 teammate error message，让他用 evidence 区分。

## Cleanup

```sh
chmod 700 /tmp/m02-perm-demo 2>/dev/null || true
chmod 600 /tmp/m02-perm-demo/data.txt 2>/dev/null || true
rm -rf /tmp/m02-perm-demo
make clean
```

## Sources

`path_resolution(7)`, `open(2)`；chapter `SOURCE_LEDGER.md`。
