#include <errno.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define WIRE_SIZE 12u
#define VERSION 1u
struct record { uint8_t version, type; uint16_t flags; uint32_t value, sequence; };
_Static_assert(CHAR_BIT == 8, "this octet wire exercise requires 8-bit C bytes");

static void put_u16_le(unsigned char *p, uint16_t v) { p[0]=(unsigned char)v; p[1]=(unsigned char)(v>>8); }
static void put_u32_le(unsigned char *p, uint32_t v) { for (unsigned i=0;i<4;i++) p[i]=(unsigned char)(v>>(8u*i)); }
static uint16_t get_u16_le(const unsigned char *p) { return (uint16_t)((uint16_t)p[0] | ((uint16_t)p[1]<<8)); }
static uint32_t get_u32_le(const unsigned char *p) { return (uint32_t)p[0] | ((uint32_t)p[1]<<8) | ((uint32_t)p[2]<<16) | ((uint32_t)p[3]<<24); }

static int encode(unsigned char *dst, size_t len, const struct record *r)
{
    if (!dst || !r || r->version != VERSION) return EINVAL;
    if (len < WIRE_SIZE) return EMSGSIZE;
    dst[0]=r->version; dst[1]=r->type; put_u16_le(dst+2,r->flags); put_u32_le(dst+4,r->value); put_u32_le(dst+8,r->sequence);
    return 0;
}
static int decode(struct record *dst, const unsigned char *src, size_t len)
{
    struct record tmp;
    if (!dst || !src) return EINVAL;
    if (len < WIRE_SIZE) return EMSGSIZE;
    if (src[0] != VERSION) return EINVAL;
    tmp.version=src[0]; tmp.type=src[1]; tmp.flags=get_u16_le(src+2); tmp.value=get_u32_le(src+4); tmp.sequence=get_u32_le(src+8);
    *dst=tmp; return 0;
}
static int same(const unsigned char *a,const unsigned char *b,size_t n){ return memcmp(a,b,n)==0; }
int main(void)
{
    const struct record r={1,2,UINT16_C(0x1234),UINT32_C(0x12345678),UINT32_C(0x90abcdef)};
    const unsigned char golden[WIRE_SIZE]={0x01,0x02,0x34,0x12,0x78,0x56,0x34,0x12,0xef,0xcd,0xab,0x90};
    unsigned char out[WIRE_SIZE]={0}; struct record decoded={0};
    if (encode(out,sizeof out,&r)!=0 || !same(out,golden,sizeof out) || decode(&decoded,out,sizeof out)!=0 || decoded.sequence!=r.sequence) return 1;
    puts("golden codec regression: PASS"); return 0;
}
