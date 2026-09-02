# Fault Station F4 — Bad Record Boundary

## Objective
Diagnose and isolate input formatting and boundary validation failures (truncated frames, delimiter errors, range errors) using byte inspection rather than concurrency tools.

## Prerequisites
- 12-octet explicit little-endian wire format specification.
- Telemetry text format: `<timestamp_ns>,<sensor_id>,<scaled_value>\n`.

## Environment
- Linux / POSIX C17 environment.
- Tool: `hexdump -C`, `od -tx1`, unit test harness.

## Build & Run
```bash
make build/fault_f4
./build/fault_f4
```

## Expected Observation
The station verifies parser error codes:
```
1. Truncated binary frame (10 bytes): codec_rc=-1 (expected -1)
2. Malformed text missing comma delimiters: parse_rc=-2 (expected -2)
3. Out-of-range sensor ID: parse_rc=-4 (expected -4)
>>> F4 VERIFIED: Boundary failures correctly identified by byte/format checks. <<<
```

## Evidence Question
Why is ThreadSanitizer or GDB thread inspection the wrong first tool when a parser reports record corruption? What byte-level inspection command reveals a short binary record?

## Verification Status
- **VERIFIED**: Deterministically returns boundary error codes.

## Cleanup
```bash
rm -f build/fault_f4
```
