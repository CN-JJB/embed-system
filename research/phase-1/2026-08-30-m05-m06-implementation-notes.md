# P1-M05 + P1-M06 Implementation & Verification Notes

> Role: Tutorial Author + Lab Designer + Technical Researcher + Code Implementer  
> Checked / executed: **2026-08-30** (America/Los_Angeles)  
> Actual canonical base: `main` @ **c54facbd88fe3b68bfef9b1316ffc0e6ba76a34c**  
> Implementation branch: `tutorial/p1-m05-m06`  
> Editorial authority: none; Leader review remains required.

## Start-state recheck

Before implementation, GitHub was re-read rather than trusting the task handoff:

- repository default/canonical branch: `main`;
- latest `main` SHA: **c54facbd88fe3b68bfef9b1316ffc0e6ba76a34c**;
- latest commit is merge of P1-M03/M04 PR #5;
- no open PRs were present at the start check;
- existing canonical Phase 1 modules: P1-M01 through P1-M04.

The implementation branch was created directly from that canonical `main`, not stacked on an old tutorial branch.

## Scope preserved

Implemented only:

- **P1-M05 — Ownership, Pointer-to-Pointer, Callback, `void *ctx`**;
- **P1-M06 — Pipe, `dup2`, Signals, Small IPC**;
- one explicit M05↔M06 synchronous integration exercise.

No formal M07 serialization/endian curriculum, M08 evidence-selection module, M09 pthread/mutex/race, M10 telemetry service, sockets, event loop, daemon/systemd, ring buffer, worker, mutex, condition variable, or binary protocol was introduced.

## Deliverables

```text
fundamentals/system-c/03-ownership-callbacks/
  README.md
  SOURCE_LEDGER.md
  diagrams/
  labs/01-ownership-audit/
  labs/02-pointer-to-pointer/
  labs/03-callback-ctx/
  labs/04-lifetime-failure/
  labs/05-integration-contract/
  challenge/
  faults/
  gate/
  reviewer/

fundamentals/linux/03-pipe-signals-ipc/
  README.md
  SOURCE_LEDGER.md
  diagrams/
  labs/01-pipe-eof/
  labs/02-fork-pipe/
  labs/03-dup2/
  labs/04-exec-pipeline/
  labs/05-eof-hang/
  labs/06-signal-stop/
  labs/07-strace-lifecycle/
  challenge/
  faults/
  gate/
  integration/
  reviewer/
```

## Authoring / verification environment

Actual executable verification environment:

```text
Linux 6.18.35 x86_64
GCC 14.2.0 (Debian 14.2.0-19)
GNU Make 4.4.1
AddressSanitizer: available / executed
UndefinedBehaviorSanitizer: available / executed
GDB: NOT INSTALLED
strace: NOT INSTALLED
```

No GDB or strace transcript is claimed. Their learner-facing command paths remain **UNVERIFIED** until executed on a host with those tools.

## Verification record — M05

| Object | Evidence actually executed | Status |
|---|---|---|
| Lab 01 ownership audit | strict build; borrow → transfer → one release | **VERIFIED** |
| Lab 02 pointer-to-pointer | strict build; success object; double-destroy-safe selected API; injected allocation failure leaves output NULL | **VERIFIED** |
| Lab 03 callback + ctx | strict build; stats context + text context; no globals | **VERIFIED** |
| Lab 04 lifetime failure | ASan heap-use-after-free after forbidden retain | **VERIFIED** |
| Lab 05 integration contract | strict build; owned input → stack-local borrowed records → stats ctx | **VERIFIED** |
| dispatcher starter | strict warning build; intentionally returns `ENOSYS` | **VERIFIED** |
| dispatcher reviewer | strict build; registration order path + first EIO propagation | **VERIFIED** |
| Fault F1 borrowed-free | ASan heap-use-after-free | **VERIFIED** |
| Fault F2 dangling ctx | registration slot retains ctx copy; owner releases ctx; ASan later use-after-free | **VERIFIED** |
| Fault F3 broken output | early-published `*out` freed on failure; ASan dereference catches dangling output | **VERIFIED** |
| Fault F4 forbidden retain | normal run completes while contract is already violated | **VERIFIED** semantic fault; demonstrates sanitizer silence limitation |
| Gate seeded owned/output/ctx | ASan reports for all three memory-lifetime cases | **VERIFIED** |
| Gate seeded retain | no memory report required; semantic contract violation visible from state | **VERIFIED** |
| Gate reviewer | strict build; `owned/output/ctx/retain` regression modes all exit 0 | **VERIFIED** |
| GDB/watchpoint workflow | tool absent | **UNVERIFIED** |

### M05 authoring correction

An initial dangling-context fixture let GCC's `-Wuse-after-free` identify a direct local use, which prevented the seeded program itself from meeting the repository's strict-warning baseline. The fixture was changed to the more realistic contract shape:

```text
registration slot stores ctx pointer
→ owner releases ctx and clears its own pointer
→ slot still holds stale borrowed ctx
→ later callback invocation
```

This preserves the intended lifetime fault while keeping the seeded source `-Werror` clean.

## Verification record — M06

| Object | Evidence actually executed | Status |
|---|---|---|
| Lab 01 pipe EOF | strict build; data read then `read()==0` after writer close | **VERIFIED** |
| Lab 02 pipe across fork | strict build; parent write / child read / EOF / wait | **VERIFIED** |
| Lab 03 `dup2` | strict build; child FD 1 byte flow reaches parent pipe | **VERIFIED** |
| Lab 04 exec pipeline | strict build; producer→consumer; parent closes copies; both children reaped | **VERIFIED** happy path |
| Lab 04 actual fork-failure injection | no fork-failure shim used | **UNVERIFIED** runtime; code-reviewed |
| Lab 05 seeded EOF hang | strict build; `/proc/<pid>/fd` showed extra writer reference; EOF after close | **VERIFIED** |
| Lab 06 signal stop flag | external SIGTERM; handler records flag; normal-context cleanup message | **VERIFIED** |
| Lab 07 `strace -f` | strace absent | **UNVERIFIED** |
| `capture_exec` reviewer | strict build; small capture; ~2 MiB producer drain; decoded exit 7; missing exec reserved 127 | **VERIFIED** |
| Fault F1 extra parent writer | `/proc` endpoint evidence + EOF after close | **VERIFIED** |
| Fault F2 inherited writer across exec | holder inherited endpoint; EOF delayed until holder exit; `/proc` checked | **VERIFIED** |
| Fault F3 wrong dup2 endpoint | wrong-end write failure observed | **VERIFIED** |
| Fault F4 wait-before-drain | large producer + wait-first fixture blocked until external timeout on authoring host | **VERIFIED** symptom; exact threshold/timing non-golden |
| Fault F5 unsafe handler | strict build + signal delivery; source/standards reasoning fault | **VERIFIED** execution, no deterministic-crash claim |
| Gate seeded | strict build; producer exited while consumer waited; `/proc` showed supervisor/consumer write-end references | **VERIFIED** |
| Gate seeded SIGTERM | unsafe handler ran; supervisor exited without coherent child lifecycle | **VERIFIED** symptom; no crash guarantee |
| Gate reviewer normal | strict build; EOF arrives; both children reaped | **VERIFIED** |
| Gate reviewer SIGTERM | fixture-controlled slow path; stop request handled by normal context; children terminated/reaped | **VERIFIED** |
| M05↔M06 integration normal | strict build; four records → synchronous callback → stats | **VERIFIED** |
| M05↔M06 integration SIGTERM | slow mode + external SIGTERM; normal context closes/stops/waits/reports | **VERIFIED** |
| all M06 strace evidence | tool absent | **UNVERIFIED** |

## Important M06 authoring correction — `dup2(oldfd == newfd)`

Close discipline was reviewed against the actual `dup2` contract. Code now avoids blindly closing the descriptor that was just duplicated when the source descriptor number already equals the target standard descriptor.

Examples use:

```c
if (pipefd[1] != STDOUT_FILENO)
    close(pipefd[1]);
```

rather than assuming pipe FDs are always greater than 2. This prevents the tutorial from accidentally teaching a hidden “FD must be 3+” literal.

## Source pins

### WG14 / C

- baseline: **N1570**;
- selected §§6.2.4, 6.3.2.3, 6.5.2.2, 6.7.6.3;
- object-pointer/`void *` conversion is kept separate from function-pointer rules.

### BusyBox

- release family: **BusyBox 1.38.0**, released 2026-05-13;
- exact-byte cross-check: maintainer mirror commit `fc71374dfccd46448c62947269a35f1420d7ee28`;
- `include/libbb.h`: callback members + `void *userData`;
- `libbb/recursive_action.c`: blob `b1c4bfad7ccff508e1322bd79c3af9e84e3bcec9`;
- release distribution license is GPLv2-only; file-level notices are recorded rather than flattened.

### Linux man-pages

- tutorial baseline remains **6.18**, matching M02/M04;
- kernel.org archive current upstream checked in this work: **6.19**, dated 2026-08-25;
- current upstream is recorded separately and does not retroactively rename 6.18 tutorial/runtime evidence.

### musl

- **musl 1.2.6**;
- commit `9fa28ece75d8a2191de7c5bb53bed224c5947417`;
- `src/unistd/pipe.c`, mirror blob `d07b8d24ae3b1f55126700e64994ab55d453fb16`;
- `src/unistd/dup2.c`, mirror blob `8f43c6ddfe8983e9565d6a14a10f423c9fd55f05`;
- `src/signal/sigaction.c`, mirror blob `e45308fae5fbf5cc30198c648ecc3b872583c5ed`;
- project COPYRIGHT: standard MIT license for musl as a whole with documented exceptions.

### strace

- current release checked: **strace 7.2**, dated 2026-08-18;
- authoring runtime does not have strace installed, so only docs/source path is recorded; no trace is marked VERIFIED.

## Learner load

Canonical design budget is preserved:

- M05: **5.5 h MUST**;
- M06: **6 h MUST**;
- combined: **11.5 h MUST**;
- combined REQUIRED external reading target: roughly **2–2.3 h**.

The implementation does not change total Phase 1 budget.

## Known limitations

1. **strace unavailable** — all `strace -f` learner paths remain UNVERIFIED in authoring environment.
2. **GDB unavailable** — no watchpoint/backtrace transcript is fabricated.
3. Actual second-`fork` failure was not forced with a test shim; cleanup logic is code-reviewed but that runtime failure branch is UNVERIFIED.
4. Pipe capacity, PIDs, FDs, scheduling order, and signal delivery timing are deliberately non-golden.
5. Unsafe signal-handler fixtures are standards/source-reasoning faults; runtime survival is not presented as legal design.
6. `capture_exec` reserved code 127 remains intentionally ambiguous with a legitimate target exit 127; solving that with a dedicated exec-status protocol is outside this challenge.
7. Reviewer solutions remain isolated under `reviewer/`.

## Review focus

Leader should especially check:

- ownership vocabulary stays contract reasoning, not invented C type semantics;
- `T **` failure/output-state contracts are coherent;
- callback retain/context/mutation rules are explicit and match reviewer code;
- semantic ownership fault is not reduced to sanitizer output;
- pipe EOF explanation counts all write-end references;
- `dup2` is taught as descriptor binding, not resource copy;
- every normal/partial process path closes/reaps coherently;
- handler architecture is “record intent; normal context cleanup”;
- no M07–M10 scope leaked into this batch.

## Publication contract

- branch: `tutorial/p1-m05-m06`;
- base: latest canonical `main` at start, `c54facbd88fe3b68bfef9b1316ffc0e6ba76a34c`;
- PR title: `tutorial: implement P1 M05-M06 ownership and IPC foundations`;
- author must **not merge** the PR.
