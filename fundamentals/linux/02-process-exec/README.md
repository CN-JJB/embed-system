# P1-M04 — Process, `fork`, `exec`, `waitpid`, Environment

> **Target depth:** L3。  
> **Prerequisites:** P1-M02 FD ownership mental model + P1-M03 object/ELF model。  
> **Module budget:** 约 5.5 h MUST；REQUIRED reading ~65–75 min。  
> **AI Mode:** process-control implementation/challenge/Gate first pass AI-Free；official man-pages allowed。

## Why

M03 已经回答“binary 是怎么来的”。现在要回答：

> **ELF file 怎样成为正在运行的 process？`fork` 与 `exec` 各自改变什么？父进程怎样知道 child 最终发生了什么？**

本章的系统主线：

```text
source
  ↓
relocatable object
  ↓ link
ELF executable
  ↓ exec
running process
```

之后再学 pipe/signal/service supervision 时，FD/process image/child lifecycle 才不会混成一团。

## Mental Model

### Diagram A — Program vs Process

```text
ELF file
  │
  │ exec
  ▼
process
├── PID
├── address space
├── FD table
├── argv/env
└── execution state
```

[`diagrams/program-process.mmd`](diagrams/program-process.mmd)

**ELF file 不是 process。** 它是 filesystem 上的 binary artifact；process 是运行时实体，具有 PID、address-space view、FD table、argv/environment、execution state 等。

### Diagram B — `fork`

```text
             fork()
               │
        ┌──────┴──────┐
        ▼             ▼
     parent         child
 return childPID    return 0
```

[`diagrams/fork.mmd`](diagrams/fork.mmd)

这是 **user-visible mental model**：调用后有 parent 与 child 两条 execution flows，具有不同 process identity；两者之后各自继续执行。不要说“fork 的实现就是复制全部 RAM”。Linux 等现代实现通常使用 copy-on-write 等优化，但 implementation internals 只做 forward reference，本章不展开 page tables/COW mechanism。

### Diagram C — `exec`

```text
same process identity
       │
       │ exec
       ▼
new program image
```

[`diagrams/exec.mmd`](diagrams/exec.mmd)

本章最重要的句子：

> **exec does not create a second child process.**

successful `execve` 用新 program image 替换当前 process 正在运行的 program image；PID 在我们的实验中保持不变。**exec success 不返回**；只有 failure 才返回到 caller。

## Minimal Theory

### 1. Program vs process

一个 executable file 可以被多次执行产生多个 processes；一个 process 在 successful `exec` 后可以开始运行完全不同的 program image，而仍保留同一个 PID identity。不要把 file identity、program image、process identity 混为一件事。

### 2. PID / PPID

`getpid()` 给当前 process ID；`getppid()` 给 parent process ID（注意 parent lifecycle/reparenting 可能使现实观察变化）。Lab 01 只要求理解 fork 后 parent/child return-value invariants，不用 `sleep` 人为“保证 print order”。

### 3. process address-space mental model

沿用 M01：process 有自己的 address-space view。`fork` 后 parent/child 在 user-visible 层面像是从相同初始 program state 分叉，但之后修改彼此的普通 memory 不应按“同一个 C object”理解。实现常用 COW；不进入 page-table internals。

### 4. inherited user-visible state

本章只观察：

- argv/environment 相关状态；
- current working context/basic process properties；
- **FD entries are inherited across fork** at this depth。

M02 的 mental model 现在跨 process：parent 打开的 FD number 可能在 child 中也存在。我们不在本章深入 shared open-file-description offset；更不教 pipe/`dup2`。

### 5. `execve` / exec family

把 exec family 看成同一核心概念的 convenience interfaces：选择 pathname/search behavior、argv 与 environment 传递方式有所不同。`execve(path, argv, envp)` 最直接暴露“program image + argv + environment”三件事。

successful exec 后旧 program image 的正常 caller code 不再继续。若它返回，说明发生 failure，应立即处理 error path。

### 6. Environment

`argv` 是 command-line argument vector；environment 是 `NAME=value` strings 的 process state。C local variable 只是当前 program image 中的 C object，不会因为名字相似自动成为 environment variable。

`fork` 后 child 可观察到 inherited environment；exec 时可显式传新 `envp`，或 convenience wrappers 使用现有 `environ`。

### 7. `waitpid` / exit status / zombie

`waitpid` 不只是“等一下”：它让 parent 获取 child state change / termination status 并完成 reap。`status` 是 encoded wait status，**不能直接当 child return code**；要先 `WIFEXITED(status)` 再 `WEXITSTATUS(status)`，或用对应 macros 处理 signal termination。

child terminated、parent 尚未 wait/reap 时可能成为 **zombie**。zombie **不是仍在运行的 child**；在本章深度，把它理解为 kernel/process table 仍需保留足够 termination status/accounting-related information，直到 parent 获取状态。

## Experiment Map

| Lab | Question | Evidence |
|---|---|---|
| [01 fork Return Values](labs/01-fork-values/README.md) | parent/child 哪些事实 invariant，哪些 print order 不保证？ | PID/PPID + wait status |
| [02 `/proc` Process State + FD](labs/02-proc-state/README.md) | child 运行时 process state/FD entries 如何观察？ | `ps`, `/proc/<pid>/status/fd/cmdline` |
| [03 exec Replacement](labs/03-exec/README.md) | successful exec 前后 PID 是否改变？argv/env 如何变化？ | own `child_image` |
| [04 exec Failure](labs/04-exec-failure/README.md) | 为什么 success 不返回、failure path 为什么 `_exit`？ | ENOENT/EACCES + control flow |
| [05 waitpid / Zombie](labs/05-wait-zombie/README.md) | zombie 能否确定性观察并在 reap 后消失？ | `/proc` state `Z`, `ps`, `waitpid` |
| [06 Environment](labs/06-environment/README.md) | inherited environment 与 local C variable 区别？ | `setenv/getenv` + exec |
| [07 M03+M04 Integration](labs/07-build-exec-integration/README.md) | 哪个 M03 artifact 被 exec？ELF 与 running process 有何不同？ | `readelf/nm` + `/proc/<pid>/cmdline` |
| [08 `strace -f`](labs/08-strace/README.md) | source API 与 observed syscall naming 是否一一同名？ | fork/exec/wait/exit trace |

## Source / Reference Walkthrough

### Official — REQUIRED

Pinned tutorial docs: **Linux man-pages 6.18**：

- `fork(2)` DESCRIPTION / RETURN VALUE / NOTES；
- `execve(2)` DESCRIPTION / RETURN VALUE / ERRORS；
- `wait(2)` (`waitpid`) DESCRIPTION + wait-status macros；
- `environ(7)`；
- selected `/proc/<pid>/{status,fd,cmdline}` pages。

man-pages **6.19 was released 2026-08-25**, so ledger explicitly distinguishes current upstream from this tutorial’s 6.18 snapshot instead of silently updating claims.

### Open-source source reading — REQUIRED / SHOULD

**musl 1.2.6**, commit `9fa28ece75d8a2191de7c5bb53bed224c5947417`：

- **REQUIRED:** `src/process/waitpid.c` — tiny wrapper，观察 libc `waitpid()` 如何进入 lower syscall boundary；
- **REQUIRED:** `src/process/execv.c` — tiny wrapper，观察 `execv` 如何使用 `__environ` 委托给 `execve`；
- **SHOULD:** `src/process/execve.c` — tiny direct syscall wrapper，帮助理解 source API/kernel syscall boundary；不要因此推断所有 libc/architecture 都同样实现。

这些 focused paths 每个远低于 20 LOC implementation body，dependency noise low；不读 glibc fork internals。

### Classic books

- **TLPI** — REQUIRED selected process creation / monitoring child processes / program execution material；目标 45–55 min，不整章照抄。
- **OSTEP** — SHOULD `Processes` / `Process API` 作为 mental-model supplement，约 15–20 min；不是 API truth source。

M03+M04 REQUIRED reading 总预算约 **2 h 15 min–2 h 30 min**，低于 2.5–3 h ceiling。

## Observation → Explanation

### `fork` 与 scheduling

Lab 01 的 parent/child print 顺序可以变；但这些事实不会因 scheduling 顺序改变：

- child sees `fork()` return 0；
- parent sees child PID；
- parent PID 与 child PID distinct；
- parent 用正确 `waitpid` target 最终取得该 child termination status。

不要加 `sleep` 把 nondeterministic scheduling 伪装成 API ordering guarantee。

### `exec`

Lab 03 会记录：

```text
before exec child PID = X
child_image PID         = X
```

相同 PID + changed program output/argv/env 是“same process identity, new program image”的直接 evidence。`exec` 没创建第二个 process。

### Zombie

Lab 05 不用 `sleep 5` 碰运气。parent 轮询自己的 child `/proc/<pid>/stat`，**只有确认 state `Z` 才开放 inspection checkpoint**；你再用 `ps` 独立验证。按 Enter 后 `waitpid`，child `/proc` entry 消失。

## FD Inheritance Bridge from M02

M02 学的是：FD 是 per-process table entry / resource reference。M04 Lab 02 让 parent `open()` 一个 file 后 `fork`；child 的 `/proc/<pid>/fd` 仍有对应 entry，而且可以使用它。核心转移是：

> **同一个 parent-created resource reference 可以在 fork 后出现在 multiple processes 的 FD tables。**

这不等于“每个 child 在所有 API 设计里都承担相同 conceptual cleanup ownership”。resource ownership contract 仍由 program design 决定。shared open-file-description offset 与 CLOEXEC policy 留到后续。

## `strace -f`

M04 必须把 trace 绑定到真实 process question：

```sh
strace -f -o trace.log ./exec_demo
strace -f -o trace.log ./fork_values
```

你可能看到 `clone`/`clone3`/fork-equivalent implementation syscall，而 source 写的是 `fork()`；wait 也可能以不同 underlying syscall 呈现。**libc API/source concept 与 observed kernel syscall 不保证同名一一对应。**

authoring runtime 没有 strace，因此这部分 **UNVERIFIED**，无 fabricated transcript。

## Debug

- `ps -o pid,ppid,stat,cmd`：process relationship/state；
- `/proc/<pid>/status`：PID/PPID/state selected fields；
- `/proc/<pid>/fd`：inherited FD references；
- `/proc/<pid>/cmdline`：exec 后 argv evidence；
- `strace -f`：multi-process syscall boundary evidence；
- GDB basic process inspection optional；`follow-fork-mode` 仅 SHOULD，不进入 advanced fork debugging。

GDB/strace 在 authoring runtime 均 unavailable → commands **UNVERIFIED**。

## Common Misconceptions

- **program == process** → ELF file 与 running process 是不同 entities。
- **fork immediately creates a new program image** → fork creates child flow based on calling process state；new image 是 exec 的工作。
- **exec creates another process** → successful exec replaces current program image。
- **child PID changes after successful exec** → Lab 03 直接反证。
- **zombie is still running** → child 已 terminated；zombie 保留的是待 parent collect 的 termination-related record。
- **waitpid status integer == exit code** → 必须用 `WIF*` / `WEXITSTATUS` 等 macros。
- **source `fork()` must appear as literal `fork` syscall in strace** → libc implementation/kernel ABI may differ。
- **inherited FD means child always owns cleanup in every API design** → inheritance fact 与 conceptual ownership contract 要分开。

## Transferable Concept vs Host-specific Evidence

| Transferable | Host-specific / implementation evidence |
|---|---|
| fork creates parent/child execution flows | Linux libc may use clone-like syscall under trace |
| exec replaces process image without new PID | exact ELF loader/syscall trace lines vary |
| wait status is encoded and must be decoded | underlying wait syscall naming may vary |
| child can inherit FDs | exact FD numbers depend on runtime |
| process state observable via OS interfaces | `/proc` paths are Linux-specific |

## Fault Injection / Challenge / Gate

- [`faults/README.md`](faults/README.md): zombie, exec fallthrough, raw wait status, unexpected inherited FD。
- [`challenge/README.md`](challenge/README.md): implement `run_one NAME=VALUE COMMAND [ARGS...]` with own fork/exec/waitpid；禁止 `system()` / `popen()`。
- [`gate/README.md`](gate/README.md): unknown mini supervisor，必须用 `ps`, `/proc`, `strace -f`, source reasoning 建 evidence chain；strace execution remains learner/Leader requirement even though authoring host lacks tool。

## Spaced Review

### D+1 — mental-model recall（AI-Free, 10 min）

画 `ELF → exec → process`，另画 fork split；写出 `fork` parent/child return values、successful exec return behavior、wait status decoding first macro。

### D+3 — changed-context transfer（AI-Free, 20 min）

给一个 parent open file → fork → child exec helper 的新程序。预测 child 的 PID、environment、FD visibility；再用 `/proc` 验证其中两个 predictions。

### D+7 — blank-file reconstruction（AI-Free, 35–45 min）

从空文件写：parent `fork`；child `exec` `/bin/echo` 或自己的 tiny helper；parent `waitpid` 并正确打印 `WEXITSTATUS`。再制造 missing executable，确保 child failure path `_exit`，不继续 caller logic。

## Career Relevance

- **process/exec → embedded Linux userspace:** init/helper/test tools 都基于 executable/process boundary。
- **`/proc`/strace → BSP/application bring-up:** “程序没启动/启动错 image/child 没回收”要有 OS evidence。
- **FD inheritance → later pipe/daemon/service:** M02 resource model开始跨 process，为 M06 pipe/`dup2` 建前置概念。
- **wait/zombie → reliable process supervision:** supervisor 必须知道 child 是否、如何结束，并完成 reap。
- **environment/argv → init/build/test tooling:** board bring-up scripts/test runners 需要明确 launch contract。

## Scope Boundary

不进入 dynamic loader internals、page tables/COW implementation、scheduler internals、namespaces/cgroups、signals 深入、pipes、`dup2`、pthread、daemonization、systemd、kernel process source internals。`O_CLOEXEC/FD_CLOEXEC` 只允许作为 SHOULD forward-looking option；本章 primary fix 是明确 close-before-exec ownership。

## Sources

精确 pins / source paths / license / current-vs-pinned notes 见 [`SOURCE_LEDGER.md`](SOURCE_LEDGER.md)。
