#ifndef TELEMETRY_CODEC_H
#define TELEMETRY_CODEC_H
#include <stddef.h>
#include <stdint.h>
#define TELEMETRY_WIRE_SIZE 12u
#define TELEMETRY_VERSION 1u
struct telemetry_record { uint8_t version; uint8_t kind; uint16_t flags; int32_t value; uint32_t sequence; };
int telemetry_encode(unsigned char *dst,size_t dst_len,const struct telemetry_record *src);
int telemetry_decode(struct telemetry_record *dst,const unsigned char *src,size_t src_len);
#endif
