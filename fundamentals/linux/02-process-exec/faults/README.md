# P1-M04 Fault Campaign — Process Lifecycle Failures

> **AI-Free first diagnosis.** Build: `make clean && make`.  
> Submit every fault as `Symptom → Hypotheses → Evidence → Root Cause → Fix → Regression`.

## F1 — Zombie: forgotten `waitpid`

```sh
./process_faults zombie
```

Fixture actively waits until `/proc/<child>/stat` becomes `Z` before checkpoint; no sleep-and-hope.

At checkpoint:

```sh
ps -o pid,ppid,stat,cmd -p <child>
```

Root cause is parent never reaps before checkpoint。Fix with targeted `waitpid` and regression that child `/proc` entry disappears after reap。

## F2 — Exec Failure Falls Through

```sh
./process_faults fallthrough
```

**VERIFIED symptom:** missing exec reports error, then child prints `BUG child continued caller logic ...` because helper returned. Fix failure path with `_exit` after reporting error；successful exec still must not return。

## F3 — Wrong Exit Status Handling

```sh
./process_faults status
```

Child `_exit(7)`; seeded parent prints raw status. **VERIFIED authoring output:** `BUG raw status reported as exit code: 1792` on this host。Do not memorize 1792; use `WIFEXITED` + `WEXITSTATUS` to obtain 7。

## F4 — Unexpected Inherited FD

```sh
./process_faults fd
```

Parent opens `fault.log` before fork; child execs `fd_probe` without closing it. **VERIFIED:** helper reports inherited fd open。

Current-depth fix: child explicitly closes descriptors that target image should not receive before exec。`O_CLOEXEC/FD_CLOEXEC` may be mentioned as SHOULD forward reference, but do not turn this into CLOEXEC engineering or pipe lab。

## Evidence expectations

- F1: `ps` + `/proc` state + source wait omission；
- F2: control-flow output + exec diagnostic；
- F3: source child code + wait macros regression；
- F4: `/proc/<pid>/fd` or helper `fcntl(F_GETFD)`-style existence evidence + source open/fork/exec ordering；
- `strace -f` SHOULD tie at least one fault to real syscalls on learner host。Authoring strace **UNVERIFIED**。
