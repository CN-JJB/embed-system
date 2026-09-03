# Reviewer Master Answer Key: Phase 1 Final Gate

> **CONFIDENTIAL:** Reviewer Reference Materials — Do NOT distribute to learners.

---

## Part A: Blank-Directory Build (`sifter`)

* **Golden Reference Directory:** `reviewer/part-a/reference/`
* **Core Modules:**
  * `main.c`: Parses `--input`, `--output`, `--filter`, `--stats`. Validates integer boundaries for `--filter` (`INT32_MIN` to `INT32_MAX`), manages owned vs borrowed descriptors, and invokes stream processing with caller-supplied callback and context.
  * `sifter.c` / `sifter.h`: Accepts caller callback `int (*sifter_record_cb)(const struct sifter_record *rec, void *ctx)` and `void *ctx`. Coordinates line buffering with exact 128-byte boundary, dispatches valid records to callback, and tracks summary statistics.
  * `parser.c` / `parser.h`: Strictly parses `<timestamp_ns> <sensor_id> <metric_val>\n`. Rejects negative unsigned values, rejects trailing non-whitespace garbage, enforces `UINT64_MAX`, sensor ID `0..255`, and metric `INT32_MIN..INT32_MAX`.
* **Validation Command:**
  ```bash
  cd reviewer/part-a && ./validate.sh
  ```
  Runs strict C17 build, file count check ($\ge 4$), functional processing, CLI range checks, comprehensive parser boundary suite (`test_boundaries.c`), callback decoupling test (`test_callback.c`), in-process descriptor lifecycle audit (`test_lifecycle.c`), ASan/UBSan/LSan safety checks, and Make dependency tracking.

---

## Part B: Unknown Bug Hidden Variant Seeds

### Variant B1 (Family B-MEM)
* **Hidden Seed:** `variants/b1/engine.c:engine_push_event` takes a shallow pointer to an ephemeral batch buffer without copying. When the batch buffer is deallocated, `engine_query_summary` triggers `heap-use-after-free` under AddressSanitizer.
* **Fix:** Duplicate string payload with `strdup()` and free in `engine_destroy()`.
* **Test:** `cd reviewer/part-b/b1 && ./test.sh`

### Variant B2 (Family B-FD)
* **Hidden Seed:** `variants/b2/spool.c:spool_rotate` opens a new descriptor for the rotated segment and reassigns `mgr->current_fd = new_fd` without calling `close(old_fd)`, leaking open file descriptions in `/proc/self/fd`.
* **Fix:** Close existing descriptor prior to handle reassignment.
* **Test:** `cd reviewer/part-b/b2 && ./test.sh`

### Variant B3 (Family B-CONC)
* **Hidden Seed:** `variants/b3/metrics.c:metrics_transfer` splits a composite balance update across two separate critical sections, dropping the lock between updating `pool_a` and `pool_b`. An auditor thread reading the snapshot observes an inconsistent total (`pool_a + pool_b != B3_TOTAL_BALANCE`).
* **Fix:** Hold `mt->lock` continuously across both updates in a single atomic critical section.
* **Test:** `cd reviewer/part-b/b3 && ./test.sh` (runs 100 cycles and ThreadSanitizer data-race check).

---

## Part C: ELF / Link / Binary Evidence

* **Task 1 (Symbols):** `internal_clamp` is LOCAL due to `static`; `compute_scaled_metric` is GLOBAL; `get_hardware_calibration_offset` is UND.
* **Task 2 (Relocations):** Relocation at call site to `get_hardware_calibration_offset`; static linker computes and patches relative PC offset.
* **Task 3 (Sections):** `g_firmware_tag` in `.rodata`; `g_initialized_config` in `.data`; `g_runtime_error_counter` in `.bss`; function in `.text`.
* **Task 4 (Compiler vs Linker):** `make failing-link` fails at link stage (`/usr/bin/ld: undefined reference`); resolved by passing `src/state.o`.
* **Task 5 (Disassembly):** `internal_clamp` lowered to `cmp`, conditional jumps, and return `ret`.
* **Verification Command:**
  ```bash
  cd reviewer/part-c && ./verify.sh
  ```

---

## Part D: Interacting Fault Pair

* **Fault 1 (Process / FD Lifecycle):** Child process post-fork fails to close inherited write end `p_fd[1]`, retaining an open write descriptor in the kernel and preventing `read()` on `p_fd[0]` from ever receiving EOF.
* **Fault 2 (Concurrency Lifecycle):** `pipeline_stop` fails to join `consumer_thread` (`pthread_join(consumer_thread)` omitted), causing the service to exit before queued items are drained (`processed_count != 50`).
* **Interaction:**
  - Fixing Fault 1 alone causes child to exit before consumer drains queue -> exit code 1.
  - Fixing Fault 2 alone leaves reader hanging on pipe EOF -> exit code 2 (watchdog).
  - Both fixed -> passes 50/50 cycles cleanly with exit code 0.
* **Regression Command:**
  ```bash
  cd reviewer/part-d && ./regression.sh
  ```
