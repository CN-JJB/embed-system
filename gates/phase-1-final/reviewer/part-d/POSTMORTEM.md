# Reviewer Postmortem — Part D (Interacting Process/FD + Concurrency Faults)

> **CONFIDENTIAL:** Reviewer Reference Material — Do NOT distribute to learners.

## 1. System Architecture & Context
The Part D service implements a streaming telemetry ingestion service spanning two boundary layers:
1. **OS / Process Boundary (`src/main.c`):** A supervisor process creates an anonymous IPC pipe and forks a worker daemon. The supervisor streams telemetry items across the pipe, closes its write descriptor, and waits for worker completion.
2. **Concurrency / Thread Pipeline (`src/pipeline.c`, `src/queue.c`):** The worker daemon launches two internal POSIX threads:
   * `reader_thread`: Reads packets from the pipe file descriptor and pushes them into an internal bounded concurrent queue.
   * `consumer_thread`: Dequeues packets, aggregates running metrics, and drains the pipeline upon shutdown.

---

## 2. The Interacting Defect Pair

### Defect 1: Leaked Inherited Descriptor (Process / FD Lifecycle Family)
* **Location:** `src/main.c` (child branch post-`fork()`).
* **Mechanism:** When `fork()` is called, the child process inherits duplicate file descriptors for both ends of the pipe (`p_fd[0]` and `p_fd[1]`). The child uses `p_fd[0]` as its input stream, but fails to close `p_fd[1]` (the write end).
* **Kernel Consequence:** When the supervisor process finishes writing and closes its write end, the pipe's kernel file description still has an active open reference in the child (`p_fd[1]`). Therefore, the kernel never delivers `EOF (0)` to `read(p_fd[0])`. The reader thread blocks indefinitely in kernel `read()`.

### Defect 2: Omitted Consumer Join & Incomplete Drain (Concurrency Family)
* **Location:** `src/pipeline.c:pipeline_stop`.
* **Mechanism:**
  `pipeline_stop` joins the `reader_thread`, but fails to join `consumer_thread`:
  ```c
  pthread_join(pl->reader_thread, NULL);
  /* pthread_join(pl->consumer_thread, NULL); <-- Omitted! */
  ```
* **Concurrency Consequence:** The consumer thread is abandoned mid-execution. `pipeline_stop` returns immediately to `main()`, where verification checks find that pending queue items were not fully processed (`processed_count < 50`), causing child failure.

---

## 3. Genuine Interaction & Residual Failure Proof

1. **Both Broken (Default Learner Fixture):**
   * Reader hangs waiting for pipe EOF that never arrives.
   * Service stalls indefinitely until the 3-second safety watchdog triggers (exit code 2).
2. **Partial Fix 1 (Process/FD Fixed Only — `partial_fd_fixed.c`):**
   * Child closes `p_fd[1]`. Reader sees EOF, closes queue, and joins.
   * Concurrency defect remains: `pipeline_stop` omits joining `consumer_thread`.
   * Result: Child verification checks `processed_count == 50`, finds undrained records, and exits with failure (exit code 1).
3. **Partial Fix 2 (Concurrency Fixed Only — `partial_conc_fixed.c`):**
   * Concurrency shutdown is fixed: `pipeline_stop` joins both reader and consumer.
   * Process/FD defect remains: Child leaves `p_fd[1]` open.
   * Result: Reader blocks indefinitely in `read()`, timing out under the watchdog (exit code 2).
4. **Integrated Reference Fix (`reference/`):**
   * Resolves both boundaries: child closes `p_fd[1]`, and `pipeline_stop` joins both reader and consumer.
   * Result: Service drains all 50 records cleanly, outputs `processed_count == 50`, and exits cleanly (exit code 0).

---

## 4. Two Required Evidence Channels

* **Channel 1 (OS / Syscall / Descriptor Boundary):**
  * `/proc/<child_pid>/fd` audit reveals both `p_fd[0]` and `p_fd[1]` open, pointing to `pipe:[...]`.
  * Verifying closure of `p_fd[1]` in `/proc` confirms that only `p_fd[0]` remains, restoring kernel EOF semantics.
* **Channel 2 (Thread / Concurrency Boundary):**
  * GDB thread inspection (`thread apply all bt`) reveals active consumer thread during shutdown.
  * Verifying consumer thread join proves that all queued items are processed before `pipeline_stop` returns.
