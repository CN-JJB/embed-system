#include "../challenge/telemetry_codec.h"
#include <errno.h>
#include <limits.h>
#include <stdint.h>
#include <string.h>
_Static_assert(CHAR_BIT==8,"wire format is defined in 8-bit octets");
static void put16(unsigned char*p,uint16_t v){p[0]=(unsigned char)v;p[1]=(unsigned char)(v>>8);}
static void put32(unsigned char*p,uint32_t v){for(unsigned i=0;i<4;i++)p[i]=(unsigned char)(v>>(8u*i));}
static uint16_t get16(const unsigned char*p){return(uint16_t)((uint16_t)p[0]|((uint16_t)p[1]<<8));}
static uint32_t get32(const unsigned char*p){return(uint32_t)p[0]|((uint32_t)p[1]<<8)|((uint32_t)p[2]<<16)|((uint32_t)p[3]<<24);}
static uint32_t signed_bits(int32_t v){uint32_t u;memcpy(&u,&v,sizeof u);return u;}
static int32_t signed_from_bits(uint32_t u){int32_t v;memcpy(&v,&u,sizeof v);return v;}
int telemetry_encode(unsigned char *dst,size_t n,const struct telemetry_record *s)
{
    if(!dst||!s||s->version!=TELEMETRY_VERSION)return EINVAL;
    if(n<TELEMETRY_WIRE_SIZE)return EMSGSIZE;
    dst[0]=s->version;dst[1]=s->kind;put16(dst+2,s->flags);put32(dst+4,signed_bits(s->value));put32(dst+8,s->sequence);return 0;
}
int telemetry_decode(struct telemetry_record *dst,const unsigned char *src,size_t n)
{
    struct telemetry_record t;if(!dst||!src)return EINVAL;if(n<TELEMETRY_WIRE_SIZE)return EMSGSIZE;if(src[0]!=TELEMETRY_VERSION)return EINVAL;
    t.version=src[0];t.kind=src[1];t.flags=get16(src+2);t.value=signed_from_bits(get32(src+4));t.sequence=get32(src+8);*dst=t;return 0;
}
