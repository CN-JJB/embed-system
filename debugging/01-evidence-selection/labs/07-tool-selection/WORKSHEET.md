# Tool Selection Worksheet

Fill **before** using tools.

| Symptom | 3–5 hypotheses (compact) | First tool/evidence | Why this first? | What would falsify leading hypothesis? | Second evidence only if needed |
|---|---|---|---|---|---|
| `undefined reference` at link |  |  |  |  |  |
| heap use-after-free report suspected |  |  |  |  |  |
| pipe consumer waits forever |  |  |  |  |  |
| serialized multi-byte field is reversed |  |  |  |  |  |
| child appears not to exec target |  |  |  |  |  |
| `record.count` mysteriously becomes zero |  |  |  |  |  |
| open fails on one path |  |  |  |  |  |
| signed arithmetic wraps unexpectedly |  |  |  |  |  |
| program bytes are correct but linked symbol is missing |  |  |  |  |  |
| decoder returns wrong value with sanitizer-clean run |  |  |  |  |  |

Candidate evidence families: GDB/watchpoint, ASan, UBSan, return+`errno`, strace, `/proc`, linker+`nm/readelf`, golden bytes+`od`.
