#ifndef FORMAT_H
#define FORMAT_H
#include <stddef.h>
extern int report_width;
int format_report(char *buf, size_t cap, int total, int samples);
#endif
