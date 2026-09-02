#define _POSIX_C_SOURCE 200809L
#include "codec.h"
#include "parser.h"
#include "queue.h"
#include <assert.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

struct sink_ctx {
    struct telemetry_record r[4];
    size_t n;
};

static int collect(const struct telemetry_record *r, void *p) {
    struct sink_ctx *s = p;

    if (s->n >= 4)
        return -1;
    s->r[s->n++] = *r;
    return 0;
}

static int parse_text(const char *s, struct sink_ctx *ctx) {
    int p[2];
    int rc;
    size_t len = strlen(s);

    assert(pipe(p) == 0);
    assert(write(p[1], s, len) == (ssize_t)len);
    assert(close(p[1]) == 0);
    rc = parse_text_fd(p[0], collect, ctx, 0);
    assert(close(p[0]) == 0);
    return rc;
}

static void test_parser(void) {
    struct sink_ctx s = {0};
    int p[2];
    volatile sig_atomic_t stop = 1;

    assert(parse_text("1 2 -3 4\n255 65535 2147483647 4294967295\n", &s)
           == PARSER_OK);
    assert(s.n == 2 && s.r[0].value == -3 && s.r[1].kind == 255);

    memset(&s, 0, sizeof s);
    assert(parse_text("1 2 3 4 trailing\n", &s) == PARSER_INVALID);

    memset(&s, 0, sizeof s);
    assert(parse_text("256 0 0 0\n", &s) == PARSER_INVALID);

    /*
     * Keep the pipe writer open: without the pre-read stop check this call
     * would block waiting for input even though shutdown was already
     * requested.
     */
    assert(pipe(p) == 0);
    assert(parse_text_fd(p[0], collect, &s, &stop) == PARSER_STOPPED);
    assert(close(p[0]) == 0);
    assert(close(p[1]) == 0);
}

static void test_codec(void) {
    struct telemetry_record r = {1, 2, 0x1234, -2, 0x78563412u};
    struct telemetry_record o = {0};
    uint8_t b[12];
    uint8_t gold[12] = {
        1, 2, 0x34, 0x12,
        0xfe, 0xff, 0xff, 0xff,
        0x12, 0x34, 0x56, 0x78
    };

    assert(telemetry_encode_le(&r, b) == CODEC_OK);
    assert(memcmp(b, gold, sizeof gold) == 0);
    assert(telemetry_decode_le(b, sizeof b, &o) == CODEC_OK);
    assert(o.value == -2 && o.sequence == 0x78563412u);

    r.value = INT32_MIN;
    assert(telemetry_encode_le(&r, b) == CODEC_OK);
    assert(b[4] == 0x00 && b[5] == 0x00 && b[6] == 0x00 && b[7] == 0x80);
    assert(telemetry_decode_le(b, sizeof b, &o) == CODEC_OK);
    assert(o.value == INT32_MIN);

    assert(telemetry_decode_le(b, sizeof b - 1, &o) == CODEC_SHORT);
    b[0] = 2;
    assert(telemetry_decode_le(b, sizeof b, &o) == CODEC_VERSION);
}

struct push_ctx {
    struct record_queue *q;
    struct telemetry_record r;
    int rc;
};

static void *pusher(void *p) {
    struct push_ctx *c = p;
    c->rc = record_queue_push(c->q, &c->r);
    return 0;
}

struct pop_ctx {
    struct record_queue *q;
    int rc;
    struct telemetry_record r;
};

static void *popper(void *p) {
    struct pop_ctx *c = p;
    c->rc = record_queue_pop(c->q, &c->r);
    return 0;
}

static void test_queue(void) {
    struct record_queue q;
    struct telemetry_record r = {1, 1, 0, 7, 1};
    struct telemetry_record o;
    struct pop_ctx c;
    struct push_ctx pc;
    pthread_t t;

    assert(record_queue_init(&q) == QUEUE_OK);
    assert(record_queue_push(&q, &r) == QUEUE_OK);
    r.sequence = 2;
    assert(record_queue_push(&q, &r) == QUEUE_OK);
    assert(record_queue_pop(&q, &o) == QUEUE_OK && o.sequence == 1);
    assert(record_queue_pop(&q, &o) == QUEUE_OK && o.sequence == 2);
    assert(record_queue_close(&q) == QUEUE_OK);
    assert(record_queue_close(&q) == QUEUE_OK);
    assert(record_queue_pop(&q, &o) == QUEUE_CLOSED);
    assert(record_queue_destroy(&q) == QUEUE_OK);

    assert(record_queue_init(&q) == QUEUE_OK);
    memset(&c, 0, sizeof c);
    c.q = &q;
    assert(pthread_create(&t, 0, popper, &c) == 0);
    assert(record_queue_close(&q) == QUEUE_OK);
    assert(pthread_join(t, 0) == 0);
    assert(c.rc == QUEUE_CLOSED);
    assert(record_queue_destroy(&q) == QUEUE_OK);

    assert(record_queue_init(&q) == QUEUE_OK);
    for (size_t i = 0; i < QUEUE_CAPACITY; ++i) {
        r.sequence = (uint32_t)i;
        assert(record_queue_push(&q, &r) == QUEUE_OK);
    }

    pc.q = &q;
    pc.r = r;
    pc.rc = 99;
    assert(pthread_create(&t, 0, pusher, &pc) == 0);
    assert(record_queue_pop(&q, &o) == QUEUE_OK);
    assert(pthread_join(t, 0) == 0);
    assert(pc.rc == QUEUE_OK);
    assert(record_queue_close(&q) == QUEUE_OK);
    while (record_queue_pop(&q, &o) == QUEUE_OK)
        ;
    assert(record_queue_destroy(&q) == QUEUE_OK);
}

int main(void) {
    test_parser();
    test_codec();
    test_queue();
    puts("unit: ok");
    return 0;
}
