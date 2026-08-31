#include <stdint.h>
#include <stdio.h>
#include <string.h>

struct host_record { uint8_t version, type; uint16_t flags; uint32_t value, sequence; };
static void put16(unsigned char *p,uint16_t v){p[0]=(unsigned char)v;p[1]=(unsigned char)(v>>8);}
static void put32(unsigned char *p,uint32_t v){for(unsigned i=0;i<4;i++)p[i]=(unsigned char)(v>>(8u*i));}
static int save(const char *path,const void *p,size_t n){FILE*f=fopen(path,"wb");if(!f)return 1;size_t w=fwrite(p,1,n,f);int c=fclose(f);return w==n&&c==0?0:1;}
int main(void)
{
    struct host_record r={1,2,UINT16_C(0x1234),UINT32_C(0x12345678),UINT32_C(0x90abcdef)};
    unsigned char wire[12]={0}; wire[0]=r.version;wire[1]=r.type;put16(wire+2,r.flags);put32(wire+4,r.value);put32(wire+8,r.sequence);
    if(save("raw.bin",&r,sizeof r)||save("wire.bin",wire,sizeof wire))return 1;
    printf("host object size=%zu, wire contract size=%zu\n",sizeof r,sizeof wire);
    puts("Compare with: od -An -tx1 -v raw.bin; od -An -tx1 -v wire.bin");
    return 0;
}
