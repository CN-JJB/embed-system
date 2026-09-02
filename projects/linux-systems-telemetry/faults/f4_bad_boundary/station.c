#define _DEFAULT_SOURCE
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <assert.h>
#include "codec.h"
#include "parser.h"

/*
 * M10 Fault Station F4: Bad Record Boundary
 *
 * Demonstrates parser/codec behavior when presented with:
 * 1. Truncated binary frame (length < 12 octets).
 * 2. Unsupported binary wire version.
 * 3. Malformed text line (missing fields or trailing tokens).
 * 4. Out-of-range sensor value (kind > UINT8_MAX).
 *
 * First diagnostic evidence must be byte/offset inspection, not threading tools.
 */

struct test_sink_ctx {
    size_t count;
    struct telemetry_record last;
};

static int test_sink(const struct telemetry_record *r, void *ctx) {
    struct test_sink_ctx *c = (struct test_sink_ctx *)ctx;
    c->last = *r;
    c->count++;
    return 0;
}

static int parse_string(const char *str) {
    int p[2];
    assert(pipe(p) == 0);
    size_t len = strlen(str);
    assert(write(p[1], str, len) == (ssize_t)len);
    close(p[1]);

    struct test_sink_ctx ctx = {0};
    int rc = parse_text_fd(p[0], test_sink, &ctx, NULL);
    close(p[0]);
    return rc;
}

int main(void) {
    printf("=== M10 Fault Station F4: Bad Record Boundary ===\n");

    /* Sub-case 1: Truncated binary wire frame (< 12 octets) */
    uint8_t short_wire[10] = { 0 };
    struct telemetry_record out;
    int codec_rc = telemetry_decode_le(short_wire, sizeof(short_wire), &out);
    printf("1. Truncated binary frame (10 bytes): codec_rc=%d (expected CODEC_SHORT=%d)\n",
           codec_rc, CODEC_SHORT);
    assert(codec_rc == CODEC_SHORT);

    /* Sub-case 2: Invalid version in wire frame */
    uint8_t bad_version_wire[TELEMETRY_WIRE_SIZE] = { 0 };
    bad_version_wire[0] = 99; /* Expected TELEMETRY_VERSION=1 */
    int ver_rc = telemetry_decode_le(bad_version_wire, sizeof(bad_version_wire), &out);
    printf("2. Bad binary wire version (99): codec_rc=%d (expected CODEC_VERSION=%d)\n",
           ver_rc, CODEC_VERSION);
    assert(ver_rc == CODEC_VERSION);

    /* Sub-case 3: Malformed text format (extra trailing token) */
    int trailing_rc = parse_string("1 2 3 4 trailing\n");
    printf("3. Malformed text with trailing token: parse_rc=%d (expected PARSER_INVALID=%d)\n",
           trailing_rc, PARSER_INVALID);
    assert(trailing_rc == PARSER_INVALID);

    /* Sub-case 4: Out-of-range field (kind 256 > UINT8_MAX) */
    int range_rc = parse_string("256 0 0 0\n");
    printf("4. Out-of-range field (kind=256): parse_rc=%d (expected PARSER_INVALID=%d)\n",
           range_rc, PARSER_INVALID);
    assert(range_rc == PARSER_INVALID);

    printf(">>> F4 VERIFIED: Boundary failures correctly identified by byte/format checks. <<<\n");
    return 0;
}
