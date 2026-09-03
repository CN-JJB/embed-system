# Reviewer Master Answer Key: Phase 1 Final Gate

> **CONFIDENTIAL:** Reviewer Reference Materials — Do NOT distribute to learners.

---

## Part A: Blank-Directory Build (`sifter`)

* **Golden Reference Directory:** `reviewer/part-a/reference/`
* **Core Modules:**
  * `main.c`: Parses `--input`, `--output`, `--filter`, `--stats`. Opens files with `O_CLOEXEC`, preserves borrowed `0`/`1`, manages lifecycle.
  * `sifter.c` / `sifter.h`: Reads input stream, parses lines, triggers callback with `struct emit_ctx`, writes filtered records.
  * `parser.c` / `parser.h`: Validates length $\le 128$ bytes, parses `uint64_t`, `uint8_t`, `int32_t` with strict range checks.
* **Validation Command:**
  ```bash
  cd reviewer/part-a && ./validate.sh
  ```
  Validates strict build, file count $\ge 4$, functional filtering, ASan/UBSan leak-free execution, `/proc/self/fd` audit, and header rebuild dependency.

---

## Part B: Unknown Bug Hidden Variant Seeds

### Variant B1 (Family B-MEM)
* **Hidden Seed:** `variants/b1/engine.c:engine_push_event` assigns `ev->payload = payload;` without copying ephemeral batch buffer, causing `heap-use-after-free` in `engine_query_summary`.
* **Fix:** Duplicate string with `strdup()` and free in `engine_destroy()`.
* **Test:** `cd reviewer/part-b/b1 && ./test.sh`

### Variant B2 (Family B-FD)
* **Hidden Seed:** `variants/b2/spool.c:spool_rotate` reassigns `mgr->current_fd = new_fd` without calling `close(mgr->current_fd)`, leaking descriptors into `/proc/self/fd`.
* **Fix:** Close old descriptor before assigning `new_fd`.
* **Test:** `cd reviewer/part-b/b2 && ./test.sh`

### Variant B3 (Family B-CONC)
* **Hidden Seed:** `variants/b3/metrics.c:metrics_transfer` drops lock mid-transfer, exposing inconsistent state (`pool_a + pool_b != TOTAL`).
* **Fix:** Hold lock across both balance updates in a single critical section.
* **Test:** `cd reviewer/part-b/b3 && ./test.sh`

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

* **Fault 1 (Process / FD):** Child process post-fork fails to close inherited write end `p_fd[1]`, causing `read()` on `p_fd[0]` to hang indefinitely without EOF.
* **Fault 2 (Concurrency):** `pipeline_stop` destroys queue mutex/condvar before joining worker threads (`pthread_join`), and `queue_pop` uses `if` instead of `while`.
* **Interaction:** Fixing one alone leaves residual failure or crash; both must be fixed together.
* **Regression Command:**
  ```bash
  cd reviewer/part-d && ./regression.sh
  ```
