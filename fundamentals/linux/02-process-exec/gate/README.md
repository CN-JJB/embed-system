# P1-M04 Gate — Mini Process Supervisor Investigation

> **AI-Free. Official Linux man-pages, `/proc`, `ps`, and strace documentation allowed.**  
> Do not open `../reviewer/` before submission.

## Objective

Diagnose and repair a陌生 mini supervisor containing four process-boundary faults：

- child exec failure falls through；
- zombies；
- raw wait-status decode bug；
- unexpected inherited log FD。

不能只“加一个 `wait()` 然后说好了”。必须形成 process evidence chain。

## Prerequisites

M04 Labs/Faults；M02 FD mental model；M03 executable/ELF model。

## Environment

Linux/WSL；GCC；`ps`; `/proc`; **`strace -f` required for learner Gate**。

## Estimated Time

70–90 min。

## AI Mode

AI-Free；official documentation allowed。

## Build

```sh
make clean && make
./mini_supervisor
```

Fixture only opens inspection window after both children are confirmed `Z` via `/proc`, so zombie observation is deterministic rather than timing luck。

## Procedure

### Station A — process tree / zombie evidence

At checkpoint, use printed PIDs:

```sh
ps -o pid,ppid,stat,cmd -p <parent>,<good>,<missing>
grep -E '^(Name|State|Pid|PPid):' /proc/<good>/status
grep -E '^(Name|State|Pid|PPid):' /proc/<missing>/status
```

Explain why both children can be zombies although they are no longer running user code。

### Station B — inherited FD

`worker_image` reports whether `SUPERVISOR_FD` is still open after exec and writes a line to it。Inspect parent/child FD evidence while possible：

```sh
ls -l /proc/<pid>/fd
cat supervisor.log
```

Root cause must refer to open-before-fork + inherited FD + no close-before-exec；do not introduce pipe/dup2。

### Station C — exec failure control flow

Missing path is intentional。Explain why failed child must not `return` into supervisor caller logic；fix with `_exit(reserved_code)` after diagnostic。

### Station D — wait status

Use `waitpid` for both children and decode with correct macros. Good worker is designed to exit 7；missing exec path uses reserved 127 in this Gate contract。

### Station E — `strace -f`

Run fresh after source inspection/fix：

```sh
strace -f -o gate.trace ./mini_supervisor
```

Provide trace evidence for process creation, failed/successful exec, wait-related syscall, and exits。Exact syscall names may vary; explain source concept ↔ observed syscall relation。

### Station F — regression

Pass requires：

- no zombies left by supervisor after it finishes normal control flow；
- good child status decoded as 7；
- missing exec failure reported distinctly per Gate’s reserved 127 contract；
- worker reports supervisor log FD **not inherited/open** after successful exec；
- no parent-like child fallthrough output；
- `strace -f` timeline consistent with source fix。

## Expected Observation

Seeded authoring run **VERIFIED** at checkpoint：both child states were `Z`; successful worker printed `inherited=yes` and `supervisor.log` contained a child write；missing exec child emitted exec failure then fell into supervisor control flow。Exact PIDs/FD numbers not fixed。

## Actual Verification Status

- Seeded strict build: **VERIFIED**。
- Deterministic two-zombie checkpoint: **VERIFIED** with `ps`/`/proc` in authoring runtime。
- inherited FD symptom: **VERIFIED** (`worker_image ... inherited=yes`, log write observed)。
- reviewer fixed build/run: **VERIFIED**; good child reports inherited=no, statuses 7/127 decoded。
- `strace -f` Gate evidence: **UNVERIFIED** because strace is not installed in authoring runtime。Learner/Leader must execute before post-review VERIFIED promotion。

## Questions

1. zombie problem与 exec-failure fallthrough 是同一个 root cause 吗？
2. 为什么 FD inheritance 是 fork fact，而“应该让 child 保留这个 FD”是 design decision？
3. `waitpid` raw status 为什么不是 7？
4. trace 若显示 clone-like syscall，不显示 literal fork，是否推翻 source reasoning？

## Failure Modes

只 wait one child；把 raw status直接 `%d`; 删除 worker env check 以“修复”FD symptom；把 missing executable改成存在路径从而绕过 fault；使用 pipe/dup2/system/popen 超出本模块范围。

## Debug Strategy

`ps/process state → /proc FDs → source fork/exec path → wait status macros → strace lifecycle → regression`。每个 fix都要有 before/after evidence。

## Challenge

写 6–8 行 postmortem，明确区分：process creation bug、program-image replacement failure、resource inheritance bug、parent reap/status bug。

## Cleanup

```sh
make clean
rm -f gate.trace supervisor.log
```

## Sources

Chapter `SOURCE_LEDGER.md`。
