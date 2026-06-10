# Session Handoff - Bàn giao phiên làm việc
**Thời điểm cập nhật:** 2026-06-10

## Trạng thái hiện tại
1. **Khắc phục hoàn toàn lỗi cú pháp cài đặt (`install_dotfiles.sh`)**:
   - Khắc phục lỗi dùng từ khóa `local` ngoài hàm trong khối script chạy dưới quyền `sudo -u ka`.
   - Khắc phục triệt để lỗi cú pháp lồng nháy đơn (`'`) của lệnh `sed` bằng cách tách biệt logic: clone bằng user, vá file bằng root, stow bằng user. Cú pháp toàn bộ script đã được kiểm tra (`bash -n`) và chạy trơn tru.

2. **Dọn dẹp các binary NixOS lỗi trong dotfiles**:
   - Khi chạy `install_dotfiles.sh`, script tự động xóa các file binary biên dịch sẵn của NixOS trong dotfiles nguồn (`~/.dotfiles/scripts/.local/bin/` bao gồm `dwm`, `st`, `dmenu`, `dwmblocks`, `stest`) trước khi chạy `stow`.
   - Điều này ngăn chặn việc `stow` liên kết các file lỗi này vào `~/.local/bin/` thay thế cho binary chuẩn của hệ thống, giúp `dwmblocks` chạy ổn định và hiển thị đúng các module khác.

3. **Cơ chế tối ưu hóa trên máy ảo (VM) vs Máy thật (Baremetal)**:
   - **Màn hình/Picom:** Phát hiện máy ảo (`is_virtual`) sẽ tự đổi picom backend sang `xrender` và tắt `vsync` để chống chớp hình/treo Xorg.
   - **Âm thanh/Pipewire:** 
     - **Trên Máy thật:** Cấu hình Pipewire đầy đủ qua `xinitrc.artix`, kill sạch tiến trình cũ mồ côi khi boot và khởi động lại chúng kèm D-Bus + DISPLAY session để âm thanh hoạt động.
     - **Trên Máy ảo (VM):** Bỏ qua việc tự khởi động Pipewire/Wireplumber nhằm tiết kiệm tài nguyên. Vá trực tiếp script `ka-volume` hiển thị tĩnh chuỗi **`🔇 VM`** (màu đỏ) trên statusbar dwmblocks để tránh tình trạng `wpctl` bị đơ/timeout làm nghẽn hiển thị thanh trạng thái.

## Kết quả kiểm tra
- Cú pháp cài đặt: `OK` (Không lỗi).
- DWmblocks trên máy ảo: Đã hoạt động bình thường, in ra các block khác và in trạng thái tĩnh `🔇 VM` ở vị trí volume.
- X11/startx: Vào dwm bình thường, không còn bị thoát đột ngột (lỗi dùng `exit 0` trong file source cũ đã được sửa thành `return 0`).

## Các bước tiếp theo (Bàn giao)
1. **Nếu muốn test âm thanh thật (có card âm thanh)**:
   - Cần kiểm tra cấu hình máy ảo, gắn thêm thiết bị âm thanh ảo (ví dụ: `ich9` hoặc `AC97` trong Virt-Manager) rồi khởi động lại VM.
   - Trong VM, kiểm tra driver bằng `aplay -l` hoặc `cat /proc/asound/cards`.
   - Khi đã có card âm thanh ảo, xóa file bypass `~/.local/bin/ka-volume` và chạy lại `./setup.sh --dotfiles` để khôi phục cơ chế đọc volume tự động.

2. **Chạy dotfiles trên máy thật**:
   - Chỉ cần chạy `./setup.sh --dotfiles` trên máy thật, script sẽ tự nhận diện không phải máy ảo và cài đặt cấu hình âm thanh Pipewire tự động đầy đủ.
