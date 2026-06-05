#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

#==============================================================================
# HÀM TIỆN ÍCH
#==============================================================================
log_info() { echo -e "\e[1;32m[INFO]\e[0m  $*"; }
log_error() { echo -e "\e[1;31m[ERROR]\e[0m $*" >&2; exit 1; }

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

sudo -u "${USER_NAME}" /bin/bash -c '
    set -euo pipefail
    METHOD="'${METHOD}'"
    REPO="'${REPO}'"
    
    log_user() { echo -e "  \e[1;32m[USER]\e[0m  $*"; }

    # Xác định thư mục lưu trữ dotfiles
    if [ "$METHOD" == "stow" ]; then
        DOTFILES_DIR="$HOME/.dotfiles"
    else
        DOTFILES_DIR="$HOME/.local/src/dotfiles"
    fi

    log_user "Cloning dotfiles từ ${REPO}..."
    if [ ! -d "$DOTFILES_DIR" ]; then
        git clone --depth=1 --recurse-submodules "${REPO}" "${DOTFILES_DIR}"
    else
        log_user "Thư mục dotfiles đã tồn tại. Pull update mới nhất..."
        cd "$DOTFILES_DIR" && git pull
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
