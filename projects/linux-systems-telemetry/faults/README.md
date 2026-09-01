# M10 Fault Campaign
1. **Queue Race:** remove synchronization around one queue field. First reasoning evidence is the named queue invariant; TSan is supporting runtime evidence where available.
2. **Shutdown Hang:** set `closed` but omit broadcasts. Root cause: predicate changed but sleeping waiters were not prompted to re-evaluate it.
3. **FD Leak:** omit close of an owned path FD on an error path. Inspect ownership table and `/proc/<pid>/fd`; use strace only if installed.
4. **Bad Record Boundary:** truncated binary, overlong text, range error, or trailing token. First evidence is bytes/parser/bounds, not threading tools.

Do not fabricate race, deadlock, FD, PID, sanitizer, or trace output.
