# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains a collection of optimized shell scripts for automating the installation and configuration of **Arch Linux** or **Artix Linux** from a Live USB/VM environment. The target setup features a suckless-based GUI environment (DWM, ST, Dmenu, Dwmblocks) and dotfiles managed via GNU Stow or Rsync.

## Development & Test Commands

Since this codebase consists of Bash installation scripts, "development" is done by testing and executing scripts in a virtualized environment (KVM/QEMU) rather than running compiler/linter tasks.

### Running & Testing Scripts
* **Run everything (automated combo):** `./setup.sh --all --disk <disk_name>` (e.g. `./setup.sh --all --disk vda`)
* **Step 1: Optimize package mirrors:** `./setup.sh --mirrors` (runs `optimize_mirrors.sh`)
* **Step 2: Install CLI Base OS:** `./setup.sh --base --disk <disk_name>` (runs `install_base.sh`)
* **Step 3: Install Apps & compile suckless tools:** `./setup.sh --apps` (runs `install_apps.sh` inside target system/chroot)
* **Step 4: Sync dotfiles:** `./setup.sh --dotfiles` (runs `install_dotfiles.sh`)

### KVM/QEMU Virtual Machine Management (for testing)
* **Create a test VM (Artix UEFI):**
  ```bash
  virt-install --connect qemu:///system \
      --name artixvm \
      --memory 6144 \
      --vcpus 2 \
      --cpu host-passthrough \
      --disk size=50,format=qcow2,bus=virtio \
      --network network=default,model=virtio \
      --os-variant archlinux \
      --cdrom /tmp/artix-x86_64.iso \
      --graphics spice,listen=none \
      --video virtio \
      --channel spicevmc \
      --boot uefi \
      --check path_in_use=off,disk_size=off
  ```
* **Start and open VM screen:** `virsh start artixvm && virt-viewer -a artixvm &`
* **Force stop VM:** `virsh destroy artixvm`
* **Delete VM & clean storage/NVRAM:** `virsh undefine artixvm --remove-all-storage --nvram`

## Codebase Architecture

The setup flow is designed to transition from the **Live USB Host** to the **Chroot Target**.

```
Live USB Host Environment                     Chroot / Target OS Environment
┌───────────────────────────┐                 ┌─────────────────────────────┐
│ 1. optimize_mirrors.sh    │                 │ 3. install_apps.sh          │
│    (Selects fast mirrors) │                 │    (Pacman + Git/Suckless)  │
└─────────────┬─────────────┘                 └──────────────┬──────────────┘
              ▼                                              ▼
┌───────────────────────────┐                 ┌─────────────────────────────┐
│ 2. install_base.sh        ├────────────────►│ 4. install_dotfiles.sh      │
│    (Partitions, pacstraps)│   Chroot/Boot   │    (stow or rsync sync)     │
└───────────────────────────┘                 └─────────────────────────────┘
```

### Script Execution Roles
1. **`setup.sh`**: The master orchestrator entrypoint. Handles command-line arguments and sequential execution.
2. **`optimize_mirrors.sh`**: Automatically detects Arch or Artix and replaces `/etc/pacman.d/mirrorlist` with verified, fast servers (e.g., Tsinghua, Funami).
3. **`install_base.sh`**: Checks for UEFI boot, partitions target drive (using GPT, UEFI system partition, and ext4 root), runs `pacstrap` (or `basestrap` on Artix), configures fstab, system clock, hostname, bootloader (GRUB EFI), and creates the primary user (default: `ka`).
4. **`install_apps.sh`**: Parses `progs.csv` to install regular packages via `pacman` and automatically clones and compiles custom suckless tool builds (dwm, dmenu, st, dwmblocks) from GitLab when marked with a `G` tag.
5. **`install_dotfiles.sh`**: Clones dotfiles repository and symlinks configuration files using `stow` or copies them directly via `rsync`.

### Core Data Configuration
* **`progs.csv`**: The package list source of truth. Format: `TAG,NAME_IN_REPO_OR_GIT_URL,PURPOSE`.
  - Empty tag: Package to be installed via `pacman -S`.
  - `G` tag: Git repository to clone and build using `make && make install`.
* **`progs.csv.mini`**: A minimized subset of packages for fast/lightweight installations.

## Guidelines & Coding Style
* **Safety First:** Always include `set -euo pipefail` and `IFS=$'\n\t'` in all bash scripts.
* **Logging & Errors:** Use the helper functions `log_info`, `log_warn`, and `log_error`. Fatal errors should log to `/tmp/install_errors.log` (or target system log path) and terminate the script.
* **Compatibility:** Scripts must handle both Arch Linux (Systemd) and Artix Linux (OpenRC) gracefully, especially when managing services or using distribution-specific base commands (like `pacstrap` vs `basestrap`).
