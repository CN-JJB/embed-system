# Shared Statistics Contract Challenge

**AI-Free Challenge: Bounded Invariant & Snapshot Protection**

## Objective
Implement thread-safe shared statistics across concurrent worker threads without relying on global locks, atomics, or rwlocks.

Your implementation must protect the multi-field invariant:
1. `count == 0` if and only if `initialized == 0`.
2. Once at least one value is added, `initialized == 1` and `min <= max` holds at all times.
3. `sum` is the exact 64-bit sum of all successfully added values.
4. Adding a value must guard against 64-bit signed integer overflow or underflow (`INT64_MAX` / `INT64_MIN`); if an overflow would occur, reject the addition with `-1` without mutating any field.
5. `stats_snapshot` must capture an atomic view under lock and write to `*out` only upon complete success. If an error occurs (such as invalid arguments), `*out` must NOT be partially overwritten.
6. `stats_destroy` must cleanly destroy the internal mutex after all callers have finished and joined.

## Starter File
Edit `challenge/shared_stats.c` to complete the contract declared in `challenge/shared_stats.h`.

## Building and Testing
Build and run the challenge test harness:

```bash
make test-challenge-starter
```

Expected observation with the starter:
The build succeeds under strict flags (`-std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror -pthread`), but the test suite fails on the uncompleted contracts.

When your implementation is complete, all assertions in `test_challenge.c` will pass:

```bash
=== M09 Challenge Test Suite ===
test_invalid_args_and_canary... OK
test_first_value_initializes... OK
test_multiple_updates_coherent... OK
test_sum_overflow_policy... OK
test_concurrent_stress_and_invariant... OK
=== All Challenge Tests PASSED ===
```

## Non-Goals / Exclusions
- Do not use C11 atomics (`stdatomic.h`) or GCC atomic builtins.
- Do not use `pthread_rwlock_t`.
- Do not expose or read internal struct members directly outside the internal mutex.
