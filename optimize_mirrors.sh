#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

#==============================================================================
# SCRIPT TỐI ƯU HÓA MIRRORS CHO ARCH/ARTIX LINUX
#==============================================================================
SCRIPT_TIME="$(date +%Y%m%d_%H%M%S)"
SCRIPT_LOG="/tmp/optimize_mirrors_${SCRIPT_TIME}.log"

log_info() { echo -e "$(date '+%H:%M:%S') \e[1;32m[INFO]\e[0m  $*"; }
log_warn() { echo -e "$(date '+%H:%M:%S') \e[1;33m[WARN]\e[0m  $*"; }
log_error() {
    echo -e "$(date '+%H:%M:%S') \e[1;31m[ERROR]\e[0m $*" >&2
    echo -e "\n========================================"
    echo "File log: ${SCRIPT_LOG}"
    echo "========================================"
    exit 1
}

# Đảm bảo ghi log
exec > >(tee -ai "${SCRIPT_LOG}") 2>&1

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
    log_error "Vui lòng chạy script này với quyền root (sudo)."
fi

# Sao lưu mirrorlist gốc
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak || true

log_info "Bắt đầu tối ưu hóa danh sách mirror..."

log_info "Đang tải rate-mirrors từ GitHub (Statically compiled Rust binary)..."
if curl -sL "https://github.com/aenmd/rate-mirrors/releases/latest/download/rate-mirrors-linux-amd64.tar.gz" | tar -xz -C /tmp 2>/dev/null; then
    chmod +x /tmp/rate-mirrors
    
    log_info "Đang đánh giá chất lượng và kiểm tra tốc độ thực tế của các mirrors..."
    if [ -f /etc/artix-release ]; then
        log_info "Đang quét các mirror cho Artix Linux..."
        if ! /tmp/rate-mirrors --concurrency 50 artix > /etc/pacman.d/mirrorlist; then
            log_warn "rate-mirrors chạy lỗi, khôi phục lại mirrorlist gốc."
            mv /etc/pacman.d/mirrorlist.bak /etc/pacman.d/mirrorlist
        fi
    else
        log_info "Đang quét các mirror cho Arch Linux..."
        if ! /tmp/rate-mirrors --concurrency 50 arch > /etc/pacman.d/mirrorlist; then
            log_warn "rate-mirrors chạy lỗi, khôi phục lại mirrorlist gốc."
            mv /etc/pacman.d/mirrorlist.bak /etc/pacman.d/mirrorlist
        fi
    fi
    
    rm -f /tmp/rate-mirrors
    log_info "Tối ưu hóa mirror hoàn tất!"
else
    log_warn "Không thể tải rate-mirrors. Đã khôi phục và giữ nguyên mirrorlist gốc của ISO."
    mv /etc/pacman.d/mirrorlist.bak /etc/pacman.d/mirrorlist
fi

# Chạy cập nhật database thử nghiệm
log_info "Đang thử nghiệm đồng bộ cơ sở dữ liệu Pacman..."
if pacman -Syy; then
    log_info "Đồng bộ pacman thành công! Tốc độ mirror đã được tối ưu."
else
    log_error "Đồng bộ pacman thất bại với mirrorlist mới. Vui lòng kiểm tra lại kết nối mạng."
fi
