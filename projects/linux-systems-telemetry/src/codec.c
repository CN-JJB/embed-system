#include "codec.h"
#include <limits.h>

#if CHAR_BIT != 8
#error "Linux Systems Telemetry requires 8-bit octets"
#endif

static void put_u16le(uint8_t *p, uint16_t v) { p[0]=(uint8_t)v; p[1]=(uint8_t)(v>>8); }
static void put_u32le(uint8_t *p, uint32_t v) { p[0]=(uint8_t)v; p[1]=(uint8_t)(v>>8); p[2]=(uint8_t)(v>>16); p[3]=(uint8_t)(v>>24); }
static uint16_t get_u16le(const uint8_t *p) { return (uint16_t)((uint16_t)p[0] | ((uint16_t)p[1]<<8)); }
static uint32_t get_u32le(const uint8_t *p) { return (uint32_t)p[0] | ((uint32_t)p[1]<<8) | ((uint32_t)p[2]<<16) | ((uint32_t)p[3]<<24); }

int telemetry_encode_le(const struct telemetry_record *r, uint8_t out[TELEMETRY_WIRE_SIZE]) {
    if (r == 0 || out == 0 || r->version != TELEMETRY_VERSION) return CODEC_VERSION;
    out[0]=r->version; out[1]=r->kind; put_u16le(&out[2], r->flags); put_u32le(&out[4], (uint32_t)r->value); put_u32le(&out[8], r->sequence);
    return CODEC_OK;
}
int telemetry_decode_le(const uint8_t *buf, size_t len, struct telemetry_record *out) {
    if (buf == 0 || out == 0) return CODEC_UNSUPPORTED;
    if (len != TELEMETRY_WIRE_SIZE) return CODEC_SHORT;
    if (buf[0] != TELEMETRY_VERSION) return CODEC_VERSION;
    out->version=buf[0]; out->kind=buf[1]; out->flags=get_u16le(&buf[2]); out->value=(int32_t)get_u32le(&buf[4]); out->sequence=get_u32le(&buf[8]);
    return CODEC_OK;
}
