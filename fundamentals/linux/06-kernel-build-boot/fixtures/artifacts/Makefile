CROSS_COMPILE ?= arm-none-linux-gnueabihf-

ifneq ($(MAKECMDGOALS),clean)
  ifeq ($(shell which $(CROSS_COMPILE)gcc 2>/dev/null),)
    $(error Cross-compiler '$(CROSS_COMPILE)gcc' not found in PATH. Pass: make CROSS_COMPILE=arm-linux-gnueabihf-)
  endif
endif

CC := $(CROSS_COMPILE)gcc
NM := $(CROSS_COMPILE)nm
ifeq ($(shell which $(NM) 2>/dev/null),)
  NM := nm
endif

.PHONY: all clean

# SYNTHETIC PEDAGOGICAL STATIC FIXTURE — NOT A LINUX KERNEL BUILD
# These artifacts are purely for fast host-side static ELF/symbol checks.
all: vmlinux System.map stale_System.map arch/arm/boot/zImage

vmlinux: vmlinux_kernel_symbols.S vmlinux.lds
	$(CC) -nostdlib -T vmlinux.lds -g vmlinux_kernel_symbols.S -o $@

System.map: vmlinux
	$(NM) -n vmlinux | awk '{print $$1, $$2, $$3}' > $@

stale_System.map: System.map
	# Create mismatched / shifted symbol map representing stale prior build
	awk '{if ($$3 == "start_kernel") print "c0804000", $$2, $$3; else if ($$3 == "rest_init") print "c0808000", $$2, $$3; else print $$0}' $< > $@

arch/arm/boot/zImage: vmlinux
	mkdir -p arch/arm/boot
	python3 -c "import struct; hdr = bytearray(0x40); struct.pack_into('<I', hdr, 0x24, 0x016f2818); open('arch/arm/boot/zImage', 'wb').write(hdr + b'\x00' * 4096)"

clean:
	rm -f vmlinux System.map stale_System.map
	rm -rf arch/
