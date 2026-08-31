# Reviewer Solution — P1-M02 Gate

## Short write

Seeded `copy_payload` 把任何 positive `testable_write()` 当成整个 read chunk 已写完。当 `LOG_COPY_WRITE_CAP=5` 时，其余 bytes 被直接丢弃。Fix 是 `write_all`：维护 `off`，直到 `off == len`，每次从 `buf + off` 写 `len - off`。

## Error-path ownership

`copy_payload` contract 是 borrowed FDs，却在 write failure 时 `close(out_fd)`；caller 随后 cleanup 同一 FD，形成 double-close/`EBADF` symptom。Helper 应只返回 failure，不改变 borrowed resource ownership；owner `copy_one` 统一 close。

## Leak

`copy_one` 成功 open input 后，output-open failure 直接 return，owned input 没 close。`--leak-demo` 重复该路径，因此 `/proc/<pid>/fd` 可看到累计 entries。Fix 在 return 前 close input，并保存/恢复 original output-open errno。

## Error propagation

cleanup 可能产生新的 errno。保存最初 failure，执行 cleanup，再显式恢复/报告原始 error，避免把 cleanup symptom 当 root cause。

## Regression

- `LOG_COPY_WRITE_CAP=1,5,32` 全部 `cmp` success；
- `/dev/full` 保留 write failure 且无 double-close；
- leak-demo 的 repeated output-open failure 不累计 input descriptors；
- ordinary success copy pass。
