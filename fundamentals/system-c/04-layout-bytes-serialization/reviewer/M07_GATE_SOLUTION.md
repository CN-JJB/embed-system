# M07 Gate Solution / Reasoning

Require these root causes:

1. raw `memcpy(struct)` makes host layout an undeclared wire contract;
2. flags use opposite byte order;
3. value bytes are read before length validation;
4. destination is mutated before parse success;
5. packed storage does not solve endian, bounds, versioning, or portable object-access concerns.

`boundary_audit_fixed.c` uses explicit offsets, prechecks, local-temporary decode, and deterministic regressions. `sizeof/offsetof` remain host diagnostics only.
