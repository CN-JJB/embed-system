################################################################################
#
# appliance-diag
#
################################################################################

APPLIANCE_DIAG_VERSION = 1.0
APPLIANCE_DIAG_SITE = $(BR2_EXTERNAL_QEMU_VIRT_A7_PATH)/package/appliance-diag/src
APPLIANCE_DIAG_SITE_METHOD = local
APPLIANCE_DIAG_LICENSE = MIT
APPLIANCE_DIAG_LICENSE_FILES = LICENSE

define APPLIANCE_DIAG_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) \
		CC="$(TARGET_CC)" \
		CFLAGS="$(TARGET_CFLAGS)"
endef

define APPLIANCE_DIAG_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/appliance-diag \
		$(TARGET_DIR)/usr/bin/appliance-diag
endef

$(eval $(generic-package))
