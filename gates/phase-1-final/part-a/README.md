# Part A — Blank-Directory Build (30%)

## 1. Objective
Starting in a completely empty working directory with **zero starter code or templates**, architect, implement, test, and package a self-contained, robust Linux C systems utility named `sifter`.

---

## 2. Functional Requirements: Bounded Record Log Sifter (`sifter`)

The `sifter` utility reads structured sensor stream records, validates syntax and numeric boundaries, filters records meeting the specified metric threshold, and outputs matching records and summary statistics.

### 2.1 Command-Line Interface
```bash
./sifter [--input PATH|-] [--filter THRESHOLD] [--output PATH|-] [--stats]
```
* `--input PATH|-`: Path to input file, or `-` (or omitted) for standard input (`stdin`). Opened with `O_RDONLY | O_CLOEXEC`.
* `--output PATH|-`: Path to output file, or `-` (or omitted) for standard output (`stdout`). Opened with `O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC`, mode `0644`.
* `--filter THRESHOLD`: Integer threshold (`int32_t`). Only records with `metric_val >= THRESHOLD` are emitted to output. Default threshold: `0`.
* `--stats`: When asserted, emits a summary line to standard error (`stderr`) upon completion:
  `[sifter] total=<N> valid=<N> filtered=<N> errors=<N>`

### 2.2 Record Syntax & Validation Rules
* Stream format: text lines formatted as:
  `<timestamp_ns:uint64> <sensor_id:uint8> <metric_val:int32>\n`
* Maximum line length: **128 bytes** (including newline). Any line exceeding 128 bytes must be safely rejected as an error without memory corruption or buffer overflow.
* Range validation:
  * `timestamp_ns`: valid 64-bit unsigned integer (`0` to `UINT64_MAX`).
  * `sensor_id`: valid 8-bit unsigned integer (`0` to `255`).
  * `metric_val`: valid 32-bit signed integer (`INT32_MIN` to `INT32_MAX`). Reject arithmetic overflow.
* Lines with syntax errors or out-of-range values increment the error count and are skipped.

### 2.3 Resource Ownership & File Descriptor Contracts
* **Borrowed vs Owned File Descriptors:**
  * When reading from `stdin` or writing to `stdout`, descriptors `STDIN_FILENO` (`0`) and `STDOUT_FILENO` (`1`) are **borrowed**. The program must **never** close them.
  * When a file path is provided, the descriptor is **owned** by the application. It must be explicitly closed on **every** exit path (including early error returns).
* **Memory Ownership:**
  * If dynamic allocation is used, maintain a strict ownership contract. All allocated blocks must be freed before termination.
* **Error Boundaries & Partial I/O:**
  * Slow system calls (`read`, `write`) must handle `EINTR` by retrying.
  * Writes must loop until all bytes are written to handle partial writes.

### 2.4 Architecture & Module Split Contract
The implementation must consist of **at least four source/header files** with a clean module separation:
1. `main.c`: CLI argument parsing, descriptor lifecycle management, and program entry point.
2. `sifter.c` / `sifter.h`: Core processing loop, stream coordination, and callback dispatch.
3. `parser.c` / `parser.h`: Line parsing, schema validation, and range checks.
4. **Callback Interface:** Record processing must decouple ingestion from handling via a callback function and context pointer:
   ```c
   typedef int (*sifter_record_cb)(const struct sifter_record *rec, void *ctx);

   int sifter_process_stream(int in_fd, sifter_record_cb cb, void *ctx,
                             struct sifter_stats *stats);
   ```

### 2.5 Build System Contract
Provide a self-contained GNU `Makefile` supporting:
* Strict compiler flags: `-std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror`.
* Separate sanitizer target `make san`: builds with `-fsanitize=address,undefined -fno-omit-frame-pointer`.
* Targets: `all`, `test`, `san`, `clean`.
* Correct header dependency tracking: modifying a `.h` header must trigger recompilation of dependent `.c` files.

---

## 3. Input Fixtures
Sample input fixtures are provided in `fixtures/`:
* `fixtures/valid.txt`: Well-formed records.
* `fixtures/invalid.txt`: Mixed invalid records (length violations, bad syntax, overflow).
* `fixtures/empty.txt`: Empty 0-byte stream.

---

## 4. Hard Pass Criteria for Part A
* Score $\ge 18 / 30$ (60%).
* **Zero Unexplained Resource Leaks:**
  * Clean execution under AddressSanitizer with `detect_leaks=1` on valid, invalid, and empty inputs.
  * Independent in-process `/proc/self/fd` lifecycle audit showing owned descriptor counts return to baseline before the application lifecycle helper returns on success and tested failure paths.
