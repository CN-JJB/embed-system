# M08 Hint Ladder

## Challenge

**Hint 1 — fault domain only:** the four modes belong to memory lifetime, byte semantics, state mutation, and OS/file boundary.  
**Hint 2 — evidence source:** ASan; golden bytes; watchpoint; return/errno + strace.  
**Hint 3 — observation:** one pointer is used after free; one 32-bit value is assembled BE against an LE contract; one sequence field is overwritten; one open/read path reports failure.

## Gate

**Hint 1:** classify memory / bytes / FD / file before tool choice.  
**Hint 2:** ASan for invalid heap access; bytes for endian; `/proc` for current FD holders; errno + strace for file boundary.  
**Hint 3:** the FD fixture retains a write endpoint while waiting, so EOF cannot arrive.

Do not reveal root cause at Hint 1.
