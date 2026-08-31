# Reviewer Answer Key — Phase 0 Baseline

> **Reviewer-only.** This file contains causal explanations and reference solutions. It must not be opened by the learner during the scored AI-Free session.

The key is intentionally more than “correct code.” For each task it identifies the reasoning path, useful evidence, common wrong answers, and what the result reveals about skill.

---

# A — System C

## A1 — Telemetry Bug Hunt

### Expected reasoning

The learner should avoid treating the first crash/warning as the whole problem. The file contains several independent defects:

1. `make_label()` returns a pointer to an automatic array whose lifetime ends when the function returns.
2. `copy_samples()` uses `sizeof(dst)` where `dst` is a pointer parameter, so the function does not know the destination array extent.
3. `sum_samples()` uses `i <= count` and reads one element past the valid copied range.
4. `scale_raw()` left-shifts a negative signed value. Left shift of a negative signed integer is undefined behavior in C.
5. `decode_header()` assumes an in-memory C struct layout is the wire layout. The normal struct may contain padding, and integer byte order follows the host representation rather than an explicit wire format.
6. `make_summary()` returns allocated memory as `const char *` without documenting ownership; `main()` never frees it.

The best repair makes extents and ownership explicit instead of relying on caller folklore.

### Key evidence

Useful evidence includes:

- compiler warning for returning the address of a local variable;
- ASan report for the out-of-bounds access in/after `sum_samples()`;
- UBSan report or language-rule explanation for negative left shift;
- `sizeof(struct wire_header)`, `offsetof()`, or debugger inspection showing padding/layout differs from the logical 7-byte packet;
- a regression that decodes sequence `0x12345678` and sample count `4` from the supplied bytes.

A runtime that “looks fine” is not evidence that UB is valid.

### Root cause

The root cause is not one bad pointer; it is a cluster of missing interface contracts: lifetime, array extent, integer domain, serialization layout, and heap ownership are implicit.

### Reference solution

A complete reference implementation is in:

`reviewer/reference/telemetry_fixed.c`

Key design changes:

- caller owns `char label[24]`; `make_label(dst, cap, id)` writes into it;
- `copy_samples(dst, capacity, src, count)` receives the extent explicitly;
- loop condition becomes `i < count`;
- scaling checks range and uses defined multiplication;
- wire bytes are decoded explicitly as little-endian fields;
- `make_summary()` returns `char *`, and the caller frees it.

### Common wrong answers

- “Add `static` to `local`.” This can remove the dangling pointer but creates shared mutable storage and does not solve the other bugs; it is only acceptable if the learner explicitly chooses and justifies that API.
- “Use `sizeof(input)` inside `copy_samples`.” The callee does not have the caller's array object.
- “Pack the struct.” Packing can remove padding but still couples the decoder to byte order, representation, alignment/access constraints, and compiler attributes.
- “Cast to unsigned before shifting and cast back.” This may make the shift defined but silently changes the API's numerical semantics for negative inputs unless carefully specified.
- “`const char *` means no one must free it.” `const` says the pointed-to characters should not be modified through that pointer; it does not express heap ownership.

### What this reveals

Strong performance shows practical understanding of C object lifetime, pointer/array decay, UB, serialization boundaries, and ownership—not merely syntax recall.

---

## A2 — Callback Event Bus

### Expected reasoning

The bus owns its slot array and bus object. A registered `ctx` is borrowed. Event `data` is borrowed for the duration of `event_bus_emit()` unless some higher-level API establishes a longer lifetime.

The pointer-to-pointer in create/destroy exists because the function must update the caller's pointer value.

### Key evidence

The supplied fixture should pass, and added tests should ideally cover NULL arguments, full capacity, unregistering an unknown token, slot reuse, and zero-sized data.

### Root cause

There is no seeded bug; this task diagnoses API construction ability. The main risks are unclear ownership, stale stack `ctx`, token collisions, and error paths.

### Reference solution

See `reviewer/reference/event_bus.c`.

The reference uses:

- a deliberately non-re-entrant baseline contract: callback-driven register/unregister/destroy during `emit` is outside the scored scope;
- `calloc()` for owned state;
- non-zero registration tokens;
- inactive slot represented by `handler == NULL`;
- `ENOENT` for unknown active token;
- destroy that frees and writes `NULL` through the caller pointer.

Other coherent token strategies are acceptable.

### Common wrong answers

- Copying bytes from `ctx` without knowing its type/size: impossible for a generic `void *` context contract.
- Freeing `ctx` during unregister/destroy: violates the borrowed-context contract.
- Storing a pointer to a local temporary as bus-owned state: lifetime bug.
- Calling handlers after their slot is unregistered: stale registration state.

### What this reveals

This separates “knows function-pointer syntax” from ability to design a small C interface with lifetime and error semantics.

---

# B — Compile / Link / ELF

## B1 — Broken multi-file project

### Expected reasoning

Compilation of each translation unit and final link are different stages. A header definition can create one external definition in every translation unit that includes it, while `static` at file scope gives internal linkage and makes a same-spelled symbol unavailable to other objects.

### Key evidence

Before repair, useful observations include patterns equivalent to:

```text
nm build/main.o       -> external definition of sample_count
nm build/metrics.o    -> external definition of sample_count
nm build/report.o     -> external definition of sample_count; U format_total
nm build/format.o     -> local text symbol format_total
```

Exact addresses/letter case may vary by toolchain.

`readelf -s` should show examples of LOCAL, GLOBAL, and UND binding/state.  
`readelf -r build/report.o` should contain a relocation associated with the unresolved call to `format_total` (exact relocation type depends on the x86-64 toolchain/code model).

### Root cause

Two independent linkage problems:

1. `metrics.h` contains `int sample_count = 1;`, creating multiple external definitions.
2. `format.c` defines `format_total` as `static`, but `report.c` expects an external symbol declared by `format.h`.

### Reference solution

Smallest coherent changes:

```c
/* metrics.h */
extern int sample_count;

/* metrics.c */
int sample_count = 1;
```

and remove `static` from the `format_total` definition so it matches the public declaration.

After repair, the intended run result is:

```text
baseline total=7 dropped=0
```

The concrete artifact path should be explained as:

- preprocessing expands/includes headers and macros into `.i`;
- compilation/code generation produces assembly `.s` (when requested);
- assembler creates relocatable `.o` with sections, symbols, and unresolved references/relocations;
- linker resolves symbols/relocations and lays out the final ELF executable.

Concrete examples:

- function machine code such as `metrics_add` belongs in `.text`;
- initialized `sample_count = 1` belongs in initialized data (normally `.data`);
- zero-initialized `dropped_count` / `running_total` use zero-fill storage (normally `.bss`);
- a call from `report.o` to `format_total` needs symbol resolution and relocation.

### Common wrong answers

- “Put `static int sample_count` in the header.” This gives each translation unit a different counter and changes program semantics.
- “Remove `format.o` from the link.” That cannot satisfy `report.o`'s required function.
- “Undefined reference is a compiler error.” The source compiled; symbol resolution failed during link.
- Giving definitions of `.text/.data/.bss` without naming project symbols: insufficient evidence.

### What this reveals

This tests whether the learner can use the toolchain as an evidence source rather than treating `gcc file.c` as one opaque operation.

---

# C — Linux Userspace

## C1 — Process pipeline

### Expected reasoning

All pipe FDs are inherited across `fork()`. After `dup2()`, each child must close both original pipe descriptors. The parent must close both pipe descriptors after the two forks. EOF is observed only when no process still holds a write end.

### Key evidence

A correct FD ownership table is conceptually:

```text
producer child:
  stdout -> pipe write
  close original read + write descriptors

filter child:
  stdin  <- pipe read
  close original read + write descriptors

parent:
  close read + write descriptors
  waitpid(producer)
  waitpid(filter)
```

Expected output:

```text
KEEP alpha
KEEP gamma
```

### Root cause of the seeded failure mode

If the parent retains the pipe write descriptor, `filter` can consume all bytes but cannot observe EOF because a writer reference still exists. Waiting longer does not fix ownership.

### Reference solution

See `reviewer/reference/pipeline.c`.

### Common wrong answers

- Add `sleep(1)` before exiting: scheduling workaround, not FD ownership.
- Close only the read side in the parent: the retained write side still prevents EOF.
- Have the parent copy bytes itself: violates the requested two-child pipeline mechanism.
- Call `system("producer | filter")`: bypasses the capability under test.

### What this reveals

Ability to reason about process inheritance, descriptor reference lifetime, EOF, and child lifecycle.

---

## C2 — Linux investigation

### Expected reasoning

The fixture repeatedly creates a pipe and child. The child exits after writing one byte. The parent reads but intentionally does not close either pipe FD and never reaps the child.

### Key evidence

Expected categories of evidence:

- `ps`: child processes in zombie/defunct state while parent remains alive;
- `/proc/<parent>/fd`: growing/accumulated `pipe:[...]` descriptors;
- `strace`: repeated `pipe2/pipe`, `clone/fork`, `read`; absence of the required parent closes/waits after each iteration.

Exact PIDs and FD numbers are not fixed.

### Root cause

Two independent resource-lifecycle bugs:

1. exited children are not reaped with `waitpid()`;
2. parent retains both pipe endpoints.

### Reference solution

For each successful parent branch:

- close `p[1]` immediately because the parent never writes;
- read from `p[0]`;
- close `p[0]` after the read;
- call `waitpid(pid, ...)` (with normal EINTR/error handling in production code).

### Common wrong answers

- “Zombie means the child is still executing.” It has exited; the kernel retains exit status/accounting until reaped.
- “Killing the zombie fixes it.” The child is already dead; the parent must reap it or exit.
- “FD leak is only a memory leak.” FDs are kernel-managed process resources and can change pipe EOF behavior.

### What this reveals

Whether the learner can investigate a running Linux process using system evidence rather than edit-run guessing.

---

# D — Debugging

For all D tasks, scoring depends on the evidence chain. A patch guessed from reading source is not equivalent to demonstrated fault isolation.

## D1 — Segmentation fault

### Expected reasoning / key evidence

`find_user(..., 7)` returns `NULL`. `print_user()` dereferences `u->name` without checking. A GDB backtrace and local `u == NULL` are direct evidence.

### Root cause

Caller does not handle the lookup's “not found” result.

### Reference solution

Define the contract. For example:

```c
const struct user *u = find_user(...);
if (u == NULL) {
    fprintf(stderr, "user %d not found\n", id);
    return;
}
```

Regression: existing ID and missing ID.

### Common wrong answers

- Check `u->name == NULL` before checking `u`: already dereferences NULL.
- Remove the ID 7 test: hides the valid error path.

### Skill revealed

GDB stack/state reasoning and distinction between crash site and violated API contract.

---

## D2 — Delayed memory corruption

### Expected reasoning / key evidence

`payload` has 16 bytes. Input has 16 visible characters plus a terminating NUL. The loop uses `i <= n`, so when `i == 16`, it writes the terminator one byte beyond `payload`, into the following `guard` subobject.

A watchpoint on `r.guard` or source-level boundary reasoning can identify the first corrupting write. A generic heap/stack ASan report is not guaranteed because the overwrite stays within the enclosing struct object.

### Root cause

The destination API has no capacity policy and writes a C string terminator into a 16-byte payload field that has no room for 16 characters plus NUL.

### Reference solution

Choose explicit semantics, for example:

- payload is binary bytes: copy at most 16 bytes and do not promise NUL termination; or
- payload is a C string: reserve one byte and copy at most 15 visible characters plus NUL.

Regression should cover 15, 16, and oversized input according to the chosen contract.

### Common wrong answers

- “ASan is clean, so no corruption exists.” Subobject overwrite can remain inside one allocated object.
- Change `guard` value: does not stop overwrite.
- Validate only after the copy: detects symptom but does not define safe copy behavior.

### Skill revealed

Ability to locate the first invalid write in delayed corruption and understand object/subobject boundaries.

---

## D3 — Race

### Expected reasoning / key evidence

`++counter` is a read-modify-write, not an atomic operation. Multiple pthreads perform it without synchronization. `volatile` only forces observable accesses according to C rules; it does not provide inter-thread atomicity or a happens-before relation.

Repeated runs may show lost updates. ThreadSanitizer, where supported, should report a data race.

### Root cause

Unsynchronized conflicting accesses to shared non-atomic state: a C data race and therefore undefined behavior.

### Reference solution

Acceptable repairs include:

```c
/* mutex */
pthread_mutex_lock(&lock);
++counter;
pthread_mutex_unlock(&lock);
```

or a C atomic counter:

```c
#include <stdatomic.h>
static _Atomic uint64_t counter;
atomic_fetch_add_explicit(&counter, 1, memory_order_relaxed);
```

`memory_order_relaxed` is sufficient if the only required invariant is an atomic numeric count and no other data is published through the counter.

Regression: many repeated runs at the original thread/iteration count with exact final count.

### Common wrong answers

- Add `volatile`: already present and still wrong.
- Add sleep/yield: changes scheduling, does not establish synchronization.
- Reduce threads to one: removes the concurrency condition rather than fixing it.

### Skill revealed

Concurrency root-cause reasoning and correct separation of volatile, atomicity, and synchronization.

---

## D4 — Link failure

### Expected reasoning / key evidence

Consumer object has an undefined external `checksum_word`. Provider object contains a same-spelled **local** text symbol because the function is file-scope `static`.

### Root cause

Internal linkage in the provider cannot satisfy another translation unit's external reference.

### Reference solution

Remove `static` from the provider definition and preferably place the declaration in a shared header.

### Common wrong answers

- Reorder object files: order does not turn a local symbol into an external one.
- Rename only the declaration: still no matching external definition.

### Skill revealed

Evidence-driven build/link debugging.

---

# E — Computer Systems

## E1 — Function call

### Expected reasoning

On the supplied x86-64 build, the learner should use actual `objdump`/GDB results rather than quote fixed offsets.

Transferable concepts:

- a call transfers the PC to a callee and preserves enough state to return;
- SP identifies the current stack position;
- an ABI defines argument/return conventions and preserved/clobbered state;
- locals may live in registers or stack storage depending on compilation;
- a return address/control link must be preserved somewhere by the architecture/ABI sequence.

x86-64 System V details typically observed at `-O0`:

- first integer/pointer arguments in registers such as RDI, RSI, RDX;
- CALL places a return address on the stack;
- RSP is the stack pointer and RIP is the instruction pointer;
- a frame pointer may be used because the Makefile requests `-fno-omit-frame-pointer`.

ARM/RISC-V use different register names, call instructions, link/return-address conventions, alignment rules, and ABIs.

### Key evidence

Credit actual register values/disassembly connected to the C values 3, 5, 7 and result 51.

### Common wrong answers

- “All arguments are on the stack.” Not on the normal x86-64 SysV integer fast path.
- “Every C local has a permanent stack slot.” Optimization/codegen can keep locals in registers.

### Skill revealed

Ability to map source-level execution onto machine state without confusing one ABI with architecture universals.

---

## E2 — Syscall / interrupt / exception

### Expected reasoning

**System call:** explicit software action by a user program invokes a defined kernel entry mechanism. Hardware transfers control to a privileged kernel entry according to the ISA/OS convention; kernel saves/restores required user context and returns to userspace.

**Hardware interrupt:** an external/peripheral interrupt request is recognized by the processor/interrupt controller. It is asynchronous with respect to the current instruction stream; hardware/handler machinery preserves required state, selects a vector/handler, services/acknowledges the device/interrupt, then returns.

**CPU exception:** synchronous condition caused by executing an instruction or detecting a fault (e.g. invalid instruction/access). The processor transfers to the architecturally selected handler with fault context so software can handle, terminate, or resume where permitted.

The exact privilege levels, vector registers, stack-frame layout, and return instructions are ISA/platform specific.

### Common wrong answers

- “All three are hardware interrupts.” A syscall is deliberate synchronous software entry; many CPU faults are synchronous exceptions.
- “The OS changes privilege by writing a variable.” Privilege transition is an architectural control transfer.

### Skill revealed

Unified exceptional-control-flow mental model.

---

## E3 — Cache/TLB locality

### Expected reasoning

Sequential accesses normally exploit cache-line spatial locality and hardware prefetch. A stride near one 4 KiB page touches a different cache line/page almost every access, reducing spatial reuse and potentially increasing TLB pressure and defeating/simple prefetch patterns.

The benchmark result is host-dependent. The learner must record actual runs and explain agreement or disagreement without claiming exact cycle counts.

### Common wrong answers

- Predicting an exact number of cycles from source alone.
- Claiming “random” when the access is deterministic striding.
- Reporting one timing without host/repetition/context.

### Skill revealed

Prediction → observation → model revision, not cache vocabulary recall.

---

## E4 — Process vs thread resources

### Reference model

Within one normal multithreaded process:

- virtual address space: shared among threads;
- heap: shared address space/storage, requiring synchronization for shared objects;
- file descriptor table: shared in the process/thread group under normal pthread model;
- current working directory: process-wide under normal pthread model;
- stack: per thread;
- CPU register state: per thread;
- signal mask: per thread in POSIX threads.

Across `fork()`, the child receives a new process/address space logically copied via copy-on-write; open file descriptors are duplicated and refer to the same underlying open-file descriptions, but the descriptor table is not simply one permanently shared table between unrelated parent/child processes.

### Skill revealed

Whether “process” and “thread” are operational resource models rather than definitions.

---

# F — STM32 Bare-metal

## F1 — Reset to main

### Expected reasoning

From the supplied vector fixture, the first vector word is `_estack`; the second is `Reset_Handler`. On Cortex-M reset, the core obtains the initial stack pointer and reset execution address from the vector table mechanism. The linker places that table in Flash and defines `_estack` at the top of SRAM.

The linker excerpt gives `.data` a run address in RAM but a load image in Flash via `AT > FLASH`. Therefore:

- `_sidata = LOADADDR(.data)` identifies the Flash source;
- `_sdata .. _edata` bound the SRAM destination;
- startup copies initialized writable objects from Flash image to RAM.

`.bss (NOLOAD)` occupies RAM but has no stored initializer bytes; `_sbss .. _ebss` bound the region startup zeros.

Then startup calls `SystemInit` and `main`.

### Key evidence

The answer must name the actual fixture symbols, not only draw a generic diagram.

### Root cause examples

If `.data` copy is omitted, non-zero initialized writable objects can begin with wrong values in RAM.  
If `.bss` zero is omitted, objects that C requires to start as zero do not receive the required runtime initialization.

### Common wrong answers

- “The CPU automatically initializes all C globals.” The reset/vector behavior is architectural; C runtime section initialization is startup software.
- “`.data` executes from Flash.” Its initial image is stored in Flash, but writable `.data` runs/resides in RAM under this linker layout.

### Skill revealed

Connection among architecture reset semantics, linker memory map, and C runtime initialization.

---

## F2 — TIM2 1 ms interrupt

### Expected reasoning

Given:

```text
HCLK  = 72 MHz
PCLK1 = 36 MHz
APB1 prescaler = /2
```

For STM32F1 general-purpose timers on APB1, when the APB prescaler is not 1, the timer clock is twice PCLK1. Thus TIM2 input timer clock is 72 MHz.

A valid pair:

```text
PSC = 71      -> counter clock = 72 MHz / (71 + 1) = 1 MHz
ARR = 999     -> update = 1 MHz / (999 + 1) = 1 kHz = 1 ms
```

Equivalent factorizations are acceptable.

Configuration sequence should include the correct concepts:

- enable TIM2 peripheral clock in RCC;
- program PSC/ARR;
- generate/ensure update so prescaler state is loaded as required;
- clear stale update flag;
- enable update interrupt in TIM2;
- enable TIM2 interrupt in NVIC;
- enable counter;
- ISR observes/clears the update pending/status flag before returning.

### Common wrong answers

- Use 36 MHz directly for TIM2 without checking APB timer clock doubling.
- Forget the “+1” in PSC/ARR divisor arithmetic.
- Enable NVIC but not the peripheral's update interrupt, or vice versa.
- Never clear the timer update flag, causing immediate repeated entry.

### Skill revealed

Manual navigation + clock-tree/peripheral reasoning.

---

## F3 — MMIO / volatile

### Expected reasoning

A peripheral register is memory-mapped I/O, so accesses must actually occur as accesses to that address. The fixture returns a plain `uint32_t *`, allowing the compiler to treat the object like ordinary memory. The access should use a volatile-qualified lvalue, for example:

```c
static volatile uint32_t *demo_ctrl(void)
{
    return (volatile uint32_t *)(PERIPH_BASE + DEMO_CTRL_OFFSET);
}
```

or a properly defined volatile peripheral register structure.

The shown sequence is read-modify-write:

```text
read current register
modify selected bits in a CPU value
write whole register back
```

This is only appropriate when the register's semantics permit it. W1C/status bits, read side effects, or concurrent hardware updates can make generic RMW incorrect.

`volatile` does not make the operation atomic, does not establish C thread/ISR synchronization, and is not a substitute for the architecture/device ordering primitives required by a particular hardware interface.

### Common wrong answers

- “volatile makes it thread safe.”
- “volatile is a memory barrier.”
- “all register updates should always use `reg |= bit`.” Register semantics matter.

### Skill revealed

Whether the learner understands MMIO as a hardware contract rather than a keyword definition.

---

## F4 — Timer -> ADC -> DMA

### Expected reasoning

The supplied snapshot deliberately breaks multiple links in the path.

The fixture explicitly assumes that ADC clock prescaling and ADC power-up/calibration readiness are already valid. Those are important real bring-up checks, but they are not hidden seeded faults in this 25-minute exercise.

High-priority findings should include:

1. `ADC1.CR2.EXTSEL = 111` does not select the intended TIM3 TRGO regular trigger; verify the exact encoding in RM0008.
2. `ADC1.CR2.DMA = 0`: ADC DMA requests are disabled.
3. Proposed DMA channel 3 must be checked against the ADC1 DMA request mapping; on the selected STM32F103 medium-density device, ADC1 uses the documented DMA1 channel mapping rather than arbitrary channel selection.
4. `DIR = 1` selects the wrong transfer direction for peripheral-to-memory acquisition.
5. 32-bit peripheral/memory widths conflict with a 16-bit ADC data result and `uint16_t samples[]`; the channel should use widths consistent with the ADC result/buffer contract.

A strong debug sequence follows the data path rather than changing all fields at once:

```text
1. Prove TIM3 is running/update events occur.
2. Prove ADC external trigger configuration matches TIM3 TRGO.
3. Prove ADC conversion occurs (status/EOC and DR behavior).
4. Prove ADC DMA request is enabled.
5. Prove correct DMA channel is enabled and receives requests.
6. Inspect DMA ISR flags / CNDTR movement / address-width-direction settings.
7. Only then inspect final buffer contents.
```

### Key evidence

The learner should cite the relevant RM0008 ADC external-trigger selection, ADC DMA enable, DMA request mapping, DMA CCR/CNDTR/ISR/IFCR descriptions.

Useful discriminators:

- timer counter/update status or a temporary diagnostic GPIO/event path;
- ADC EOC/status and DR change;
- DMA channel `CNDTR` decrement and transfer/error flags;
- buffer change in SRAM;
- scope on a safe timer-correlated GPIO or analog input signal if hardware is available.

### Root cause

The seeded configuration does not form one valid trigger/request/data-transfer chain. Multiple independent configuration errors can each stop or corrupt acquisition.

### Common wrong answers

- “DMA is broken because the buffer is unchanged” with no stage-by-stage evidence.
- Change every register at once: may make it work but provides weak diagnostic evidence.
- Use `volatile` on the buffer as a substitute for configuring DMA.
- Assume any DMA channel can serve ADC1.
- Probe MCU pins destructively or use unsafe voltage injection: not required.

### What this reveals

Ability to navigate a reference manual and design a root-cause investigation across timer, ADC, DMA, memory, and instrumentation boundaries.

---

# Reviewer calibration notes

- Reward evidence that falsifies hypotheses, not log volume.
- Do not require identical commands or implementation style when the mechanism is correct.
- Version/ABI-dependent observations must be judged against the learner's recorded host.
- For STM32, manual-backed reasoning is scoreable without hardware. Any claimed hardware measurement must be genuine; otherwise mark it unverified.
- If an exercise unexpectedly behaves differently on a newer toolchain, preserve the learner evidence and review the fixture rather than forcing the golden symptom.
