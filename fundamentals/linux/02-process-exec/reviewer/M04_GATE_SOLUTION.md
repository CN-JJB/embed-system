# M04 Gate — Reviewer Solution Notes

Reference fixed supervisor source: [`mini_supervisor_fixed.c`](mini_supervisor_fixed.c).

Expected mechanisms:

- child closes inherited supervisor log FD before exec；
- child exec failure prints diagnostic then `_exit(127)`；
- parent calls `waitpid` for both child PIDs；
- `WIFEXITED/WEXITSTATUS` (or signal macros) decode result；
- no zombie inspection window remains in fixed normal path。

Authoring regression **VERIFIED**:

```text
worker ... inherited=no
child ... exited code=7
child ... exited code=127
```

Missing executable diagnostic is expected. `strace -f` remains **UNVERIFIED** until target WSL because the authoring runtime lacks strace。
