# Unholy Phoenix Kernel

Custom kernel for **Poco X2 / Redmi K30 (phoenix)** with KernelSU root support.

## Specifications

| Property | Value |
|----------|-------|
| **Device** | Poco X2 / Redmi K30 |
| **Codename** | phoenix |
| **Kernel Version** | 4.14.356 |
| **Base** | Unholy Phoenix v2.2 |
| **Root Solution** | KernelSU-Next v3.2.0 |
| **Root Hiding** | SusFS v2.0.0 (v1.5.1 backported) |
| **SoC** | Snapdragon 730G (SM7150) |

## Features

### KernelSU-Next v3.2.0
- Kernel-based `su` and root access management
- Module system (Magic Mount + OverlayFS)
- Per-app root profile management
- Built-in SELinux policy patching

### SusFS v2.0.0 (v1.5.1 backported to kernel 4.14)
- SUS_PATH: Hide suspicious paths
- SUS_MOUNT: Hide suspicious mounts
- SUS_KSTAT: Spoof file statistics
- SUS_OVERLAYFS: Hide overlayfs
- TRY_UMOUNT: Auto-unmount suspicious mounts
- SPOOF_UNAME: Hide kernel version
- SPOOF_CMDLINE_OR_BOOTCONFIG: Spoof cmdline/bootconfig
- OPEN_REDIRECT: Redirect file opens
- SUS_SU: Classical su binary support (with hooks)
- HIDE_KSU_SUSFS_SYMBOLS: Hide KSU/SusFS symbols
- AUTO_ADD_SUS_BIND_MOUNT: Auto add bind mounts as suspicious
- AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT: Auto add try umount
- AUTO_ADD_SUS_KSU_DEFAULT_MOUNT: Auto add KSU default mounts
- SELinux policy injection

## Building

### Option 1: GitHub Actions (Recommended)

1. Create a GitHub repository
2. Push this code to the repository
3. Go to **Actions** tab
4. Click **"Run workflow"**
5. Wait for build to complete (~2-3 hours)
6. Download the flashable zip from **Artifacts**

### Option 2: Local Build (WSL/Linux)

```bash
# Install dependencies
chmod +x build_setup.sh
./build_setup.sh

# Build kernel
chmod +x build_kernel.sh
./build_kernel.sh
```

### Option 3: Manual

```bash
# Clone sources
git clone --depth 1 -b v2.2 https://github.com/KBapna/Unholy_Phoenix_Redmi_K30_Kernel.git kernel_source
git clone --depth=1 https://github.com/kdrag0n/proton-clang.git proton-clang
cd kernel_source
git clone --depth 1 https://github.com/KernelSU-Next/KernelSU-Next.git
ln -sf KernelSU-Next/kernel drivers/kernelsu
```

## Installation

1. Download the flashable zip
2. Transfer to phone storage
3. Boot to recovery (TWRP/OrangeFox)
4. Flash the zip
5. Reboot

## Customization

### Change KernelSU Version

```bash
# Edit build_kernel.sh or workflow
KSU_VERSION="v3.2.0"  # Change to desired version
```

### Change SusFS Version

```bash
# Edit build_kernel.sh or workflow
SUSFS_VERSION="1.4.2-kernel-4.14"  # Change to desired version
```

## Kernel 4.14 Backports

The following patches are applied for kernel 4.14 compatibility:

| API | Newer Kernel | 4.14 Backport |
|-----|-------------|---------------|
| `selinux_cred()` | 5.0+ | `current_cred()->security` |
| `__arm64_sys_ni_syscall` | 5.5+ | `sys_ni_syscall` |
| `ksys_close()` | 5.11+ | `close_fd()` |
| `set_task_syscall_work()` | 5.11+ | `set_tsk_thread_flag()` |

## Credits

- [Unholy Phoenix Kernel](https://github.com/KBapna/Unholy_Phoenix_Redmi_K30_Kernel)
- [KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next)
- [SusFS](https://gitlab.com/simonpunk/susfs4ksu)
- [Proton Clang](https://github.com/kdrag0n/proton-clang)
- [AnyKernel3](https://github.com/osm0sis/AnyKernel3)

## License

GPL-2.0
