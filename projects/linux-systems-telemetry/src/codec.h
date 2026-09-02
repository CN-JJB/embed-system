#ifndef CODEC_H
#define CODEC_H

#include <stddef.h>
#include <stdint.h>
#include "telemetry.h"

enum codec_status { CODEC_OK = 0, CODEC_SHORT = 1, CODEC_VERSION = 2, CODEC_UNSUPPORTED = 3 };
int telemetry_encode_le(const struct telemetry_record *r, uint8_t out[TELEMETRY_WIRE_SIZE]);
int telemetry_decode_le(const uint8_t *buf, size_t len, struct telemetry_record *out);

#endif
