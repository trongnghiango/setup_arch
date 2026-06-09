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

# Xác định thư mục lưu trữ dotfiles (bằng đường dẫn tuyệt đối từ root hệ thống)
# Lấy thư mục home của user một cách an toàn
USER_HOME=$(eval echo "~${USER_NAME}")
if [ "$METHOD" == "stow" ]; then
    DOTFILES_DIR="${USER_HOME}/.dotfiles"
else
    DOTFILES_DIR="${USER_HOME}/.local/src/dotfiles"
fi

#------------------------------------------------------------------------------
# 1. CLONE / PULL DOTFILES (Bằng tài khoản User để bảo toàn phân quyền git)
#------------------------------------------------------------------------------
log_info "Cloning dotfiles từ ${REPO}..."
if [ -d "$DOTFILES_DIR" ] && [ ! -d "$DOTFILES_DIR/.git" ]; then
    log_info "Thư mục dotfiles không hợp lệ (clone dang dở). Xóa và clone lại..."
    rm -rf "$DOTFILES_DIR"
fi

if [ ! -d "$DOTFILES_DIR" ]; then
    sudo -u "${USER_NAME}" git clone --depth=1 --recurse-submodules "${REPO}" "${DOTFILES_DIR}"
else
    log_info "Thư mục dotfiles đã tồn tại. Pull update mới nhất..."
    sudo -u "${USER_NAME}" bash -c "cd '${DOTFILES_DIR}' && git pull"
fi

#------------------------------------------------------------------------------
# 2. VÁ LỖI CẤU HÌNH NGUỒN (Chạy bằng Root – cực kỳ an toàn, không lo lỗi nháy đơn)
#------------------------------------------------------------------------------

# Vá lỗi logic trong remapd để tránh treo bàn phím trên máy ảo/mới
remapd_file="${DOTFILES_DIR}/scripts/.local/bin/remapd"
if [ -f "${remapd_file}" ]; then
    log_info "Vá lỗi logic trong remapd để tránh treo bàn phím trên máy ảo..."
    sed -i 's/sleep 2/exit 1/g' "${remapd_file}"
    sed -i 's/udevadm failed, sleeping 2s to prevent CPU spam/udevadm monitor failed or was interrupted. Exiting remapd daemon to prevent keyboard lock./g' "${remapd_file}"
fi

# Phát hiện môi trường ảo và cấu hình lại picom sang xrender
if is_virtual; then
    log_info "Phát hiện môi trường ảo – sẽ cấu hình picom dùng backend xrender để tránh treo màn hình."
    picom_conf="${DOTFILES_DIR}/picom/.config/picom/picom.conf"
    if [ -f "$picom_conf" ]; then
        sed -i 's/backend = "glx";/backend = "xrender";/g' "$picom_conf"
        sed -i 's/vsync = true;/vsync = false;/g' "$picom_conf"
        log_info "Đã sửa picom sang backend xrender và tắt vsync trong $picom_conf"
    fi
else
    log_info "Không phát hiện môi trường ảo – giữ nguyên cấu hình picom mặc định (glx backend)."
fi

# Vá lỗi khởi chạy Pipewire trên Artix Linux (thiếu XDG_RUNTIME_DIR và D-Bus)
artix_xinitrc="${DOTFILES_DIR}/x11/.config/x11/xinitrc.artix"
if [ -f "${artix_xinitrc}" ]; then
    log_info "Cập nhật cơ chế khởi động Pipewire trong xinitrc.artix..."
    if is_virtual; then
        log_info "Môi trường ảo: Bỏ qua khởi chạy Pipewire tự động trong xinitrc.artix."
        cat << 'EOF_ARTIX_VM' > "${artix_xinitrc}"
#!/usr/bin/env sh
# Môi trường ảo (VM) - Không khởi chạy Pipewire để tránh lỗi D-Bus/Audio Sink
# Tránh dùng exit 0 vì file này được source (. xinitrc.artix), exit sẽ tắt luôn cả session X.
return 0
EOF_ARTIX_VM
    else
        log_info "Môi trường máy thật: Cấu hình Pipewire đầy đủ trong xinitrc.artix."
        cat << 'EOF_ARTIX' > "${artix_xinitrc}"
#!/usr/bin/env sh

# ==============================================================================
# Khởi chạy âm thanh Pipewire trên Artix (không dùng systemd user services)
# ==============================================================================

# 1. Tạo XDG_RUNTIME_DIR (elogind tạo /run/user/<uid> khi login vào tty)
if [ -z "$XDG_RUNTIME_DIR" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"
fi

# 2. Khởi chạy D-Bus session nếu chưa có
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    if command -v dbus-launch >/dev/null 2>&1; then
        eval "$(dbus-launch --sh-syntax --exit-with-session)"
    fi
fi

# 3. Đảm bảo D-Bus sẵn sàng trước khi khởi chạy Pipewire
for i in $(seq 1 20); do
    [ -n "$DBUS_SESSION_BUS_ADDRESS" ] && break
    sleep 0.05
done

# 4. Luôn khởi động lại các daemon Pipewire trong session X để kế thừa D-Bus/DISPLAY đúng
killall -9 pipewire wireplumber pipewire-pulse >/dev/null 2>&1 || true

pipewire >/dev/null 2>&1 &

# Đợi socket pipewire được tạo (tối đa 3 giây)
for i in $(seq 1 30); do
    [ -S "$XDG_RUNTIME_DIR/pipewire-0" ] && break
    sleep 0.1
done

wireplumber >/dev/null 2>&1 &

# Đợi wireplumber khởi động (tối đa 3 giây)
for i in $(seq 1 30); do
    pgrep -x wireplumber >/dev/null && break
    sleep 0.1
done

pipewire-pulse >/dev/null 2>&1 &
EOF_ARTIX
    fi
fi

# Vá lỗi script hiển thị volume ka-volume trong dotfiles
ka_volume_file="${DOTFILES_DIR}/scripts/.local/bin/ka-volume"
if [ -f "${ka_volume_file}" ]; then
    if is_virtual; then
        log_info "Môi trường ảo: Vá ka-volume để hiển thị trạng thái máy ảo."
        # Thay thế logic hiển thị để in trực tiếp "🔇 VM" trên máy ảo
        cat << 'EOF_VOL_VM' > "${ka_volume_file}"
#!/usr/bin/env sh
# Hiển thị trạng thái máy ảo
echo "^C3^🔇 ^C15^VM"
EOF_VOL_VM
    fi
fi

# Xóa các file binary NixOS cũ được compile sẵn trong dotfiles nguồn (gây lỗi interpreter trên Artix)
log_info "Dọn dẹp các file binary NixOS compile sẵn trong dotfiles..."
rm -f "${DOTFILES_DIR}/scripts/.local/bin/dwm" \
      "${DOTFILES_DIR}/scripts/.local/bin/st" \
      "${DOTFILES_DIR}/scripts/.local/bin/dmenu" \
      "${DOTFILES_DIR}/scripts/.local/bin/dwmblocks" \
      "${DOTFILES_DIR}/scripts/.local/bin/stest"

# Đảm bảo tất cả các file đã vá vẫn thuộc sở hữu của user
chown -R "${USER_NAME}:${USER_NAME}" "${DOTFILES_DIR}"

#------------------------------------------------------------------------------
# 3. ÁP DỤNG DOTFILES (Bằng tài khoản User)
#------------------------------------------------------------------------------
sudo -u "${USER_NAME}" env METHOD="${METHOD}" DOTFILES_DIR="${DOTFILES_DIR}" /bin/bash -c '
    set -euo pipefail
    log_user() { echo -e "  \e[1;32m[USER]\e[0m  $*"; }

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
