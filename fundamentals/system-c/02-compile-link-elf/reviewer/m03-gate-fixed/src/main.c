#include "report.h"
#include "sampler.h"
int main(void)
{
    sampler_record(3);
    sampler_record(8);
    report_emit();
    return 0;
}
