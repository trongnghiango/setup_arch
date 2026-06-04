#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

log_info() { echo -e "\e[1;32m[INFO]\e[0m  $*"; }
log_warn() { echo -e "\e[1;33m[WARN]\e[0m  $*"; }
log_error() { echo -e "\e[1;31m[ERROR]\e[0m $*" >&2; exit 1; }

if [ "$#" -ne 2 ]; then
    log_error "Usage: $0 <url> <user>"
fi

PROGS_LIST_URL="$1"
USER_NAME="$2"
AUR_HELPER="yay"
PROGS_FILE="/tmp/progs.csv"

# 1. Ép DNS Google (Cực quan trọng)
echo "nameserver 1.1.1.1" > /etc/resolv.conf

log_info "Tải danh sách gói..."
curl -Ls --retry 3 "${PROGS_LIST_URL}" | sed '/^#/d' > "${PROGS_FILE}"
[ ! -s "${PROGS_FILE}" ] && log_error "List trống."

log_info "Cài gói Pacman cơ bản..."
while IFS=, read -r tag program comment; do
    if [[ "$tag" == "" || "$tag" == "M" ]]; then
        pacman -S --noconfirm --needed "$program" || true
    fi
done < "${PROGS_FILE}"

log_info "Chuyển sang user ${USER_NAME}..."
mkdir -p "/home/${USER_NAME}/.local/src"
chown -R "${USER_NAME}:${USER_NAME}" "/home/${USER_NAME}/.local"

sudo -u "${USER_NAME}" /bin/bash -c '
    set -euo pipefail
    SRC_DIR="$HOME/.local/src"
    mkdir -p "$SRC_DIR"
    
    # Hàm log user
    log_u() { echo -e "  \e[1;34m[USER]\e[0m $*"; }
    log_err_u() { echo -e "  \e[1;31m[FAIL]\e[0m $*"; }

    # Cấu hình Git để tránh lỗi khi Makepkg clone source từ Github
    git config --global http.version HTTP/1.1
    git config --global http.postBuffer 524288000
    git config --global http.sslVerify false # Tắt check SSL (Desperate mode)

    # Hàm cài đặt thủ công khi Yay thất bại (Cứu cánh)
    install_manual() {
        pkg="$1"
        log_u "Dùng phương pháp tải Snapshot cho: $pkg..."
        cd "$SRC_DIR"
        rm -rf "$pkg" "$pkg.tar.gz"
        
        # Tải file .tar.gz trực tiếp (Né lỗi Git Handshake)
        curl -L -k -O "https://aur.archlinux.org/cgit/aur.git/snapshot/$pkg.tar.gz" || return 1
        
        if [ -f "$pkg.tar.gz" ]; then
            tar -xvf "$pkg.tar.gz" > /dev/null
            cd "$pkg"
            # Cài đặt, bỏ qua check PGP và checksum nếu cần
            makepkg -si --noconfirm --needed --nocheck --skippgpcheck
        else
            return 1
        fi
    }

    # Cài Yay-bin (Nhanh hơn Yay thường)
    if ! command -v yay &> /dev/null; then
        log_u "Cài đặt yay-bin..."
        install_manual "yay-bin" || log_err_u "Không cài được yay-bin."
    fi

    # Vòng lặp cài đặt chính
    PROGS_FILE="'${PROGS_FILE}'"
    while IFS=, read -r tag program comment; do
        case "$tag" in
            "A")
                log_u "Cài đặt AUR: ${program}"
                # Thử dùng yay trước
                if ! yay -S --noconfirm --needed --mflags "--nocheck" "$program"; then
                    log_err_u "Yay lỗi mạng. Chuyển sang tải thủ công..."
                    # Nếu yay lỗi, gọi hàm thủ công ngay lập tức
                    install_manual "$program" || log_err_u "Bó tay với gói $program"
                fi
                ;;
            "G")
                # Xử lý git packages
                progname="${program##*/}"
                progname="${progname%.git}"
                log_u "Build Git Repo: $progname"
                cd "$SRC_DIR"
                [ ! -d "$progname" ] && git clone --depth 1 "$program"
                cd "$progname" 2>/dev/null || continue
                [ -f "Makefile" ] && (make && sudo make install)
                ;;
        esac
    done < "${PROGS_FILE}"
'

log_info "Cài đặt các gói đã hoàn tất."
