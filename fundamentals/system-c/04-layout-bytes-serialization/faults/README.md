# M07 Fault Campaign

## Objective

Use different evidence for layout/serialization contract faults versus actual memory-safety faults.

## Build

    make
    make asan
    make ubsan

| Fault | Mode | First evidence | Verification |
|---|---|---|---|
| F1 object layout as wire | `raw` | sizeof/offsetof + wire table | **VERIFIED** semantic path |
| F2 host-endian write | `endian` | golden bytes + declared endian | **PARTIALLY VERIFIED** — current LE host matches LE golden; cross-endian not executed |
| F3 unaligned typed load | `unaligned` | alignment reasoning + UBSan | **VERIFIED** runtime alignment diagnostic |
| F4 short input | `short` | bounds + ASan | **VERIFIED** heap-buffer-overflow |
| F5 partial publication | `partial` | before/after output state | **VERIFIED** |

ASan/UBSan addresses and exact formatting are non-golden.

Root-cause wording must name the violated contract, not merely repeat “UBSan says misaligned” or “ASan says OOB”.
