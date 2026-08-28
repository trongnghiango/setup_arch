# Kế hoạch Kiến trúc: Lai tạo Omarchy và Dotfiles Cá nhân (Hybrid Setup)

Bản kế hoạch này phác thảo lộ trình từng bước để chuyển đổi hệ thống Arch Linux (X11/DWM) hiện tại sang một kiến trúc tiên tiến hơn: Sử dụng lõi Omarchy (Wayland/Btrfs) kết hợp với sức mạnh tuỳ biến cá nhân từ kho `.dotfiles`.

## 1. Mục tiêu Kiến trúc

*   **Đổi Móng (Phần Xác):** Thay thế hệ thống Arch + Ext4 + X11 thuần túy bằng nền tảng Omarchy. Nhờ đó có ngay Wayland (Hyprland), hệ thống snapshot Btrfs an toàn, và cơ chế Update Channels.
*   **Giữ Hồn (Phần Hồn):** Giữ nguyên quy trình quản lý bằng `GNU Stow` và tái sử dụng toàn bộ cấu hình lõi của bạn (Neovim, Tmux, Zsh, LF, Scripts). Omarchy hoàn toàn tương thích và thậm chí chính thức khuyến nghị sử dụng Stow.

---

## 2. Phân tích Chuyển đổi (Migration Matrix)

| Thành phần | Hiện tại (`setup_arch`) | Mục tiêu (Omarchy Hybrid) | Hành động cần làm |
| :--- | :--- | :--- | :--- |
| **Cài đặt Base OS** | Kịch bản `install_base.sh` | Omarchy ISO / Installer | Tạm ngưng `install_base.sh` |
| **Quản lý Mirror** | Kịch bản `optimize_mirrors.sh` | Omarchy Channels | Tạm ngưng `optimize_mirrors.sh` |
| **Hiển thị & Window Manager** | X11, DWM, picom, st | Wayland, Hyprland, Foot | Loại bỏ X11 khỏi `.dotfiles` |
| **App Launcher / Menu** | dmenu / rofi | Omarchy Menu | Cập nhật file `progs.csv` |
| **Công cụ CLI cốt lõi** | Neovim, Tmux, Zsh, Lf | Neovim, Tmux, Zsh, Lf (Của bạn) | Dùng `stow` quản lý trong `~/.config` |

---

## 3. Các bước Triển khai Chi tiết

### Giai đoạn 1: Chuẩn bị & "Gọt dũa" `.dotfiles`
Trước khi cài hệ điều hành mới, bạn cần dọn dẹp kho `.dotfiles` trên Github:
1.  **Xóa bỏ tàn dư X11:** Xóa (hoặc chuyển sang nhánh backup) các thư mục cấu hình dành riêng cho X11 như: `dwm`, `st`, `dmenu`, `picom`, `x11`.
2.  **Cập nhật `progs.csv`:**
    *   Bỏ các ứng dụng compile từ Git (tag `G`) thuộc hệ sinh thái Suckless (vì không còn dùng DWM).
    *   Tối ưu lại danh sách vì Omarchy đã cài sẵn trình duyệt, terminal mặc định là `foot`.

### Giai đoạn 2: Cài đặt Phần Xác (Omarchy OS)
1.  Bỏ qua kịch bản cài đặt tự động (`setup.sh`, `install_base.sh`) của repo `setup_arch`.
2.  Tiến hành cài đặt Omarchy bằng script chính thức.
3.  Kết quả: Bạn có một hệ thống Hyprland đẹp mắt, các file cấu hình gốc an toàn nằm trong `/usr/share/omarchy/` (bạn không bao giờ được sửa file ở đây).

### Giai đoạn 3: Tích hợp Dotfiles với Omarchy bằng GNU Stow
Theo tài liệu chính thức của Omarchy, mọi thay đổi của bạn phải diễn ra trong `~/.config/`.
1.  Mở terminal, clone repo `.dotfiles` của bạn về.
2.  Đồng bộ cấu hình CLI của bạn (Neovim, Tmux, Zsh):
    ```bash
    # Nếu Omarchy đã tạo sẵn cấu hình mẫu, hãy xóa nó đi trước khi stow
    rm -rf ~/.config/nvim ~/.bashrc
    cd ~/.dotfiles
    stow nvim
    stow tmux
    ```
    *Lưu ý: Omarchy khuyên bạn đặt các Alias và Function vào `~/.bashrc` vì file này không bị ghi đè khi update.*

### Giai đoạn 4: Tuỳ biến Giao diện Hyprland (Theo chuẩn Omarchy)
Đừng ghi đè file `.conf`! Kiến trúc Omarchy tách Hyprland ra thành các module file `.lua` cực kỳ thông minh. Bạn tạo cấu trúc thư mục sau trong `.dotfiles` và `stow` chúng:
1.  **Phím tắt (Keybindings):** Quản lý tại `~/.config/hypr/bindings.lua`. Bạn dùng hàm `hl.unbind()` để xóa phím tắt mặc định và `o.bind()` để thêm phím tắt theo chuẩn DWM cũ.
2.  **Khởi động cùng OS:** Quản lý tại `~/.config/hypr/autostart.lua`. Dùng hàm `o.launch_on_start("your-script")` để chạy script của riêng bạn (sạch sẽ hơn `xinitrc`).
3.  **Hooks / Events:** Omarchy có cơ chế Hook tuyệt vời. Bạn có thể cho script chạy vào lúc pin yếu, hoặc ngay sau khi update bằng cách bỏ script vào `~/.config/omarchy/hooks/`.

---

## 4. Cơ chế An toàn (Rollback)
Sức mạnh của kiến trúc mới nằm ở sự an toàn:
1.  Bất cứ khi nào bạn chỉnh sửa file `.lua` hoặc stow một ứng dụng lớn, nếu cấu hình bị lỗi, Omarchy có sẵn menu `Update > Config` để reset mọi thứ về mặc định.
2.  Ở cấp độ OS, nếu toàn bộ GUI bị sập, khởi động lại và chọn Btrfs Snapshot cũ từ menu boot để hoàn tác hệ thống trong 1 nốt nhạc.
