# MODULE_650_LINUX
Patch for the Linux kernel adapted for the module_llm development board.  
Compilation will automatically download and apply the relevant patches to compile into a kernel project.  

auto compile:
```bash
sudo apt install flex bison libssl-dev libelf-dev
source /opt/gcc-linaro-7.5.0-2019.12-x86_64_aarch64-linux-gnu/bash.bashrc
make distclean
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- m5stack_AX650C_emmc_arm64_defconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j `nproc`
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- m5stack-ax650-AI-Pyramid.dtb
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- m5stack-ax650-Sbc.dtb
make Packaxera_dts PACK_DTB=m5stack-ax650-Sbc

make Packaxera
# pushd build/linux-5.15.73
# scripts/config --set-str INITRAMFS_SOURCE "你的路径/文件名"
# popd 
# make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
# make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j `nproc`
# make Packaxera
```

just Extract:
```bash
make Extracting
```

just Patch:
```bash
make Patching
```

just Configur:
```bash
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Configuring
```

## Local Compilation on AI-Pyramid

On the AI-Pyramid device, the kernel source code is located at `/usr/src/module_650_linux`. You can compile directly without cross-compilation:

```bash
# Install required dependencies
apt install flex bison libssl-dev

cd /usr/src/module_650_linux

# Update the source code
git pull

# Clean previous builds
make distclean

# Configure the kernel
make m5stack_AX650C_emmc_arm64_defconfig

# Compile the kernel (using 6 parallel jobs)
make -j 6
```

### Compiling External Kernel Modules

After successfully compiling the kernel, you can compile external wireless USB modules by pointing to the kernel directory at `/usr/src/module_650_linux`. For example, to compile the rtl88x2BU WiFi driver:

```bash
make ARCH=arm64 CROSS_COMPILE= -C /usr/src/module_650_linux M=/root/rtl88x2BU_WiFi_linux_v5.13.1.1-1-g6f2541ef2.20240507_COEX20220812-18317b7b modules
```

**Note:** When compiling on the device itself, `CROSS_COMPILE` is left empty since native compilation is used.
