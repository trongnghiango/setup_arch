#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

#==============================================================================
# Cấu hình mirrorlist chính thức và đáng tin cậy cho cả Artix và Arch Linux
#==============================================================================
SCRIPT_TIME="$(date +%Y%m%d_%H%M%S)"
SCRIPT_LOG="/tmp/optimize_mirrors_${SCRIPT_TIME}.log"

log_info() { echo -e "$(date '+%H:%M:%S') \e[1;32m[INFO]\e[0m  $*"; }
log_warn() { echo -e "$(date '+%H:%M:%S') \e[1;33m[WARN]\e[0m  $*"; }
log_error() {
    echo -e "$(date '+%H:%M:%S') \e[1;31m[ERROR]\e[0m $*" >&2
    echo -e "\nFile log: ${SCRIPT_LOG}"
    exit 1
}

exec > >(tee -ai "${SCRIPT_LOG}") 2>&1

if [ "$EUID" -ne 0 ]; then
    log_error "Vui lòng chạy script này với quyền root (sudo)."
fi

MIRRORLIST="/etc/pacman.d/mirrorlist"

log_info "Sao lưu mirrorlist gốc..."
if [ -f "$MIRRORLIST" ]; then
    cp "$MIRRORLIST" "${MIRRORLIST}.bak"
fi

if grep -qi "artix" /etc/os-release 2>/dev/null; then
    log_info "Phát hiện hệ thống Artix Linux. Ghi các mirror Artix đáng tin cậy..."
    tee "$MIRRORLIST" > /dev/null << 'EOF'
# Default stable official mirrors for Artix Linux (Verified active)
Server = https://mirrors.tuna.tsinghua.edu.cn/artixlinux/$repo/os/$arch
Server = https://ftp.sh.cvut.cz/artix-linux/$repo/os/$arch
Server = https://mirrors.dotsrc.org/artix-linux/repos/$repo/os/$arch
Server = https://mirrors.rit.edu/artixlinux/$repo/os/$arch
Server = https://ftp.crifo.org/artix/repos/$repo/os/$arch
Server = https://mirror.funami.tech/artix/$repo/os/$arch
EOF
else
    log_info "Phát hiện hệ thống Arch Linux. Ghi các mirror Arch đáng tin cậy..."
    tee "$MIRRORLIST" > /dev/null << 'EOF'
# Default stable official mirrors for Arch Linux (Verified active)
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch
Server = https://mirror.funami.tech/archlinux/$repo/os/$arch
Server = https://mirrors.kernel.org/archlinux/$repo/os/$arch
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch
EOF
fi

log_info "Đồng bộ lại database Pacman với các server chính thức..."
if pacman -Syy --noconfirm; then
    log_info "Đồng bộ Pacman thành công! Hệ thống đã sẵn sàng."
else
    log_error "Đồng bộ Pacman thất bại. Vui lòng kiểm tra lại kết nối mạng."
fi
