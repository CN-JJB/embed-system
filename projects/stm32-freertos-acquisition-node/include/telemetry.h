#ifndef TELEMETRY_H
#define TELEMETRY_H

#include <stdint.h>
#include "FreeRTOS.h"

/**
 * @brief Fixed-size telemetry record produced by Task_Process and consumed by Task_Comm.
 */
typedef struct {
    uint32_t sequence;      /* Acquisition batch sequence number */
    TickType_t timestamp;   /* Kernel tick timestamp */
    uint16_t min;           /* Minimum sample in 64-sample batch (0..4095) */
    uint16_t max;           /* Maximum sample in 64-sample batch (0..4095) */
    uint16_t avg;           /* Integer average sample (0..4095) */
    uint16_t rms;           /* Integer RMS sample (0..4095) */
    uint16_t drop_count;    /* Cumulative acquisition drop count */
} TelemetryRecord_t;

#endif /* TELEMETRY_H */
