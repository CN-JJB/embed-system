# Reviewer Postmortem — Variant B1 (Family B-MEM)

## Hidden Seed Specification
* **Component:** `variants/b1/engine.c:engine_push_event`
* **Defect:** `engine_push_event` takes ownership of the string pointer `payload` via shallow assignment (`ev->payload = payload;`) without duplicating the buffer. The caller allocates an ephemeral batch buffer on the heap and frees it when batch ingestion concludes. When `engine_query_summary` later reads `ev->payload[0]`, it triggers a `heap-use-after-free`.
* **Broken Contract:** Object Lifetime & Storage Duration contract. Pointers stored in a persistent window structure must own their buffers or duplicate them if the caller's allocation extent is ephemeral.

## Reference Repair
In `engine_push_event`:
```c
ev->payload = payload ? strdup(payload) : NULL;
```
In `engine_destroy`:
```c
for (size_t i = 0; i < win->count; i++) {
    free(win->events[i].payload);
}
```

## Evidence & Verification
* **Reproducing:** `./repro` aborts with `AddressSanitizer: heap-use-after-free on address ... READ of size 1`.
* **Fixing:** `solution.c` duplicates the payload and deallocates it in `engine_destroy`, running completely clean under AddressSanitizer across repeated iterations.
