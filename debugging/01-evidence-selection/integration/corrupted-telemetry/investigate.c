#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
struct record{uint8_t version,kind;uint16_t flags;uint32_t value,sequence;};
static uint16_t le16(const unsigned char*p){return(uint16_t)((uint16_t)p[0]|((uint16_t)p[1]<<8));}static uint32_t le32(const unsigned char*p){return(uint32_t)p[0]|((uint32_t)p[1]<<8)|((uint32_t)p[2]<<16)|((uint32_t)p[3]<<24);}static uint32_t be32(const unsigned char*p){return((uint32_t)p[0]<<24)|((uint32_t)p[1]<<16)|((uint32_t)p[2]<<8)|p[3];}
static int decode(struct record*d,const unsigned char*b,size_t n){struct record t;if(n<12)return EMSGSIZE;if(b[0]!=1)return EINVAL;t.version=b[0];t.kind=b[1];t.flags=le16(b+2);t.value=le32(b+4);t.sequence=le32(b+8);*d=t;return 0;}
static int short_fault(void){unsigned char*p=malloc(3);if(!p)return 1;p[0]=1;p[1]=2;p[2]=3;volatile uint32_t v=le32(p);printf("%u\n",v);free(p);return 0;}
static int memory_fault(void){struct{uint32_t*p;}h={0};uint32_t*p=malloc(sizeof*p);if(!p)return 1;*p=0x12345678;h.p=p;free(p);printf("value=0x%08x\n",*h.p);return 0;}
static void state_fault(struct record*r){r->sequence=0;}
int main(int argc,char**argv){const unsigned char g[12]={1,2,0x34,0x12,0x78,0x56,0x34,0x12,0xef,0xcd,0xab,0x90};struct record r={0};if(argc!=2){fprintf(stderr,"modes: good short wrong-endian memory-fault state-change\n");return 2;}if(!strcmp(argv[1],"short"))return short_fault();if(!strcmp(argv[1],"memory-fault"))return memory_fault();if(!strcmp(argv[1],"wrong-endian")){printf("wrong value=0x%08x expected=0x12345678\n",be32(g+4));return 1;}if(decode(&r,g,sizeof g))return 1;if(!strcmp(argv[1],"state-change")){state_fault(&r);printf("sequence=0x%08x expected=0x90abcdef\n",r.sequence);return 1;}if(!strcmp(argv[1],"good")){printf("kind=%u flags=0x%04x value=0x%08x seq=0x%08x\n",r.kind,r.flags,r.value,r.sequence);return r.value==0x12345678&&r.sequence==0x90abcdef?0:1;}return 2;}
