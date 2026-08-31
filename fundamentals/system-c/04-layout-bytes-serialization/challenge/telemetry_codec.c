#include "telemetry_codec.h"
#include <errno.h>
int telemetry_encode(unsigned char *dst,size_t dst_len,const struct telemetry_record *src)
{
    (void)dst;(void)dst_len;(void)src;return ENOSYS;
}
int telemetry_decode(struct telemetry_record *dst,const unsigned char *src,size_t src_len)
{
    (void)dst;(void)src;(void)src_len;return ENOSYS;
}
