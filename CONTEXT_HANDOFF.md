# Session Handoff - Bàn giao phiên làm việc
**Thời điểm cập nhật:** 2026-06-10

## Trạng thái công việc đã hoàn thành

1. **Khắc phục lỗi cú pháp install_dotfiles.sh:**
   - Xóa từ khóa `local` ngoài hàm trong khối `sudo -u user /bin/bash -c '...'`.
   - Tách biệt logic: clone bằng user, vá file bằng root, stow bằng user — loại bỏ hoàn toàn lỗi lồng nháy đơn (`'`) của sed/EOF.
   - Kiểm tra cú pháp: `bash -n install_dotfiles.sh` trả về OK.

2. **Tối ưu hóa máy ảo (VM) tự động (tương tự picom):**
   - **Picom:** Nếu là máy ảo → backend `xrender`, `vsync = false`.
   - **Âm thanh (Pipewire):** Nếu là máy ảo → xinitrc.artix không khởi chạy Pipewire/Wireplumber nữa (tránh tốn CPU + log lỗi D-Bus).
   - **Statusbar:** Nếu là máy ảo → patch `ka-volume` in tĩnh `🔇 VM` thay vì gọi `wpctl` (tránh treo thanh trạng thái).

3. **Dọn dẹp binary NixOS trong dotfiles:**
   - Script `install_dotfiles.sh` tự động xóa các binary `dwm`, `st`, `dmenu`, `dwmblocks`, `stest` trong `~/.dotfiles/scripts/.local/bin/` trước khi stow, tránh lỗi interpreter NixOS (`/nix/store/...-glibc`) trên Arch/Artix.

4. **Cập nhật danh sách gói:**
   - Xóa `progs.csv.mini` (trùng với `progs.csv` cũ, 67 dòng).
   - Khôi phục `progs.csv.bak` thành `progs.csv` (full list, 190 dòng).
   - Tạo `FONT.md`: ghi chú map font `ttf-blex-nerd-font-git` (AUR) ↔ `ttf-ibmplex-mono-nerd` (official pacman).

5. **Tài liệu hóa:**
   - Cập nhật `CLAUDE.md`: thêm phần hướng dẫn code style (không dùng local ngoài hàm, tránh lồng nháy), mô tả cơ chế VM.
   - Cập nhật `README.md`: thêm bảng tổng quan các script, cơ chế tối ưu VM.
   - Tạo `CONTEXT_HANDOFF.md`: file bàn giao này.
   - Tạo `FONT.md`: ghi chú font Nerd Font.

## Các bước còn tồn đọng / cần làm tiếp

1. **Kiểm tra âm thanh trên máy thật:** cần boot máy thật chạy `./setup.sh --dotfiles` để xác nhận Pipewire tự khởi động đúng.
2. **Refactor utilities chung (tùy chọn):** trích xuất hàm `is_virtual`, `log_info`, `log_error` vào tệp `utils.sh` dùng chung để tránh trùng lặp code.
3. **Tách `make` và `make install` trong install_apps.sh** để user build, root cài — tránh sudo trong chroot.
4. **Hàm `run_in_chroot` trong setup.sh** tránh trùng lặp logic chroot cho --apps, --dotfiles, --all.

## Commit cuối cùng
```
6a42e3d feat: optimize VM setup scripts, fix NixOS binaries, and update full package list
```
