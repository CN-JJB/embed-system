
# P1-M06 — Pipe, `dup2`, Signals, Small IPC

> Phase 1 / M06  
> Target: **L3**, with **L4-local** diagnosis for FD-lifecycle / EOF hangs  
> AI mode: Challenge, Gate, first EOF-hang diagnosis, and D+7 reconstruction are **AI-Free**; official docs/upstream source are allowed.  
> Planned learner time: **6 h MUST**. REQUIRED external reading target: **~65–75 min**.

## Why

`pipe()` 本身很短；真正决定 pipeline 是否可靠的是 **FD lifecycle contract**：

```text
Which process owns which descriptor?
Which descriptor numbers refer to which underlying pipe endpoint?
Who still holds a write end?
When can read() return 0?
What changed after dup2()?
What survives fork/exec?
Who reaps every child?
What can a signal handler safely do?
```

本模块的核心 skill 是：**pipeline hang 时先画 process × FD matrix，再收集 `/proc/<pid>/fd` / syscall evidence，不先加 sleep。**

## Prerequisites

- M02 pathname/FD/open-file mental model；
- M04 `fork/exec/waitpid` + inherited FDs；
- M05 ownership/lifetime/API contract reasoning。

## Mental Model 1 — pipe 是 kernel byte stream

```text
write end FD(s)
      ↓
┌──────────────────┐
│ kernel byte stream│   no message boundaries
└──────────────────┘
      ↓
read end FD(s)
```

Pipe 不保存“message boundaries”。本模块只处理 byte flow，不进入 framing/serialization；那属于 M07。

关键 EOF rule：

> Reader 只有在 pipe 中现有 bytes 已读尽，并且 **所有仍能引用该 pipe write end 的 relevant descriptors 都关闭** 后，`read()` 才返回 `0`。

“parent 自己不用 write end”不等于它已关闭；“producer child 已退出”也不保证 unrelated process 没有继承 write end。

## Mental Model 2 — process × FD close matrix

每个 multi-process pipe lab 都先填：

| Process | pipe read end | pipe write end | after `dup2` original? |
|---|---|---|---|
| parent | close/keep? | close/keep? | n/a |
| producer child | close/keep? | close/keep? | close? |
| consumer child | close/keep? | close/keep? | close? |

这张表是 debugging tool，不是作业装饰。EOF hang 的很多 root cause 就是 matrix 里多了一个 `keep`。

## Mental Model 3 — FD number ≠ underlying resource

`dup2(pipefd[1], STDOUT_FILENO)` 的含义是：

```text
descriptor number 1
        │
        └──── now refers to the same target open file description / pipe endpoint
              as pipefd[1]
```

它不是“复制 pipe bytes”，也不是“把 stdout 这个对象变成 pipe”。成功后原来的 `pipefd[1]` descriptor **仍存在**；如果不再需要，通常必须 close，以免增加一个不必要的 endpoint reference。

`dup2(oldfd, newfd)` 的关键 contract：

- 若 `oldfd != newfd`，成功操作使 `newfd` 绑定到 `oldfd` 当前引用的 open file description；原 `newfd` binding 被替换；
- `oldfd` 本身仍保持打开；
- `oldfd == newfd` 时，合法 `oldfd` 下 `dup2` 不需要替换 binding；至少要意识到这不是普通“close new then dup”手写替代能完全等价覆盖的 corner case。

本模块不深入 `dup3`。

## Mental Model 4 — fork + pipe + exec lifecycle

```text
pipe()
  ↓
fork consumer
  ↓
fork producer
  ↓
child close unused ends
  ↓
dup2(target, stdin/stdout)
  ↓
close original duplicated pipe fd
  ↓
exec
  ↓
parent closes both pipe copies
  ↓
parent drains / waits according to protocol
  ↓
waitpid every child
```

M04 已学 process creation；M06 新增的是 **descriptor graph + EOF progress + duplication + evidence**。

## Minimal Theory

### 1. `read()==0`

对 pipe，`read()` 返回 0 表示 EOF：当前没有更多 bytes，而且不会再有 writer 通过任何 still-open write-end descriptor 写入。不要把 EOF 想成传输的特殊 byte。

### 2. inherited descriptors extend lifetime

`fork()` 后，child 得到 descriptor table entries 的副本；这些 entries 指向相同底层 open file description / pipe endpoints。一个“不参与写”的 child 如果忘关 write end，仍可能延长 EOF lifetime。

### 3. wait-before-drain risk

Pipe buffering 是有限的，但本课程不要求背某个默认容量。若 parent：

```text
wait producer completely
↓
then read captured stdout
```

而 producer 输出超过当前可用 pipe buffering，producer 可能阻塞在 write，parent 又阻塞在 wait：形成 progress cycle。正确 `capture_exec` baseline 是 parent **持续 drain pipe**，EOF 后/合适时再完成 wait status collection。

### 4. signals baseline

本章只做：

```text
SIGINT / SIGTERM
        ↓
handler records intent
        ↓
volatile sig_atomic_t stop_requested = 1
        ↓
normal control flow performs close / kill-if-policy / wait / cleanup
```

Canonical handler：

```c
static volatile sig_atomic_t stop_requested;

static void on_signal(int signo)
{
    (void)signo;
    stop_requested = 1;
}
```

本课程 handler **不调用**：

- `printf` / stdio；
- `malloc/free`；
- complex application cleanup；
- callback dispatch；
- pthread APIs。

即使某个具体 low-level function 出现在 POSIX async-signal-safe list，也不要把 handler 设计成 resource cleanup center。本章 architecture 是 **record intent; normal context cleans up**。

`volatile sig_atomic_t` 是 signal-handler communication baseline，不是未来 pthread synchronization replacement。

### 5. `EINTR` / `SA_RESTART`

最小 mental model：

- signal 可能让某些 blocking interfaces 返回 failure with `errno == EINTR`；
- 是否自动 restart 取决于 interface、signal disposition、flags 和平台语义；
- `SA_RESTART` **不是 restart everything**；
- 先检查实际 return/errno，再按 operation contract 决定 retry 或回到 control loop。

M06 code 通常在 `read` 的 `EINTR` 上先检查 `stop_requested`；如果是 stop request，就回到 normal cleanup，而不是无条件永远 retry。

## Experiment Map

| Lab | Observable boundary | Main evidence |
|---|---|---|
| [01 Pipe EOF](labs/01-pipe-eof/) | close writer → reader eventually sees `read()==0` | return value |
| [02 Pipe Across fork](labs/02-fork-pipe/) | inherited endpoints + close matrix | data + child status |
| [03 `dup2` Redirection](labs/03-dup2/) | FD 1 binding redirected | byte flow + optional `/proc` |
| [04 Two-Process Exec Pipeline](labs/04-exec-pipeline/) | producer stdout → consumer stdin | FD matrix + wait status |
| [05 Deliberate EOF Hang](labs/05-eof-hang/) | extra writer delays EOF | `/proc/<pid>/fd` + process state |
| [06 `sigaction` Stop Flag](labs/06-signal-stop/) | handler intent → normal cleanup | signal delivery + cleanup message |
| [07 `strace -f` Lifecycle](labs/07-strace-lifecycle/) | syscall boundary lifecycle | trace, when tool exists |

## Official Source Walkthrough — Linux man-pages 6.18 baseline

为与 M02/M04 保持一致，教程 API baseline 固定为 **Linux man-pages 6.18**：

- `pipe(2)`, `pipe(7)`；
- `dup(2)` / `dup2()`；
- `read(2)`, `write(2)`；
- `sigaction(2)`, `signal-safety(7)`, selected `signal(7)`；
- `wait(2)` as needed；
- `proc_pid_fd(5)`。

**Current upstream is recorded separately:** kernel.org archive shows man-pages **6.19**, dated 2026-08-25. 本批不 silently rebadge 6.18 runtime/tutorial evidence as 6.19。

阅读顺序：

1. `pipe(7)` 先找 pipe I/O + EOF / writers/readers relationship；
2. `dup(2)` 看 duplicate descriptor semantics + `dup2` replacement；
3. `sigaction(2)` 看 installation contract；
4. `signal-safety(7)` 看 async-signal-safety why；
5. `read(2)` 看 0/EINTR return evidence。

## Open-source Source Walkthrough — musl 1.2.6

Pinned canonical source family:

```text
musl 1.2.6
commit 9fa28ece75d8a2191de7c5bb53bed224c5947417
```

Guided paths:

- `src/unistd/pipe.c` — tiny wrapper chooses `SYS_pipe` or `SYS_pipe2(...,0)` depending build target;
- `src/unistd/dup2.c` — handles `old==new` in fallback path and loops on an internal `EBUSY` case before returning through syscall-result helper;
- `src/signal/sigaction.c` — a much richer libc boundary that maps user `struct sigaction` to kernel ABI state and tracks internal signal concerns.

Teaching question:

> 这些 files 展示 **one concrete libc implementation → lower syscall boundary**。它们不能推出“所有 libc/architecture 都这样”。

不要让 `sigaction.c` 的 internal threading/lock code把课程拉进 pthread curriculum；只观察 wrapper boundary 和为何 implementation 可以比 man-page API contract复杂。

## Observation → Explanation

完成 labs 后应该能解释：

- consumer 卡在 `read()` 不代表 kernel “忘发 EOF”；先找 remaining write-end references。
- `dup2` 成功后 original pipe FD 仍然是一个 descriptor，通常还要 close。
- 一个 unrelated exec child 也能因为 inherited endpoint 延长 pipe lifetime。
- `waitpid` 与 pipe drain 的顺序会影响 progress。
- handler 内打印“在我机器上工作”不能证明 design 合法。
- `/proc/<pid>/fd` 是 Linux-specific runtime evidence；FD number 不应写成 golden literal。
- strace 中 exact syscall spelling 可能受 libc/kernel/arch 影响；source-level contract 与 observed syscall 要对应但不要求同名。

## Debug — Pipe Lifecycle Workflow

```text
Symptom
↓
Own Description
↓
3–5 Hypotheses
↓
process × FD matrix
↓
/proc/<pid>/fd
↓
strace -f (if available)
↓
Narrow Scope
↓
Root Cause
↓
Minimal close/dup/wait/signal fix
↓
Regression
```

对 hang，先问：

1. reader blocked 在什么 operation？
2. 哪些 process 仍然 alive？
3. 每个 alive process 是否还有 pipe write endpoint？
4. 是否有 descriptor duplication 导致额外 reference？
5. parent 是否在等待一个被 full pipe 卡住的 producer？

## Common Misconceptions

| Misconception | Correction |
|---|---|
| writer child exited → EOF must arrive | 还要检查 parent/unrelated child 的 write-end refs |
| `dup2` copies resource | 它修改 descriptor binding；底层 resource 被共同引用 |
| after `dup2` old pipe fd is automatically closed | 不会；按 lifecycle contract cleanup |
| pipeline hang → add sleep | 先画 FD matrix + collect evidence |
| pipe preserves writes as messages | byte stream；framing later in M07 |
| wait first is always clean | captured output may block producer if parent不drain |
| handler can `printf` because it worked once | runtime luck ≠ async-signal-safe design |
| `SA_RESTART` restarts all calls | interface/flags-specific；inspect return + errno |
| `sig_atomic_t` solves threads later | 本章只用于 signal-handler communication baseline |

## Fault Injection

[`faults/`](faults/) 覆盖：

- F1 parent forgets write-end close；
- F2 unrelated child retains write end across exec；
- F3 wrong `dup2` endpoint/direction；
- F4 wait-before-drain progress cycle；
- F5 unsafe signal-handler design review。

至少一个 fault 必须用 `/proc` evidence，不允许只靠 timeout 猜。

## Challenge — `capture_exec COMMAND [ARGS...]`

[`challenge/`](challenge/) 要实现 child stdout capture：

```text
child stdout → pipe → parent drain → EOF → decoded child status
```

提供 `burst` helper 输出远大于单次 read buffer 的数据，用来暴露 “wait completely, then read” 的阻塞风险；不要求背 pipe capacity。

## Gate — Pipe Lifecycle & Shutdown Audit

[`gate/`](gate/) 是 **75–100 min AI-Free** small supervisor/pipeline。必须画 FD matrix，保存 hang symptom，用 `/proc` + `strace -f`（若工具存在）缩小 scope，修 lifecycle + signal handler，wait/reap every child，最后 repeated regression。

## M05 ↔ M06 Integration Exercise

[`integration/`](integration/) 明确连接：

```text
pipe/input FD
↓
line reader
↓
record parser
↓
synchronous callback(record, ctx)
↓
stats
```

SIGTERM/SIGINT：

```text
handler sets stop_requested
↓
normal loop exits
↓
normal context closes FD / terminates child if policy requires / waitpid
```

保持 single-threaded、no ring buffer、no mutex/condvar、no worker、no binary serialization。

## Spaced Review

### D+1 — 10 min, AI-Free

闭卷画一个 parent + producer + consumer 的 process × FD matrix。解释什么时候 consumer 才可能得到 EOF。

### D+3 — 20 min, AI-Free

给一个 `dup2` 后忘关 original descriptor 的新 fixture。先预测 `/proc/<pid>/fd` 会看到什么 **类别**，再运行验证，不固定 FD number。

### D+7 — 45–55 min, AI-Free

从空文件构建 producer → consumer pipeline：2 children、pipe、`dup2`、close discipline、waitpid。画 FD matrix；故意制造一个 EOF hang；用 `/proc` 找到 extra writer 后修复。

## Career Relevance

```text
FD lifecycle / pipe / dup2
→ init/test tooling
→ process supervision
→ embedded Linux bring-up
→ shell/service data flow
```

Signal shutdown discipline：

```text
application lifecycle discipline
→ later service/daemon/threaded shutdown design
```

这里只建立 userspace foundation，不假装等于 kernel driver lifecycle。

## Scope Boundary

不正式进入 sockets/TCP/UDP/Unix socket、shared memory/message queues、select/poll/epoll、daemonization/systemd、realtime signals/signalfd/job control、pthread/mutex/condvar、binary framing/endian/serialization。`sigwait()` 最多 forward reference，不是 MUST。

## Sources

精确 source pins、license/provenance、current-upstream distinction、teaching question 与 version risk 见 [`SOURCE_LEDGER.md`](SOURCE_LEDGER.md)。
