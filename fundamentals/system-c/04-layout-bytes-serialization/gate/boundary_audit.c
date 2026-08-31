#include <errno.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#define WIRE 12u
struct rec { uint8_t version,kind; uint16_t flags; uint32_t value,sequence; };
#if defined(__GNUC__)
struct __attribute__((packed)) packed_rec { uint8_t version,kind; uint16_t flags; uint32_t value,sequence; };
#endif
static int raw_encode(unsigned char *out,size_t n,const struct rec*r){if(n<sizeof *r)return EMSGSIZE;memcpy(out,r,sizeof *r);return 0;}
static int bad_decode(struct rec*d,const unsigned char*b,size_t n){
    d->version=b[0]; d->kind=b[1];
    d->flags=(uint16_t)(((uint16_t)b[2]<<8)|b[3]);
    d->value=(uint32_t)b[4]|((uint32_t)b[5]<<8)|((uint32_t)b[6]<<16)|((uint32_t)b[7]<<24);
    if(n<WIRE)return EMSGSIZE;
    if(d->version!=1)return EINVAL;
    d->sequence=(uint32_t)b[8]|((uint32_t)b[9]<<8)|((uint32_t)b[10]<<16)|((uint32_t)b[11]<<24); return 0;
}
int main(int argc,char**argv){
    const unsigned char good[12]={1,2,0x34,0x12,0x78,0x56,0x34,0x12,0xef,0xcd,0xab,0x90}; struct rec r={0};
    if(argc>1&&strcmp(argv[1],"short")==0){unsigned char tiny[3]={1,2,3};return bad_decode(&r,tiny,sizeof tiny)==0?0:1;}
    printf("sizeof(rec)=%zu align=%zu\n",sizeof(struct rec),_Alignof(struct rec));
    if(bad_decode(&r,good,sizeof good)!=0)return 1;
    printf("flags=0x%04x value=0x%08x seq=0x%08x\n",r.flags,r.value,r.sequence);
    unsigned char out[sizeof r]; if(raw_encode(out,sizeof out,&r)!=0)return 1; puts("seeded raw object copy completed; this is not a portable wire contract"); return 0;
}
