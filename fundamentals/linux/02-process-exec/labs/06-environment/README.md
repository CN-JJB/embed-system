# Lab 06 — Environment Is Process State, Not a C Local Variable

## Objective

区分 inherited process environment 与 source-level local C variable；观察 parent `setenv` 后 fork+exec child 的 `getenv`。

## Prerequisites

Lab 03。

## Environment

Linux/WSL；GCC。

## Estimated Time

30–40 min。

## AI Mode

AI-Free first run。

## Build

```sh
make clean && make
./env_parent
```

## Procedure

parent sets `DEMO_COLOR=green-from-parent-environment`，同时有普通 local `int local_only=99`。fork 后 child `execv("./env_image", ...)`；`env_image` 只通过 `getenv("DEMO_COLOR")` 读取 environment。

## Expected Observation

child image sees `DEMO_COLOR` because it is in inherited process environment passed by the exec wrapper；它不会自动拥有名为 `local_only` 的 C local object/identifier from old image。

## Actual Verification Status

**VERIFIED.** parent printed local value + environment; exec’d `env_image` printed same environment value。

## Questions

1. `setenv` 与 `int local_only` 分别改变什么 state？
2. exec 后旧 stack/local object 怎么了？
3. `execv` 与 `execve` 在 environment control 上的 mental-model difference 是什么？

## Failure Modes

把 shell variable、C local、process environment 混成同一个 namespace；认为 fork inheritance 等于 source identifier inheritance。

## Debug Strategy

用 `getenv`/explicit `envp` 做 observation；不要通过 shell-specific features 推断 C object semantics。

## Challenge

把 child 改用 explicit `execve` envp，只传 `DEMO_COLOR=blue-explicit`，观察 inherited environment 与 explicit replacement 的 difference。

## Cleanup

```sh
make clean
```

## Sources

`environ(7)`, `execve(2)`; musl `execv.c` REQUIRED source reading。
