/*
 * appliance-diag -- original Phase 3 diagnostic utility (P3-M06).
 *
 * Reports three facts that are each produced by a different layer of the
 * Buildroot pipeline, which is exactly why it is useful for provenance work:
 *
 *   1. the kernel release        -> produced by the Linux kernel package
 *   2. the appliance identity    -> produced by the root filesystem overlay
 *   3. the device tree model     -> produced by the kernel's DT consumption
 *
 * SOURCE-REV is intentionally emitted as one compile-time string literal so
 * reviewer tooling can inspect the built target binary and final image without
 * executing an ARM binary on the host. BUILD-ID is retained as a legacy alias.
 */
#include <stdio.h>
#include <string.h>
#include <sys/utsname.h>

#ifndef APPLIANCE_DIAG_SOURCE_REV
#define APPLIANCE_DIAG_SOURCE_REV "1.0"
#endif

static int print_file_line(const char *path, const char *label)
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
	printf("%s=%s\n", label, buf);
	return 0;
}

int main(void)
{
	struct utsname uts;

	printf("APPLIANCE-DIAG-BEGIN\n");
	printf("SOURCE-REV=" APPLIANCE_DIAG_SOURCE_REV "\n");
	printf("BUILD-ID=" APPLIANCE_DIAG_SOURCE_REV "\n");

	if (uname(&uts) == 0)
		printf("KERNEL-RELEASE=%s\n", uts.release);
	else
		printf("KERNEL-RELEASE=UNAVAILABLE\n");

	print_file_line("/etc/appliance-release", "APPLIANCE-RELEASE");
	print_file_line("/sys/firmware/devicetree/base/model", "DT-MODEL");

	printf("APPLIANCE-DIAG-END\n");
	return 0;
}
