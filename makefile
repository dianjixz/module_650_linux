# SPDX-FileCopyrightText: 2024 M5Stack Technology CO LTD
#
# SPDX-License-Identifier: MIT

PATCH_DIR := patches
SRC_DIR := build/linux-5.15.73
PATCHES := $(wildcard patches/*.patch)
DTSS := $(wildcard linux-dts/*.dts*)
CONFIG_FILES := $(wildcard *.config)
LINUX_TAR_SHA := 380a230cea3819eb2640aa4f4719237aefa60aecf18ce434f15d8fc0ab0b0a65
LINUX_TAR_NAME := $(LINUX_TAR_SHA)-linux-5.15.73.tar.gz
LINUX_TAR_URL := https://mirror.tuna.tsinghua.edu.cn/kernel/v5.x/linux-5.15.73.tar.gz

# AX630C_KERNEL_PARAM := ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu-
# KERNEL_MAKE := cd $(SRC_DIR) ; $(MAKE) $(AX630C_KERNEL_PARAM)

ifeq ($(strip $(M)),)
KERNEL_MAKE := $(MAKE) -C $(SRC_DIR)
else
KERNEL_MAKE := $(MAKE) -C $(SRC_DIR) PWD=$(PWD)
endif

%:
	@ if [ "$(MAKECMDGOALS)" != "build_init" ] ; then \
		$(MAKE) build_init ; \
		$(KERNEL_MAKE)  $(MAKECMDGOALS) ; \
	fi

build_init:Configuring

Extracting:
	$(MAKE) build/check_build.tmp
	$(MAKE) build/check_dts.tmp

Patching:Extracting 
	$(MAKE) build/check_patch.tmp

Configuring:Patching 
	$(MAKE) build/check_config.tmp  

build/check_build.tmp:$(PATCHES)
	[ -d 'build' ] || mkdir build
	@if [ -f '.stamp_extracted' ] ; then \
		[ -f '../../../dl/$(LINUX_TAR_NAME)' ] || wget --passive-ftp -nd -t 3 -O '../../../dl/$(LINUX_TAR_NAME)' '$(LINUX_TAR_URL)' ; \
		calculated_hash=$$(sha256sum ../../../dl/$(LINUX_TAR_NAME) | awk '{ print $$1 }'); \
		if [ "$$calculated_hash" != "$(LINUX_TAR_SHA)" ]; then \
			rm ../../../dl/$(LINUX_TAR_NAME) ; \
			exit 1; \
		fi ; \
		[ -d 'build/linux-4.19.125' ] || tar zxf ../../../dl/$(LINUX_TAR_NAME) -C build/ ; \
	else \
		[ -f '.$(LINUX_TAR_NAME)' ] || wget --passive-ftp -nd -t 3 -O '.$(LINUX_TAR_NAME)' '$(LINUX_TAR_URL)' ; \
		calculated_hash=$$(sha256sum .$(LINUX_TAR_NAME) | awk '{ print $$1 }'); \
		if [ "$$calculated_hash" != "$(LINUX_TAR_SHA)" ]; then \
			rm .$(LINUX_TAR_NAME) ; \
			exit 1; \
		fi ; \
		[ -d 'build/linux-4.19.125' ] || tar zxf .$(LINUX_TAR_NAME) -C build/ ; \
	fi
	@[ -L 'arch' ] || ln -s $(SRC_DIR)/arch arch
	@[ -L 'scripts' ] || ln -s $(SRC_DIR)/scripts scripts
	@[ -L 'include' ] || ln -s $(SRC_DIR)/scripts include
	@rm -f build/check_build.tmp
	@touch build/check_build.tmp

build/check_dts.tmp:$(DTSS)
	@cp linux-dts/* $(SRC_DIR)/arch/arm64/boot/dts/
	@rm -f build/check_dts.tmp
	@touch build/check_dts.tmp

build/check_patch.tmp:$(PATCHES)
	@[ -d 'build/linux-4.19.125/arch/arm64/boot/dts/axera' ] || {\
		for patch in $^; do \
			echo "Applying $$patch..."; \
			patch -p1 -d build <$$patch || { echo "Failed to apply $$patch"; exit 1; } \
		done ; \
	}
	@rm -f build/check_patch.tmp
	@touch build/check_patch.tmp

build/check_config.tmp:$(CONFIG_FILES)
	@[ -f '$(SRC_DIR)/arch/arm64/configs/m5stack_AX650C_emmc_arm64_defconfig' ] || { cat $(SRC_DIR)/arch/arm64/configs/axera_AX650A_emmc_defconfig fragment-03-systemd.config linux-disable.config linux-enable-m5stack.config > $(SRC_DIR)/arch/arm64/configs/m5stack_AX650C_emmc_arm64_defconfig ; }
	@rm -f build/check_config.tmp
	@touch build/check_config.tmp

distclean:
	@rm -f build -rf
	@rm -f arch
	@rm -f scripts
	@rm -f include
linux-distclean:
	@$(KERNEL_MAKE) distclean
	@rm -f build/check_config.tmp 