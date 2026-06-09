#!/usr/bin/env bash
# ====================================================================
# user_setup.sh
#   Cài ứng dụng + dotfiles từ progs.csv, dùng stow, xử lý lỗi có hỏi
# ====================================================================
# Cách dùng: sudo ./user_setup.sh
#   - Chạy sau khi boot vào hệ thống mới (hoặc trong chroot)
#   - Đọc progs.csv, cài pacman packages & build suckless (tag G)
#   - Clone dotfiles-stow và áp dụng bằng stow
#   - Khi lỗi: in ra lỗi, hỏi [c]ontinue hay [a]bort
# ====================================================================
set -euo pipefail
IFS=$'\n\t'

# --------------------------- CẤU HÌNH --------------------------------
USER_NAME="${SUDO_USER:-${USER}}"
HOME_DIR="/home/${USER_NAME}"
DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/trongnghiango/dotfiles-stow.git}"
DOTFILES_DIR="${HOME_DIR}/.dotfiles"
PROGS_CSV="progs.csv"
LOG_FILE="/tmp/setup_$(date +%Y%m%d_%H%M%S).log"
ERR_FILE="/tmp/setup_errors_$(date +%Y%m%d_%H%M%S).log"
STEP_N=0
STEP_TOTAL=0

mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$ERR_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

# --------------------------- HÀM LOG ---------------------------------
log_info() { echo -e "$(date '+%H:%M:%S') \e[1;32m[INFO]\e[0m  $*"; }
log_warn() { echo -e "$(date '+%H:%M:%S') \e[1;33m[WARN]\e[0m  $*"; }
log_error() {
    echo -e "$(date '+%H:%M:%S') \e[1;31m[ERROR]\e[0m $*" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" >> "$ERR_FILE"
}

# ------------------------- XỬ LÝ LỖI --------------------------------
handle_error() {
    local rc=$?
    local line=${1:-?}
    local msg="${2:-Không xác định}"
    log_error "Dòng $line: $msg (exit=$rc)"
    while true; do
        read -rp "=> [c]ontinue (bỏ qua) hay [a]bort (thoát)? " ans
        case "$ans" in
            [cC]*) log_warn "Đã bỏ qua lỗi ở dòng $line."; return ;;
            [aA]*) log_error "Người dùng yêu cầu thoát."; exit $rc ;;
            *) echo "Nhập 'c' hoặc 'a'." ;;
        esac
    done
}
trap 'handle_error ${LINENO}' ERR

# ------------------------- KIỂM TRA ROOT ----------------------------
if [[ $EUID -ne 0 ]]; then
    echo "Chạy với sudo: sudo ./user_setup.sh" >&2
    exit 1
fi

# --------------------------- HÀM CÀI --------------------------------
install_pacman() {
    local pkg=$1
    log_info "[$STEP_N/$STEP_TOTAL] pacman -S $pkg"
    pacman -S --noconfirm --needed "$pkg"
}

install_gitmake() {
    local url=$1
    local name; name=$(basename "$url" .git)
    local src="/opt/$name"
    log_info "[$STEP_N/$STEP_TOTAL] Build $name"
    if [[ -d "$src/.git" ]]; then
        (cd "$src" && git pull --ff-only) || true
    else
        rm -rf "$src"
        git clone --depth=1 "$url" "$src"
    fi
    (cd "$src" && make clean 2>/dev/null; make && make install)
}

install_aur() {
    local pkg=$1
    log_info "[$STEP_N/$STEP_TOTAL] AUR $pkg"
    if pacman -Qqm | grep -qx "$pkg"; then
        log_warn "  $pkg đã cài, bỏ qua."
        return
    fi
    local helper=""
    for cmd in yay paru; do
        command -v "$cmd" &>/dev/null && { helper=$cmd; break; }
    done
    if [[ -z $helper ]]; then
        log_error "Không tìm thấy AUR helper (yay/paru). Cài thủ công: $pkg"
        return
    fi
    sudo -u "$USER_NAME" "$helper" -S --noconfirm "$pkg"
}

install_pip() {
    local pkg=$1
    log_info "[$STEP_N/$STEP_TOTAL] pip $pkg"
    command -v pip &>/dev/null || pacman -S --noconfirm python-pip
    sudo -u "$USER_NAME" pip install --break-system-packages "$pkg"
}

# ----------------------- ĐỌC PROGS.CSV ------------------------------
install_from_csv() {
    [[ -f $PROGS_CSV ]] || { log_error "Không thấy $PROGS_CSV"; return; }
    STEP_TOTAL=$(grep -cEv '^\s*(#|$)' "$PROGS_CSV" || echo 0)
    STEP_N=0
    log_info "Đang cài $STEP_TOTAL gói từ $PROGS_CSV ..."
    while IFS=',' read -r tag prog _; do
        [[ -z $prog || $prog == \#* ]] && continue
        STEP_N=$((STEP_N + 1))
        case "$tag" in
            G) install_gitmake "$prog" ;;
            A) install_aur "$prog" ;;
            P) install_pip "$prog" ;;
            *) install_pacman "$prog" ;;
        esac
    done < <(grep -v '^\s*#' "$PROGS_CSV")
}

# ---------------------- ĐẢM BẢO XORG INPUT -------------------------
ensure_xorg_input() {
    log_info "Kiểm tra driver nhập liệu Xorg..."
    if ! pacman -Qi xf86-input-libinput &>/dev/null; then
        log_warn "Thiếu xf86-input-libinput, đang cài..."
        pacman -S --noconfirm xf86-input-libinput
    fi
    local d=/etc/X11/xorg.conf.d
    mkdir -p "$d"
    if [[ ! -f $d/00-keyboard.conf ]]; then
        cat >"$d/00-keyboard.conf" <<'EOF'
Section "InputClass"
    Identifier      "system-keyboard"
    MatchIsKeyboard "yes"
    Option "XkbRules"   "evdev"
    Option "XkbModel"   "pc105"
    Option "XkbLayout"  "us"
    Option "XkbVariant" ""
    Option "XkbOptions" "caps:super,altwin:menu_win"
EndSection
EOF
        log_info "Đã tạo $d/00-keyboard.conf"
    fi
    if [[ ! -f $d/40-libinput.conf ]]; then
        cat >"$d/40-libinput.conf" <<'EOF'
Section "InputClass"
    Identifier "libinput touchpad catchall"
    MatchIsTouchpad "on"
    MatchDevicePath "/dev/input/event*"
    Driver "libinput"
    Option "Tapping" "on"
    Option "NaturalScrolling" "true"
EndSection
EOF
        log_info "Đã tạo $d/40-libinput.conf"
    fi
}

# ------------------------ CÀI DOTFILES -----------------------------
setup_dotfiles() {
    log_info "Thiết lập dotfiles từ $DOTFILES_REPO ..."
    command -v stow &>/dev/null || pacman -S --noconfirm stow
    if [[ -d $DOTFILES_DIR/.git ]]; then
        log_warn "Dotfiles đã có, pull cập nhật..."
        (cd "$DOTFILES_DIR" && git pull --ff-only) || true
    else
        rm -rf "$DOTFILES_DIR"
        git clone --depth=1 "$DOTFILES_REPO" "$DOTFILES_DIR"
    fi
    sudo -u "$USER_NAME" bash -c "
        cd '$DOTFILES_DIR'
        for pkg in */; do
            pkg_name=\"\${pkg%/}\"
            [[ \$pkg_name =~ ^(nixos|docs|setup_arch)$ ]] && continue
            echo '  stow --restow --target=$HOME_DIR \$pkg_name'
            stow --restow --target='$HOME_DIR' \"\$pkg_name\"
        done
    "
    # Cấp quyền thực thi script
    if [[ -d $HOME_DIR/.local/bin ]]; then
        find "$HOME_DIR/.local/bin" -type f -exec chmod +x {} \;
    fi
    log_info "Dotfiles hoàn tất."
}

# ---------------------------- MAIN -----------------------------------
log_info "========== USER SETUP =========="
log_info "Người dùng: $USER_NAME"
log_info "Log file : $LOG_FILE"
log_info "Log lỗi  : $ERR_FILE"

ensure_xorg_input
install_from_csv
setup_dotfiles

# Tổng kết lỗi
if [[ -s $ERR_FILE ]]; then
    echo ""
    echo "========== LỖI ĐÃ XẢY RA =========="
    cat "$ERR_FILE"
    echo "====================================="
    while true; do
        read -rp "Có lỗi ở trên. Tiếp tục (c) hay thoát (q)? " ans
        case "$ans" in
            [cC]*) log_warn "Kết thúc script mặc dù có lỗi."; break ;;
            [qQ]*) log_error "Người dùng thoát."; exit 1 ;;
            * ) echo "Nhập 'c' hoặc 'q'." ;;
        esac
    done
fi

log_info "========== HOÀN TẤT =========="
echo ""
echo "Reboot hoặc startx để vào môi trường đồ họa."
echo "Các file log:"
echo "  $LOG_FILE"
echo "  $ERR_FILE"
exit 0
