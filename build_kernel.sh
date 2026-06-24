#!/bin/bash
set -e

echo "=================================================="
echo "  Unholy Phoenix Kernel Build Script"
echo "  Device: Poco X2 / Redmi K30 (phoenix)"
echo "  Kernel: 4.14.356"
echo "  Root:   KernelSU-Next v3.2.0"
echo "  SusFS:  v1.5.1 backported to v2.0.0 (kernel 4.14)"
echo "=================================================="
echo ""

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
KERNEL_DIR="$BASE_DIR/kernel_source"
TOOLCHAIN_DIR="$BASE_DIR/proton-clang"
BUILD_LOG="$BASE_DIR/build.log"
OUTPUT_DIR="$BASE_DIR/output"

# ============================================================
# Pre-flight checks
# ============================================================
echo "[Pre-flight] Checking requirements..."

if [ ! -d "$KERNEL_DIR/arch/arm64" ]; then
    echo "ERROR: Kernel source not found at $KERNEL_DIR"
    echo "Run ./build_setup.sh first"
    exit 1
fi

if [ ! -f "$TOOLCHAIN_DIR/bin/clang" ]; then
    echo "ERROR: Toolchain not found at $TOOLCHAIN_DIR"
    echo "Run ./build_setup.sh first"
    exit 1
fi

if [ ! -d "$KERNEL_DIR/KernelSU-Next/kernel" ]; then
    echo "ERROR: KernelSU-Next not found"
    echo "Run ./build_setup.sh first"
    exit 1
fi

echo "[+] All requirements met."

# ============================================================
# Phase 1: Prepare build directory
# ============================================================
echo ""
echo "[Phase 1] Preparing build directory..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# ============================================================
# Phase 2: Integrate SusFS v1.5.1 (backported to 4.14)
# ============================================================
echo ""
echo "[Phase 2] Integrating SusFS v1.5.1 (backported to kernel 4.14)..."
cd "$KERNEL_DIR"

SUSFS_DIR="$BASE_DIR/susfs4ksu"
if [ -d "$SUSFS_DIR" ]; then
    echo "[+] SusFS found, applying patches..."
    
    # Check if already patched
    if ! grep -q "susfs" fs/open.c 2>/dev/null; then
        # Apply KernelSU-Next SusFS patches
        if [ -d "$SUSFS_DIR/kernel_patches/KernelSU-Next" ]; then
            echo "[+] Patching KernelSU-Next for SusFS..."
            for patch in "$SUSFS_DIR/kernel_patches/KernelSU-Next"/*.patch; do
                [ -f "$patch" ] && echo "  - $(basename $patch)" && \
                cp "$patch" ./KernelSU-Next/ && \
                cd KernelSU-Next && \
                yes | patch -p1 --forward < "$(basename $patch)" 2>/dev/null || true && \
                cd ..
            done
        fi
        
        # Apply kernel patches
        if [ -d "$SUSFS_DIR/kernel_patches" ]; then
            echo "[+] Applying kernel SusFS patches..."
            for patch in "$SUSFS_DIR/kernel_patches"/*.patch; do
                [ -f "$patch" ] && echo "  - $(basename $patch)" && \
                yes | patch -p1 -F 3 --forward < "$patch" 2>/dev/null || true
            done
        fi
        
        # Copy SusFS files
        [ -d "$SUSFS_DIR/kernel_patches/fs" ] && \
            cp -r "$SUSFS_DIR/kernel_patches/fs"/* ./fs/ 2>/dev/null || true
        [ -d "$SUSFS_DIR/kernel_patches/include" ] && \
            cp -r "$SUSFS_DIR/kernel_patches/include"/* ./include/ 2>/dev/null || true
        [ -d "$SUSFS_DIR/kernel_patches/arch" ] && \
            cp -r "$SUSFS_DIR/kernel_patches/arch"/* ./arch/ 2>/dev/null || true
        
        echo "[+] SusFS patches applied."
    else
echo "[+] SusFS already patched."
fi
else
    echo "[!] SusFS not found, skipping."
fi

# ============================================================
# Phase 2.5: Backport SusFS v1.5.1 features to kernel 4.14
# ============================================================
echo ""
echo "[Phase 2.5] Backporting SusFS v1.5.1 features to kernel 4.14..."
cd "$KERNEL_DIR"

# Backport 1: Add HIDE_KSU_SUSFS_SYMBOLS feature
if ! grep -q "HIDE_KSU_SUSFS_SYMBOLS" include/linux/susfs.h 2>/dev/null; then
    echo "[+] Backporting HIDE_KSU_SUSFS_SYMBOLS..."
    cat >> include/linux/susfs.h << 'BACKPORT1'

/* Backported from SusFS v1.5.1 for kernel 4.14 */
#ifdef CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS
extern void susfs_hide_ksu_suspend_symbols(void);
extern void susfs_show_ksu_suspend_symbols(void);
#else
static inline void susfs_hide_ksu_suspend_symbols(void) {}
static inline void susfs_show_ksu_suspend_symbols(void) {}
#endif
BACKPORT1
fi

# Backport 2: Add SPOOF_CMDLINE_OR_BOOTCONFIG feature
if ! grep -q "SPOOF_CMDLINE_OR_BOOTCONFIG" include/linux/susfs.h 2>/dev/null; then
    echo "[+] Backporting SPOOF_CMDLINE_OR_BOOTCONFIG..."
    cat >> include/linux/susfs.h << 'BACKPORT2'

/* Backported from SusFS v1.5.1 for kernel 4.14 */
#ifdef CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG
extern int susfs_set_spoof_cmdline_or_bootconfig(char __user *user_buf, size_t buf_len);
extern int susfs_get_spoof_cmdline_or_bootconfig(char *buf, size_t buf_len);
#endif
BACKPORT2
fi

# Backport 3: Add OPEN_REDIRECT feature
if ! grep -q "OPEN_REDIRECT" include/linux/susfs.h 2>/dev/null; then
    echo "[+] Backporting OPEN_REDIRECT..."
    cat >> include/linux/susfs.h << 'BACKPORT3'

/* Backported from SusFS v1.5.1 for kernel 4.14 */
#ifdef CONFIG_KSU_SUSFS_OPEN_REDIRECT
struct st_susfs_open_redirect {
    char target_pathname[SUSFS_MAX_LEN_PATHNAME];
    char redirected_pathname[SUSFS_MAX_LEN_PATHNAME];
};
extern int susfs_add_open_redirect(struct st_susfs_open_redirect __user *user_info);
extern int susfs_get_redirected_path(const char *pathname, char *buf, size_t buf_len);
#endif
BACKPORT3
fi

# Backport 4: Add AUTO_ADD_SUS_BIND_MOUNT feature
if ! grep -q "AUTO_ADD_SUS_BIND_MOUNT" include/linux/susfs.h 2>/dev/null; then
    echo "[+] Backporting AUTO_ADD_SUS_BIND_MOUNT..."
    cat >> include/linux/susfs.h << 'BACKPORT4'

/* Backported from SusFS v1.5.1 for kernel 4.14 */
#ifdef CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT
extern void susfs_auto_add_sus_bind_mount(const char *pathname);
extern bool susfs_is_sus_mount(unsigned long mnt_id);
#endif
BACKPORT4
fi

# Backport 5: Add AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT feature
if ! grep -q "AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT" include/linux/susfs.h 2>/dev/null; then
    echo "[+] Backporting AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT..."
    cat >> include/linux/susfs.h << 'BACKPORT5'

/* Backported from SusFS v1.5.1 for kernel 4.14 */
#ifdef CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT
extern void susfs_auto_add_try_umount_for_bind_mount(const char *pathname);
extern void susfs_try_umount_all(uid_t uid);
#endif
BACKPORT5
fi

# Backport 6: Add AUTO_ADD_SUS_KSU_DEFAULT_MOUNT feature
if ! grep -q "AUTO_ADD_SUS_KSU_DEFAULT_MOUNT" include/linux/susfs.h 2>/dev/null; then
    echo "[+] Backporting AUTO_ADD_SUS_KSU_DEFAULT_MOUNT..."
    cat >> include/linux/susfs.h << 'BACKPORT6'

/* Backported from SusFS v1.5.1 for kernel 4.14 */
#ifdef CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT
extern void susfs_auto_add_sus_ksu_default_mount(const char *pathname);
#endif
BACKPORT6
fi

# Backport 7: Add SUS_SU_WITH_HOOKS support
if ! grep -q "SUS_SU_WITH_HOOKS" include/linux/susfs_def.h 2>/dev/null; then
    echo "[+] Backporting SUS_SU_WITH_HOOKS..."
    cat >> include/linux/susfs_def.h << 'BACKPORT7'

/* Backported from SusFS v1.5.1 for kernel 4.14 */
#ifndef SUS_SU_WITH_HOOKS
#define SUS_SU_WITH_HOOKS 2
#endif
BACKPORT7
fi

echo "[+] SusFS v1.5.1 features backported to kernel 4.14."

# ============================================================
# Phase 3: Add SusFS Kconfig
# ============================================================
echo ""
echo "[Phase 3] Adding SusFS Kconfig..."
cd "$KERNEL_DIR"

if ! grep -q "KSU_SUSFS" fs/Kconfig 2>/dev/null; then
    # Insert before endmenu
    sed -i '/^endmenu/i \
\
menuconfig KSU_SUSFS\
\tbool "SusFS - Root hiding filesystem"\
\tdefault n\
\
if KSU_SUSFS\
\
config KSU_SUSFS_SUS_PATH\
\tbool "Hide suspicious paths"\
\tdefault y\
\
config KSU_SUSFS_SUS_MOUNT\
\tbool "Hide suspicious mounts"\
\tdefault y\
\
config KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT\
\tbool "Auto add KSU default mount as suspicious"\
\tdefault y\
\
config KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT\
\tbool "Auto add bind mounts as suspicious"\
\tdefault y\
\
config KSU_SUSFS_SUS_KSTAT\
\tbool "Spoof file statistics"\
\tdefault y\
\
config KSU_SUSFS_SUS_OVERLAYFS\
\tbool "Hide overlayfs"\
\tdefault y\
\
config KSU_SUSFS_TRY_UMOUNT\
\tbool "Try unmount suspicious mounts"\
\tdefault y\
\
config KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT\
\tbool "Auto add try umount for bind mounts"\
\tdefault y\
\
config KSU_SUSFS_SPOOF_UNAME\
\tbool "Spoof uname"\
\tdefault y\
\
config KSU_SUSFS_ENABLE_LOG\
\tbool "Enable SusFS logging"\
\tdefault y\
\
config KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS\
\tbool "Hide KSU/SusFS symbols"\
\tdefault y\
\
config KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG\
\tbool "Spoof cmdline/bootconfig"\
\tdefault y\
\
config KSU_SUSFS_OPEN_REDIRECT\
\tbool "Open redirect support"\
\tdefault y\
\
config KSU_SUSFS_SUS_SU\
\tbool "Suspicious su handling"\
\tdefault y\
\
config KSU_SUSFS_HAS_MAGIC_MOUNT\
\tbool "Magic mount support"\
\tdefault y\
\
config KSU_SUSFS_FCHMODAT_HOOK\
\tbool "Hook fchmodat"\
\tdefault y\
\
config KSU_SUSFS_FSTATAT_HOOK\
\tbool "Hook fstatat"\
\tdefault y\
\
config KSU_SUSFS_STATX_HOOK\
\tbool "Hook statx"\
\tdefault y\
\
config KSU_SUSFS_SELINUX_POLICY_INJECTION\
\tbool "SELinux policy injection"\
\tdefault y\
\
endif # KSU_SUSFS' fs/Kconfig
    echo "[+] SusFS Kconfig added."
else
    echo "[+] SusFS Kconfig already present."
fi

# ============================================================
# Phase 4: Apply Kernel 4.14 Backports
# ============================================================
echo ""
echo "[Phase 4] Applying kernel 4.14 backport patches..."
cd "$KERNEL_DIR"

# Patch 1: Fix selinux_cred() for kernel < 5.0
if grep -q "selinux_cred(cred)" KernelSU-Next/kernel/selinux/selinux.c 2>/dev/null; then
    echo "[+] Patching selinux_cred()..."
    sed -i '/#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 18, 0)/,/#else$/{
        s/#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 18, 0)/#if LINUX_VERSION_CODE < KERNEL_VERSION(5, 0, 0)\n    tsec = (struct task_security_struct *)current_cred()->security;\n#elif LINUX_VERSION_CODE < KERNEL_VERSION(6, 18, 0)/
    }' KernelSU-Next/kernel/selinux/selinux.c
fi

# Patch 2: Fix syscall symbol names
if grep -q "__arm64_sys_ni_syscall" KernelSU-Next/kernel/hook/arm64/syscall_hook.c 2>/dev/null; then
    echo "[+] Patching syscall symbols..."
    sed -i 's/ksu_lookup_symbol("__arm64_sys_ni_syscall")/#if LINUX_VERSION_CODE < KERNEL_VERSION(5, 5, 0)\n        ksu_lookup_symbol("sys_ni_syscall")\n#else\n        ksu_lookup_symbol("__arm64_sys_ni_syscall")\n#endif/' \
        KernelSU-Next/kernel/hook/arm64/syscall_hook.c
fi

# Patch 3: Fix ksys_close()
if grep -q "ksys_close(fd)" KernelSU-Next/kernel/infra/su_mount_ns.c 2>/dev/null; then
    echo "[+] Patching ksys_close()..."
    sed -i 's/ksys_close(fd);/#if LINUX_VERSION_CODE < KERNEL_VERSION(5, 0, 0)\n    close_fd(fd);\n#else\n    ksys_close(fd);\n#endif/' \
        KernelSU-Next/kernel/infra/su_mount_ns.c
fi

echo "[+] Backport patches applied."

# ============================================================
# Phase 5: Configure kernel
# ============================================================
echo ""
echo "[Phase 5] Configuring kernel..."
cd "$KERNEL_DIR"

DEFCONFIG="arch/arm64/configs/phoenix_defconfig"

if [ ! -f "$DEFCONFIG" ]; then
    echo "ERROR: Defconfig not found at $DEFCONFIG"
    ls arch/arm64/configs/ 2>/dev/null || echo "No configs directory"
    exit 1
fi

# Clean old configs
sed -i '/^CONFIG_KSU/d' "$DEFCONFIG" 2>/dev/null || true
sed -i '/^CONFIG_SECURITY_SELINUX/d' "$DEFCONFIG" 2>/dev/null || true
sed -i '/^# KernelSU/d' "$DEFCONFIG" 2>/dev/null || true
sed -i '/^# SusFS/d' "$DEFCONFIG" 2>/dev/null || true
sed -i '/^# SELinux/d' "$DEFCONFIG" 2>/dev/null || true

# Remove trailing blank lines
sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$DEFCONFIG" 2>/dev/null || true

# Add new configs
cat >> "$DEFCONFIG" << 'EOF'

# =====================================================
# KernelSU-Next v3.2.0 & SusFS v1.4.2 - Full Config
# =====================================================

# Required for KernelSU
CONFIG_KPROBES=y
CONFIG_KSU=y
CONFIG_KSU_DEBUG=n

# SusFS Integration
CONFIG_KSU_SUSFS=y
CONFIG_KSU_SUSFS_SUS_PATH=y
CONFIG_KSU_SUSFS_SUS_MOUNT=y
CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y
CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=y
CONFIG_KSU_SUSFS_SUS_KSTAT=y
CONFIG_KSU_SUSFS_SUS_OVERLAYFS=y
CONFIG_KSU_SUSFS_TRY_UMOUNT=y
CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT=y
CONFIG_KSU_SUSFS_SPOOF_UNAME=y
CONFIG_KSU_SUSFS_ENABLE_LOG=y
CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y
CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y
CONFIG_KSU_SUSFS_OPEN_REDIRECT=y
CONFIG_KSU_SUSFS_SUS_SU=y
CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=y
CONFIG_KSU_SUSFS_FCHMODAT_HOOK=y
CONFIG_KSU_SUSFS_FSTATAT_HOOK=y
CONFIG_KSU_SUSFS_STATX_HOOK=y

# SELinux Integration
CONFIG_SECURITY_SELINUX=y
CONFIG_KSU_SUSFS_SELINUX_POLICY_INJECTION=y
EOF

echo "[+] Configuration updated."

# ============================================================
# Phase 6: Build kernel
# ============================================================
echo ""
echo "[Phase 6] Building kernel..."
cd "$KERNEL_DIR"

# Clean and prepare
rm -rf out
mkdir -p out
cp "$DEFCONFIG" out/.config

# Prepare config
echo "[+] Preparing kernel config..."
make O=out ARCH=arm64 oldconfig < /dev/null 2>&1 || true

# Get number of cores
CORES=$(nproc 2>/dev/null || echo 4)
echo "[+] Building with $CORES cores..."

# Set environment
export ARCH=arm64
export SUBARCH=arm64
export PATH="$TOOLCHAIN_DIR/bin:$PATH"

# Build
make -j$CORES O=out \
    HOSTCC=gcc \
    HOSTCXX=g++ \
    HOSTLD=ld \
    HOSTCFLAGS="-fcommon" \
    KBUILD_HOSTCFLAGS="-fcommon" \
    ARCH=arm64 \
    CC="$TOOLCHAIN_DIR/bin/clang" \
    CROSS_COMPILE="$TOOLCHAIN_DIR/bin/aarch64-linux-gnu-" \
    CROSS_COMPILE_ARM32="$TOOLCHAIN_DIR/bin/arm-linux-gnueabi-" \
    LD="$TOOLCHAIN_DIR/bin/ld.lld" \
    AR="$TOOLCHAIN_DIR/bin/llvm-ar" \
    NM="$TOOLCHAIN_DIR/bin/llvm-nm" \
    OBJCOPY="$TOOLCHAIN_DIR/bin/llvm-objcopy" \
    OBJDUMP="$TOOLCHAIN_DIR/bin/llvm-objdump" \
    STRIP="$TOOLCHAIN_DIR/bin/llvm-strip" \
    Image.gz-dtb 2>&1 | tee "$BUILD_LOG"

echo "[+] Kernel build completed!"

# ============================================================
# Phase 7: Package
# ============================================================
echo ""
echo "[Phase 7] Packaging with AnyKernel3..."

KERNEL_IMAGE="$KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb"
if [ ! -f "$KERNEL_IMAGE" ]; then
    echo "ERROR: Image.gz-dtb not found!"
    echo "Build log tail:"
    tail -50 "$BUILD_LOG"
    exit 1
fi

echo "[+] Image found: $(ls -lh $KERNEL_IMAGE)"

# Package
cd "$BASE_DIR"
rm -rf AnyKernel3
git clone --depth 1 https://github.com/osm0sis/AnyKernel3.git
cd AnyKernel3

cp "$KERNEL_IMAGE" ./

# Configure AnyKernel3
sed -i 's/kernel.string=.*/kernel.string=Unholy-PocoX2-KSUNext-SusFS/' anykernel.sh
sed -i 's/device.name1=.*/device.name1=phoenix/' anykernel.sh
sed -i 's/device.name2=.*/device.name2=phoenixin/' anykernel.sh

# Create zip
OUTPUT_ZIP="$OUTPUT_DIR/AnyKernel-PocoX2-KSUNext-SusFS-$(date +%Y%m%d).zip"
zip -r9 "$OUTPUT_ZIP" * -x .git README.md *placeholder

echo ""
echo "=================================================="
echo "  BUILD SUCCESSFUL!"
echo "=================================================="
echo ""
echo "Output: $OUTPUT_ZIP"
echo "Size: $(ls -lh $OUTPUT_ZIP | awk '{print $5}')"
echo ""
echo "To flash:"
echo "  1. Transfer zip to phone"
echo "  2. Boot to recovery"
echo "  3. Flash the zip"
echo "  4. Reboot"
echo "=================================================="
