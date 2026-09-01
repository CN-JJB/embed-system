# Shared Stats Invariant

## Objective
Protect a multi-field count+sum contract and take a coherent snapshot.

## Prerequisites
M09 mental model; basic C functions and return-value checking.

## Environment
Linux/POSIX pthreads; strict C17 flags; GCC/Clang equivalent permitted.

## Estimated Time
45 min.

## AI Mode
First pass **AI-Free**. Documentation lookup is allowed.

## Build
`cc -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror -pthread lab.c -o lab`

## Procedure
Inspect update and snapshot critical sections; verify no scalar is read outside the contract.

## Expected Observation
Snapshot corresponds to one mutex-protected state, not independently sampled scalars.

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
