# Bộ Script Cài Đặt Tự Động Arch/Artix Linux tối ưu

Bộ script hỗ trợ cài đặt hệ thống Arch Linux hoặc Artix Linux nhanh chóng từ môi trường Live USB với giao diện DWM và cấu hình dotfiles tối ưu.

## Yêu cầu
- Máy ảo hoặc máy thật đang boot ở chế độ **UEFI** (Bắt buộc).
- Kết nối mạng Internet hoạt động tốt.

## Hướng dẫn Sử dụng

Bộ setup sử dụng script chính là `setup.sh`. Các bước thực hiện:

### Chạy tự động tất cả các bước (Một lệnh ăn ngay):
```bash
./setup.sh --all --disk <tên_ổ_đĩa>
```
Ví dụ với ổ đĩa ảo `vda`:
```bash
./setup.sh --all --disk vda
```

### Chạy chi tiết từng giai đoạn:

1. **Tối ưu hóa gương tải gói (Mirrors):**
   ```bash
   ./setup.sh --mirrors
   ```

2. **Cài đặt hệ điều hành tối giản (CLI Base):**
   ```bash
   ./setup.sh --base --disk <tên_ổ_đĩa>
   ```

3. **Cài đặt ứng dụng & build DWM (sau khi đã chroot):**
   ```bash
   ./setup.sh --apps
   ```

4. **Thiết lập dotfiles:**
   ```bash
   ./setup.sh --dotfiles
   ```

---

## Các tệp script cài đặt chính

| Tên Script | Mục đích | Cách hoạt động / Chế độ chạy |
|------------|----------|------------------------------|
| **`setup.sh`** | Điều phối | Script chính điều khiển toàn bộ quá trình, nhận diện chroot và truyền tham số cho các script con. |
| **`install_base.sh`** | CLI Base | Phân vùng (LVM2 / LUKS), định dạng, pacstrap và cài đặt GRUB bootloader cho hệ thống mới. |
| **`install_apps.sh`** | Cài ứng dụng | Cài đặt gói Pacman / AUR từ danh sách `progs.csv`, biên dịch các công cụ suckless (dwm, st, dmenu, dwmblocks). Cài đặt cơ chế an toàn khôi phục DNS ban đầu sau khi kết thúc. |
| **`install_dotfiles.sh`** | Đồng bộ cấu hình | Clone repo dotfiles, dọn dẹp các binary NixOS cũ, vá lỗi logic phím/màn hình/âm thanh và áp dụng qua `stow` hoặc `rsync`. |
| **`user_setup.sh`** | Thiết lập độc lập | *Script tiện ích thay thế.* Chạy trực tiếp sau khi boot vào hệ điều hành mới để cài ứng dụng và dotfiles. Cung cấp giao diện tương tác hỏi người dùng có muốn **bỏ qua lỗi [c]ontinue hay dừng lại [a]bort** khi một bước cài đặt bị thất bại. |

---

## Cơ chế tối ưu hóa tự động trên Máy ảo (VM)

Khi chạy bước đồng bộ dotfiles (`install_dotfiles.sh`), script sẽ tự động kiểm tra môi trường ảo (`is_virtual`). Nếu phát hiện đang chạy trong máy ảo (như QEMU, KVM, VirtualBox, VMware), hệ thống sẽ tự động thực hiện các tối ưu hóa sau:

1. **Tối ưu đồ họa (Picom compositor):**
   - Tự động thay đổi backend của `picom.conf` từ `glx` sang **`xrender`** (vẽ bằng CPU, cực kỳ ổn định trên VM) và thiết lập `vsync = false` để loại bỏ hoàn toàn hiện tượng chớp nháy màn hình hoặc đơ màn hình đồ họa Xorg.
2. **Bypass hệ thống âm thanh (Pipewire / Wireplumber):**
   - Trên máy ảo (thường không cấu hình card âm thanh vật lý hoạt động), script sẽ tắt bỏ hoàn toàn việc tự động khởi chạy các dịch vụ Pipewire/Wireplumber/Pipewire-pulse để tiết kiệm tài nguyên CPU của máy ảo và tránh lỗi D-Bus session.
   - Trạng thái khởi chạy âm thanh trên máy ảo sẽ được trả về trực tiếp để tránh gây crash cho session đăng nhập X11.
3. **Chống treo thanh trạng thái DWMBlocks (Volume module):**
   - Script tự động vá tệp script lấy âm lượng `ka-volume` trên máy ảo thành giá trị tĩnh **`🔇 VM`** (màu đỏ) hiển thị trực quan trên statusbar.
   - Việc này giúp tránh việc lệnh `wpctl get-volume` bị treo (do thiếu Audio Device) làm đóng băng toàn bộ thanh trạng thái.

*Lưu ý: Trên máy thật (Baremetal), toàn bộ cấu hình đồ họa GLX và hệ thống âm thanh kết nối Pipewire đầy đủ sẽ được giữ nguyên.*

---

## Tùy chọn dotfiles nâng cao

### Sử dụng phương thức stow (mặc định):
```bash
./setup.sh --all --disk vda
```

### Sử dụng phương thức rsync:
```bash
./setup.sh --all --disk vda --dotfiles-method rsync
```

### Sử dụng repo dotfiles tùy chỉnh:
```bash
./setup.sh --all --disk vda --dotfiles-method stow --dotfiles-repo "https://github.com/username/dotfiles.git"
```

## Các điểm lưu ý trong phiên bản này
- Tự động kiểm tra và cài đặt các công cụ phân vùng (`parted`, `gptfdisk`, `lvm2`) trên môi trường Live trước khi chạy.
- Tự động tắt swap, unmount `/mnt`, tắt LVM/LUKS cũ để đảm bảo chạy lại script không bị lỗi "Device or resource busy".
- Đã sửa lỗi cấu hình PGP Keyring trên Live USB giúp quá trình tải gói tin qua `pacstrap` ổn định mà không lo lỗi Signature.
- Sử dụng danh sách phần mềm từ file local `progs.csv` trong suốt quá trình chroot.
- Dọn dẹp hoàn toàn các binary NixOS compile sẵn trong dotfiles nguồn để đảm bảo khả năng tương thích glibc trên hệ điều hành mới.
