# Condition Variable Predicate

## Objective
Use a fixed-capacity queue with one producer/consumer, predicate while-loops, close and empty termination.

## Prerequisites
M09 mental model; basic C functions and return-value checking.

## Environment
Linux/POSIX pthreads; strict C17 flags; GCC/Clang equivalent permitted.

## Estimated Time
60 min.

## AI Mode
First pass **AI-Free**. Documentation lookup is allowed.

## Build
`cc -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror -pthread lab.c -o lab`

## Procedure
Trace count/closed predicates, then close, wake, join, destroy in order.

## Expected Observation
Consumer drains accepted records then exits on closed && empty.

## Actual Verification Status
**VERIFIED** for strict compilation in the authoring environment when included by `make` in this module; schedule-sensitive outcomes are not golden evidence.

## Questions
Name the shared state, its owner/lifetime, the invariant, and the predicate (if any). What evidence would falsify your first hypothesis?

## Failure Modes
Context lifetime expiry, unchecked pthread return values, racing reads, `if` instead of `while`, close without wake, or destroying synchronization before join.

## Debug Strategy
Write 3–5 hypotheses before tools. Prefer invariant/predicate inspection; use TSan for race evidence where available and minimal GDB thread commands only when installed.

## Challenge
Change one input/schedule pressure without changing the invariant and re-run the regression.

## Cleanup
Join live workers before destroying synchronization objects; remove generated binaries.

## Sources
See `../../SOURCE_LEDGER.md`.
