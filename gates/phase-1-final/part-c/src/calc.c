#include "calc.h"

/* Static helper with internal linkage: should appear as LOCAL symbol */
static int32_t internal_clamp(int32_t val, int32_t min_v, int32_t max_v) {
    if (val < min_v) return min_v;
    if (val > max_v) return max_v;
    return val;
}

/* Global function with external linkage: should appear as GLOBAL symbol */
int64_t compute_scaled_metric(int32_t val, int32_t scale) {
    int32_t clamped = internal_clamp(val, -1000, 1000);
    /* External call creates an unresolved relocation entry in calc.o */
    int32_t offset = get_hardware_calibration_offset();
    return ((int64_t)clamped * scale) + offset;
}
