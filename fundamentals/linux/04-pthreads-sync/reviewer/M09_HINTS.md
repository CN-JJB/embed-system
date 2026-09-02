# M09 Hint Ladder
Use only the next level requested.

## F1/F2
1. **Fault domain:** inspect whether a multi-step shared-state contract can change concurrently.
2. **Evidence family:** invariant table + TSan for conflicting access where supported.
3. **Concrete observation:** identify the shared member/check whose access is outside the mutex-protected critical section.

## F3
1. **Fault domain:** waiter correctness after a wakeup.
2. **Evidence family:** predicate trace: `(count, closed)` before wait and after wake.
3. **Concrete observation:** wakeup does not guarantee data exists; re-check `count==0 && !closed` in `while`.

## F4/F5
1. **Fault domain:** lifetime or lock acquisition contract.
2. **Evidence family:** join/lifetime timeline; controlled ERRORCHECK return or minimal thread backtraces when GDB exists.
3. **Concrete observation:** context expires before use, or the same thread attempts a diagnostic self-lock / lock ordering creates a cycle.
