# Module C — Linux Userspace

**Time box:** 80 min  
**Score:** 20 points  
**Mode:** AI-Free; Linux documentation allowed

## C1 — Process Pipeline (45 min, 12 pts)

Implement `starter/pipeline.c` so one parent launches exactly two children:

```text
parent
 ├── producer  --stdout--> pipe --stdin-->  filter
 └── filter
```

Required APIs/mechanisms:

- `pipe`
- `fork`
- `dup2`
- `exec`
- closing all unused FDs in **parent and both children**
- `waitpid` for both children
- propagation of failure as a non-zero parent exit status

Build fixtures and your pipeline:

```sh
make
./pipeline ./producer ./filter
```

Expected output:

```text
KEEP alpha
KEEP gamma
```

`filter` reads until EOF. If the parent accidentally keeps the pipe write end open, the filter should wait forever for EOF. Demonstrate that you understand this failure mode; do not “fix” it by adding a timeout to normal operation.

Submit a small FD table showing which process owns which pipe end immediately after `fork()` and which descriptors remain after `dup2()`/close.

## C2 — Linux Investigation (35 min, 8 pts)

Build and run:

```sh
./fd_zombie_lab
```

The program intentionally stops after creating a small number of children. Do **not** edit it first.

Use evidence from at least:

- `ps`
- `/proc/<pid>/fd` (or equivalent `/proc` inspection)
- `strace` from process start for the lifecycle syscalls. Attaching after the program reaches its final `pause()` can still inspect the current blocked state, but it cannot reconstruct earlier `pipe/fork/read` history; restart the fixture under `strace` when historical syscall evidence is needed.

Answer:

1. What process-lifecycle problem is visible?
2. What file-descriptor problem is visible?
3. Which system calls/FD numbers in `strace` support those conclusions?
4. Why can an inherited or leaked pipe write end prevent EOF in a reader?
5. Propose the smallest code fixes and explain where each `close()`/`waitpid()` belongs.

Terminate the lab process when done. Do not leave child/zombie test processes intentionally running.
