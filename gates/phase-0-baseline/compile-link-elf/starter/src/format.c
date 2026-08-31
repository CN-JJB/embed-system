#include <stdio.h>
#include <stddef.h>

/* This function intentionally has internal linkage although another translation unit
 * expects a public symbol with the same spelling.
 */
static int format_total(char *dst, size_t cap, int total, int dropped)
{
    return snprintf(dst, cap, "baseline total=%d dropped=%d", total, dropped);
}

/* Keep the local function referenced so optimizers/toolchains retain it in the object. */
int format_self_test(void)
{
    char buf[8];
    return format_total(buf, sizeof buf, 0, 0);
}
