# Challenge — Fixed Telemetry Record Codec

## Objective

从 starter `ENOSYS` 实现 fixed 12-octet little-endian codec；不使用 raw struct serialization 或 byte-buffer cast。

## Contract

`telemetry_record`: version u8, kind u8, flags u16, value int32, sequence u32. Wire offsets 0/1/2/4/8; sizes 1/1/2/4/4; all multi-byte fields LE; version=1; wire size=12.

`telemetry_decode()` failure leaves `*dst` unchanged. Encode validates pointer/version/length before writing. Supported implementation requires 8-bit octets and the exact-width integer types in the header.

## Prerequisites

M07 Labs 01–05.

## Environment

C17 strict warnings. No packed struct, no `*(uint32_t *)(buf+4)`, no raw struct copy as encoder.

## Estimated Time

**40–50 min**, inside M07 4.5 h MUST budget.

## AI Mode

**AI-Free first pass.** Docs allowed; reviewer solution isolated.

## Build

    make
    ./test_codec

Starter compiles but tests intentionally fail until implemented.

## Procedure

1. Reconstruct wire table.
2. Implement LE helpers.
3. Move `int32_t` representation without pointer-punning.
4. Precheck pointers/version/length.
5. Pass zero, non-palindromic, signed edge, invalid-version, short-input, unchanged-output tests.

## Expected Observation

Correct implementation exits 0; addresses/layout are not golden.

## Actual Verification Status

- starter strict build and seeded failing tests: **VERIFIED**;
- reviewer reference with all vectors/failure-state tests: **VERIFIED**.

## Failure Modes

Raw struct copy; host endian; reads before length check; partial `dst`; incompatible pointer cast.

## Debug Strategy

Start at first mismatching golden byte. ASan is useful only when the hypothesis is memory safety; endian mismatch should start with bytes.

## Challenge

Add another deterministic edge vector without changing wire contract.

## Cleanup

    make clean

## Sources

M07-S01/S04/S07/S11.
