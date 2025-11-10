# SPDX-FileCopyrightText: 2024 M5Stack Technology CO LTD
# SPDX-License-Identifier: MIT

# ============================================================================
# 配置区域 - 根据需求修改此部分
# ============================================================================

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
CONFIG_FRAGMENT_DIR := .

# ----------------------------------------------------------------------------
# 配置片段文件（按顺序合并）
# ----------------------------------------------------------------------------
CONFIG_FRAGMENTS    := fragment-03-systemd.config \
					   linux-disable.config \
					   linux-enable-m5stack.config

# ----------------------------------------------------------------------------
# 下载目录配置
# ----------------------------------------------------------------------------
# 是否使用外部下载目录（yes/no）
USE_EXTERNAL_DL     := yes
# 外部下载目录路径
DOWNLOAD_DIR        := ../../../dl

# ----------------------------------------------------------------------------
# 交叉编译配置（如需要请取消注释）
# ----------------------------------------------------------------------------
# ARCH              := arm64
# CROSS_COMPILE     := aarch64-none-linux-gnu-
# KERNEL_EXTRA_PARAMS := ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE)

# ============================================================================
# 内部变量 - 通常不需要修改
# ============================================================================

# 目录和文件定义
BUILD_DIR           := build
SRC_DIR             := $(BUILD_DIR)/linux-$(LINUX_VERSION)
LINUX_TAR_NAME      := $(LINUX_TAR_SHA)-linux-$(LINUX_VERSION).tar.gz

# 收集源文件
PATCHES             := $(sort $(wildcard $(PATCH_DIR)/*.patch))
DTSS                := $(wildcard $(DTS_DIR)/*.dts*)
CONFIG_FILES        := $(addprefix $(CONFIG_FRAGMENT_DIR)/,$(CONFIG_FRAGMENTS))

# 构建检查标记文件
CHECK_BUILD_STAMP   := $(BUILD_DIR)/.stamp_extracted
CHECK_DTS_STAMP     := $(BUILD_DIR)/.stamp_dts
CHECK_PATCH_STAMP   := $(BUILD_DIR)/.stamp_patched
CHECK_CONFIG_STAMP  := $(BUILD_DIR)/.stamp_configured

# 确定下载目录
ifeq ($(USE_EXTERNAL_DL),yes)
	DL_DIR := $(DOWNLOAD_DIR)
else
	DL_DIR := .
endif

# 内核编译命令
ifeq ($(strip $(M)),)
	KERNEL_MAKE := $(MAKE) -C $(SRC_DIR) $(KERNEL_EXTRA_PARAMS)
else
	KERNEL_MAKE := $(MAKE) -C $(SRC_DIR) $(KERNEL_EXTRA_PARAMS) M=$(M)
endif

# ============================================================================
# 主要目标
# ============================================================================

.PHONY: all build_init help menuconfig savedefconfig
.PHONY: extracting patching configuring
.PHONY: distclean linux-distclean mrproper
.PHONY: show-config list-patches list-dts

# 默认规则：将未定义的目标传递给内核 Makefile
%:
	@if [ "$(MAKECMDGOALS)" != "build_init" ] && \
		[ "$(MAKECMDGOALS)" != "help" ] && \
		[ "$(MAKECMDGOALS)" != "show-config" ] && \
		[ "$(MAKECMDGOALS)" != "list-patches" ] && \
		[ "$(MAKECMDGOALS)" != "list-dts" ]; then \
		$(MAKE) build_init; \
		$(KERNEL_MAKE) $(MAKECMDGOALS); \
	fi

all: build_init

# ============================================================================
# 构建流程
# ============================================================================

# 构建初始化总入口
build_init: configuring
	@echo ""
	@echo "==> ✓ Build initialization complete!"
	@echo "    Source:  $(SRC_DIR)"
	@echo "    Config:  $(TARGET_DEFCONFIG)"
	@echo ""
	@echo "    Next steps:"
	@echo "      make menuconfig  - Configure kernel options"
	@echo "      make -j$$(nproc)      - Build kernel"
	@echo "      make modules     - Build modules"

# 构建流程依赖链
configuring: patching $(CHECK_CONFIG_STAMP)

patching: extracting $(CHECK_PATCH_STAMP)

extracting: $(CHECK_BUILD_STAMP) $(CHECK_DTS_STAMP)

# ============================================================================
# 构建步骤实现
# ============================================================================

# 步骤 1: 下载和解压 Linux 源码
$(CHECK_BUILD_STAMP):
	@echo "==> [1/4] Extracting Linux source..."
	@mkdir -p $(BUILD_DIR)
	@$(MAKE) --no-print-directory _download-kernel
	@$(MAKE) --no-print-directory _extract-kernel
	@$(MAKE) --no-print-directory _create-symlinks
	@touch $@
	@echo "    ✓ Extraction complete"

# 步骤 2: 复制设备树文件
$(CHECK_DTS_STAMP): $(CHECK_BUILD_STAMP) $(DTSS)
	@echo "==> [2/4] Copying device tree files..."
	@if [ -n "$(DTSS)" ]; then \
		mkdir -p $(SRC_DIR)/arch/$(BOARD_ARCH)/boot/dts/; \
		for dts in $(DTSS); do \
			cp $$dts $(SRC_DIR)/arch/$(BOARD_ARCH)/boot/dts/; \
			echo "    ✓ Copied $$(basename $$dts)"; \
		done; \
		echo "    Total: $(words $(DTSS)) file(s)"; \
	else \
		echo "    ⚠ No DTS files found in $(DTS_DIR)"; \
	fi
	@touch $@

# 步骤 3: 应用补丁
$(CHECK_PATCH_STAMP): $(CHECK_DTS_STAMP) $(PATCHES)
	@echo "==> [3/4] Applying patches..."
	@if [ -n "$(PATCHES)" ]; then \
		patch_count=0; \
		for patch in $(PATCHES); do \
			patch_count=$$((patch_count + 1)); \
			echo "    [$$patch_count/$(words $(PATCHES))] Applying $$(basename $$patch)..."; \
			if ! patch -p1 -d $(SRC_DIR) -N -s < $$patch 2>/dev/null; then \
				if patch -p1 -d $(SRC_DIR) --dry-run -R < $$patch >/dev/null 2>&1; then \
					echo "    ⚠ Already applied, skipping"; \
				else \
					echo "    ✗ ERROR: Failed to apply $$patch"; \
					exit 1; \
				fi; \
			fi; \
		done; \
		echo "    ✓ Applied $(words $(PATCHES)) patch(es)"; \
	else \
		echo "    ⚠ No patches found in $(PATCH_DIR)"; \
	fi
	@touch $@

# 步骤 4: 生成配置文件
$(CHECK_CONFIG_STAMP): $(CHECK_PATCH_STAMP) $(CONFIG_FILES)
	@echo "==> [4/4] Generating kernel config..."
	@$(MAKE) --no-print-directory _generate-defconfig
	@touch $@
	@echo "    ✓ Configuration complete"

# ============================================================================
# 内部辅助目标（不直接调用）
# ============================================================================

# 下载内核源码
.PHONY: _download-kernel
_download-kernel:
	@if [ ! -f '$(DL_DIR)/$(LINUX_TAR_NAME)' ]; then \
		echo "    Downloading Linux $(LINUX_VERSION)..."; \
		mkdir -p $(DL_DIR); \
		if ! wget --passive-ftp -nd -t 3 -O '$(DL_DIR)/$(LINUX_TAR_NAME)' '$(LINUX_TAR_URL)'; then \
			echo "    ✗ Download failed"; \
			rm -f $(DL_DIR)/$(LINUX_TAR_NAME); \
			exit 1; \
		fi; \
		echo "    ✓ Download complete"; \
	else \
		echo "    ✓ Archive already downloaded"; \
	fi
	@echo "    Verifying checksum..."
	@calculated_hash=$$(sha256sum $(DL_DIR)/$(LINUX_TAR_NAME) | awk '{print $$1}'); \
	if [ "$$calculated_hash" != "$(LINUX_TAR_SHA)" ]; then \
		echo "    ✗ ERROR: Checksum mismatch!"; \
		echo "      Expected: $(LINUX_TAR_SHA)"; \
		echo "      Got:      $$calculated_hash"; \
		rm $(DL_DIR)/$(LINUX_TAR_NAME); \
		exit 1; \
	fi; \
	echo "    ✓ Checksum verified"

# 解压内核源码
.PHONY: _extract-kernel
_extract-kernel:
	@if [ ! -d '$(SRC_DIR)' ]; then \
		echo "    Extracting source to $(SRC_DIR)..."; \
		tar zxf $(DL_DIR)/$(LINUX_TAR_NAME) -C $(BUILD_DIR)/; \
		echo "    ✓ Extraction complete"; \
	else \
		echo "    ✓ Source already extracted"; \
	fi

# 创建符号链接
.PHONY: _create-symlinks
_create-symlinks:
	@if [ ! -L 'arch' ]; then \
		ln -sf $(SRC_DIR)/arch arch; \
		echo "    ✓ Created symlink: arch"; \
	fi
	@if [ ! -L 'scripts' ]; then \
		ln -sf $(SRC_DIR)/scripts scripts; \
		echo "    ✓ Created symlink: scripts"; \
	fi
	@if [ ! -L 'include' ]; then \
		ln -sf $(SRC_DIR)/include include; \
		echo "    ✓ Created symlink: include"; \
	fi

# 生成 defconfig
.PHONY: _generate-defconfig
_generate-defconfig:
	@target_config=$(SRC_DIR)/arch/$(BOARD_ARCH)/configs/$(TARGET_DEFCONFIG); \
	if [ ! -f "$$target_config" ]; then \
		echo "    Generating $(TARGET_DEFCONFIG)..."; \
		base_config=$(SRC_DIR)/arch/$(BOARD_ARCH)/configs/$(BASE_DEFCONFIG); \
		if [ ! -f "$$base_config" ]; then \
			echo "    ✗ ERROR: Base config not found: $$base_config"; \
			echo "    Available configs:"; \
			ls $(SRC_DIR)/arch/$(BOARD_ARCH)/configs/*defconfig 2>/dev/null | head -5; \
			exit 1; \
		fi; \
		cat $$base_config > $$target_config; \
		echo "    ✓ Base config: $(BASE_DEFCONFIG)"; \
		fragment_count=0; \
		for fragment in $(CONFIG_FILES); do \
			if [ -f "$$fragment" ]; then \
				fragment_count=$$((fragment_count + 1)); \
				echo "    ✓ Merging $$(basename $$fragment)"; \
				cat $$fragment >> $$target_config; \
			else \
				echo "    ✗ WARNING: Fragment not found: $$fragment"; \
			fi; \
		done; \
		echo "    Total fragments merged: $$fragment_count"; \
	else \
		echo "    ✓ Config already exists: $(TARGET_DEFCONFIG)"; \
	fi

# ============================================================================
# 常用内核操作
# ============================================================================

# 配置内核
menuconfig: build_init
	@echo "==> Opening kernel configuration..."
	@$(KERNEL_MAKE) $(TARGET_DEFCONFIG)
	@$(KERNEL_MAKE) menuconfig

# 使用默认配置
defconfig: build_init
	@echo "==> Loading default configuration..."
	@$(KERNEL_MAKE) $(TARGET_DEFCONFIG)
	@echo "    ✓ Loaded $(TARGET_DEFCONFIG)"

# 保存当前配置为 defconfig
savedefconfig: build_init
	@echo "==> Saving defconfig..."
	@$(KERNEL_MAKE) savedefconfig
	@cp $(SRC_DIR)/defconfig $(SRC_DIR)/arch/$(BOARD_ARCH)/configs/$(TARGET_DEFCONFIG)
	@echo "    ✓ Saved to arch/$(BOARD_ARCH)/configs/$(TARGET_DEFCONFIG)"

# ============================================================================
# 信息显示
# ============================================================================

# 显示当前配置
show-config:
	@echo "╔════════════════════════════════════════════════════════════════╗"
	@echo "║              Kernel Build Configuration                        ║"
	@echo "╠════════════════════════════════════════════════════════════════╣"
	@echo "║ Linux Version:    $(LINUX_VERSION)"
	@echo "║ Board Name:       $(BOARD_NAME)"
	@echo "║ Architecture:     $(BOARD_ARCH)"
	@echo "║ Base Config:      $(BASE_DEFCONFIG)"
	@echo "║ Target Config:    $(TARGET_DEFCONFIG)"
	@echo "║ Source Dir:       $(SRC_DIR)"
	@echo "║ Download Dir:     $(DL_DIR)"
	@echo "╠════════════════════════════════════════════════════════════════╣"
	@echo "║ Config Fragments: $(words $(CONFIG_FRAGMENTS)) file(s)"
	@for frag in $(CONFIG_FRAGMENTS); do \
		if [ -f "$(CONFIG_FRAGMENT_DIR)/$$frag" ]; then \
			printf "║   ✓ %-58s║\n" "$$frag"; \
		else \
			printf "║   ✗ %-58s║\n" "$$frag (missing)"; \
		fi; \
	done
	@echo "╠════════════════════════════════════════════════════════════════╣"
	@echo "║ Patches:          $(words $(PATCHES)) file(s)"