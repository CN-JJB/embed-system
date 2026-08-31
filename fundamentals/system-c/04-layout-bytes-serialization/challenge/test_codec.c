#include "telemetry_codec.h"
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
static int check(int ok,const char *name){ if(!ok){fprintf(stderr,"FAIL: %s\n",name);return 1;}return 0; }
int main(void)
{
    const struct telemetry_record r={1,2,UINT16_C(0x1234),INT32_C(-19088743),UINT32_C(0x89abcdef)};
    const unsigned char golden[12]={0x01,0x02,0x34,0x12,0x99,0xba,0xdc,0xfe,0xef,0xcd,0xab,0x89};
    unsigned char out[12]; memset(out,0xa5,sizeof out);
    struct telemetry_record d={9,9,9,9,9}; struct telemetry_record before=d;
    int failures=0;
    failures+=check(telemetry_encode(out,sizeof out,&r)==0,"encode success");
    failures+=check(memcmp(out,golden,sizeof out)==0,"golden non-palindromic vector");
    failures+=check(telemetry_decode(&d,golden,sizeof golden)==0,"decode success");
    failures+=check(d.value==r.value && d.sequence==r.sequence,"round trip");
    d=before; failures+=check(telemetry_decode(&d,golden,5)==EMSGSIZE,"short input rejected");
    failures+=check(memcmp(&d,&before,sizeof d)==0,"decode failure leaves output unchanged");
    { unsigned char bad[12]; memcpy(bad,golden,12); bad[0]=2; d=before; failures+=check(telemetry_decode(&d,bad,12)==EINVAL,"invalid version rejected"); failures+=check(memcmp(&d,&before,sizeof d)==0,"version failure leaves output unchanged"); }
    { struct telemetry_record zero={1,0,0,0,0}; const unsigned char z[12]={1,0,0,0,0,0,0,0,0,0,0,0}; failures+=check(telemetry_encode(out,12,&zero)==0 && memcmp(out,z,12)==0,"zero vector"); }
    { struct telemetry_record edge={1,255,UINT16_MAX,INT32_MIN,UINT32_MAX}; const unsigned char x[12]={1,255,255,255,0,0,0,128,255,255,255,255}; failures+=check(telemetry_encode(out,12,&edge)==0 && memcmp(out,x,12)==0,"edge vector"); }
    return failures?1:0;
}
