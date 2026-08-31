# Reviewer Hints — M02

Do not expose before the learner records hypothesis + first evidence.

## Challenge `--limit`

- **Hint 1:** 先决定每轮最多应该 `read` 多少，而不是读完后再修剪。
- **Hint 2:** 用 `remaining = limit - copied`，前提是 invariant `copied <= limit`。
- **Hint 3:** `read(2)` / `write(2)` RETURN VALUE；`strtoumax` + `ERANGE`。

## Faults / Gate

- **Hint 1 — leak:** failure path 中“已经成功 open 的资源”仍然需要 owner cleanup。
- **Hint 2 — ownership:** helper parameter contract 写 borrowed 时，error path 也不能偷偷 close。
- **Hint 3 — short write:** 比较 requested count 与 actual returned count；remaining pointer 从哪里开始？
- **Hint 3 — evidence:** `/proc/<pid>/fd` 看 accumulation；strace 用 `%file,%desc` 收窄；保存最早 failure errno 再 cleanup。
