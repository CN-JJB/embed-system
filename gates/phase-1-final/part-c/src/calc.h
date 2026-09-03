#ifndef PART_C_CALC_H
#define PART_C_CALC_H

#include <stdint.h>

/* Global function declared in calc.c */
int64_t compute_scaled_metric(int32_t val, int32_t scale);

/* External dependency expected by calc.c */
int32_t get_hardware_calibration_offset(void);

#endif /* PART_C_CALC_H */
