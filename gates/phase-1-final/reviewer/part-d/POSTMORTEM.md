# Reviewer Postmortem — Part D (Interacting Process/FD + Concurrency Faults)

## 1. System Architecture & Context
The Part D service implements a streaming telemetry ingestion pipeline spanning two boundary layers:
1. **OS / Process Boundary (`src/main.c`):** A supervisor process creates an anonymous IPC pipe and forks a worker daemon. The supervisor streams telemetry items across the pipe, closes its write descriptor, and waits for worker completion.
2. **Concurrency / Thread Pipeline (`src/pipeline.c`, `src/queue.c`):** The worker daemon launches two internal POSIX threads:
   * `reader_thread`: Reads packets from the pipe file descriptor and pushes them into an internal bounded concurrent queue.
   * `consumer_thread`: Pops packets from the queue, aggregates running metrics, and commits them.

---

## 2. The Interacting Defect Pair

### Fault 1: Leaked Inherited Descriptor (Process / FD Lifecycle Family)
* **Location:** `src/main.c` (child branch post-`fork()`).
* **Mechanism:** When `fork()` is called, the child process inherits duplicate file descriptors for both ends of the pipe (`p_fd[0]` and `p_fd[1]`). The child uses `p_fd[0]` as its input stream, but fails to close `p_fd[1]` (the write end).
* **Kernel Consequence:** When the supervisor process finishes writing and closes its write end, the pipe's kernel file description still has an active open reference in the child (`p_fd[1]`). Therefore, the kernel never delivers `EOF (0)` to `read(p_fd[0])`. The reader thread blocks indefinitely in kernel `read()`.

### Fault 2: Predicate Misuse & Destroy-Before-Join Inversion (Concurrency Family)
* **Location:** `src/queue.c:queue_pop` and `src/pipeline.c:pipeline_stop`.
* **Mechanism:**
  1. `queue_pop` evaluates the wait predicate using an `if` statement rather than a canonical `while` loop:
     ```c
     if (q->count == 0 && !q->closed) pthread_cond_wait(&q->not_empty, &q->lock);
     ```
     This leaves the queue vulnerable to spurious wakeups and underflow.
  2. `pipeline_stop` destroys queue synchronization primitives (`queue_destroy(&pl->queue)`) **before** joining the reader and consumer threads (`pthread_join`):
     ```c
     queue_destroy(&pl->queue); // Mutex and condvar destroyed while consumer thread is active!
     pthread_join(pl->reader_thread, NULL);
     pthread_join(pl->consumer_thread, NULL);
     ```
* **Concurrency Consequence:** The consumer thread attempts to lock or unlock a destroyed mutex during its termination sequence, or `pthread_mutex_destroy` fails with `EBUSY`.

---

## 3. The Genuine Interaction

1. **Partial Fix 1 (Fixing only Process/FD):**
   If the learner adds `close(p_fd[1])` to the child process without fixing the concurrency lifecycle, the reader sees EOF and closes the queue, but `pipeline_stop()` destroys the mutex while the consumer is still draining. Under AddressSanitizer/TSan, this triggers an immediate `EBUSY` abort or use-after-destroy crash.
2. **Partial Fix 2 (Fixing only Concurrency):**
   If the learner fixes the queue while predicate and thread join ordering without closing `p_fd[1]`, the service still stalls indefinitely because `read()` in the reader thread never returns EOF.
3. **Integrated Solution:**
   Both boundaries must be resolved in unison to achieve clean termination.

---

## 4. Two Required Evidence Channels

* **Channel 1 (OS / Syscall / Descriptor Boundary):**
  * `/proc/<child_pid>/fd` audit reveals both `0` (or `p_fd[0]`) and `p_fd[1]` pointing to `pipe:[...]`.
  * `read()` remains blocked waiting for write closure.
* **Channel 2 (Thread / Concurrency Boundary):**
  * GDB `thread apply all bt` shows worker thread blocked waiting on queue or mutex.
  * ThreadSanitizer flags destruction order or data race between thread exit and `pthread_mutex_destroy`.

---

## 5. Reference Repair Summary
1. In `main.c`: Add `close(p_fd[1]);` immediately after `fork()` in the child process.
2. In `queue.c`: Change `if` to `while` predicate loop in `queue_pop`:
   ```c
   while (q->count == 0 && !q->closed) {
       pthread_cond_wait(&q->not_empty, &q->lock);
   }
   ```
3. In `pipeline.c`: Reorder `pipeline_stop`:
   ```c
   pthread_join(pl->reader_thread, NULL);
   pthread_join(pl->consumer_thread, NULL);
   queue_destroy(&pl->queue);
   ```
