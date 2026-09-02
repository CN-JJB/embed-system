#ifndef TELEMETRY_H
#define TELEMETRY_H

#include <stdint.h>

#define TELEMETRY_VERSION 1u
#define TELEMETRY_WIRE_SIZE 12u

struct telemetry_record {
    uint8_t version;
    uint8_t kind;
    uint16_t flags;
    int32_t value;
    uint32_t sequence;
};

#endif
