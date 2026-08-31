# P1-M07 + P1-M08 Implementation & Verification Notes

> Role: Tutorial Author + Lab Designer + Technical Researcher + Code Implementer  
> Checked / executed: **2026-08-31** (America/Los_Angeles)  
> Canonical base at implementation start: `main` @ **311471afd005248de273b79e51269a596e57d1a4**  
> Implementation branch: `tutorial/p1-m07-m08`  
> Editorial authority: none; Leader review remains required.

## Start-state recheck

GitHub was re-read before implementation rather than trusting the handoff:

- repository default/canonical branch: `main`;
- latest `main` SHA at start: **311471afd005248de273b79e51269a596e57d1a4**;
- that commit is the merge of P1-M05/M06 PR #6;
- open PRs at start: **0**;
- canonical P1-M01 through P1-M06 are present;
- `roadmap/phase-1-foundations.md`, the Phase 1 research design, editorial policies, and the M05/M06 implementation style were re-read.

The implementation branch was created directly from canonical `main`, not stacked on `tutorial/p1-m05-m06`.

## Canonical scope and learner load

The prompt suggested 5.5–6 h per module only if canonical design lacked a more precise split. The repository roadmap does provide one, so this batch preserves it:

- P1-M07: **4.5 h MUST**;
- P1-M08: **5 h MUST**;
- combined: **9.5 h MUST**;
- combined REQUIRED external reading target: roughly **1.8–2.1 h**.

No M09 pthread/mutex/race curriculum and no M10 full telemetry service were implemented.

## Deliverables

```text
fundamentals/system-c/04-layout-bytes-serialization/
  README.md
  SOURCE_LEDGER.md
  diagrams/
  labs/01-layout-audit/
  labs/02-object-bytes/
  labs/03-field-reordering/
  labs/04-explicit-codec/
  labs/05-raw-struct-trap/
  challenge/
  faults/
  gate/
  reviewer/

debugging/01-evidence-selection/
  README.md
  SOURCE_LEDGER.md
  diagrams/
  labs/01-gdb-state/
  labs/02-watchpoint/
  labs/03-asan-report/
  labs/04-ubsan/
  labs/05-strace-errno/
  labs/06-multiprocess-evidence/
  labs/07-tool-selection/
  challenge/
  faults/
  gate/
  integration/corrupted-telemetry/
  reviewer/
```

## Authoring / verification environment

Actual executable verification environment:

```text
Linux localhost 6.18.35 #1 SMP Fri Aug 21 00:36:21 UTC 2026 x86_64 GNU/Linux
GCC 14.2.0 (Debian 14.2.0-19)
GNU binutils / ld 2.44
GNU Make 4.4.1
GDB: NOT INSTALLED
strace: NOT INSTALLED
od: /usr/bin/od
xxd: NOT INSTALLED
hexdump: NOT INSTALLED
AddressSanitizer: available / executed
UndefinedBehaviorSanitizer: available / executed
/proc: available / executed
```

No GDB or strace transcript is claimed. No internet transcript is substituted for missing runtime evidence.

## Strict-build sweep

After fixture corrections, a full tree sweep executed **20 Makefile `all` targets** with the module strict flags. Result: **20/20 passed**.

Intentional runtime faults remain warning-clean under their documented build target; sanitizer variants use narrow instrumentation flags instead of globally disabling warnings.

## Verification record — M07

| Object | Evidence actually executed | Status |
|---|---|---|
| Lab 01 Layout Audit | strict build; `sizeof/_Alignof/offsetof`; authoring host sample A size 12, reordered variants 8; array stride 12 | **VERIFIED** |
| Lab 02 Object Bytes | strict build; `0x11223344` observed as `44 33 22 11` on authoring host | **VERIFIED** host observation; explicitly non-golden |
| Lab 03 Field Reordering | strict build; size/offset comparison | **VERIFIED** |
| Lab 04 Explicit Codec | strict build; 12-byte LE golden vector + round trip | **VERIFIED** |
| Lab 05 Raw-Struct Trap | wrote `raw.bin` and `wire.bin`; `od -An -tx1 -v` compared both | **VERIFIED** |
| Raw/wire equality on current host | both observed as `01 02 34 12 78 56 34 12 ef cd ab 90` | **VERIFIED** coincidence; explicitly **not** portability proof |
| Challenge starter | strict build; seeded `ENOSYS` causes tests to fail as intended | **VERIFIED** |
| Challenge reviewer | zero/non-palindromic/signed-edge/invalid-version/short/unchanged-output regressions | **VERIFIED** |
| Fault F1 raw object/wire assumption | semantic path + object-size evidence | **VERIFIED** |
| Fault F2 host-endian write | current LE host bytes match LE golden | **PARTIALLY VERIFIED** — no cross-endian runtime |
| Fault F3 unaligned typed dereference | UBSan alignment diagnostic | **VERIFIED** |
| Fault F4 short input | ASan heap-buffer-overflow | **VERIFIED** |
| Fault F5 partial output | before/after state shows failure publication | **VERIFIED** |
| Gate seeded normal | strict build; wrong-endian/raw-copy behavior observed | **VERIFIED** |
| Gate seeded short | ASan stack-buffer-overflow | **VERIFIED** |
| Gate reviewer | golden/short/invalid/output-state regressions | **VERIFIED** |

### M07 golden vectors

Protocol bytes are deterministic and intentionally fixed. The challenge includes:

- zero payload fields;
- non-palindromic multi-byte values;
- signed edge `INT32_MIN`;
- `UINT16_MAX` / `UINT32_MAX`;
- invalid version;
- short input;
- unchanged output on decode failure.

The reference requires 8-bit octets and uses exact-width integer types. Signed `int32_t` representation is moved with `memcpy`, then encoded explicitly; no incompatible pointer-punning is used.

## Verification record — M08

| Object | Evidence actually executed | Status |
|---|---|---|
| Lab 01 GDB State | strict build; deterministic `result=9 expected=10` symptom | **PARTIALLY VERIFIED** — GDB unavailable |
| Lab 02 Watchpoint | strict build; `count=0 expected=5` symptom | **PARTIALLY VERIFIED** — watchpoint execution unavailable |
| Lab 03 ASan | heap-use-after-free; report contained invalid access plus allocation/free stack evidence | **VERIFIED** |
| Lab 04 UBSan | signed `2147483647 + 1` overflow diagnostic | **VERIFIED** |
| Lab 05 errno/strace | missing path produced ENOENT | **PARTIALLY VERIFIED** — strace unavailable |
| Lab 06 multiprocess | seeded EOF hang; `/proc` showed parent two pipe endpoints, child one for same pipe | **PARTIALLY VERIFIED** — `/proc` verified, strace unavailable |
| Lab 07 Tool Selection Drill | reasoning worksheet only | **UNVERIFIED** learner exercise |
| Challenge memory | ASan UAF | **VERIFIED** |
| Challenge endian/state/file symptoms | strict build/runtime paths | **VERIFIED** |
| Challenge GDB state workflow | tool unavailable | **UNVERIFIED** |
| Challenge strace file workflow | tool unavailable | **UNVERIFIED** |
| Fault F1 UAF | ASan UAF | **VERIFIED** |
| Fault F2 state overwrite | deterministic symptom | **PARTIALLY VERIFIED** — GDB unavailable |
| Fault F3 open failure | errno path | **PARTIALLY VERIFIED** — strace unavailable |
| Fault F4 wrong endian | deterministic semantic mismatch | **VERIFIED** |
| Fault F5 pipe hang | hang + `/proc` retained-writer evidence | **PARTIALLY VERIFIED** — strace unavailable |
| Gate memory | ASan UAF | **VERIFIED** |
| Gate bytes | deterministic semantic mismatch | **VERIFIED** |
| Gate FD | hang + `/proc` retained-writer evidence | **VERIFIED** current-state evidence |
| Gate file | missing-file path | **VERIFIED** |
| Complete Gate tool-selection execution | GDB/strace portions unavailable | **PARTIALLY VERIFIED** |
| Integration good | expected decoded fields | **VERIFIED** |
| Integration wrong-endian | `0x78563412` vs declared `0x12345678` | **VERIFIED** |
| Integration short | ASan heap-buffer-overflow | **VERIFIED** |
| Integration memory-fault | ASan heap-use-after-free | **VERIFIED** |
| Integration state-change | sequence overwritten to zero | **PARTIALLY VERIFIED** — symptom verified, GDB watchpoint unavailable |

Exact sanitizer addresses/stack formatting, PIDs, FDs, pipe inode numbers, and eventual strace syscall spelling are deliberately non-golden.

## Authoring corrections found by verification

### 1. Strict-warning noise in M07

Two compact seeded fixtures initially triggered `-Werror=misleading-indentation`. They were rewritten with explicit control flow. The intended serialization/bounds faults remain; unrelated warning/style noise was removed.

### 2. M08 GDB Lab 01 symptom was initially ineffective

The first condition used `>`, so the chosen input reached the intended limit and the program accidentally passed. The condition was changed to a deterministic boundary-state bug using `>=`; rerun produced `result=9 expected=10`.

### 3. Multiprocess fixture cleanup semantics

A casual close-helper pattern that could distract with `close(2)`/EINTR semantics was removed. The fixture now keeps attention on the intended pipe-writer ownership/EOF fault.

### 4. M07 F2 aligned with the requested host-endian **write** fault

The fixture writes a `uint32_t` host representation into bytes and compares against the declared LE golden vector. On this authoring host they match, which is itself the teaching point: same-host success is not a portability proof.

## Source pins

### C / WG14

Baseline: **N1570**. Re-checked exact clauses:

- §6.2.6.1 object representation/padding;
- §6.2.8 alignment;
- §6.3.2.3 p7 alignment on pointer conversion;
- §6.5 p7 character-type access;
- §6.5.3.4 `sizeof` / `_Alignof`;
- §6.7.2.1 struct member order/padding;
- §7.19 `offsetof`;
- §7.20.1.1 exact-width integer types.

### Host ABI

x86-64 psABI is used only as host-specific supporting evidence. The checked upstream GitLab UI exposed abbreviated revision **`e1ce0983`** (2025-03-12) for `x86-64-ABI/low-level-sys-info.tex`. The ledger records that limitation instead of inventing a full commit ID.

### Linux source reading

Linux **v6.18**, commit **`7d0a66e4bb9081d75c82ec4957c50034cb0ea449`**, `include/linux/unaligned.h`. It is a future/transferable source-reading example, not a userspace macro dependency.

### GCC / sanitizers

Execution baseline: **GCC 14.2.0**; official 14.2.0 Debugging and Instrumentation Options.

### GDB

Official release pinned: **GDB 17.2**, released 2026-05-10. Manual sections for breakpoints/watchpoints, stack, data, and memory are recorded. Runtime: **NOT INSTALLED**, therefore execution **UNVERIFIED**.

### strace

Official release rechecked: **strace v7.2**, 2026-08-18; tag object `8c49c884a2c64061cdd810e3c2b6e0f1dfc3e743`, commit `195ac8ddbf6fad16ff1ff125b0feb725b6c46dcf`. Pinned `doc/strace.1.in` covers `-f`, `%process`, `%file`, `%desc`, and wrapper/syscall-name caveats. Runtime: **NOT INSTALLED**.

## M07 ↔ M08 integration

`debugging/01-evidence-selection/integration/corrupted-telemetry/` keeps a fixed record pipeline but changes the fault domain:

```text
known bytes
↓
decoder
↓
record
↓
validation/state
↓
output
```

Modes: `good`, `short`, `wrong-endian`, `memory-fault`, `state-change`.

The learner must predict why the first evidence changes among golden bytes/bounds, ASan, and GDB watchpoint. This is the batch's primary transfer exercise.

## Verification integrity

No fabricated evidence is present:

- GDB output: none fabricated;
- strace output: none fabricated;
- sanitizer output: only actual executions were used to set status; fragile addresses/format are not copied as golden;
- `/proc`: only actual snapshots support VERIFIED claims;
- host object bytes: recorded only as host-specific observations;
- wire golden bytes: fixed because they are protocol contract, not host runtime formatting.

## Known limitations

1. GDB is not installed; all GDB/watchpoint runtime workflows remain **UNVERIFIED** or cause an otherwise-executed lab to be **PARTIALLY VERIFIED**.
2. strace is not installed; all strace runtime workflows remain **UNVERIFIED**.
3. No big-endian or second ABI host was available; host-endian F2 is **PARTIALLY VERIFIED** across portability dimension.
4. x86-64 psABI upstream UI exposed only an abbreviated checked revision in this research pass; ledger discloses that.
5. Sanitizer coverage is explicitly partial; silence is never used as correctness proof.
6. Reviewer solutions remain isolated under `reviewer/`.
7. No exact sanitizer formatting, address, PID, FD, pipe inode, or syscall spelling is golden.

## Explicit exclusions

No packed-struct serialization baseline; bit-field hardware mapping; MMIO/volatile/DMA/cache curriculum; network protocols/sockets; TLV/protobuf/JSON/CBOR; checksum/crypto/compression; Valgrind/rr/perf/ftrace/eBPF; core dump deep dive; KGDB/JTAG/remote GDB; GDB Python; production observability; M09 threads; M10 service machinery.

## Review focus

Leader should especially challenge:

- whether object representation and wire contract remain strictly separate;
- whether all byte-buffer parsing avoids struct-pointer casts;
- whether signed-field representation handling is explicit/coherent;
- whether failure output state stays unchanged;
- whether packed structs are only a warning/forward reference;
- whether M08 is organized by debugging question rather than command list;
- whether tool-choice rationale/falsification is actually required in Challenge/Gate;
- whether `/proc` snapshot and strace timeline remain distinct;
- whether sanitizer silence is correctly bounded;
- whether source/ABI evidence is not overgeneralized.

## Publication contract

- branch: `tutorial/p1-m07-m08`;
- base: latest canonical `main` rechecked before publication;
- PR title: `tutorial: implement P1 M07-M08 data layout and debugging foundations`;
- author must **not merge** the PR.
