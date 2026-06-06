#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

#==============================================================================
# KIỂM TRA UEFI (BẮT BUỘC)
#==============================================================================
if [ ! -d "/sys/firmware/efi" ]; then
    echo -e "\e[1;31m[ERROR]\e[0m Hệ thống đang khởi động ở chế độ BIOS/Legacy."
    echo -e "Script này sử dụng ổ đĩa GPT và GRUB EFI, CHỈ HỖ TRỢ UEFI."
    echo -e "Vui lòng khởi động lại máy, truy cập BIOS và chọn boot USB ở chế độ UEFI."
    exit 1
fi

#==============================================================================
# HÀM TIỆN ÍCH
#==============================================================================
SCRIPT_TIME="$(date +%Y%m%d_%H%M%S)"
SCRIPT_LOG="/tmp/setup_base_${SCRIPT_TIME}.log"
log_info() { echo -e "$(date '+%H:%M:%S') \e[1;32m[INFO]\e[0m  $*"; }
log_warn() { echo -e "$(date '+%H:%M:%S') \e[1;33m[WARN]\e[0m  $*"; }
log_error() {
    echo -e "$(date '+%H:%M:%S') \e[1;31m[ERROR]\e[0m $*" >&2
    exit 1
}
step() { echo -e "\n$(date '+%H:%M:%S') \e[1;34m>>> $*\e[0m"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
exec > >(tee -ai "${SCRIPT_LOG}") 2>&1

#==============================================================================
# KHỞI TẠO BIẾN CẤU HÌNH (Đã điền sẵn các URL mẫu để tránh lỗi)
#==============================================================================
ENCRYPTION=false
USER_NAME="ka"
DISK="vda"
HOSTNAME="archlinux"
FILESYSTEM="ext4"
DOTFILES_METHOD="stow"

# CHÚ Ý: BẠN HÃY THAY CÁC URL NÀY BẰNG REPO CỦA BẠN
DOTFILES_RSYNC_REPO="https://github.com/trongnghiango/voidrice.git"
DOTFILES_STOW_REPO="https://github.com/trongnghiango/dotfiles-stow.git"
DOTFILES_REPO=""
PROGS_LIST_URL="https://raw.githubusercontent.com/trongnghiango/setup_arch/refs/heads/main/progs.csv"


TIME_ZONE="Asia/Ho_Chi_Minh"
LOCALE="en_US.UTF-8"
PASSWORD=""

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Giai đoạn 1: Cài đặt hệ thống Arch/Artix CLI tối giản."
    echo
    echo "Options:"
    echo "  -u, --user <name>      Tên tài khoản (mặc định: ka)"
    echo "  -d, --disk <device>    Ổ đĩa cài đặt (ví dụ: sda, vda) (mặc định: vda)"
    echo "  -H, --hostname <name>  Tên máy (mặc định: archlinux)"
    echo "  -f, --filesystem <fs>  Hệ thống tập tin root (ext4 hoặc btrfs) (mặc định: ext4)"
    echo "  -D, --dotfiles-method  Phương pháp dotfiles (rsync hoặc stow) (mặc định: stow)"
    echo "  -r, --dotfiles-repo    Đường dẫn git repo dotfiles tùy chỉnh"
    echo "  -p, --password <pass>  Mật khẩu cho user, root và LUKS (nếu mã hóa)"
    echo "  -e, --encrypt          Bật mã hóa đĩa LUKS"
    echo "  -h, --help             Hiển thị trợ giúp này"
}

#==============================================================================
# PHÁT HIỆN INIT SYSTEM & CHUẨN BỊ ĐĨA
#==============================================================================
os_detect_init() {
    if command -v rc-update &>/dev/null; then echo "openrc";
    elif [ -d /etc/runit ]; then echo "runit";
    elif command -v s6-service &>/dev/null; then echo "s6";
    else echo "systemd"; fi
}

disk_prepare() {
    local device="$1"
    log_info "Tắt swap, LVM, và đóng LUKS cũ nếu có..."
    swapoff -a || true
    vgchange -an vg0 || true
    cryptsetup close cryptlvm || true
    log_info "Đang dọn dẹp signature cũ trên $device..."
    wipefs -af "$device" || true
    log_info "Tạo bảng phân vùng GPT mới..."
    sgdisk -og -n 1:2048:+512M -t 1:ef00 -n 2:0:0 -t 2:8e00 "$device" || log_error "sgdisk thất bại!"
    
    # Logic xác định tên phân vùng chính xác (hỗ trợ NVMe, MMC, SD)
    if [[ "$device" =~ [0-9]$ ]]; then
        PART_BOOT="${device}p1"
        PART_LVM="${device}p2"
    else
        PART_BOOT="${device}1"
        PART_LVM="${device}2"
    fi
    
    log_info "Đồng bộ kernel..."
    udevadm settle || true
    blockdev --rereadpt "$device" || true
    sleep 2
    partprobe "$device" || udevadm settle || true
}

disk_encrypt_setup() {
    local lvm_part="$1" password="$2"
    if [ "$ENCRYPTION" = true ]; then
        log_info "Thiết lập mã hóa LUKS trên ${lvm_part}..."
        echo -n "$password" | cryptsetup luksFormat --type luks2 "$lvm_part" -
        log_info "Mở khóa phân vùng đã mã hóa..."
        echo -n "$password" | cryptsetup open "$lvm_part" cryptlvm -
        PV_DEVICE="/dev/mapper/cryptlvm"
    else
        PV_DEVICE="$lvm_part"
    fi
}

disk_get_pv_uuid() {
    local lvm_part="$1"
    if [ "$ENCRYPTION" = true ]; then
        blkid -s UUID -o value "$lvm_part"
    else
        echo ""
    fi
}

initramfs_get_hooks() {
    local fs="$1"
    if [ "$ENCRYPTION" = true ]; then
        if [ "$fs" = "btrfs" ]; then
            echo "base udev autodetect keyboard keymap modconf block btrfs encrypt lvm2 filesystems fsck"
        else
            echo "base udev autodetect keyboard keymap modconf block encrypt lvm2 filesystems fsck"
        fi
    else
        if [ "$fs" = "btrfs" ]; then
            echo "base udev autodetect keyboard keymap modconf block btrfs lvm2 filesystems fsck"
        else
            echo "base udev autodetect keyboard keymap modconf block lvm2 filesystems fsck"
        fi
    fi
}

bootloader_get_kernel_cmdline() {
    local lvm_uuid="$1"
    if [ "$ENCRYPTION" = true ] && [ -n "$lvm_uuid" ]; then
        echo "cryptdevice=UUID=${lvm_uuid}:cryptlvm root=/dev/vg0/root"
    else
        echo "root=/dev/vg0/root"
    fi
}

os_get_base_packages() {
    local fs="$1" method="$2"
    local kernel="linux-lts"
    # Artix Linux mặc định không có linux-lts trong repo system/world
    if [ -f /etc/artix-release ] || command -v basestrap >/dev/null 2>&1; then
        kernel="linux"
    fi
    # Thêm sẵn các thư viện phát triển X11 và XCB phục vụ biên dịch các gói suckless
    local -a pkgs=(
        base base-devel "$kernel" linux-firmware rsync xorg-xinit lvm2 grub efibootmgr sudo git curl neovim zsh dash libnewt
        libxcb xcb-util xcb-util-image xcb-util-keysyms xcb-util-wm
        libx11 libxft libxinerama libxrandr imlib2
    )
    [ "$ENCRYPTION" = true ] && pkgs+=(cryptsetup)
    [ "$fs" = "btrfs" ] && pkgs+=(btrfs-progs)
    [ "$method" = "stow" ] && pkgs+=(stow)
    
    # Thêm service packages tương ứng với Init System
    case "$INIT_SYSTEM" in
        openrc) pkgs+=(openrc elogind-openrc networkmanager-openrc lvm2-openrc) ;;
        runit)  pkgs+=(runit elogind-runit networkmanager-runit lvm2-runit) ;;
        s6)     pkgs+=(s6 elogind-s6 networkmanager-s6 lvm2-s6) ;;
        *)      pkgs+=(networkmanager) ;;
    esac
    printf "%s\n" "${pkgs[@]}"
}

pgp_fix_before_pacstrap() {
    log_warn "Tạm thời vô hiệu hóa kiểm tra chữ ký PGP của môi trường LIVE để cài đặt ổn định..."
    cp /etc/pacman.conf /etc/pacman.conf.bak
    sed -i 's/^#*SigLevel.*/SigLevel = Never/' /etc/pacman.conf
    # Bật tải song song gói trên môi trường Live
    if grep -q "^#ParallelDownloads" /etc/pacman.conf; then
        sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 8/' /etc/pacman.conf
    elif ! grep -q "^ParallelDownloads" /etc/pacman.conf; then
        sed -i '/\[options\]/a ParallelDownloads = 8' /etc/pacman.conf
    fi
    pacman -Syy --noconfirm
}

pgp_restore_after_pacstrap() {
    log_info "Khôi phục lại /etc/pacman.conf của môi trường LIVE..."
    mv /etc/pacman.conf.bak /etc/pacman.conf
}

#==============================================================================
# XỬ LÝ ĐẦU VÀO
#==============================================================================
TEMP=$(getopt -o u:d:H:f:D:r:p:eh --long user:,disk:,hostname:,filesystem:,dotfiles-method:,dotfiles-repo:,password:,encrypt,help -n "$0" -- "$@")
if [ $? != 0 ]; then log_error "Lỗi phân tích tham số."; fi
eval set -- "$TEMP"; unset TEMP
while true; do
    case "$1" in
        -u|--user) USER_NAME="$2"; shift 2 ;;
        -d|--disk) DISK="$2"; shift 2 ;;
        -H|--hostname) HOSTNAME="$2"; shift 2 ;;
        -f|--filesystem)
            if [[ "$2" == "ext4" || "$2" == "btrfs" ]]; then FILESYSTEM="$2"; else log_error "Filesystem không hợp lệ."; fi
            shift 2 ;;
        -D|--dotfiles-method)
            if [[ "$2" == "rsync" || "$2" == "stow" ]]; then DOTFILES_METHOD="$2"; else log_error "Phương pháp không hợp lệ."; fi
            shift 2 ;;
        -r|--dotfiles-repo) DOTFILES_REPO="$2"; shift 2 ;;
        -p|--password) PASSWORD="$2"; shift 2 ;;
        -e|--encrypt) ENCRYPTION=true; shift ;;
        -h|--help) usage; exit 0 ;;
        --) shift; break ;;
        *) log_error "Tham số không hợp lệ." ;;
    esac
done

if [ -z "${DOTFILES_REPO}" ]; then
    if [ "${DOTFILES_METHOD}" == "rsync" ]; then DOTFILES_REPO="${DOTFILES_RSYNC_REPO}"; else DOTFILES_REPO="${DOTFILES_STOW_REPO}"; fi
fi

INIT_SYSTEM=$(os_detect_init)
PART_BOOT=""
PART_LVM=""
PV_DEVICE=""

clear; log_info "--- GIAI ĐOẠN 1: CÀI ĐẶT HỆ THỐNG CƠ BẢN (CLI) ---"
echo "-------------------------------------------------"
echo "Cấu hình sẽ được sử dụng:"
echo "  - User:           ${USER_NAME}"
echo "  - Hostname:       ${HOSTNAME}"
echo "  - Disk:           /dev/${DISK}"
echo "  - Filesystem:     ${FILESYSTEM}"
echo "  - Encryption:     ${ENCRYPTION}"
echo "  - Dotfiles method:${DOTFILES_METHOD}"
echo "  - Dotfiles repo:  ${DOTFILES_REPO}"
echo "  - Init system:    ${INIT_SYSTEM}"
echo "-------------------------------------------------"

# TÌM XUỐNG ĐOẠN XỬ LÝ NHẬP MẬT KHẨU (Sửa lại để an toàn hơn)
if [ -z "${PASSWORD}" ]; then
    # Yêu cầu nhập 2 lần để tránh gõ sai
    while true; do
        read -sp "Nhập mật khẩu cho user '${USER_NAME}', 'root' và LUKS: " PASS1; echo
        read -sp "Nhập lại mật khẩu để xác nhận: " PASS2; echo
        if [ "$PASS1" = "$PASS2" ] && [ -n "$PASS1" ]; then
            PASSWORD="$PASS1"
            break
        else
            log_warn "Mật khẩu không khớp hoặc bị trống. Vui lòng nhập lại."
        fi
    done
fi

read -rp "CẢNH BÁO: Dữ liệu trên /dev/${DISK} sẽ bị XÓA SẠCH. Tiếp tục? [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then log_info "Đã hủy."; exit 0; fi

# Dọn dẹp mount, swap, LVM, LUKS cũ để chạy lại an toàn
log_info "Dọn dẹp mount, swap, LVM và LUKS cũ..."
if mountpoint -q /mnt; then umount -R /mnt 2>/dev/null || true; fi
swapoff -a 2>/dev/null || true
vgchange -an vg0 2>/dev/null || true
cryptsetup close cryptlvm 2>/dev/null || true

# Cài đặt công cụ phân vùng và LVM trên Live environment
pgp_fix_before_pacstrap
pacman -Sy --noconfirm --needed parted gptfdisk lvm2

# Thực hiện phân vùng
DEVICE="/dev/${DISK}"
disk_prepare "$DEVICE"
disk_encrypt_setup "$PART_LVM" "$PASSWORD"

log_info "Thiết lập LVM, định dạng và mount..."
pvcreate -ff -y "$PV_DEVICE"
vgcreate -y vg0 "$PV_DEVICE"
RAM_SIZE_MB=$(free -m | awk '/^Mem:/{print $2}')
lvcreate -L "${RAM_SIZE_MB}M" vg0 -n swap
lvcreate -l 100%FREE vg0 -n root
mkfs.fat -F32 "${PART_BOOT}"

if [ "${FILESYSTEM}" = "btrfs" ]; then
    mkfs.btrfs -f /dev/vg0/root
else
    mkfs.ext4 -F /dev/vg0/root
fi

mkswap /dev/vg0/swap
swapon /dev/vg0/swap
mount /dev/vg0/root /mnt
mkdir -p /mnt/boot
mount "${PART_BOOT}" /mnt/boot

# Cập nhật cơ sở dữ liệu pacman (mirrorlist đã được tối ưu riêng)
log_info "Sử dụng mirrorlist hiện tại..."
pacman -Syy --noconfirm

PACKAGES_TO_INSTALL=( $(os_get_base_packages "$FILESYSTEM" "$DOTFILES_METHOD") )
log_info "Bắt đầu cài đặt các gói CLI cơ bản vào /mnt..."

# Xác định trình cài đặt là basestrap (Artix) hoặc pacstrap (Arch)
INSTALLER=""
if command -v basestrap &>/dev/null; then
    INSTALLER="basestrap"
elif command -v pacstrap &>/dev/null; then
    INSTALLER="pacstrap"
else
    log_error "Không tìm thấy lệnh cài đặt (basestrap/pacstrap). Hãy cài gói arch-install-scripts hoặc tương đương."
fi

# Chạy lệnh cài đặt
$INSTALLER /mnt "${PACKAGES_TO_INSTALL[@]}"

pgp_restore_after_pacstrap

log_info "Tạo fstab..."
if command -v fstabgen &>/dev/null; then
    fstabgen -U /mnt >> /mnt/etc/fstab
else
    genfstab -U /mnt >> /mnt/etc/fstab
fi

PART_LVM_UUID=$(disk_get_pv_uuid "$PART_LVM")
HOOKS_LINE=$(initramfs_get_hooks "$FILESYSTEM")
KERNEL_CMDLINE=$(bootloader_get_kernel_cmdline "$PART_LVM_UUID")

# Viết tệp tham số và cấu hình chroot
cat << VAR_FILE > /mnt/root/install_vars.sh
ENCRYPTION="${ENCRYPTION}"
INIT_SYSTEM="${INIT_SYSTEM}"
HOSTNAME="${HOSTNAME}"; USER_NAME="${USER_NAME}"; PASSWORD="${PASSWORD}"; LOCALE="${LOCALE}"; TIME_ZONE="${TIME_ZONE}"; FILESYSTEM="${FILESYSTEM}"; PART_LVM_UUID="${PART_LVM_UUID}"; HOOKS_LINE="${HOOKS_LINE}"; KERNEL_CMDLINE="${KERNEL_CMDLINE}"
DOTFILES_METHOD="${DOTFILES_METHOD}"
DOTFILES_REPO="${DOTFILES_REPO}"
PROGS_LIST_URL="${PROGS_LIST_URL}"
VAR_FILE

cat << 'CHROOT_SCRIPT' > /mnt/root/chroot_config.sh
#!/usr/bin/env bash
set -euo pipefail
source /root/install_vars.sh

# Đồng bộ thời gian & Locale
ln -sf "/usr/share/zoneinfo/${TIME_ZONE}" /etc/localtime
hwclock --systohc
sed -i "s/^#${LOCALE}/${LOCALE}/" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "${HOSTNAME}" > /etc/hostname

# Khởi tạo Pacman Keyring
pacman-key --init
if [ -f /etc/artix-release ]; then
    pacman-key --populate artix
else
    pacman-key --populate archlinux
fi

# Tải song song gói trong hệ thống mới
if grep -q "^#ParallelDownloads" /etc/pacman.conf; then
    sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 8/' /etc/pacman.conf
elif ! grep -q "^ParallelDownloads" /etc/pacman.conf; then
    sed -i '/\[options\]/a ParallelDownloads = 8' /etc/pacman.conf
fi

pacman -Syu --noconfirm

# Cấu hình initramfs & bootloader
sed -i "s/^HOOKS=.*/HOOKS=(${HOOKS_LINE})/" /etc/mkinitcpio.conf
mkinitcpio -P
sed -i "s|GRUB_CMDLINE_LINUX=\"\"|GRUB_CMDLINE_LINUX=\"${KERNEL_CMDLINE}\"|" /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck
grub-mkconfig -o /boot/grub/grub.cfg

# Cấu hình tài khoản người dùng
useradd -m -U -G wheel -s /bin/zsh "${USER_NAME}"
echo "${USER_NAME}:${PASSWORD}" | chpasswd
echo "root:${PASSWORD}" | chpasswd
echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/99_install_privileges

# Kích hoạt NetworkManager và D-Bus tùy thuộc Init System
case "$INIT_SYSTEM" in
    openrc) rc-update add NetworkManager default; rc-update add dbus default ;;
    runit)  ln -sf /etc/runit/sv/NetworkManager /etc/runit/runsvdir/default/
            ln -sf /etc/runit/sv/dbus /etc/runit/runsvdir/default/ ;;
    s6)     s6-service enable default NetworkManager
            s6-service enable default dbus ;;
    *)      systemctl enable NetworkManager ;;
esac

ln -sfT /bin/dash /bin/sh
CHROOT_SCRIPT

chmod 644 /mnt/root/install_vars.sh
chmod 755 /mnt/root/chroot_config.sh

log_info "Thực thi chroot cấu hình hệ thống..."
if command -v artix-chroot &>/dev/null; then
    artix-chroot /mnt /bin/bash /root/chroot_config.sh
else
    arch-chroot /mnt /bin/bash /root/chroot_config.sh
fi

rm /mnt/root/chroot_config.sh

# Lưu lại các file script cài đặt sang hệ thống mới để chạy offline/post-install dễ dàng
mkdir -p "/mnt/home/${USER_NAME}/setup_arch"
cp -r "${SCRIPT_DIR}"/* "/mnt/home/${USER_NAME}/setup_arch/"

# Dùng chroot để đổi quyền vì user chỉ tồn tại bên trong /mnt
if command -v artix-chroot &>/dev/null; then
    artix-chroot /mnt chown -R "${USER_NAME}:${USER_NAME}" "/home/${USER_NAME}/setup_arch/"
else
    arch-chroot /mnt chown -R "${USER_NAME}:${USER_NAME}" "/home/${USER_NAME}/setup_arch/"
fi

# Sao chép log setup_base vào phân vùng mới
cp "${SCRIPT_LOG}" /mnt/var/log/setup_base.log 2>/dev/null || true

log_info "GIAI ĐOẠN 1 HOÀN TẤT!"
log_info "Hệ điều hành CLI đã được cài đặt thành công."
log_info "Anh có thể reboot vào hệ thống mới và chạy script setup để cài tiếp giao diện."
