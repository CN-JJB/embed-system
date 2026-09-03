# Reviewer Postmortem — Variant B3 (Family B-CONC)

## Hidden Seed Specification
* **Component:** `variants/b3/metrics.c:metrics_transfer`
* **Defect:** `metrics_transfer` splits an atomic transfer across two disjoint critical sections: it acquires `mt->lock`, decrements `mt->pool_a`, and releases the lock, before re-acquiring the lock to increment `mt->pool_b`. Under concurrent execution, an auditor reading `pool_a` and `pool_b` observes intermediate states where `pool_a + pool_b != B3_TOTAL_BALANCE`.
* **Broken Contract:** Multi-field Invariant & Critical Section Atomicity. A mutex protects a composite invariant across multiple related fields (`pool_a + pool_b == CONSTANT`). The lock must be held continuously until all fields participating in the invariant are updated.

## Reference Repair
In `metrics_transfer`:
Perform the transfer atomically in a single critical section:
```c
void metrics_transfer(struct metrics_tracker *mt, int64_t amount) {
    pthread_mutex_lock(&mt->lock);
    mt->pool_a -= amount;
    mt->pool_b += amount;
    pthread_mutex_unlock(&mt->lock);
}
```

## Evidence & Verification
* **Reproducing:** `./repro` detects `pool_a + pool_b != 1000000` within milliseconds.
* **Fixing:** Holding the lock across both updates preserves the balance invariant, passing 100 consecutive cycles without a single anomaly.
