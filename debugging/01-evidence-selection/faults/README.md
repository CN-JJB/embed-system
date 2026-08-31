# M08 Fault Campaign

## Objective

Practice evidence selection by fault domain, not by favorite tool.

## Build

    make
    make asan

| Fault | Mode | Primary evidence | Why | Actual verification |
|---|---|---|---|---|
| F1 UAF | `uaf` | ASan | access/allocation/free chain | **VERIFIED** ASan heap-use-after-free |
| F2 state overwritten | `state` | GDB watchpoint | asks “who wrote this location?” | symptom **VERIFIED**; GDB **UNVERIFIED** → **PARTIALLY VERIFIED** |
| F3 open failure | `open` | return + errno, then strace | program contract then OS boundary | errno **VERIFIED**; strace **UNVERIFIED** → **PARTIALLY VERIFIED** |
| F4 wrong endian | `endian` | golden bytes / codec reasoning | semantic bytes, not memory safety | **VERIFIED** semantic mismatch |
| F5 pipe hang | `pipe` | FD matrix + `/proc`, then strace | current holders then timeline | `/proc` hang evidence **VERIFIED**; strace **UNVERIFIED** → **PARTIALLY VERIFIED** |

## Root-cause standard

Not enough:

> ASan says heap-use-after-free.

Required shape:

> An owner freed the allocation while a retained pointer still crossed a later access boundary; the retention/lifetime contract was incoherent.

Likewise, “strace shows read” is observation, not root cause. “Wrong endian” must identify the declared byte-order contract and the decoder operation that violated it.

## Cleanup

Pipe modes intentionally hang until the retained writer is closed or the fixture is terminated. Clean up child processes before moving on.
