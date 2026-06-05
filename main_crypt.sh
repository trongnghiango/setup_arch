#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

#==============================================================================
# HÀM TIỆN ÍCH
#==============================================================================
log_info() { echo -e "\e[1;32m[INFO]\e[0m  $*"; }
log_warn() { echo -e "\e[1;33m[WARN]\e[0m  $*"; }
log_error() {
    echo -e "\e[1;31m[ERROR]\e[0m $*" >&2
    exit 1
}
step() { echo -e "\n\e[1;34m>>> $*\e[0m"; }

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "A fully automated Arch/Artix Linux + Desktop installer based on your dotfiles structure."
    echo
    echo "Options:"
    echo "  -u, --user <name>      Set the username (default: ka)"
    echo "  -d, --disk <device>    Set the installation disk (e.g., sda, vda) (default: vda)"
    echo "  -H, --hostname <name>  Set the hostname (default: archlinux)"
    echo "  -f, --filesystem <fs>  Set the root filesystem (ext4 or btrfs) (default: ext4)"
    echo "  -D, --dotfiles-method  Set the dotfiles method (rsync or stow) (default: stow)"
    echo "  -r, --dotfiles-repo    Set a custom dotfiles repo URL"
    echo "  -h, --help             Display this help message"
}

#==============================================================================
# CHƯƠNG TRÌNH CHÍNH
#==============================================================================

main() {
    # --- Cấu hình Mặc định & Tham số ---
    local ENCRYPTION=true
    local USER_NAME="ka" DISK="vda" HOSTNAME="archlinux" FILESYSTEM="ext4" DOTFILES_METHOD="stow"
    local DOTFILES_RSYNC_REPO="https://github.com/trongnghiango/voidrice.git"
    local DOTFILES_STOW_REPO="https://github.com/trongnghiango/dotfiles-stow.git"
    local DOTFILES_REPO=""
    local PROGS_LIST_URL="https://raw.githubusercontent.com/trongnghiango/setup_arch/refs/heads/main/progs.csv"
    local TIME_ZONE="Asia/Ho_Chi_Minh" LOCALE="en_US.UTF-8"

    # ====================================================================
    # ADAPTER FUNCTIONS (Để tương thích ngược và chạy trên cả Arch/Artix)
    # ====================================================================
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
        PART_BOOT="${device}1"; PART_LVM="${device}2"
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
        local -a pkgs=(base base-devel linux-lts linux-firmware rsync xorg-xinit lvm2 grub efibootmgr sudo git curl neovim zsh dash libnewt)
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
        echo "${pkgs[@]}"
    }

    pgp_fix_before_pacstrap() {
        log_warn "Tạm thời vô hiệu hóa kiểm tra chữ ký PGP của môi trường LIVE để cài đặt ổn định..."
        cp /etc/pacman.conf /etc/pacman.conf.bak
        sed -i 's/^#*SigLevel.*/SigLevel = Never/' /etc/pacman.conf
        pacman -Syy --noconfirm
    }

    pgp_restore_after_pacstrap() {
        log_info "Khôi phục lại /etc/pacman.conf của môi trường LIVE..."
        mv /etc/pacman.conf.bak /etc/pacman.conf
    }

    # Phân tích tham số dòng lệnh
    local TEMP; TEMP=$(getopt -o u:d:H:f:D:r:h --long user:,disk:,hostname:,filesystem:,dotfiles-method:,dotfiles-repo:,help -n "$0" -- "$@")
    if [ $? != 0 ]; then log_error "Terminating..."; fi
    eval set -- "$TEMP"; unset TEMP
    while true; do
        case "$1" in
            -u|--user) USER_NAME="$2"; shift 2 ;; -d|--disk) DISK="$2"; shift 2 ;; -H|--hostname) HOSTNAME="$2"; shift 2 ;;
            -f|--filesystem) if [[ "$2" == "ext4" || "$2" == "btrfs" ]]; then FILESYSTEM="$2"; else log_error "Filesystem không hợp lệ: '$2'."; fi; shift 2 ;;
            -D|--dotfiles-method) if [[ "$2" == "rsync" || "$2" == "stow" ]]; then DOTFILES_METHOD="$2"; else log_error "Phương pháp dotfiles không hợp lệ: '$2'."; fi; shift 2 ;;
            -r|--dotfiles-repo) DOTFILES_REPO="$2"; shift 2 ;; -h|--help) usage; exit 0 ;; --) shift; break ;; *) log_error "Internal error!" ;;
        esac
    done
    if [ -z "${DOTFILES_REPO}" ]; then
        if [ "${DOTFILES_METHOD}" == "rsync" ]; then DOTFILES_REPO="${DOTFILES_RSYNC_REPO}"; else DOTFILES_REPO="${DOTFILES_STOW_REPO}"; fi
    fi

    # Khởi tạo các biến môi trường phát hiện động
    local INIT_SYSTEM; INIT_SYSTEM=$(os_detect_init)
    local PART_BOOT PART_LVM PV_DEVICE
    
    # --- Bắt đầu ---
    clear; log_info "Bắt đầu quy trình cài đặt Arch/Artix Linux + Desktop."
    echo "-------------------------------------------------"
    echo "Cấu hình sẽ được sử dụng:"
    echo "  - User:           ${USER_NAME}"
    echo "  - Hostname:       ${HOSTNAME}"
    echo "  - Disk:           /dev/${DISK}"
    echo "  - Filesystem:     ${FILESYSTEM}"
    echo "  - Dotfiles method:${DOTFILES_METHOD}"
    echo "  - Dotfiles repo:  ${DOTFILES_REPO}"
    echo "  - Init system:    ${INIT_SYSTEM}"
    echo "-------------------------------------------------"
    read -sp "Nhập mật khẩu cho user '${USER_NAME}', 'root' và MÃ HÓA ĐĨA (nếu bật): " PASSWORD; echo; echo
    if [ -z "${PASSWORD}" ]; then log_error "Mật khẩu không được để trống."; fi
    read -rp "CẢNH BÁO: TOÀN BỘ DỮ LIỆU TRÊN /dev/${DISK} SẼ BỊ XÓA. Tiếp tục? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then log_info "Đã hủy."; exit 0; fi

    # GIAI ĐOẠN 1: CÀI ĐẶT ARCH/ARTIX CƠ BẢN
    step "Giai đoạn 1: Cài đặt hệ thống cơ bản"
    local DEVICE="/dev/${DISK}"; log_info "Phân vùng..."
    disk_prepare "$DEVICE"

    disk_encrypt_setup "$PART_LVM" "$PASSWORD"

    log_info "Thiết lập LVM trên thiết bị, Định dạng, Mount..."
    pvcreate -ff -y "$PV_DEVICE"
    vgcreate -y vg0 "$PV_DEVICE"
    local RAM_SIZE_MB; RAM_SIZE_MB=$(free -m | awk '/^Mem:/{print $2}')
    lvcreate -L "${RAM_SIZE_MB}M" vg0 -n swap; lvcreate -l 100%FREE vg0 -n root
    mkfs.fat -F32 "${PART_BOOT}"; if [ "${FILESYSTEM}" = "btrfs" ]; then mkfs.btrfs -f /dev/vg0/root; else mkfs.ext4 -F /dev/vg0/root; fi
    mkswap /dev/vg0/swap; swapon /dev/vg0/swap; mount /dev/vg0/root /mnt; mkdir -p /mnt/boot; mount "${PART_BOOT}" /mnt/boot
    
    pgp_fix_before_pacstrap

    log_info "Tối ưu mirror và pacstrap..."; pacman -Sy --noconfirm --needed reflector &>/dev/null
    reflector --country 'VN,SG,JP,HK,TW' --protocol https --sort rate --save /etc/pacman.d/mirrorlist
    
    local -a PACKAGES_TO_INSTALL; IFS=' ' read -ra PACKAGES_TO_INSTALL <<< "$(os_get_base_packages "$FILESYSTEM" "$DOTFILES_METHOD")"
    if command -v basestrap &>/dev/null; then
        basestrap /mnt "${PACKAGES_TO_INSTALL[@]}"
    else
        pacstrap /mnt "${PACKAGES_TO_INSTALL[@]}"
    fi

    pgp_restore_after_pacstrap
    
    log_info "Tạo fstab và cấu hình chroot..."
    if command -v fstabgen &>/dev/null; then
        fstabgen -U /mnt >> /mnt/etc/fstab
    else
        genfstab -U /mnt >> /mnt/etc/fstab
    fi

    local PART_LVM_UUID; PART_LVM_UUID=$(disk_get_pv_uuid "$PART_LVM")
    local HOOKS_LINE; HOOKS_LINE=$(initramfs_get_hooks "$FILESYSTEM")
    local KERNEL_CMDLINE; KERNEL_CMDLINE=$(bootloader_get_kernel_cmdline "$PART_LVM_UUID")

    cat << VAR_FILE > /mnt/root/install_vars.sh
ENCRYPTION="${ENCRYPTION}"
INIT_SYSTEM="${INIT_SYSTEM}"
HOSTNAME="${HOSTNAME}"; USER_NAME="${USER_NAME}"; PASSWORD="${PASSWORD}"; LOCALE="${LOCALE}"; TIME_ZONE="${TIME_ZONE}"; FILESYSTEM="${FILESYSTEM}"; PART_LVM_UUID="${PART_LVM_UUID}"; HOOKS_LINE="${HOOKS_LINE}"; KERNEL_CMDLINE="${KERNEL_CMDLINE}"
VAR_FILE
    cat << 'CHROOT_SCRIPT' > /mnt/root/chroot_config.sh
#!/usr/bin/env bash
set -euo pipefail; source /root/install_vars.sh
ln -sf "/usr/share/zoneinfo/${TIME_ZONE}" /etc/localtime; hwclock --systohc
sed -i "s/^#${LOCALE}/${LOCALE}/" /etc/locale.gen; locale-gen; echo "LANG=${LOCALE}" > /etc/locale.conf
echo "${HOSTNAME}" > /etc/hostname

echo "--> Kích hoạt bảo mật và khởi tạo Pacman Keyring..."
pacman-key --init
if [ -f /etc/artix-release ]; then
    pacman-key --populate artix
else
    pacman-key --populate archlinux
fi
echo "--> Thực hiện nâng cấp toàn bộ hệ thống lần đầu..."
pacman -Syu --noconfirm

# Cấu hình mkinitcpio
sed -i "s/^HOOKS=.*/HOOKS=(${HOOKS_LINE})/" /etc/mkinitcpio.conf; mkinitcpio -P

# Cấu hình GRUB
sed -i "s|GRUB_CMDLINE_LINUX=\"\"|GRUB_CMDLINE_LINUX=\"${KERNEL_CMDLINE}\"|" /etc/default/grub

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck
grub-mkconfig -o /boot/grub/grub.cfg
useradd -m -U -G wheel -s /bin/zsh "${USER_NAME}";
echo "${USER_NAME}:${PASSWORD}" | chpasswd; echo "root:${PASSWORD}" | chpasswd
echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/99_install_privileges

    # Kích hoạt NetworkManager tương ứng với Init System
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
    chmod 644 /mnt/root/install_vars.sh; chmod 755 /mnt/root/chroot_config.sh
    
    if command -v artix-chroot &>/dev/null; then
        artix-chroot /mnt /bin/bash /root/chroot_config.sh
    else
        arch-chroot /mnt /bin/bash /root/chroot_config.sh
    fi
    rm /mnt/root/chroot_config.sh /mnt/root/install_vars.sh

    # GIAI ĐOẠN 2 & 3 (Không thay đổi, giữ nguyên)
    step "Giai đoạn 2: Cài đặt môi trường desktop"
    cp ./install_packages.sh /mnt/root/ && chmod +x /mnt/root/install_packages.sh
    
    if command -v artix-chroot &>/dev/null; then
        artix-chroot /mnt /root/install_packages.sh "${PROGS_LIST_URL}" "${USER_NAME}"
    else
        arch-chroot /mnt /root/install_packages.sh "${PROGS_LIST_URL}" "${USER_NAME}"
    fi

    if [ "${DOTFILES_METHOD}" == "rsync" ]; then
        cp ./setup_dotfiles.sh /mnt/root/ && chmod +x /mnt/root/setup_dotfiles.sh
        if command -v artix-chroot &>/dev/null; then
            artix-chroot /mnt /root/setup_dotfiles.sh "${DOTFILES_REPO}" "${USER_NAME}"
        else
            arch-chroot /mnt /root/setup_dotfiles.sh "${DOTFILES_REPO}" "${USER_NAME}"
        fi
    else # stow
        cp ./setup_dotfiles_stow.sh /mnt/root/ && chmod +x /mnt/root/setup_dotfiles_stow.sh
        if command -v artix-chroot &>/dev/null; then
            artix-chroot /mnt /root/setup_dotfiles_stow.sh "${DOTFILES_REPO}" "${USER_NAME}"
        else
            arch-chroot /mnt /root/setup_dotfiles_stow.sh "${DOTFILES_REPO}" "${USER_NAME}"
        fi
    fi
    
    step "Giai đoạn 3: Dọn dẹp"
    if command -v artix-chroot &>/dev/null; then
        artix-chroot /mnt rm /etc/sudoers.d/99_install_privileges
        artix-chroot /mnt /bin/bash -c "echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel;"
        local dotfiles_script_to_remove="setup_dotfiles.sh"
        if [ "${DOTFILES_METHOD}" == "stow" ]; then dotfiles_script_to_remove="setup_dotfiles_stow.sh"; fi
        artix-chroot /mnt rm /root/install_packages.sh "/root/${dotfiles_script_to_remove}"
    else
        arch-chroot /mnt rm /etc/sudoers.d/99_install_privileges
        arch-chroot /mnt /bin/bash -c "echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel;"
        local dotfiles_script_to_remove="setup_dotfiles.sh"
        if [ "${DOTFILES_METHOD}" == "stow" ]; then dotfiles_script_to_remove="setup_dotfiles_stow.sh"; fi
        arch-chroot /mnt rm /root/install_packages.sh "/root/${dotfiles_script_to_remove}"
    fi
    
    rm -f /mnt/tmp/progs.csv
    log_info "CÀI ĐẶT HOÀN TẤT!"
    log_info "Bây giờ anh có thể unmount và khởi động lại."
    printf "\n  umount -R /mnt\n  reboot\n\n"
}

main "$@"
