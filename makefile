# SPDX-FileCopyrightText: 2024 M5Stack Technology CO LTD
# SPDX-License-Identifier: MIT

# ============================================================================
# 配置区域 - 根据需求修改此部分
# ============================================================================
THIS_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
# ----------------------------------------------------------------------------
# Linux 内核版本配置
# ----------------------------------------------------------------------------
LINUX_VERSION       := 5.15.73
LINUX_TAR_SHA       := 380a230cea3819eb2640aa4f4719237aefa60aecf18ce434f15d8fc0ab0b0a65

# 内核源码下载 URL（可选其他镜像）
# - https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-$(LINUX_VERSION).tar.gz
# - https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/linux-$(LINUX_VERSION).tar.gz
LINUX_TAR_URL       := https://mirror.tuna.tsinghua.edu.cn/kernel/v5.x/linux-$(LINUX_VERSION).tar.gz

# ----------------------------------------------------------------------------
# 板级配置
# ----------------------------------------------------------------------------
BOARD_NAME          := m5stack_AX650C
BOARD_ARCH          := arm64
BASE_DEFCONFIG      := axera_AX650A_emmc_defconfig
TARGET_DEFCONFIG    := $(BOARD_NAME)_emmc_$(BOARD_ARCH)_defconfig

# ----------------------------------------------------------------------------
# 目录配置
# ----------------------------------------------------------------------------
PATCH_DIR           := patches
DTS_DIR             := linux-dts
CONFIG_DIR          := defconfigs


# ----------------------------------------------------------------------------
# 下载目录配置
# ----------------------------------------------------------------------------
# 外部下载目录路径
DOWNLOAD_DIR        := $(THIS_DIR)/../../../dl

# ----------------------------------------------------------------------------
# 交叉编译配置（如需要请取消注释）
# ----------------------------------------------------------------------------
# ARCH              := arm64
# CROSS_COMPILE     := aarch64-none-linux-gnu-
# KERNEL_EXTRA_PARAMS := ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE)

# ============================================================================
# 内部变量 - 通常不需要修改
# ============================================================================
# 确定下载目录

DL_DIR := .
ifneq ($(wildcard $(DOWNLOAD_DIR)),)
	DL_DIR := $(DOWNLOAD_DIR)
endif

# 目录和文件定义
BUILD_DIR           := build
SRC_DIR             := $(BUILD_DIR)/linux-$(LINUX_VERSION)
LINUX_TAR_NAME      := $(LINUX_TAR_SHA)-linux-$(LINUX_VERSION).tar.gz
LINUX_TAR			:= $(DL_DIR)/.$(LINUX_TAR_NAME)

# 收集源文件
PATCHES             := $(sort $(wildcard $(PATCH_DIR)/*.patch))
DTSS                := $(wildcard $(DTS_DIR)/*) 
CONFIG_FILES        := $(wildcard $(CONFIG_DIR)/*.config)
SYMLINK_DIRS      	:= arch scripts include




# 内核编译命令
KERNEL_MAKE := +$(MAKE) -C $(SRC_DIR) PWD=$(PWD) PROJECT=AX650_emmc LIBC=glibc $(KERNEL_EXTRA_PARAMS)
ifneq ($(strip $(M)),)
	KERNEL_MAKE := $(KERNEL_MAKE) M=$(M)
endif

# ============================================================================
# 主要目标
# ============================================================================

SIGN_EXTS := all vmlinux Image zImage bzImage uImage  modules modules_install modules_prepare config menuconfig  olddefconfig defconfig  oldconfig savedefconfig clean mrproper install tar-pkg rpm-pkg deb-pkg kernelrelease %_defconfig %.dtb dtbs help headers_install kernelversion scripts

define SIGN_RULE
$(1): _build_init
	$(KERNEL_MAKE) $(MAKECMDGOALS)
endef

$(foreach ext,$(SIGN_EXTS),$(eval $(call SIGN_RULE,$(ext))))


# ============================================================================
# 构建流程
# ============================================================================

# 构建初始化总入口
_build_init: Patching Extracting

# 构建流程依赖链

Patching: $(BUILD_DIR)/.stamp_patching $(BUILD_DIR)/.stamp_dtsing $(BUILD_DIR)/.stamp_config

Extracting: $(BUILD_DIR)/.stamp_extract

# ============================================================================
# 内部辅助目标（不直接调用）
# ============================================================================

$(BUILD_DIR)/.stamp_config : $(CONFIG_FILES) $(BUILD_DIR)/.stamp_patching
	cat $(SRC_DIR)/arch/$(BOARD_ARCH)/configs/$(BASE_DEFCONFIG)	$(CONFIG_FILES) > $(SRC_DIR)/arch/$(BOARD_ARCH)/configs/$(TARGET_DEFCONFIG) && touch $@

$(BUILD_DIR)/.stamp_patching : $(PATCHES) $(BUILD_DIR)/.stamp_extract
	for p in $(PATCHES); do patch -p1 -d $(SRC_DIR) < $$p; done && touch $@

$(BUILD_DIR)/.stamp_dtsing : $(DTSS) $(BUILD_DIR)/.stamp_extract
	cp $(DTSS) $(SRC_DIR)/arch/$(BOARD_ARCH)/boot/dts/ && touch $@



$(BUILD_DIR)/.stamp_extract : $(LINUX_TAR)
	mkdir -p $(BUILD_DIR)
	tar zxf $(LINUX_TAR) -C $(BUILD_DIR) && { for d in $(SYMLINK_DIRS); do ln -sf $(SRC_DIR)/$$d $$d; done } && touch $@
	 

$(LINUX_TAR) : README.md
	@if [ ! -f "$(LINUX_TAR)" ]; then \
		wget --passive-ftp -nd -t 3 -O '$(LINUX_TAR)' '$(LINUX_TAR_URL)' || rm -f '$(LINUX_TAR)'; \
	else \
		touch '$(LINUX_TAR)'; \
	fi




AXERA_TOOLS_PATH := $(THIS_DIR)/axerabin/tools/bin
ifneq ($(wildcard $(AXERA_TOOLS_PATH)/ax650n_BuildEnv.mk),)
include $(AXERA_TOOLS_PATH)/ax650n_BuildEnv.mk
BINARIES_DIR := $(SRC_DIR)/arch/arm64/boot
OUT_BINARIES_DIR := $(SRC_DIR)/..

Packaxera_dts: 
	python3 $(AXERA_TOOLS_SIGN_SCRIPT_650) -i $(BINARIES_DIR)/dts/$(PACK_DTB).dtb \
		-o $(OUT_BINARIES_DIR)/$(PACK_DTB)_signed.dtb -pub $(AXERA_TOOLS_PUB_KEY) -prv $(AXERA_TOOLS_PRIV_KEY) $(AXERA_TOOLS_SIGN_PARAMS_650_BOOT)

Packaxera_kernel: 
	python3 $(AXERA_TOOLS_SIGN_SCRIPT_650) -i $(BINARIES_DIR)/Image \
		-o $(OUT_BINARIES_DIR)/boot_signed.bin -pub $(AXERA_TOOLS_PUB_KEY) -prv $(AXERA_TOOLS_PRIV_KEY) $(AXERA_TOOLS_SIGN_PARAMS_650_BOOT)

Packaxera: 
	$(MAKE) Packaxera_dts PACK_DTB=m5stack-ax650-AI-Pyramid
	$(MAKE) Packaxera_dts PACK_DTB=AX650_emmc_dual_pcie
	$(MAKE) Packaxera_kernel
	cp $(OUT_BINARIES_DIR)/boot_signed.bin $(OUT_BINARIES_DIR)/recovery_signed.bin
	cp $(OUT_BINARIES_DIR)/AX650_emmc_signed.dtb $(OUT_BINARIES_DIR)/recovery_signed.dtb
	cp $(OUT_BINARIES_DIR)/m5stack-ax650-AI-Pyramid_signed.dtb $(OUT_BINARIES_DIR)/AX650_emmc_signed.dtb

else
Packaxera: 
	@echo "Axera signing tools not found. Skipping signing step."

Packaxera_dts: 
	@echo "Axera signing tools not found. Skipping signing step."

Packaxera_kernel:
	@echo "Axera signing tools not found. Skipping signing step."
endif

linux-distclean:
	@$(KERNEL_MAKE) distclean

distclean:
	@rm -f build -rf
	@rm -f arch
	@rm -f scripts
	@rm -f include
