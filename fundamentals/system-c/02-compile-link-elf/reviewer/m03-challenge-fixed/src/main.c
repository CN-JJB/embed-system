#include "registry.h"
#include "report.h"
int main(void)
{
    registry_add(4);
    registry_add(5);
    report_emit();
    return registry_total() == 9 && registry_limit() == 64 ? 0 : 1;
}
