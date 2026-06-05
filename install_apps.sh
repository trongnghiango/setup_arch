#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_LOG="/tmp/setup_apps_$(date +%Y%m%d_%H%M%S).log"
log_info() { echo -e "$(date '+%H:%M:%S') \e[1;32m[INFO]\e[0m  $*"; }
log_warn() { echo -e "$(date '+%H:%M:%S') \e[1;33m[WARN]\e[0m  $*"; }
log_error() { echo -e "$(date '+%H:%M:%S') \e[1;31m[ERROR]\e[0m $*" >&2; exit 1; }

exec > >(tee -ai "${SCRIPT_LOG}") 2>&1

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Giai đoạn 2: Cài đặt gói Pacman, AUR và build các công cụ suckless."
    echo
    echo "Options:"
    echo "  -p, --progs-url <url>  URL đến file progs.csv (mặc định: từ GitHub)"
    echo "  -u, --user <name>      Tên tài khoản (mặc định: ka)"
    echo "  -n, --no-build         Chỉ cài package, không build suckless"
    echo "  -h, --help             Hiển thị trợ giúp"
}

#==============================================================================
# XỬ LÝ THAM SỐ
#==============================================================================
PROGS_LIST_URL="https://raw.githubusercontent.com/trongnghiango/setup_arch/refs/heads/main/progs.csv"
USER_NAME="ka"
SKIP_BUILD=false

TEMP=$(getopt -o p:u:nh --long progs-url:,user:,no-build,help -n "$0" -- "$@")
if [ $? != 0 ]; then log_error "Lỗi phân tích tham số."; fi
eval set -- "$TEMP"; unset TEMP
while true; do
    case "$1" in
        -p|--progs-url) PROGS_LIST_URL="$2"; shift 2 ;;
        -u|--user) USER_NAME="$2"; shift 2 ;;
        -n|--no-build) SKIP_BUILD=true; shift ;;
        -h|--help) usage; exit 0 ;;
        --) shift; break ;;
        *) log_error "Tham số không hợp lệ." ;;
    esac
done

#==============================================================================
# 1. CHUẨN BỊ DNS & PACMAN
#==============================================================================
echo "nameserver 1.1.1.1" > /etc/resolv.conf

# Bật ParallelDownloads trong hệ thống mới
if grep -q "^#ParallelDownloads" /etc/pacman.conf; then
    sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 8/' /etc/pacman.conf
elif ! grep -q "^ParallelDownloads" /etc/pacman.conf; then
    sed -i '/\[options\]/a ParallelDownloads = 8' /etc/pacman.conf
fi

log_info "Tải danh sách gói..."
PROGS_FILE="/tmp/progs.csv"
curl -Ls --retry 3 "${PROGS_LIST_URL}" | sed '/^#/d' > "${PROGS_FILE}"
[ ! -s "${PROGS_FILE}" ] && log_error "Danh sách gói trống hoặc không tải được."

#==============================================================================
# 2. BATCH INSTALL PACMAN PACKAGES (1 lệnh duy nhất)
#==============================================================================
log_info "Thu thập tất cả gói Pacman để cài đặt đồng loạt..."

PACMAN_PKGS=()
while IFS=, read -r tag program comment; do
    if [[ "$tag" == "" || "$tag" == "M" ]]; then
        PACMAN_PKGS+=("$program")
    fi
done < "${PROGS_FILE}"

if [ ${#PACMAN_PKGS[@]} -gt 0 ]; then
    log_info "Cài đặt ${#PACMAN_PKGS[@]} gói Pacman trong 1 lệnh..."
    pacman -S --noconfirm --needed "${PACMAN_PKGS[@]}" || log_warn "Một số gói Pacman cài đặt thất bại."
else
    log_info "Không có gói Pacman nào cần cài đặt."
fi

#==============================================================================
# 3. CHUẨN BỊ USER & BUILD AUR/SUCK LESS
#==============================================================================
AUR_HELPER="yay"
log_info "Chuẩn bị môi trường build cho user '${USER_NAME}'..."
mkdir -p "/home/${USER_NAME}/.local/src"
chown -R "${USER_NAME}:${USER_NAME}" "/home/${USER_NAME}/.local"

sudo -u "${USER_NAME}" /bin/bash -c '
    set -euo pipefail
    SRC_DIR="$HOME/.local/src"
    PROGS_FILE="'${PROGS_FILE}'"
    SKIP_BUILD="'${SKIP_BUILD}'"

    log_user() { echo -e "  \e[1;34m[USER]\e[0m $*"; }
    log_err_u() { echo -e "  \e[1;31m[FAIL]\e[0m $*"; }

    # Cài đặt thủ công từ AUR Snapshot (dự phòng)
    install_manual() {
        pkg="$1"
        log_user "Tải Snapshot cho: $pkg..."
        cd "$SRC_DIR"
        rm -rf "$pkg" "$pkg.tar.gz"
        # Sửa lại URL AUR chuẩn
        curl -L -k -O "https://aur.archlinux.org/cgit/aur.git/snapshot/${pkg}.tar.gz"
        if [ -f "${pkg}.tar.gz" ]; then
            tar -xvf "${pkg}.tar.gz" > /dev/null
            cd "$pkg"
            makepkg -si --noconfirm --needed --nocheck --skippgpcheck
        else
            return 1
        fi
    }

    # Cài yay-bin (AUR helper)
    if ! command -v yay &> /dev/null; then
        log_user "Cài đặt yay-bin..."
        install_manual "yay-bin" || log_err_u "Không cài được yay-bin. Vui lòng kiểm tra mạng."
    fi

    # Cài gói AUR (tag "A")
    while IFS=, read -r tag program comment; do
        case "$tag" in
            "A")
                log_user "Cài đặt AUR: ${program}"
                if ! yay -S --noconfirm --needed --mflags "--nocheck" "$program"; then
                    log_err_u "Yay lỗi, thử tải thủ công..."
                    install_manual "$program" || log_err_u "Bó tay với gói $program"
                fi
                ;;
        esac
    done < "${PROGS_FILE}"

    # Build các công cụ Suckless từ Git (tag "G") - Đã cài sẵn libxcb và thư viện XCB
    if [ "$SKIP_BUILD" = false ]; then
        while IFS=, read -r tag program comment; do
            if [ "$tag" == "G" ]; then
                progname="${program##*/}"; progname="${progname%.git}"
                log_user "Build Git Repo: $progname"
                cd "$SRC_DIR"
                if [ -d "$progname" ] && [ ! -d "$progname/.git" ]; then
                    rm -rf "$progname"
                fi
                [ ! -d "$progname" ] && git clone --depth 1 "$program"
                cd "$progname" 2>/dev/null || continue
                if [ -f "config.mk" ] || [ -f "Makefile" ]; then
                    # Build and install, logging details if it fails
                    if ! (make && sudo make install); then
                        log_err_u "Lỗi biên dịch $progname. Hãy kiểm tra các file log tại /var/log/ để biết chi tiết."
                        exit 1
                    fi
                fi
            fi
        done < "${PROGS_FILE}"
    fi
'

log_info "Cài đặt ứng dụng hoàn tất."
mkdir -p /var/log
cp "${SCRIPT_LOG}" /var/log/setup_apps.log 2>/dev/null || true
