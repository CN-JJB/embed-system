#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
struct record { uint8_t version,type; uint16_t flags; uint32_t value,sequence; };
static void bad_host_write(unsigned char *p,uint32_t v){memcpy(p,&v,sizeof v);}
static uint32_t bad_short(const unsigned char*p){return (uint32_t)p[0]|((uint32_t)p[1]<<8)|((uint32_t)p[2]<<16)|((uint32_t)p[3]<<24);}
static uint32_t bad_unaligned(const unsigned char *p){const uint32_t *q=(const uint32_t *)(p+1);return *q;}
static int bad_partial(struct record *d,const unsigned char*p,size_t n){d->version=p[0];d->type=p[1];if(n<12)return -1;return 0;}
int main(int argc,char**argv)
{
    if(argc!=2){fprintf(stderr,"modes: raw endian unaligned short partial\n");return 2;}
    if(strcmp(argv[1],"raw")==0){struct record r={1,2,0x1234,0x12345678,0x90abcdef};unsigned char raw[sizeof r];memcpy(raw,&r,sizeof r);printf("raw copied %zu object bytes; wire contract=12\n",sizeof raw);return 0;}
    if(strcmp(argv[1],"endian")==0){unsigned char b[4]={0};const unsigned char golden[4]={0x78,0x56,0x34,0x12};bad_host_write(b,UINT32_C(0x12345678));printf("host write bytes=%02x %02x %02x %02x; LE golden %s\n",b[0],b[1],b[2],b[3],memcmp(b,golden,4)==0?"MATCH":"DIFFER");return 0;}
    if(strcmp(argv[1],"unaligned")==0){unsigned char b[8]={0,1,2,3,4,5,6,7};printf("%u\n",bad_unaligned(b));return 0;}
    if(strcmp(argv[1],"short")==0){unsigned char *p=malloc(3);if(!p)return 1;p[0]=1;p[1]=2;p[2]=3;printf("%u\n",bad_short(p));free(p);return 0;}
    if(strcmp(argv[1],"partial")==0){unsigned char b[2]={1,2};struct record r={9,9,9,9,9};int rc=bad_partial(&r,b,sizeof b);printf("rc=%d published version=%u type=%u\n",rc,r.version,r.type);return 0;}
    return 2;
}
