#include "state.h"

/* Read-only constant array: placed in .rodata */
const char g_firmware_tag[] = "FINAL_GATE_RELEASE";

/* Read-only pointer: string literal in .rodata, pointer variable in .data */
const char *g_firmware_version = "v1.2.0";

/* Initialized global variable: placed in .data */
int32_t g_initialized_config = 42;

/* Uninitialized global variable: placed in .bss (or COMMON) */
int32_t g_runtime_error_counter;

/* Static initialized variable: placed in .data as LOCAL symbol */
static int32_t s_local_accumulator = 100;

int32_t get_hardware_calibration_offset(void) {
    return g_initialized_config + s_local_accumulator;
}
