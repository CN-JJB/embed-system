# Part D — Process / FD / Concurrency Interacting Debugging (25%)

## 1. Objective
Diagnose and repair a complex, interacting defect spanning the operating system process/descriptor boundary and internal multithreaded synchronization.

---

## 2. System Architecture
The system consists of a concurrent streaming telemetry service:
* **Supervisor Process (`main.c`):** Creates an IPC pipe, launches a worker child process, streams telemetry packets across the pipe boundary, closes transmission, and coordinates shutdown.
* **Worker Process:** Hosts a multithreaded ingest pipeline:
  * **Reader Thread:** Reads packets from the input descriptor and enqueues them into a bounded concurrent ring-buffer queue.
  * **Consumer Thread:** Dequeues packets, processes metrics, and drains the pipeline upon shutdown.

---

## 3. The Observed Symptom
When executing `./repro`, the service stalls indefinitely during shutdown under streaming workloads:
```bash
make repro
./repro
```
The harness includes a 3-second watchdog timer to safely terminate the stall if shutdown fails to complete.

---

## 4. Assessment Requirements

### 4.1 Two Required Independent Evidence Channels
You must employ and submit concrete evidence from **at least two independent diagnostic channels**:
* **Channel 1 (OS / Syscall / Descriptor Boundary):** `/proc/<pid>/fd` runtime descriptor inspection, system call return logs, or kernel stream state observation.
* **Channel 2 (Thread / Concurrency State):** ThreadSanitizer runtime report, GDB thread state analysis (`thread apply all bt`), or mutex/condvar coordination logs.

### 4.2 Interacting Failure Analysis
* Identify the two interacting faults across the OS and concurrency boundaries.
* Explain why fixing only one fault leaves residual failures or causes regression crashes.
* Submit an integrated repair resolving both boundaries cleanly.

---

## 5. Hard Pass Criteria for Part D
* Score $\ge 15 / 25$ (60%).
* **Runtime Root-Cause Proof:** Submit runtime trace evidence proving that:
  1. The OS/process stream lifecycle boundary cleanly terminates and closes all descriptors upon completion.
  2. The multithreaded queue drains cleanly, worker threads join promptly, and mutex/condvar objects are destroyed without error.
  3. The regression test passes across repeated consecutive cycles with zero deadlocks and zero resource leaks.
