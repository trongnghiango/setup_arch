#!/bin/sh

# Customized LARBS for GNU Stow & Custom Arch Setup
# Based on Luke's Auto Rice Bootstrapping Script (LARBS)

### OPTIONS AND VARIABLES ###

# THAY ĐỔI ĐƯỜNG DẪN ĐẾN KHO DOTFILES CỦA BẠN TẠI ĐÂY
dotfilesrepo="https://github.com/trongnghiango/dotfiles-stow.git" # Thay thế bằng link Git dotfiles thực tế của bạn
aurhelper="yay"
repobranch="main"
export TERM=ansi

### FUNCTIONS ###

installpkg() {
	pacman --noconfirm --needed -S "$1" >/dev/null 2>&1
}

error() {
	printf "%s\n" "$1" >&2
	exit 1
}

welcomemsg() {
	whiptail --title "Welcome!" \
		--msgbox "Welcome to your customized Arch Bootstrapping Script!\\n\\nThis script will install your custom terminal-centric system on Arch Linux." 10 60

	whiptail --title "Important Note!" --yes-button "All ready!" \
		--no-button "Return..." \
		--yesno "Be sure the computer you are using has current pacman updates and refreshed Arch keyrings.\\n\\nIf it does not, the installation of some programs might fail." 8 70
}

getuserandpass() {
	name=$(whiptail --inputbox "First, please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
	while ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; do
		name=$(whiptail --nocancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
	pass1=$(whiptail --nocancel --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
	pass2=$(whiptail --nocancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
		pass1=$(whiptail --nocancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
		pass2=$(whiptail --nocancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
}

usercheck() {
	! { id -u "$name" >/dev/null 2>&1; } ||
		whiptail --title "WARNING" --yes-button "CONTINUE" \
			--no-button "No wait..." \
			--yesno "The user \`$name\` already exists on this system. Installing can overwrite conflicting settings/dotfiles on the user account.\\n\\nOnly click <CONTINUE> if you don't mind your settings being overwritten." 14 70
}

preinstallmsg() {
	whiptail --title "Let's get this party started!" --yes-button "Let's go!" \
		--no-button "No, nevermind!" \
		--yesno "The rest of the installation will now be automated.\\n\\nNow just press <Let's go!> and the system will begin installation!" 13 60 || {
		clear
		exit 1
	}
}

adduserandpass() {
	whiptail --infobox "Adding user \"$name\"..." 7 50
	useradd -m -g wheel -s /bin/zsh "$name" >/dev/null 2>&1 ||
		usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
	export repodir="/home/$name/.local/src"
	mkdir -p "$repodir"
	chown -R "$name":wheel "$(dirname "$repodir")"
	echo "$name:$pass1" | chpasswd
	unset pass1 pass2
}

refreshkeys() {
	whiptail --infobox "Refreshing Arch Keyring..." 7 40
	pacman --noconfirm -S archlinux-keyring >/dev/null 2>&1
}

manualinstall() {
	pacman -Qq "$1" && return 0
	whiptail --infobox "Installing \"$1\" manually." 7 50
	sudo -u "$name" mkdir -p "$repodir/$1"
	sudo -u "$name" git -C "$repodir" clone --depth 1 --single-branch \
		--no-tags -q "https://aur.archlinux.org/$1.git" "$repodir/$1" ||
		{
			cd "$repodir/$1" || return 1
			sudo -u "$name" git pull --force origin master
		}
	cd "$repodir/$1" || exit 1
	sudo -u "$name" \
		makepkg --noconfirm -si >/dev/null 2>&1 || return 1
}

maininstall() {
	whiptail --title "Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" 9 70
	installpkg "$1"
}

gitmakeinstall() {
	progname="${1##*/}"
	progname="${progname%.git}"
	dir="$repodir/$progname"
	whiptail --title "Installation" \
		--infobox "Installing \`$progname\` ($n of $total) via \`git\` and \`make\`." 8 70
	sudo -u "$name" git -C "$repodir" clone --depth 1 --single-branch \
		--no-tags -q "$1" "$dir" ||
		{
			cd "$dir" || return 1
			sudo -u "$name" git pull --force origin master
		}
	cd "$dir" || exit 1
	make >/dev/null 2>&1
	make install >/dev/null 2>&1
	cd /tmp || return 1
}

aurinstall() {
	whiptail --title "Installation" \
		--infobox "Installing \`$1\` ($n of $total) from the AUR." 9 70
	echo "$aurinstalled" | grep -q "^$1$" && return 1
	sudo -u "$name" $aurhelper -S --noconfirm "$1" >/dev/null 2>&1
}

pipinstall() {
	whiptail --title "Installation" \
		--infobox "Installing Python package \`$1\` ($n of $total)." 9 70
	[ -x "$(command -v "pip")" ] || installpkg python-pip >/dev/null 2>&1
	yes | pip install "$1"
}

installationloop() {
	local_csv="/home/$name/.dotfiles/setup_arch/progs.csv"
	if [ -f "$local_csv" ]; then
		cp "$local_csv" /tmp/progs.csv
		whiptail --infobox "Found your custom progs.csv in dotfiles! Using it." 7 60
	else
		error "Could not find progs.csv in /home/$name/.dotfiles/setup_arch/progs.csv. Please ensure your repository is correct."
	fi

	total=$(wc -l </tmp/progs.csv)
	aurinstalled=$(pacman -Qqm)
	n=0
	while IFS=, read -r tag program comment; do
		# Bỏ qua dòng trống hoặc comment
		case "$tag" in
			"#"* | "") continue ;;
		esac
		n=$((n + 1))
		echo "$comment" | grep -q "^\".*\"$" &&
			comment="$(echo "$comment" | sed -E "s/(^\"|\"$)//g")"
		case "$tag" in
		"A") aurinstall "$program" "$comment" ;;
		"G") gitmakeinstall "$program" "$comment" ;;
		"P") pipinstall "$program" "$comment" ;;
		*) maininstall "$program" "$comment" ;;
		esac
	done </tmp/progs.csv
}

clonedotfiles() {
	whiptail --infobox "Cloning your custom dotfiles repository..." 7 60
	dotfilesdir="/home/$name/.dotfiles"
	[ -d "$dotfilesdir" ] && rm -rf "$dotfilesdir"
	sudo -u "$name" git clone --recursive -b "$repobranch" "$dotfilesrepo" "$dotfilesdir" ||
		error "Failed to clone dotfiles repository."
}

deploydotfiles() {
	whiptail --infobox "Deploying config files using GNU Stow..." 7 60
	dotfilesdir="/home/$name/.dotfiles"
	cd "$dotfilesdir" || return
	
	# Duyệt qua các thư mục con trong .dotfiles và stow chúng
	for folder in */; do
		folder="${folder%/}"
		# Bỏ qua các thư mục không cần stow trực tiếp vào $HOME
		case "$folder" in
			"docs"|"nixos"|"setup_arch"|"cron"|"images")
				continue
				;;
		esac
		sudo -u "$name" stow -vt "/home/$name" "$folder"
	done
}

lazyinstall() {
	whiptail --infobox "Bootstrapping Neovim plugins via lazy.nvim..." 7 60
	# Chạy headless nvim để kích hoạt quá trình tự động tải của lazy.nvim
	sudo -u "$name" nvim --headless "+Lazy! sync" +qa >/dev/null 2>&1
}

finalize() {
	whiptail --title "All done!" \
		--msgbox "Congratulations! The installation script has completed successfully.\\n\\nTo run the new graphical environment, log out and log back in as your new user, then run \"startx\"." 13 80
}

### THE ACTUAL SCRIPT ###

# Check root and base requirements
pacman --noconfirm --needed -Sy libnewt ||
	error "Are you sure you're running this as the root user, are on an Arch-based distribution and have an internet connection?"

welcomemsg || error "User exited."
getuserandpass || error "User exited."
usercheck || error "User exited."
preinstallmsg || error "User exited."

# Refresh keys
refreshkeys || error "Error refreshing keyrings."

# Install core utilities needed for script execution (added stow)
for x in curl ca-certificates base-devel git ntp zsh dash stow xf86-input-libinput; do
	whiptail --title "LARBS Installation" \
		--infobox "Installing bootstrap utility \`$x\`..." 8 70
	installpkg "$x"
done

whiptail --title "LARBS Installation" \
	--infobox "Synchronizing system time..." 8 70
ntpd -q -g >/dev/null 2>&1

adduserandpass || error "Error adding username and/or password."

[ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers

# Temp passwordless sudo for installation
trap 'rm -f /etc/sudoers.d/larbs-temp' HUP INT QUIT TERM PWR EXIT
echo "%wheel ALL=(ALL) NOPASSWD: ALL
Defaults:%wheel,root runcwd=*" >/etc/sudoers.d/larbs-temp

# Pacman optimizations
grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
sed -Ei "s/^#(ParallelDownloads).*/\1 = 5/;/^#Color$/s/#//" /etc/pacman.conf

# Makeflags optimization
sed -i "s/-j2/-j$(nproc)/;/^#MAKEFLAGS/s/^#//" /etc/makepkg.conf

# Install AUR Helper
manualinstall $aurhelper || error "Failed to install AUR helper."
$aurhelper -Y --save --devel

# Clone dotfiles đầu tiên để có file progs.csv và cấu hình
clonedotfiles

# Chạy vòng lặp cài đặt các gói phần mềm dựa trên progs.csv của bạn
installationloop

# Triển khai cấu hình dotfiles bằng GNU Stow
deploydotfiles

# Kích hoạt tải plugins Neovim bằng lazy.nvim
lazyinstall

# Tắt tiếng beep khó chịu của loa bo mạch
rmmod pcspkr >/dev/null 2>&1
echo "blacklist pcspkr" >/etc/modprobe.d/nobeep.conf

# Thiết lập thư mục và Shell mặc định cho user
chsh -s /bin/zsh "$name" >/dev/null 2>&1
sudo -u "$name" mkdir -p "/home/$name/.cache/zsh/"
sudo -u "$name" mkdir -p "/home/$name/.config/mpd/playlists/"

# Chuyển đổi liên kết /bin/sh sang /bin/dash để tăng tốc xử lý script
ln -sfT /bin/dash /bin/sh >/dev/null 2>&1

# Đồng bộ hóa cấu hình thiết bị đầu vào (Keyboard & Touchpad) cho X230
mkdir -p /etc/X11/xorg.conf.d

# 1. Layout bàn phím và phím Caps Lock -> Super
cat <<EOF >/etc/X11/xorg.conf.d/00-keyboard.conf
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "us"
        Option "XkbOptions" "caps:super,altwin:menu_win"
EndSection
EOF

# 2. Touchpad Tapping & Natural Scrolling
cat <<EOF >/etc/X11/xorg.conf.d/40-libinput.conf
Section "InputClass"
        Identifier "libinput touchpad catchall"
        MatchIsTouchpad "on"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
        Option "Tapping" "on"
        Option "NaturalScrolling" "true"
EndSection
EOF

# Cấp quyền sudo có mật khẩu an toàn khi hoàn thành hệ thống
echo "%wheel ALL=(ALL:ALL) ALL" >/etc/sudoers.d/00-larbs-wheel-can-sudo
echo "%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys" >/etc/sudoers.d/01-larbs-cmds-without-password
echo "Defaults editor=/usr/bin/nvim" >/etc/sudoers.d/02-larbs-visudo-editor
mkdir -p /etc/sysctl.d
echo "kernel.dmesg_restrict = 0" > /etc/sysctl.d/dmesg.conf

# Cleanup sudo temp
rm -f /etc/sudoers.d/larbs-temp

finalize