# M04 Reviewer Hints

> Reviewer-only.

## Challenge

- Child branch should apply override, then exec; any code after exec is failure-only。
- Use `_exit` on child failure path。
- Parent waits exact child PID and decodes status macros。
- Reserve 127 limitation must be stated; do not reward hidden pipe/dup2 scope expansion。

## Gate hint ladder

1. Capture both child PIDs at deterministic zombie checkpoint。
2. Successful worker’s `SUPERVISOR_FD` should not survive exec in fixed version；at this depth close it explicitly in child before exec。
3. Failed exec child must terminate from failure branch rather than return into supervisor main。
4. Parent waits both children, then calls status decoder only on actual `waitpid` outputs。
5. Exact strace syscall spelling is host-dependent；grade lifecycle relation, not `fork` literal。
