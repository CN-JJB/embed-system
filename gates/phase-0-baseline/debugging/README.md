# Module D — Debugging

**Time box:** 105 min  
**Score:** 25 points  
**Mode:** AI-Free; tool/documentation lookup allowed

This is the most important module. A successful patch without a defensible evidence chain receives limited credit.

For **each fault**, submit:

```text
Symptom:
Initial hypotheses:
Evidence:
Experiment:
Hypotheses rejected:
Root cause:
Fix:
Regression test:
```

## D1 — Segmentation fault (20 min, 5 pts)

Program: `fault_seg.c`

Use GDB. At minimum capture a backtrace and inspect the frame/locals/pointer that caused the invalid access. Explain why the crashing line is a symptom location or root-cause location.

## D2 — Delayed memory corruption (30 min, 7 pts)

Program: `fault_corruption.c`

The first visible failure is later than the write that corrupts state. Find the **write that first makes the program wrong**, not only the later validation failure. GDB watchpoints are allowed. Sanitizers are allowed, but a sanitizer not reporting this particular subobject overwrite does not prove the code is valid.

## D3 — Race / synchronization-like bug (35 min, 8 pts)

Program: `fault_race.c`

The final count may vary between runs. Prove or strongly evidence the concurrency defect. Repeated runs and ThreadSanitizer are allowed if supported locally.

Critical rule:

> Adding a sleep, increasing a delay, changing a timeout, or reducing thread count until the failure disappears is **not** a root-cause fix.

Your fix must establish a valid synchronization/atomicity rule and your regression must exercise the original concurrency condition.

## D4 — Build/link failure (20 min, 5 pts)

Files: `fault_link_main.c`, `fault_link_provider.c`

The provider object is present in the link command, yet the required symbol is unresolved. Use `nm`/`readelf` as evidence before editing. Explain the symbol binding/linkage problem, repair it, and show a successful link/run.

## Build

```sh
make
make fault-link       # expected to fail before D4 repair
```
