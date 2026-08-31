# P1-M05 Fault Campaign — Ownership / Callback Contracts

> First diagnosis **AI-Free**. Use the full Symptom → Hypotheses → Evidence → Root Cause → Fix → Regression chain.

## Build

```sh
make clean && make
make san
```

## F1 — Borrowed pointer freed by callee

```sh
./ownership_faults_san borrowed-free
```

Root cause: **callee violated borrowed ownership contract**. ASan UAF is supporting evidence after owner later accesses its object.

## F2 — Dangling callback context

```sh
./ownership_faults_san dangling-ctx
```

Context object is freed before later callback-like use. Root cause is ctx lifetime not covering invocation.

## F3 — Broken `T **` failure contract

```sh
./ownership_faults_san broken-out
```

Function publishes `*out` before it knows construction succeeds, then frees it on failure. Caller sees a non-null dangling output and cannot infer cleanup ownership coherently.

## F4 — Callback retains forbidden borrowed record

```sh
./ownership_faults retain
```

This run can finish without sanitizer diagnostics because the retained pointer is still within lifetime during this immediate observation. **The contract is already violated.** This is the required semantic ownership fault sanitizer may not automatically identify.

## Actual Verification Status

- strict build: **VERIFIED**;
- ASan F1 borrowed-free UAF: **VERIFIED**;
- ASan F2 dangling ctx UAF: **VERIFIED**;
- ASan F3 dangling output dereference: **VERIFIED**;
- F4 normal run is silent while semantic retain violation exists: **VERIFIED** as contract observation; sanitizer silence is not proof of correctness.

## Cleanup

```sh
make clean
```

Sources: chapter ledger.
