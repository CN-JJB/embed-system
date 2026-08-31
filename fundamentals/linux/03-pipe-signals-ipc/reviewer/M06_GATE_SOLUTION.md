# P1-M06 Gate Reference Reasoning

The seeded hang has **multiple lifecycle causes**, not one magic line:

- the supervisor retains its pipe write end;
- the consumer retains a write-end descriptor across exec, so the process waiting for EOF is itself also a writer reference;
- the producer retains the original descriptor after `dup2` until exec/exit;
- second-fork failure abandons the already-created consumer;
- the handler performs allocator/stdio/application cleanup instead of recording intent.

The reference implementation closes both original endpoints in each exec child after the required `dup2`, closes both parent copies immediately after forks, reaps every created child, repairs the second-fork partial-success path, and leaves the signal handler with only `stop_requested = 1`.

The important proof is the before/after descriptor graph: after setup, **only producer FD 1 refers to the write endpoint** and **only consumer FD 0 refers to the read endpoint**. Once producer exits/closes its last write reference and buffered bytes drain, consumer can observe EOF.

Sanity checks used by the reviewer should include repeated normal completion and a SIGTERM run. `strace -f` remains a separate runtime evidence source and must not be invented when unavailable.
