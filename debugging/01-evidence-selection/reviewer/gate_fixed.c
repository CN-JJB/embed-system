#include <stdint.h>
#include <stdio.h>
static uint32_t le32(const unsigned char*p){return(uint32_t)p[0]|((uint32_t)p[1]<<8)|((uint32_t)p[2]<<16)|((uint32_t)p[3]<<24);}
int main(void){const unsigned char b[4]={0x78,0x56,0x34,0x12};uint32_t v=le32(b);printf("reference byte regression: 0x%08x\n",v);return v==0x12345678?0:1;}
