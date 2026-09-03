#include "state.h"

const char g_firmware_tag[] = "FINAL_GATE_RELEASE";
const char *g_firmware_version = "v1.2.0";
int32_t g_initialized_config = 42;
int32_t g_runtime_error_counter;
static int32_t s_local_accumulator = 100;

int32_t get_hardware_calibration_offset(void) {
    return g_initialized_config + s_local_accumulator;
}
