# Remediation Map — Phase 0 Baseline

Paths below are curriculum targets; some may not exist yet. They are deliberately stable skill-path names rather than promises that modules are already authored.

| Failure signal | Remediation target | Re-test evidence |
|---|---|---|
| A1 lifetime / dangling pointer | `fundamentals/system-c/lifetime-ownership` | repair two lifetime bugs + explain storage duration |
| A1 OOB / `sizeof(pointer)` | `fundamentals/system-c/pointers-arrays-bounds` | bounded buffer lab under ASan + API extent exercise |
| A1 signed/shift UB | `fundamentals/system-c/integer-ub` | integer edge-case tests + sanitizer evidence |
| A1 struct/endian/layout | `fundamentals/system-c/layout-endian-serialization` | explicit wire decoder + `offsetof/sizeof` inspection |
| A2 callback/function pointer | `fundamentals/system-c/callbacks-context` | implement callback registry with borrowed `ctx` |
| A2 ownership/error paths | `fundamentals/system-c/api-ownership-errors` | create/destroy/error-path test matrix |
| B symbols/linkage | `fundamentals/toolchain/symbols-linkage` | repair static/extern/global failures using `nm` |
| B ELF/relocation weak | `fundamentals/toolchain/elf-linking` | object→ELF inspection lab with `readelf/objdump` |
| C1 process/FD/EOF | `fundamentals/linux/process-fd-pipe` | independent two-child pipeline with FD table |
| C1 wait/exec errors | `fundamentals/linux/process-lifecycle-exec` | exec failure + status propagation lab |
| C2 `/proc` weak | `fundamentals/linux/proc-observability` | explain live process FD/state evidence |
| C2 `strace` weak | `fundamentals/linux/strace-evidence` | trace one blocking syscall to root cause |
| D1 GDB weak | `fundamentals/debugging/gdb-stack-state` | crash→frame→locals→cause report |
| D2 corruption weak | `fundamentals/debugging/memory-corruption` | delayed overwrite with watchpoint/sanitizer evidence |
| D3 race weak | `fundamentals/debugging/concurrency-races` | mutex/atomic repair + repeated regression |
| D4 link-debug weak | `fundamentals/debugging/build-link-failures` | symbol-binding failure postmortem |
| Debug method weak across faults | `fundamentals/debugging/foundations` | fresh 3-fault AI-Free root-cause Gate |
| E1 ABI/stack weak | `fundamentals/computer-systems/abi-stack` | C→assembly→GDB call trace on x86-64 then ARM/RISC-V comparison |
| E2 privilege/exception weak | `fundamentals/computer-systems/exception-privilege` | syscall/trap/IRQ control-flow exercise |
| E3 cache/TLB weak | `fundamentals/computer-systems/cache-tlb-locality` | prediction→benchmark→explanation lab |
| E4 process/thread model weak | `fundamentals/os/process-thread-resources` | resource-sharing diagram + `fork` experiment |
| F1 startup/linker weak | `fundamentals/stm32/startup-linker` | vector + `.data/.bss` trace on selected MCU |
| F2 timer/IRQ weak | `fundamentals/stm32/timer-interrupt` | RM-backed 1 ms timer config + scope/GPIO validation later |
| F3 MMIO/volatile weak | `fundamentals/stm32/mmio-volatile-rmw` | register-access review + atomicity/ordering contrast |
| F4 DMA debug plan weak | `fundamentals/stm32/dma-data-path-debug` | ADC/DMA seeded fault with register observation plan |

## Placement use

- One narrow failure: assign only mapped remediation and a focused re-test.
- Multiple A/B failures: rebuild System C/toolchain as one foundation block.
- C + D failures: complete Linux process/FD material and Debugging Foundations before later kernel/driver work.
- Debug Gate failure: always blocks Linux Driver main-line entry regardless of total score.
- Broad failures across >=3 modules: use Foundation Rebuild rather than stacking many isolated micro-remediations.
