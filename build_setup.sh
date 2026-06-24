#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

echo "=================================================="
echo "  Unholy Phoenix Kernel - Build Environment Setup"
echo "  Device: Poco X2 / Redmi K30 (phoenix)"
echo "  Kernel: 4.14.356"
echo "  Root:   KernelSU-Next v3.2.0 + SusFS v2.0.0"
echo "=================================================="
echo ""

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$BASE_DIR"

# ============================================================
# Phase 1: System Dependencies
# ============================================================
echo "[Phase 1] Installing system dependencies..."
sudo apt-get update -y
sudo apt-get install -y \
    build-essential bc bison flex curl git zip unzip \
    libssl-dev libelf-dev cpio libncurses-dev wget \
    python3 python3-pip gcc g++ clang lld llvm \
    device-tree-compiler rsync libslang2-dev \
    libbabeltrace-dev libdw-dev systemtap-sdt \
    gcc-arm-linux-gnueabi gcc-aarch64-linux-gnu

echo "[+] System dependencies installed."

# ============================================================
# Phase 2: Kernel Source
# ============================================================
echo ""
echo "[Phase 2] Cloning kernel source..."
if [ ! -d "$BASE_DIR/kernel_source/arch/arm64" ]; then
    rm -rf "$BASE_DIR/kernel_source"
    echo "[+] Cloning Unholy Phoenix kernel v2.2..."
    git clone --depth 1 -b v2.2 \
        https://github.com/KBapna/Unholy_Phoenix_Redmi_K30_Kernel.git \
        "$BASE_DIR/kernel_source"
else
    echo "[+] Kernel source already exists."
fi

# ============================================================
# Phase 3: Toolchain
# ============================================================
echo ""
echo "[Phase 3] Setting up toolchain..."
if [ ! -d "$BASE_DIR/proton-clang/bin" ]; then
    rm -rf "$BASE_DIR/proton-clang"
    echo "[+] Cloning Proton Clang toolchain..."
    git clone --depth=1 https://github.com/kdrag0n/proton-clang.git \
        "$BASE_DIR/proton-clang"
else
    echo "[+] Toolchain already exists."
fi

# Verify toolchain
if [ ! -f "$BASE_DIR/proton-clang/bin/clang" ]; then
    echo "ERROR: clang not found in toolchain!"
    exit 1
fi
echo "[+] Toolchain ready: $(ls $BASE_DIR/proton-clang/bin/clang)"

# ============================================================
# Phase 4: KernelSU-Next
# ============================================================
echo ""
echo "[Phase 4] Cloning KernelSU-Next v3.2.0..."
KSU_DIR="$BASE_DIR/kernel_source/KernelSU-Next"

if [ ! -d "$KSU_DIR/.git" ]; then
    rm -rf "$KSU_DIR"
    git clone --branch v3.2.0 --depth 1 \
        https://github.com/KernelSU-Next/KernelSU-Next.git \
        "$KSU_DIR" || {
        echo "WARNING: Failed to clone v3.2.0, trying latest..."
        git clone --depth 1 \
            https://github.com/KernelSU-Next/KernelSU-Next.git \
            "$KSU_DIR"
    }
else
    echo "[+] KernelSU-Next already exists."
fi

# Create symlink
cd "$BASE_DIR/kernel_source"
rm -rf drivers/kernelsu 2>/dev/null || true
ln -sf ../KernelSU-Next/kernel drivers/kernelsu || \
    cp -r KernelSU-Next/kernel drivers/kernelsu

# Ensure drivers/Makefile entry
if ! grep -q "kernelsu" drivers/Makefile 2>/dev/null; then
    echo "" >> drivers/Makefile
    echo "obj-\$(CONFIG_KSU) += kernelsu/" >> drivers/Makefile
fi

# Ensure drivers/Kconfig entry
if ! grep -q "kernelsu" drivers/Kconfig 2>/dev/null; then
    sed -i '/^endmenu/i source "drivers/kernelsu/Kconfig"' drivers/Kconfig
fi

echo "[+] KernelSU-Next integrated."

# ============================================================
# Phase 5: SusFS (latest v1.5.1, backported to kernel 4.14)
# ============================================================
echo ""
echo "[Phase 5] Cloning SusFS v1.5.1 (latest, will backport to kernel 4.14)..."
SUSFS_DIR="$BASE_DIR/susfs4ksu"

if [ ! -d "$SUSFS_DIR/.git" ]; then
    rm -rf "$SUSFS_DIR"
    # Clone latest GKI version (will be backported to 4.14)
    git clone --depth 1 \
        https://gitlab.com/simonpunk/susfs4ksu.git \
        "$SUSFS_DIR" || {
        echo "WARNING: Failed to clone from GitLab, trying GitHub..."
        git clone --depth 1 \
            https://github.com/simonpunk/susfs4ksu.git \
            "$SUSFS_DIR" || {
            echo "WARNING: Failed to clone SusFS"
        }
    }
else
    echo "[+] SusFS already exists."
fi

# Show version
if [ -d "$SUSFS_DIR" ]; then
    cd "$SUSFS_DIR"
    SUSFS_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "latest")
    echo "[+] SusFS version: $SUSFS_TAG"
fi

# ============================================================
# Phase 6: AnyKernel3
# ============================================================
echo ""
echo "[Phase 6] Cloning AnyKernel3..."
if [ ! -d "$BASE_DIR/AnyKernel3/.git" ]; then
    git clone --depth 1 https://github.com/osm0sis/AnyKernel3.git \
        "$BASE_DIR/AnyKernel3"
else
    echo "[+] AnyKernel3 already exists."
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "=================================================="
echo "  Setup Complete!"
echo "=================================================="
echo ""
echo "Directory structure:"
ls -la "$BASE_DIR" | grep -v "^total"
echo ""
echo "KernelSU-Next:"
ls "$BASE_DIR/kernel_source/KernelSU-Next/kernel/" 2>/dev/null | head -5
echo ""
echo "Next steps:"
echo "  1. Run: ./build_kernel.sh"
echo "  2. Or push to GitHub and use Actions"
echo "=================================================="
