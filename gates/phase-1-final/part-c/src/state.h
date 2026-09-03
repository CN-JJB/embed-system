#ifndef PART_C_STATE_H
#define PART_C_STATE_H

#include <stdint.h>

extern const char g_firmware_tag[];
extern const char *g_firmware_version;
extern int32_t g_initialized_config;
extern int32_t g_runtime_error_counter;

int32_t get_hardware_calibration_offset(void);

#endif /* PART_C_STATE_H */
