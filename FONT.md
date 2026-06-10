# Ghi chú về Nerd Fonts trên Arch / Artix Linux
Tài liệu này lưu lại thông tin về các font chữ lập trình (Nerd Fonts) được sử dụng trong dotfiles để cấu hình cho `st` (terminal), `dwm` (status bar) và `neovim`, giúp tránh các lỗi không tìm thấy font hoặc lỗi cài đặt do thay đổi tên gói.

---

## 1. Gói IBM Plex Mono Nerd Font (Blex)

Font chữ chính thức: **IBM Plex Mono Nerd Font** (còn gọi là **Blex Nerd Font** trong thư viện Nerd Fonts).

### 🔍 So sánh hai gói cài đặt:

| Tên Gói | Nguồn | Loại tag trong `progs.csv` | Ưu / Nhược điểm |
|---------|-------|----------------------------|-----------------|
| **`ttf-blex-nerd-font-git`** | **AUR** | **`A`** (Cài qua `yay`) | ❌ Cài đặt lâu (phải tải git và build thủ công), dễ lỗi timeout mạng.<br>❌ Phụ thuộc vào AUR helper (`yay`/`paru`). |
| **`ttf-ibmplex-mono-nerd`** | **Official (`extra`)** | **Trống** (Cài qua `pacman`) | **`[KHUYÊN DÙNG]`**<br>➕ Cài đặt cực nhanh (chỉ mất 2-5 giây vì đã được build sẵn).<br>➕ Ổn định tối đa vì thuộc kho chính thức của Arch/Artix. |

### 📌 Khuyên dùng:
Nên sửa tag trong `progs.csv` từ:
`A,ttf-blex-nerd-font-git`
Thành:
`,ttf-ibmplex-mono-nerd`
để chuyển sang cài qua `pacman` nhanh và không bị lỗi.

---

## 2. Các Font chữ khác trong hệ thống

Dưới đây là danh sách các gói font cần thiết để hiển thị đầy đủ icon trên thanh trạng thái `dwmblocks` và giao diện đồ họa:

| Tên Gói trên Arch | Mục đích sử dụng | Cách cài đặt |
|-------------------|------------------|--------------|
| **`ttf-jetbrains-mono-nerd`** | Font chữ chính cho Terminal `st` và Editor `neovim`. | `,ttf-jetbrains-mono-nerd` (Pacman) |
| **`noto-fonts-emoji`** | Hiển thị biểu tượng cảm xúc (emoji). | `,noto-fonts-emoji` (Pacman) |
| **`noto-fonts`** | Font fallback hiển thị ký tự đa ngôn ngữ (CJK - Trung, Nhật, Hàn, Việt). | `,noto-fonts` (Pacman) |
| **`ttf-dejavu`** | Font dự phòng hiển thị các ký tự unicode lạ. | `,ttf-dejavu` (Pacman) |

---

## 🛠️ Lệnh kiểm tra danh sách Font đã nhận dạng trong hệ thống:

Nếu font cài xong nhưng DWm không hiển thị đúng (hoặc ST bị lỗi font), chạy các lệnh sau để kiểm tra:

```bash
# 1. Liệt kê tất cả Nerd Font đã cài đặt
fc-list : family | grep -i "nerd" | sort -u

# 2. Kiểm tra xem hệ thống đã nhận dạng "BlexMono" chưa
fc-list : family | grep -i "blex"

# 3. Kiểm tra xem hệ thống đã nhận dạng "JetBrainsMono" chưa
fc-list : family | grep -i "jetbrains"

# 4. Làm mới bộ đệm font (chạy sau khi cài thủ công font mới)
fc-cache -fv
```
