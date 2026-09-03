#include <stdio.h>
#include <inttypes.h>
#include "calc.h"
#include "state.h"

int main(void) {
    printf("Firmware Tag: %s\n", g_firmware_tag);
    printf("Firmware Version: %s\n", g_firmware_version);
    int64_t result = compute_scaled_metric(50, 4);
    printf("Calculated Result: %" PRId64 "\n", result);
    return 0;
}
