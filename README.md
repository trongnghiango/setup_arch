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
