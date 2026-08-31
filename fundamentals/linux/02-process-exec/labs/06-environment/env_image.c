#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
int main(void)
{
    printf("env_image pid=%ld DEMO_COLOR=%s\n", (long)getpid(), getenv("DEMO_COLOR") ? getenv("DEMO_COLOR") : "<unset>");
    return 0;
}
