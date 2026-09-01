# M07 Challenge Solution Reasoning

Reference: `telemetry_codec_solution.c` plus learner tests.

The reference never uses `sizeof(struct)` as wire size. It requires 8-bit octets, writes declared offsets, converts the `int32_t` representation via `memcpy` to/from a `uint32_t` object, and only then performs explicit LE encoding. Decode parses a local temporary and publishes `*dst` only after complete validation.

Reviewer:

    make
    ./challenge_solution

Verified: zero, non-palindromic signed value, INT32_MIN/max unsigned fields, invalid version, short input, unchanged output on failure.
