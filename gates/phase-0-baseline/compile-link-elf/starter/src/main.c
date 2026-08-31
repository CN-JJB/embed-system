#include "metrics.h"
#include "report.h"

int main(void)
{
    metrics_add(1);
    metrics_add(3);
    report_print();
    return 0;
}
