#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

#==============================================================================
# HÀM TIỆN ÍCH
#==============================================================================
SCRIPT_LOG="/tmp/setup_dotfiles_$(date +%Y%m%d_%H%M%S).log"
ERROR_LOG="/tmp/install_errors.log"
# Đảm bảo file tồn tại và cho phép ghi rộng rãi
touch "${ERROR_LOG}" && chmod 666 "${ERROR_LOG}" || true

log_info() { echo -e "$(date '+%H:%M:%S') \e[1;32m[INFO]\e[0m  $*"; }
log_error() {
    local msg="$(date '+%H:%M:%S') [ERROR] $*"
    echo -e "$(date '+%H:%M:%S') \e[1;31m[ERROR]\e[0m $*" >&2
    echo -e "${msg}" >> "${ERROR_LOG}"
    exit 1;
}

is_virtual() {
    # 1. Dùng systemd-detect-virt nếu có (Arch)
    if command -v systemd-detect-virt &>/dev/null; then
        if systemd-detect-virt -q; then
            return 0
        fi
    fi
    # 2. Kiểm tra thông tin DMI (không cần quyền root)
    if [ -f /sys/class/dmi/id/product_name ]; then
        local prod
        prod=$(cat /sys/class/dmi/id/product_name | tr '[:upper:]' '[:lower:]')
        if [[ "$prod" =~ (qemu|kvm|virtualbox|vmware|virtual|bochs) ]]; then
            return 0
        fi
    fi
    if [ -f /sys/class/dmi/id/sys_vendor ]; then
        local vendor
        vendor=$(cat /sys/class/dmi/id/sys_vendor | tr '[:upper:]' '[:lower:]')
        if [[ "$vendor" =~ (qemu|kvm|virtualbox|vmware) ]]; then
            return 0
        fi
    fi
    return 1
}

exec > >(tee -ai "${SCRIPT_LOG}") 2>&1

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Giai đoạn 3: Đồng bộ dotfiles của người dùng."
    echo
    echo "Options:"
    echo "  -m, --method <stow|rsync>  Phương pháp áp dụng dotfiles (mặc định: stow)"
    echo "  -r, --repo <url>           Đường dẫn git repo dotfiles"
    echo "  -u, --user <name>          Tên tài khoản cấu hình (mặc định: ka)"
    echo "  -h, --help                 Hiển thị trợ giúp"
}

#==============================================================================
# XỬ LÝ THAM SỐ
#==============================================================================
METHOD="stow"
REPO=""
USER_NAME="ka"

TEMP=$(getopt -o m:r:u:h --long method:,repo:,user:,help -n "$0" -- "$@")
if [ $? != 0 ]; then log_error "Lỗi phân tích tham số."; fi
eval set -- "$TEMP"; unset TEMP
while true; do
    case "$1" in
        -m|--method)
            if [[ "$2" == "stow" || "$2" == "rsync" ]]; then METHOD="$2"; else log_error "Phương pháp không hợp lệ."; fi
            shift 2 ;;
        -r|--repo) REPO="$2"; shift 2 ;;
        -u|--user) USER_NAME="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        --) shift; break ;;
        *) log_error "Tham số không hợp lệ." ;;
    esac
done

if [ -z "${REPO}" ]; then
    if [ "${METHOD}" == "rsync" ]; then
        REPO="https://github.com/trongnghiango/voidrice.git"
    else
        REPO="https://github.com/trongnghiango/dotfiles-stow.git"
    fi
fi

# Cài đặt stow nếu chưa có và dùng method stow
if [ "${METHOD}" == "stow" ] && ! command -v stow &>/dev/null; then
    log_info "Cài đặt 'stow'..."
    pacman -S --noconfirm --needed stow
fi

log_info "Thiết lập dotfiles cho '${USER_NAME}' bằng phương thức '${METHOD}'..."

IS_VM="false"
if is_virtual; then
    IS_VM="true"
fi

sudo -u "${USER_NAME}" env METHOD="${METHOD}" REPO="${REPO}" IS_VM="${IS_VM}" /bin/bash -c '
    set -euo pipefail

    log_user() { echo -e "  \e[1;32m[USER]\e[0m  $*"; }

    # Xác định thư mục lưu trữ dotfiles
    if [ "$METHOD" == "stow" ]; then
        DOTFILES_DIR="$HOME/.dotfiles"
    else
        DOTFILES_DIR="$HOME/.local/src/dotfiles"
    fi

    log_user "Cloning dotfiles từ ${REPO}..."
    if [ -d "$DOTFILES_DIR" ] && [ ! -d "$DOTFILES_DIR/.git" ]; then
        log_user "Thư mục dotfiles không hợp lệ (clone dang dở). Xóa và clone lại..."
        rm -rf "$DOTFILES_DIR"
    fi
    if [ ! -d "$DOTFILES_DIR" ]; then
        git clone --depth=1 --recurse-submodules "${REPO}" "${DOTFILES_DIR}"
    else
        log_user "Thư mục dotfiles đã tồn tại. Pull update mới nhất..."
        cd "$DOTFILES_DIR" && git pull
    fi

    # Vá lỗi logic trong remapd để tránh treo bàn phím trên máy ảo/mới
    remapd_file="${DOTFILES_DIR}/scripts/.local/bin/remapd"
    if [ -f "${remapd_file}" ]; then
        log_user "Vá lỗi logic trong remapd để tránh treo bàn phím trên máy ảo..."
        sed -i 's/sleep 2/exit 1/g' "${remapd_file}"
        sed -i 's/udevadm failed, sleeping 2s to prevent CPU spam/udevadm monitor failed or was interrupted. Exiting remapd daemon to prevent keyboard lock./g' "${remapd_file}"
    fi

    # Phát hiện môi trường ảo và cấu hình lại picom sang xrender
    if [ "${IS_VM}" = "true" ]; then
        log_user "Phát hiện môi trường ảo – sẽ cấu hình picom dùng backend xrender để tránh treo màn hình."
        # Cập nhật cấu hình picom.conf sang xrender và tắt vsync
        picom_conf="${DOTFILES_DIR}/picom/.config/picom/picom.conf"
        if [ -f "$picom_conf" ]; then
            sed -i 's/backend = "glx";/backend = "xrender";/g' "$picom_conf"
            sed -i 's/vsync = true;/vsync = false;/g' "$picom_conf"
            log_user "Đã sửa picom sang backend xrender và tắt vsync trong $picom_conf"
        fi
    else
        log_user "Không phát hiện môi trường ảo – giữ nguyên cấu hình picom mặc định (glx backend)."
    fi

    if [ "$METHOD" == "stow" ]; then
        log_user "Chạy stow để tạo các liên kết tượng trưng (symlinks)..."
        cd "$DOTFILES_DIR"
        for pkg in */; do
            pkg_name="${pkg%/}"
            # Bỏ qua thư mục không dùng stow
            if [[ "$pkg_name" =~ ^(nixos|docs|setup_arch)$ ]]; then
                log_user "Bỏ qua thư mục: ${pkg_name}"
                continue
            fi
            log_user "Stowing package: ${pkg_name}"
            stow --restow --target="$HOME" "${pkg_name}"
        done
        # Xóa các link nixos cũ nếu có
        log_user "Dọn dẹp các liên kết NixOS cũ..."
        rm -f "$HOME/.local/bin/dwm" "$HOME/.local/bin/st" "$HOME/.local/bin/dmenu" "$HOME/.local/bin/dwmblocks" "$HOME/.local/bin/stest"
    else
        log_user "Đồng bộ hóa trực tiếp bằng rsync..."
        rsync -a --exclude=".git" --exclude="README.md" "${DOTFILES_DIR}/" "$HOME/"
    fi

    log_user "Cấp quyền thực thi cho script trong ~/.local/bin..."
    if [ -d "$HOME/.local/bin" ]; then
        find "$HOME/.local/bin" -type f -exec chmod +x {} \;
    fi
'

log_info "Thiết lập dotfiles đã hoàn tất."
mkdir -p /var/log
cp "${SCRIPT_LOG}" /var/log/setup_dotfiles.log 2>/dev/null || true
