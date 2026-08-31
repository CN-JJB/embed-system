#include <stdio.h>
#include <string.h>

int main(void)
{
    char line[128];
    while (fgets(line, sizeof line, stdin) != NULL) {
        if (strncmp(line, "KEEP ", 5) == 0) {
            fputs(line, stdout);
        }
    }
    return ferror(stdin) ? 1 : 0;
}
