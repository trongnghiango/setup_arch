# Danh sách các chương trình cài đặt (progs.csv)

Tài liệu này mô tả chi tiết các phần mềm và công cụ được cấu hình để cài đặt trong hệ thống Arch Linux của bạn, được chia theo các nhóm chức năng rõ ràng.

---

## Nhóm 1: Core & Build Tools (Hệ thống cốt lõi & Công cụ biên dịch)
Các gói cơ bản để xây dựng hệ thống Arch Linux tối giản và cung cấp môi trường biên dịch phần mềm.

| Tên gói | Loại | Mô tả / Mục đích |
| :--- | :---: | :--- |
| `base` | Arch | Hệ thống Arch Linux tối giản nhất. |
| `base-devel` | Arch | Bộ công cụ biên dịch thiết yếu (gcc, make, autoconf, v.v.). |
| `linux-lts` | Arch | Kernel Linux phiên bản Hỗ trợ Dài hạn (LTS) ổn định. |
| `linux-firmware` | Arch | Các tệp firmware cần thiết cho thiết bị phần cứng. |
| `grub` | Arch | Trình khởi động hệ thống GNU GRUB. |
| `efibootmgr` | Arch | Công cụ quản lý các tùy chọn khởi động UEFI EFI. |
| `lvm2` | Arch | Bộ công cụ quản lý phân vùng đĩa Logic (LVM). |
| `networkmanager` | Arch | Trình quản lý kết nối mạng daemon (Wi-Fi, Ethernet). |
| `sudo` | Arch | Cho phép chạy các lệnh với đặc quyền quản trị hệ thống. |
| `stow` | Arch | GNU Stow dùng để quản lý liên kết tượng trưng (symlinks) cho dotfiles. |
| `direnv` | Arch | Bộ chuyển đổi biến môi trường tự động dựa trên thư mục hiện tại. |
| `tuned` | Arch | Daemon điều chỉnh cấu hình hiệu năng hệ thống một cách linh hoạt. |
| `zram-generator` | Arch | Tự động thiết lập và quản lý bộ nhớ swap zram để tối ưu RAM. |
| `libxcrypt-compat` | Arch | Thư viện mã hóa tương thích ngược cho các phần mềm cũ. |
| `man-db` | Arch | Công cụ để đọc trang hướng dẫn (manual) của các lệnh. |

---

## Nhóm 2: X11 & WM & UI (Giao diện đồ họa & Trình quản lý cửa sổ)
Cấu hình máy chủ đồ họa X11, trình quản lý cửa sổ DWM cùng các tiện ích bổ trợ.

| Tên gói / URL | Loại | Mô tả / Mục đích |
| :--- | :---: | :--- |
| `xorg-server` | Arch | Máy chủ đồ họa Xorg chính. |
| `xorg-xinit` | Arch | Công cụ khởi chạy máy chủ đồ họa từ TTY (`startx`). |
| `xorg-xprop` | Arch | Tiện ích kiểm tra thuộc tính của cửa sổ X11. |
| `xorg-xrandr` | Arch | Cấu hình độ phân giải, tần số quét và màn hình hiển thị. |
| `xorg-xset` | Arch | Công cụ cấu hình các cài đặt của máy chủ X (như tắt màn hình, bàn phím). |
| `xorg-xsetroot` | Arch | Đặt tham số hiển thị cho cửa sổ gốc (background). |
| `xorg-xwininfo` | Arch | Truy vấn thông tin chi tiết về các cửa sổ đang chạy. |
| `picom` | Arch | Trình tổng hợp (compositor) giúp tạo hiệu ứng trong suốt, đổ bóng và chống xé hình. |
| `lxappearance` | Arch | Công cụ GUI để chọn theme GTK và bộ icon. |
| `dunst` | Arch | Daemon hiển thị thông báo hệ thống gọn nhẹ. |
| `rofi` | Arch | Trình khởi chạy ứng dụng, chuyển đổi cửa sổ thay thế dmenu. |
| `slock` | Arch | Trình khóa màn hình tối giản của suckless. |
| `stalonetray` | Arch | Khay hệ thống độc lập để hiển thị ứng dụng chạy ngầm. |
| `unclutter` | Arch | Ẩn con trỏ chuột khi không hoạt động để tránh vướng mắt. |
| `xcape` | Arch | Cấu hình gán phím đặc biệt (ví dụ chuyển đổi Escape/Super). |
| `xclip` | Arch | Giao tiếp với clipboard X11 thông qua dòng lệnh. |
| `xdotool` | Arch | Mô phỏng hành động bàn phím, chuột từ script dòng lệnh. |
| `xwallpaper` | Arch | Thiết lập ảnh nền màn hình. |
| `maim` | Arch | Chụp ảnh màn hình linh hoạt. |
| `yad` | Arch | Hiển thị các hộp thoại đồ họa GTK+ từ mã shell script. |
| `https://gitlab.com/ntnghiatn/dwmblocks.git` | Git | Thanh trạng thái dạng mô-đun cho DWM. |
| `https://gitlab.com/ntnghiatn/dmenu.git` | Git | Trình đơn động của suckless tùy biến để lựa chọn ứng dụng. |
| `https://gitlab.com/ntnghiatn/st.git` | Git | Trình giả lập terminal st (Simple Terminal) tùy biến riêng. |
| `https://gitlab.com/ntnghiatn/dwm.git` | Git | Trình quản lý cửa sổ xếp gạch DWM tùy biến riêng. |

---

## Nhóm 3: Vietnamese Input Method (Bộ gõ tiếng Việt)
Các gói phần mềm hỗ trợ gõ tiếng Việt trên môi trường Linux sử dụng bộ khung Fcitx5.

| Tên gói | Loại | Mô tả / Mục đích |
| :--- | :---: | :--- |
| `fcitx5` | Arch | Bộ khung quản lý gõ phím đa ngôn ngữ thế hệ mới. |
| `fcitx5-bamboo` | Arch | Bộ gõ tiếng Việt kiểu Bamboo (hỗ trợ nhiều chế độ gõ hiện đại). |
| `fcitx5-unikey` | Arch | Bộ gõ tiếng Việt kiểu Unikey truyền thống. |
| `fcitx5-configtool` | Arch | Công cụ GUI cấu hình giao diện và bộ gõ Fcitx5. |
| `fcitx5-gtk` | Arch | Thư viện hỗ trợ Fcitx5 hoạt động mượt mà trên ứng dụng GTK. |
| `fcitx5-qt` | Arch | Thư viện hỗ trợ Fcitx5 hoạt động mượt mà trên ứng dụng Qt. |

---

## Nhóm 4: Editors & Toolchains (Trình soạn thảo & Bộ công cụ lập trình)
Các trình soạn thảo mã nguồn và môi trường thực thi (runtime)/trình biên dịch ngôn ngữ lập trình.

| Tên gói | Loại | Mô tả / Mục đích |
| :--- | :---: | :--- |
| `neovim` | Arch | Trình soạn thảo văn bản nâng cao trên terminal (dùng cấu hình cá nhân). |
| `neovide` | Arch | Giao diện đồ họa (GUI) mượt mà cho Neovim. |
| `code` | Arch | Phiên bản mã nguồn mở của Visual Studio Code. |
| `cursor-bin` | AUR | Trình soạn thảo IDE tích hợp AI chuyên sâu. |
| `pycharm-community-edition` | Arch | IDE chuyên nghiệp cho ngôn ngữ Python (bản Cộng đồng). |
| `clang` | Arch | Bộ biên dịch C/C++ và các công cụ LLVM đi kèm. |
| `rust` | Arch | Bộ cài đặt trình biên dịch Rust và trình quản lý gói Cargo. |
| `python311` | AUR | Môi trường thực thi Python phiên bản 3.11. |
| `python-pip` | Arch | Trình quản lý gói thư viện cho Python. |
| `npm` | Arch | Trình quản lý gói cho môi trường Node.js. |
| `lua51` | Arch | Trình thông dịch ngôn ngữ Lua phiên bản 5.1. |
| `tree-sitter-cli` | Arch | Công cụ dòng lệnh phân tích cú pháp mã nguồn Tree-sitter. |

---

## Nhóm 5: CLI Utilities (Công cụ dòng lệnh tiện ích)
Các công cụ cải thiện năng suất làm việc hàng ngày trên Terminal.

| Tên gói | Loại | Mô tả / Mục đích |
| :--- | :---: | :--- |
| `bat` | Arch | Phiên bản cải tiến của `cat` với tính năng highlight cú pháp và tích hợp git. |
| `eza` | Arch | Trình liệt kê thư mục hiện đại thay thế cho `ls` với màu sắc và biểu tượng. |
| `fd` | Arch | Tìm kiếm tập tin và thư mục nhanh chóng, trực quan thay cho `find`. |
| `fzf` | Arch | Bộ lọc tìm kiếm mờ (fuzzy finder) cực nhanh trên terminal. |
| `btop` | Arch | Trình giám sát tài nguyên hệ thống đẹp mắt và chi tiết. |
| `htop-vim` | AUR | Trình giám sát tiến trình hệ thống hỗ trợ phím di chuyển Vim. |
| `jq` | Arch | Bộ phân tích và xử lý dữ liệu JSON trên dòng lệnh. |
| `lf` | Arch | Trình quản lý tệp tin trên terminal điều khiển hoàn toàn bằng bàn phím. |
| `tmux` | Arch | Trình đa nhiệm và quản lý phiên làm việc terminal. |
| `yt-dlp` | Arch | Công cụ tải video/âm thanh mạnh mẽ từ Youtube và hàng trăm trang web khác. |
| `trash-cli` | Arch | Công cụ quản lý thùng rác thay cho lệnh xóa vĩnh viễn `rm`. |
| `moreutils` | Arch | Bộ công cụ bổ trợ thêm các lệnh xử lý UNIX hữu ích khác. |
| `socat` | Arch | Công cụ chuyển tiếp dòng dữ liệu hai chiều giữa hai điểm đầu cuối. |
| `rsync` | Arch | Đồng bộ hóa dữ liệu tập tin và thư mục hiệu quả cục bộ hoặc từ xa. |

---

## Nhóm 6: Audio & Media (Âm thanh & Đa phương tiện)
Hệ thống âm thanh Pipewire cùng các trình phát nhạc, phát video và xử lý đa phương tiện.

| Tên gói | Loại | Mô tả / Mục đích |
| :--- | :---: | :--- |
| `pipewire-alsa` | Arch | Cung cấp lớp tương thích ALSA cho hệ thống âm thanh Pipewire. |
| `pipewire-pulse` | Arch | Khả năng tương thích với các phần mềm sử dụng PulseAudio. |
| `wireplumber` | Arch | Trình quản lý phiên làm việc và chính sách âm thanh cho Pipewire. |
| `pulsemixer` | Arch | Công cụ điều chỉnh âm lượng bằng giao diện dòng lệnh (TUI). |
| `mpd` | Arch | Máy chủ chơi nhạc chạy ngầm (Music Player Daemon). |
| `mpc` | Arch | Công cụ dòng lệnh điều khiển trình phát nhạc MPD. |
| `ncmpcpp` | Arch | Trình phát nhạc giao diện terminal cực đẹp kết nối tới MPD. |
| `mpv` | Arch | Trình phát video mạnh mẽ, gọn nhẹ và có khả năng tùy biến cao. |
| `obs-studio` | Arch | Phần mềm quay màn hình và phát trực tiếp (streaming). |
| `ffmpegthumbnailer` | Arch | Trình tạo ảnh xem trước (thumbnail) cho các tệp video. |
| `imagemagick` | Arch | Bộ công cụ chỉnh sửa và chuyển đổi định dạng hình ảnh qua dòng lệnh. |
| `mediainfo` | Arch | Hiển thị thông tin kỹ thuật chi tiết của các file âm thanh/video. |

---

## Nhóm 7: Network & Browsers (Mạng & Trình duyệt web)
Các trình duyệt và công cụ quản lý mạng, kết nối từ xa.

| Tên gói | Loại | Mô tả / Mục đích |
| :--- | :---: | :--- |
| `brave-bin` | AUR | Trình duyệt web bảo mật, chặn quảng cáo mặc định. |
| `qutebrowser` | Arch | Trình duyệt web tối giản điều khiển hoàn toàn bằng phím tắt Vim. |
| `helium-browser-bin` | AUR | Trình duyệt web dạng nổi (floating) tiện dụng. |
| `cloudflared` | Arch | Thiết lập và quản lý các đường hầm kết nối Cloudflare Tunnel. |
| `dnsmasq` | Arch | Bộ phân giải DNS và DHCP gọn nhẹ chạy cục bộ. |
| `wget` | Arch | Tải xuống tệp tin từ mạng Internet thông qua các giao thức HTTP, HTTPS, FTP. |
| `curl` | Arch | Công cụ truyền tải dữ liệu với cú pháp URL trên dòng lệnh. |
| `sshpass` | Arch | Tự động điền mật khẩu đăng nhập SSH không cần tương tác. |
| `s-tui` | Arch | Công cụ giám sát nhiệt độ CPU và stress-test hệ thống dạng đồ họa terminal. |

---

## Nhóm 8: Productivity & Office (Làm việc & Văn phòng)
Các ứng dụng hỗ trợ học tập, tổ chức công việc và đọc tài liệu.

| Tên gói | Loại | Mô tả / Mục đích |
| :--- | :---: | :--- |
| `calcurse` | Arch | Trình quản lý lịch và công việc hàng ngày ngay trên terminal. |
| `mutt-wizard-git` | AUR | Bộ công cụ giúp cấu hình nhanh email client trên terminal. |
| `newsboat` | Arch | Trình đọc tin tức RSS dạng dòng lệnh. |
| `w3m` | Arch | Trình duyệt web dạng văn bản trên terminal, hỗ trợ hiển thị ảnh. |
| `pandoc-cli` | Arch | Bộ chuyển đổi đa năng giữa các định dạng tài liệu (Markdown, PDF, Docx...). |
| `calibre` | Arch | Quản lý, chuyển đổi định dạng và đọc sách điện tử (e-book). |
| `dbeaver` | Arch | Trình quản lý cơ sở dữ liệu vạn năng hỗ trợ nhiều hệ quản trị SQL. |
| `anki-bin` | AUR | Phần mềm học từ vựng bằng thẻ ghi nhớ (flashcard) lặp lại ngắt quãng. |
| `zathura` | Arch | Trình xem tài liệu PDF tối giản sử dụng phím tắt Vim. |
| `zathura-pdf-mupdf` | Arch | Plugin hỗ trợ hiển thị PDF dựa trên MuPDF cho Zathura. |
| `telegram-desktop` | AUR | Ứng dụng nhắn tin Telegram phiên bản máy tính. |
| `zoom` | AUR | Phần mềm họp và học trực tuyến. |
| `abook` | AUR | Sổ địa chỉ ngoại tuyến tích hợp với email client NeoMutt. |
| `pdfjs` | Arch | Thư viện hiển thị tệp PDF trong các môi trường web. |
| `ocrmypdf` | AUR | Công cụ nhận dạng ký tự quang học (OCR) trực tiếp vào file PDF. |
| `poppler` | Arch | Thư viện xử lý và kết xuất nội dung file PDF. |
| `tesseract-data-eng` | Arch | Dữ liệu ngôn ngữ Tiếng Anh dùng cho công cụ nhận dạng chữ OCR Tesseract. |
| `tesseract-data-vie` | Arch | Dữ liệu ngôn ngữ Tiếng Việt dùng cho OCR Tesseract. |
| `zbar` | Arch | Tiện ích quét và giải mã mã vạch/mã QR từ hình ảnh. |
| `pomo` | AUR | Đồng hồ bấm giờ quản lý thời gian Pomodoro trên terminal. |

---

## Nhóm 9: Virtualization & Container (Ảo hóa & Container)
Môi trường chạy máy ảo và quản lý các ứng dụng đóng gói.

| Tên gói | Loại | Mô tả / Mục đích |
| :--- | :---: | :--- |
| `qemu-img` | Arch | Quản lý và chuyển đổi định dạng đĩa ảo QEMU. |
| `docker` | Arch | Nền tảng quản lý và chạy các ứng dụng trong container. |
| `docker-compose` | Arch | Định nghĩa và chạy các ứng dụng Docker đa container. |
| `lazydocker-bin` | AUR | Giao diện TUI trực quan để quản lý các container Docker. |
| `libvirt` | Arch | API và bộ daemon quản lý công nghệ ảo hóa (KVM, QEMU). |
| `guestfs-tools` | Arch | Bộ công cụ để truy cập và sửa đổi ổ đĩa máy ảo. |
| `libosinfo` | Arch | Cơ sở dữ liệu thông tin về các hệ điều hành để hỗ trợ cài máy ảo. |

---

## Nhóm 10: Aesthetics & Fonts (Thẩm mỹ & Phông chữ)
Giao diện biểu tượng, chủ đề GTK và các phông chữ đẹp mắt để hiển thị ký tự mã nguồn tốt nhất.

| Tên gói | Loại | Mô tả / Mục đích |
| :--- | :---: | :--- |
| `papirus-icon-theme` | Arch | Bộ icon Papirus hiện đại cho hệ thống. |
| `gtk-theme-arc-gruvbox-git` | AUR | Chủ đề giao diện màu tối phong cách Gruvbox cho GTK. |
| `gtk-engine-murrine` | AUR | Bộ dựng theme để hiển thị các ứng dụng GTK2 cũ đẹp hơn. |
| `noto-fonts` | Arch | Phông chữ hỗ trợ đa ngôn ngữ bao gồm tiếng Trung, Nhật, Hàn (CJK). |
| `noto-fonts-cjk` | Arch | Phông chữ Noto chuyên dụng cho chữ CJK. |
| `noto-fonts-emoji` | Arch | Phông hiển thị emoji thế hệ mới. |
| `otf-libertinus` | Arch | Bộ phông chữ có chân (Serif) Libertinus. |
| `ttf-dejavu` | Arch | Phông chữ dự phòng hỗ trợ đầy đủ các ký tự đặc biệt. |
| `ttf-jetbrains-mono-nerd` | Arch | Phông chữ đơn cách JetBrains Mono tích hợp đầy đủ icon chuyên lập trình. |
| `ttf-blex-nerd-font-git` | AUR | Phông chữ IBM Plex Mono phiên bản Nerd Font. |
| `woff2-font-awesome` | Arch | Cung cấp các biểu tượng Font Awesome dạng phông chữ web. |

---

## Nhóm 11: Compression & Utilities (Nén dữ liệu & Tiện ích mở rộng)
Tập hợp các thư viện nén, driver thiết bị ngoại vi và các tiện ích hệ thống khác.

| Tên gói | Loại | Mô tả / Mục đích |
| :--- | :---: | :--- |
| `7zip` | Arch | Trình nén/giải nén file định dạng 7z và các định dạng khác. |
| `atool` | Arch | Trình quản lý các định dạng lưu trữ nén nâng cao. |
| `unrar` | Arch | Công cụ giải nén file định dạng RAR. |
| `unzip` | Arch | Công cụ giải nén file định dạng ZIP. |
| `zip` | Arch | Công cụ tạo file nén ZIP. |
| `jbig2enc` | AUR | Trình mã hóa hình ảnh JBIG2 giúp tối ưu dung lượng PDF. |
| `bc` | Arch | Trình máy tính tính toán biểu thức toán học trên dòng lệnh. |
| `dash` | Arch | Trình thông dịch shell chuẩn POSIX tốc độ cao thay zsh/bash khi chạy script. |
| `git` | Arch | Hệ thống quản lý mã nguồn phân tán Git. |
| `hugo` | Arch | Trình tạo trang web tĩnh siêu nhanh từ Markdown. |
| `ueberzugpp` | Arch | Thư viện hỗ trợ vẽ ảnh lên terminal (dùng xem trước ảnh trong `lf`). |
| `yay-bin` | AUR | Trình hỗ trợ cài đặt gói từ kho AUR (Arch User Repository) dạng nhị phân. |
| `yay-bin-debug` | AUR | Gói debug cho yay-bin. |
| `opencode-bin` | AUR | Chuyển tiếp các tác vụ code thông qua cổng kết nối AI. |
| `rate-mirrors-bin` | AUR | Kiểm tra và sắp xếp tốc độ các kho lưu trữ Arch Linux. |
| `smartmontools` | Arch | Công cụ kiểm tra sức khỏe và thông số ổ đĩa cứng (S.M.A.R.T.). |
| `cups-pdf` | Arch | Trình in ảo để xuất tài liệu ra định dạng PDF. |
| `cnrdrvcups-sfp` | AUR | Driver điều khiển thiết bị máy in Canon. |
| `bluez` | Arch | Bộ giao thức kết nối Bluetooth chính trên Linux. |
| `bluez-utils` | Arch | Cung cấp công cụ điều khiển Bluetooth qua dòng lệnh (`bluetoothctl`). |
| `brightnessctl` | Arch | Tiện ích thay đổi độ sáng màn hình laptop qua terminal. |
| `dosfstools` | Arch | Tiện ích làm việc và định dạng phân vùng đĩa DOS (FAT16/FAT32). |
| `ntfs-3g` | Arch | Driver đọc/ghi phân vùng định dạng NTFS của Windows. |
| `simple-mtpfs-git` | AUR | Gắn kết (mount) bộ nhớ điện thoại Android thông qua giao thức MTP. |
| `usbutils` | Arch | Hiển thị thông tin các thiết bị USB đang kết nối (`lsusb`). |
| `intel-media-driver` | Arch | Driver tăng tốc phần cứng giải mã video dành cho GPU Intel. |
| `vulkan-intel` | Arch | Cung cấp API đồ họa Vulkan cho GPU Intel. |
| `vulkan-tools` | Arch | Công cụ chuẩn đoán và kiểm tra cấu hình Vulkan. |
| `flatpak` | Arch | Hệ thống phân phối ứng dụng đóng gói độc lập sandbox. |
| `clipmenu` | Arch | Quản lý lịch sử khay nhớ tạm (clipboard) thông qua Rofi/dmenu. |
| `gnome-keyring` | Arch | Lưu trữ bảo mật mật khẩu hệ thống cho trình duyệt và các ứng dụng. |
| `polkit-gnome` | Arch | Giao diện xác thực quyền quản trị của PolicyKit. |
| `xdg-desktop-portal-gtk` | Arch | Lớp giao tiếp trung gian cổng kết nối của giao diện GTK. |
| `code-marketplace` | AUR | Cho phép sử dụng kho extension chính thức của VS Code trên bản VSCodium/code. |
| `alsa-utils` | Arch | Các tiện ích cấu hình âm thanh ALSA. |
| `antigravity` | AUR | Tiện ích antigravity. |
| `autorandr` | Arch | Tự động chuyển đổi cấu hình màn hình hiển thị dựa trên kết nối phần cứng. |
| `bmon` | Arch | Trình giám sát băng thông và lưu lượng mạng trực quan. |
| `edk2-ovmf` | Arch | Firmware ảo hóa UEFI cho các máy ảo QEMU. |
| `gvfs-mtp` | Arch | Hỗ trợ giao thức MTP cho hệ thống tập tin ảo GVfs. |
| `lazygit` | Arch | Giao diện đồ họa terminal (TUI) trực quan cho các thao tác Git. |
| `libnewt` | Arch | Thư viện lập trình các hộp thoại giao diện dòng lệnh. |
| `libnotify` | Arch | Thư viện gửi thông báo hệ thống trên desktop. |
| `nsxiv` | Arch | Trình xem ảnh tối giản và nhanh chóng. |
| `python-adblock` | Arch | Tiện ích chặn quảng cáo dựa trên Python. |
| `python-qdarkstyle` | Arch | Giao diện màu tối cho các ứng dụng viết bằng framework Qt (Python). |
| `qemu-full` | Arch | Trọn bộ trình giả lập ảo hóa QEMU đầy đủ tính năng. |
| `qt5-base` | Arch | Thư viện nền tảng của framework đồ họa Qt5. |
| `qt5-declarative` | Arch | Thành phần xử lý ngôn ngữ giao diện QML của Qt5. |
| `qt5-graphicaleffects` | Arch | Các hiệu ứng đồ họa dựng sẵn trong Qt5. |
| `qt5-multimedia` | Arch | Thành phần hỗ trợ âm thanh, video trong Qt5. |
| `qt5-quickcontrols2` | Arch | Bộ điều khiển giao diện người dùng nhanh cho Qt5 Quick. |
| `qt5-svg` | Arch | Hỗ trợ hiển thị ảnh vector định dạng SVG trong Qt5. |
| `sof-firmware` | Arch | Firmware hỗ trợ âm thanh Intel Smart Sound Technology (SST). |
| `swtpm` | Arch | Trình mô phỏng thiết bị bảo mật TPM cho máy ảo. |
| `zalo-macos` | AUR | Gói hỗ trợ cài đặt Zalo (hoặc tương thích). |
| `zsh` | Arch | Trình thông dịch dòng lệnh Z shell năng suất cao. |
| `zsh-fast-syntax-highlighting-git` | AUR | Plugin làm nổi bật cú pháp câu lệnh Zsh tức thời khi gõ. |
