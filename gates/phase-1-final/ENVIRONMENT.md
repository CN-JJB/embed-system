# Phase 1 Final Gate: Environment Verification Record

Record your host development environment before commencing the assessment.

```bash
# Capture commands:
uname -a
gcc --version | head -n1
make --version | head -n1
gdb --version | head -n1 2>/dev/null || echo "GDB: UNAVAILABLE"
strace --version | head -n1 2>/dev/null || echo "strace: UNAVAILABLE"
```

---

## Host Toolchain Record (Fill In Upon Start)

* **Operating System / Kernel:** `______________________________`
* **C Compiler:** `______________________________`
* **Build System:** `______________________________`
* **Debugger:** `AVAILABLE / UNAVAILABLE — version: __________________`
* **Syscall Tracing:** `AVAILABLE / UNAVAILABLE — version: ______________`
* **Process Filesystem:** `/proc AVAILABLE / UNAVAILABLE`
* **Sanitizers:**
  * AddressSanitizer (ASan): `VERIFIED / PARTIALLY VERIFIED / UNVERIFIED`
  * UndefinedBehaviorSanitizer (UBSan): `VERIFIED / PARTIALLY VERIFIED / UNVERIFIED`
  * LeakSanitizer (LSan): `VERIFIED / PARTIALLY VERIFIED / UNVERIFIED`
  * ThreadSanitizer (TSan): `VERIFIED / PARTIALLY VERIFIED / UNVERIFIED`

---

## Tool Availability Status Policy

* `VERIFIED`: Tool is installed and executed successfully on the host environment.
* `PARTIALLY VERIFIED`: Tool runs with specific flags or execution wrappers (e.g. `setarch x86_64 -R make tsan`).
* `UNVERIFIED`: Tool is not installed or not supported (e.g. `strace` in container/minimal VM). Use an approved equivalent evidence channel.

### Approved Equivalent Evidence Channels
1. If `strace` is UNAVAILABLE:
   * Perform manual directory audits of `/proc/<pid>/fd/`.
   * Log explicit system call return values and `errno` values directly in test harnesses.
2. If `GDB` is UNAVAILABLE:
   * Analyze crash stack traces via AddressSanitizer / ThreadSanitizer.
   * Inspect `/proc/<pid>/status` and `/proc/<pid>/wchan` for thread execution states.
