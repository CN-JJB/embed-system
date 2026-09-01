# M08 Hint Ladder

## Challenge

**Hint 1 — fault domain only:** the four modes belong to memory lifetime, byte semantics, state mutation, and OS/file boundary.  
**Hint 2 — evidence family:** ASan can answer invalid heap-access questions; golden bytes answer byte-order semantics; a watchpoint answers who writes a field; return/errno answers the immediate file API boundary before tracing.  
**Hint 3 — observation:** a retained pointer outlives its allocation; one 32-bit value is assembled against the declared LE order; `sequence` changes after valid state creation; the file path can fail at open or reach EOF before the required bytes arrive.

## Gate

**Hint 1 — fault domain only:** classify memory / bytes / FD lifecycle / file boundary before choosing a tool.  
**Hint 2 — evidence family:** ASan for invalid heap access; declared bytes + golden decode for endian; an FD-holder snapshot for EOF ownership; return/errno for the file boundary, with strace only as supplementary evidence.  
**Hint 3 — observation:** a heap pointer is retained beyond its valid lifetime; the byte decoder disagrees with the LE contract; a pipe writer remains open while the reader waits for EOF; a missing path produces an OS-level open failure.

Do not reveal the root cause at Hint 1. Even Hint 3 should point to the observation the learner must explain, not provide the repaired code.
