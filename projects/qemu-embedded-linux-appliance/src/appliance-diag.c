/*
 * appliance-diag -- P3-M08 original target diagnostic utility.
 *
 * Minimal, synchronous, no network / daemon / arguments:
 * prints one bounded fact set to stdout and always exits 0.
 *
 * Output contract (exact line prefixes, checked by the runtime binder):
 *   APPLIANCE-DIAG-BEGIN
 *   SOURCE-REV=<compile-time rev>
 *   KERNEL-RELEASE=<uname release, or UNAVAILABLE>
 *   APPLIANCE-RELEASE=<first line of /etc/appliance-release>
 *   DT-MODEL=<first line of /sys/firmware/devicetree/base/model, or UNAVAILABLE>
 *   UPTIME-SEC=<integer seconds from /proc/uptime, or UNAVAILABLE>
 *   MEM-AVAILABLE-KB=<MemAvailable kB from /proc/meminfo, or UNAVAILABLE>
 *   APPLIANCE-DIAG-END
 *
 * NOTE: the APPLIANCE-OVERLAY-BOOT-MARKER line is emitted by
 * overlay/etc/init.d/S99appliance-diag before exec'ing this program,
 * so the boot log proves the overlay init script ran, not just the binary.
 */
#include <stdio.h>
#include <string.h>
#include <sys/utsname.h>

#ifndef APPLIANCE_DIAG_SOURCE_REV
#define APPLIANCE_DIAG_SOURCE_REV "1.0"
#endif

static int print_first_line(const char *path, const char *label)
{
	FILE *fp = fopen(path, "r");
	char buf[512];

	if (fp == NULL) {
		printf("%s=UNAVAILABLE\n", label);
		return -1;
	}
	if (fgets(buf, sizeof(buf), fp) == NULL) {
		fclose(fp);
		printf("%s=EMPTY\n", label);
		return -1;
	}
	fclose(fp);
	buf[strcspn(buf, "\r\n")] = '\0';
	if (buf[0] == '\0') {
		printf("%s=EMPTY\n", label);
		return -1;
	}
	printf("%s=%s\n", label, buf);
	return 0;
}

static void print_uptime_sec(void)
{
	FILE *fp = fopen("/proc/uptime", "r");
	double up = 0.0;

	if (fp == NULL) {
		printf("UPTIME-SEC=UNAVAILABLE\n");
		return;
	}
	if (fscanf(fp, "%lf", &up) != 1) {
		fclose(fp);
		printf("UPTIME-SEC=UNAVAILABLE\n");
		return;
	}
	fclose(fp);
	printf("UPTIME-SEC=%d\n", (int)up);
}

static void print_mem_available(void)
{
	FILE *fp = fopen("/proc/meminfo", "r");
	char line[512];

	if (fp == NULL) {
		printf("MEM-AVAILABLE-KB=UNAVAILABLE\n");
		return;
	}
	while (fgets(line, sizeof(line), fp) != NULL) {
		unsigned long kb = 0;
		if (sscanf(line, "MemAvailable: %lu kB", &kb) == 1) {
			printf("MEM-AVAILABLE-KB=%lu\n", kb);
			fclose(fp);
			return;
		}
	}
	fclose(fp);
	printf("MEM-AVAILABLE-KB=UNAVAILABLE\n");
}

int main(void)
{
	struct utsname uts;

	printf("APPLIANCE-DIAG-BEGIN\n");
	printf("SOURCE-REV=" APPLIANCE_DIAG_SOURCE_REV "\n");

	if (uname(&uts) == 0 && uts.release[0] != '\0')
		printf("KERNEL-RELEASE=%s\n", uts.release);
	else
		printf("KERNEL-RELEASE=UNAVAILABLE\n");

	print_first_line("/etc/appliance-release", "APPLIANCE-RELEASE");
	print_first_line("/sys/firmware/devicetree/base/model", "DT-MODEL");
	print_uptime_sec();
	print_mem_available();
	printf("APPLIANCE-DIAG-END\n");
	return 0;
}
