#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

#==============================================================================
# SCRIPT ENTRYPOINT CHÍNH CỦA BỘ SETUP
#==============================================================================
log_info() { echo -e "\e[1;32m[INFO]\e[0m  $*"; }
log_error() { echo -e "\e[1;31m[ERROR]\e[0m $*" >&2; exit 1; }
step() { echo -e "\n\e[1;34m>>> $*\e[0m"; }

# Đổi thư mục làm việc về thư mục chứa script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

usage() {
    echo "Usage: $0 [MODE] [OPTIONS]"
    echo
    echo "Hệ thống cài đặt tối ưu cho Arch/Artix Linux."
    echo
    echo "Modes (Chọn một):"
    echo "  --mirrors    Tối ưu hóa gương tải gói (optimize_mirrors.sh)"
    echo "  --base       Cài đặt hệ điều hành tối giản (install_base.sh)"
    echo "  --apps       Cài đặt gói ứng dụng và biên dịch dwm (install_apps.sh)"
    echo "  --dotfiles   Thiết lập cấu hình dotfiles (install_dotfiles.sh)"
    echo "  --all        Chạy Combo từ đầu đến cuối ngay trong Live USB (Một lệnh ăn ngay)"
    echo
    echo "Xem trợ giúp chi tiết của từng giai đoạn bằng cách gọi script con tương ứng."
}

#==============================================================================
# XỬ LÝ CHẾ ĐỘ CHẠY (MODE)
#==============================================================================
if [ "$#" -lt 1 ]; then
    usage
    exit 1
fi

MODE="$1"
shift

case "$MODE" in
    --mirrors)
        exec "$SCRIPT_DIR/optimize_mirrors.sh" "$@"
        ;;
    --base)
        exec "$SCRIPT_DIR/install_base.sh" "$@"
        ;;
    --apps)
        exec "$SCRIPT_DIR/install_apps.sh" "$@"
        ;;
    --dotfiles)
        exec "$SCRIPT_DIR/install_dotfiles.sh" "$@"
        ;;
    --all)
        # Tiến trình COMBO chạy tuần tự trong Live USB
        # Ghi log toàn bộ quá trình cài đặt ra file để dễ gỡ lỗi
        LOG_FILE="/tmp/install.log"
        log_info "Toàn bộ quá trình cài đặt sẽ được ghi vào file log: ${LOG_FILE}"
        
        {
            step "BƯỚC 0: Tối ưu hóa mirror..."
            "$SCRIPT_DIR/optimize_mirrors.sh"

            step "BƯỚC 1: Cài đặt hệ thống cơ bản..."
            "$SCRIPT_DIR/install_base.sh" "$@"

            # Trích xuất cấu hình vừa ghi trong install_vars.sh của phân vùng mới
            if [ ! -f /mnt/root/install_vars.sh ]; then
                log_error "Không tìm thấy thông tin cấu hình tại /mnt/root/install_vars.sh"
            fi
            source /mnt/root/install_vars.sh

            step "BƯỚC 2: Cài đặt ứng dụng và build suckless..."
            cp "$SCRIPT_DIR/install_apps.sh" /mnt/root/
            mkdir -p /mnt/tmp
            cp "$SCRIPT_DIR/progs.csv" /mnt/tmp/progs.csv
            
            if command -v artix-chroot &>/dev/null; then
                artix-chroot /mnt /root/install_apps.sh --user "${USER_NAME}" --progs-url "${PROGS_LIST_URL}"
            else
                arch-chroot /mnt /root/install_apps.sh --user "${USER_NAME}" --progs-url "${PROGS_LIST_URL}"
            fi

            step "BƯỚC 3: Thiết lập dotfiles..."
            cp "$SCRIPT_DIR/install_dotfiles.sh" /mnt/root/
            
            if command -v artix-chroot &>/dev/null; then
                artix-chroot /mnt /root/install_dotfiles.sh --user "${USER_NAME}" --method "${DOTFILES_METHOD}" --repo "${DOTFILES_REPO}"
            else
                arch-chroot /mnt /root/install_dotfiles.sh --user "${USER_NAME}" --method "${DOTFILES_METHOD}" --repo "${DOTFILES_REPO}"
            fi

            step "BƯỚC 4: Dọn dẹp hệ thống..."
            if command -v artix-chroot &>/dev/null; then
                artix-chroot /mnt rm /etc/sudoers.d/99_install_privileges
                artix-chroot /mnt /bin/bash -c "echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel;"
                artix-chroot /mnt rm -f /root/install_apps.sh /root/install_dotfiles.sh /root/install_vars.sh
            else
                arch-chroot /mnt rm /etc/sudoers.d/99_install_privileges
                arch-chroot /mnt /bin/bash -c "echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel;"
                arch-chroot /mnt rm -f /root/install_apps.sh /root/install_dotfiles.sh /root/install_vars.sh
            fi
        } 2>&1 | tee "${LOG_FILE}"

        # Sao chép file log vào hệ thống mới để người dùng kiểm tra sau khi boot
        if [ -d /mnt/var/log ]; then
            cp "${LOG_FILE}" /mnt/var/log/install.log
            log_info "Đã lưu bản sao log vào hệ thống mới tại /var/log/install.log"
        fi

        log_info "CÀI ĐẶT HOÀN TẤT TOÀN BỘ HỆ THỐNG!"
        log_info "Anh có thể khởi động lại máy:"
        printf "\n  umount -R /mnt\n  reboot\n\n"
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    *)
        log_error "Chế độ không hợp lệ: $MODE. Dùng --help để biết thêm chi tiết."
        ;;
esac
