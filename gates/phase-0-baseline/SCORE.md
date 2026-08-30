# Scoring and Placement

## Score weights

| Module | Points |
|---|---:|
| A — System C | 15 |
| B — Compile / Link / ELF | 10 |
| C — Linux userspace | 20 |
| D — Debugging | 25 |
| E — Computer Systems | 15 |
| F — STM32 bare-metal | 15 |
| **Total** | **100** |

This preserves the approved v1.2 allocation by treating A+B as the original 25-point System C/toolchain domain.

## Pass rules

A Baseline pass requires **all** of the following:

- total score **>= 70/100**;
- A+B combined (System C + toolchain) **>= 17/25** (at least 65% after integer rounding);
- Debugging **>= 17/25**;
- no individual module below 50%: A >= 8/15, B >= 5/10, C >= 10/20, D >= 13/25, E >= 8/15, F >= 8/15;
- at least **3 of 4 Debugging faults** reach the actual root cause with evidence;
- scored tasks completed under the AI-Free rules.

A total score alone cannot compensate for unsafe gaps in C/toolchain or root-cause debugging.

## Placement levels

| Placement | Criteria | Action |
|---|---|---|
| **Fast Track** | >=85, all modules >=70%, Debugging root cause 4/4 | compress selected fundamentals while still completing missing evidence-based labs |
| **Normal** | passes all Gate rules, normally 70–84 | follow the normal roadmap |
| **Remediation Required** | total 60–69, or >=70 but one/more Gate conditions fail | targeted 2–4 week remediation, then re-test only failed domains plus Debug Gate if applicable |
| **Foundation Rebuild** | <60, or broad failure across three or more modules | rebuild foundations before entering the later main line |

### Debugging blocker

If the Debugging root-cause Gate fails (<3/4 true root causes), do **not** treat a high total as readiness for the Linux Driver main line. The learner first completes `fundamentals/debugging/foundations` remediation and a fresh debugging re-test.

## What scores mean

- A repaired program without explaining UB/lifetime/layout receives partial credit.
- A pipeline that prints expected text but leaks the write end and hangs waiting for EOF does not pass C1.
- A Debugging patch guessed by trial-and-error is not equivalent to evidence-backed root-cause isolation.
- STM32 answers receive credit for correct manual navigation and reasoning even without hardware, but fabricated board evidence is a zero for the affected evidence item.

Detailed item-level scoring is in `reviewer/RUBRIC.md`.
