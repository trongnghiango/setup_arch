#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

#==============================================================================
# Tối ưu hóa mirrors dựa trên file mirrorlist có sẵn của Live ISO
# Không phụ thuộc vào bất kỳ nguồn ngoài nào, không tải gì từ mạng
#==============================================================================
SCRIPT_TIME="$(date +%Y%m%d_%H%M%S)"
SCRIPT_LOG="/tmp/optimize_mirrors_${SCRIPT_TIME}.log"

log_info() { echo -e "$(date '+%H:%M:%S') \e[1;32m[INFO]\e[0m  $*"; }
log_warn() { echo -e "$(date '+%H:%M:%S') \e[1;33m[WARN]\e[0m  $*"; }
log_error() {
    echo -e "$(date '+%H:%M:%S') \e[1;31m[ERROR]\e[0m $*" >&2
    echo -e "\nFile log: ${SCRIPT_LOG}"
    exit 1
}

exec > >(tee -ai "${SCRIPT_LOG}") 2>&1

if [ "$EUID" -ne 0 ]; then
    log_error "Vui lòng chạy script này với quyền root (sudo)."
fi

MIRRORLIST="/etc/pacman.d/mirrorlist"

if [ ! -f "$MIRRORLIST" ]; then
    log_error "Không tìm thấy file mirrorlist tại $MIRRORLIST"
fi

log_info "Sao lưu mirrorlist gốc..."
cp "$MIRRORLIST" "${MIRRORLIST}.bak"

log_info "Tải danh sách mirror chính thức từ Artix Gitea..."
if curl -sL --connect-timeout 4 -m 15 -o "$MIRRORLIST" "https://gitea.artixlinux.org/packages/artix-mirrorlist/raw/branch/master/mirrorlist"; then
    log_info "Đã tải thành công mirrorlist mới nhất."
else
    log_warn "Tải mirrorlist mới thất bại, sử dụng mirrorlist có sẵn của Live ISO."
fi

#==============================================================================
# THỬ DÙNG RATE-MIRRORS (NHANH & CHÍNH XÁC)
#==============================================================================
USE_RATE_MIRRORS=false
RATE_MIRRORS_BIN="/tmp/rate-mirrors"

log_info "Thử tải công cụ rate-mirrors từ GitHub..."
# Lấy URL download động của phiên bản mới nhất từ API GitHub (có chứa số version trong tên file)
DOWNLOAD_URL=$(curl -s https://api.github.com/repos/westandskif/rate-mirrors/releases/latest | grep -o 'https://github.com/westandskif/rate-mirrors/releases/download/[^"]*-x86_64-unknown-linux-musl.tar.gz' | head -n 1)
if [ -n "$DOWNLOAD_URL" ] && curl -sL --connect-timeout 4 -m 15 "$DOWNLOAD_URL" | tar -xz -C /tmp 2>/dev/null; then
    if [ -x "$RATE_MIRRORS_BIN" ]; then
        USE_RATE_MIRRORS=true
    fi
fi

if [ "$USE_RATE_MIRRORS" = true ]; then
    log_info "Tải thành công rate-mirrors. Tiến hành đo và sắp xếp các mirror..."
    if grep -qi "artix" /etc/os-release 2>/dev/null; then
        # Artix Linux
        if $RATE_MIRRORS_BIN --allow-root artix --save="$MIRRORLIST"; then
            log_info "Đã tối ưu hóa mirrorlist của Artix bằng rate-mirrors thành công!"
            rm -f "$RATE_MIRRORS_BIN"
            
            log_info "Đồng bộ lại database Pacman..."
            pacman -Syy --noconfirm || true
            exit 0
        fi
    else
        # Arch Linux
        if $RATE_MIRRORS_BIN --allow-root arch --save="$MIRRORLIST"; then
            log_info "Đã tối ưu hóa mirrorlist của Arch bằng rate-mirrors thành công!"
            rm -f "$RATE_MIRRORS_BIN"
            
            log_info "Đồng bộ lại database Pacman..."
            pacman -Syy --noconfirm || true
            exit 0
        fi
    fi
    log_warn "rate-mirrors chạy lỗi, chuyển sang phương án dự phòng..."
    rm -f "$RATE_MIRRORS_BIN"
else
    log_warn "Không thể tải rate-mirrors (có thể do chặn mạng GitHub), chuyển sang phương án dự phòng..."
fi

log_info "Bỏ comment các dòng Server trong mirrorlist..."
sed -i -E 's/^#[[:space:]]*Server/Server/' "$MIRRORLIST"

log_info "Kiểm tra danh sách server có sẵn..."
SERVER_COUNT=$(grep -c "^Server" "$MIRRORLIST" 2>/dev/null || echo 0)
if [ "$SERVER_COUNT" -eq 0 ]; then
    log_error "Không tìm thấy dòng Server nào trong mirrorlist. File mirrorlist có thể bị hỏng."
fi
log_info "Tìm thấy $SERVER_COUNT server trong mirrorlist."

log_info "Đo tốc độ và kiểm tra HTTP status đến các server..."
if grep -qi "artix" /etc/os-release 2>/dev/null; then
    REPO="system"
else
    REPO="core"
fi
ARCH=$(uname -m)
RESULTS=$(mktemp)
PID_LIST=""

idx=0
while IFS= read -r line; do
    # TRÍCH XUẤT CHÍNH XÁC URL ĐỂ DÙNG CHO CURL (loại bỏ chữ "Server = ")
    raw_url=$(echo "$line" | sed -E 's/^Server[[:space:]]*=[[:space:]]*//')
    url=$(echo "$raw_url" | sed "s/\$repo/$REPO/g; s/\$arch/$ARCH/g")
    
    idx=$((idx + 1))
    (
        db_url="${url%/}/${REPO}.db"
        # Dùng GET request với Range 0-0 (chỉ tải 1 byte) kèm User-Agent để tránh bị CDN/Firewall block (trả về 403/404/405)
        resp=$(curl -s -o /dev/null -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -w "%{http_code}:%{time_total}" -r 0-0 --connect-timeout 2 -m 4 "$db_url" 2>/dev/null || echo "000:999")
        http_code="${resp%%:*}"
        latency="${resp##*:}"
        
        # Chấp nhận mã 200 (OK), hoặc 301/302/304 (Chuyển hướng hợp lệ)
        if [[ ! "$http_code" =~ ^(200|301|302|304)$ ]]; then
            latency="999"
        fi
        echo "$latency $line" >> "$RESULTS"
    ) &
    PID_LIST="$PID_LIST $!"
    if [ $((idx % 20)) -eq 0 ]; then
        wait $PID_LIST 2>/dev/null || true
        PID_LIST=""
    fi
done < <(grep "^Server" "$MIRRORLIST")
wait $PID_LIST 2>/dev/null || true

FASTEST=$(mktemp)
# Sort theo số để tìm server nhanh nhất
sort -n "$RESULTS" | head -20 > "$FASTEST"

# Kiểm tra xem có server nào hoạt động không
VALID_COUNT=$(awk '$1 != "999" {print}' "$FASTEST" | wc -l)
if [ "$VALID_COUNT" -eq 0 ]; then
    log_warn "Không có server nào hoạt động tốt (tất cả đều lỗi hoặc timeout)."
    log_info "Khôi phục lại mirrorlist gốc..."
    mv "${MIRRORLIST}.bak" "$MIRRORLIST"
    rm -f "$RESULTS" "$FASTEST"
    exit 1
fi

log_info "Top server nhanh nhất (dưới 1 giây):"
while IFS=' ' read -r latency line; do
    if [ "$latency" = "999" ]; then
        continue
    fi
    # Tách URL cho hiển thị log
    raw_url=$(echo "$line" | sed -E 's/^Server[[:space:]]*=[[:space:]]*//')
    
    ms=$(awk -v l="$latency" 'BEGIN { printf "%.0f", l * 1000 }' 2>/dev/null || echo "?")
    if [ "$ms" != "?" ] && [ "$ms" -lt 1000 ]; then
        printf "  \u2705 %4sms  %s\n" "$ms" "$raw_url"
    else
        printf "  \u26a0\ufe0f %4sms  %s\n" "$ms" "$raw_url"
    fi
done < "$FASTEST"

log_info "Cập nhật mirrorlist với các server phản hồi tốt..."
grep -v "^Server" "$MIRRORLIST" > "${MIRRORLIST}.tmp"

# CHỈ THÊM CÁC SERVER CÓ LATENCY KHÁC 999 VÀO MIRRORLIST
while IFS=' ' read -r latency line; do
    if [ "$latency" != "999" ]; then
        echo "$line" >> "${MIRRORLIST}.tmp"
    fi
done < "$FASTEST"

mv "${MIRRORLIST}.tmp" "$MIRRORLIST"
rm -f "$RESULTS" "$FASTEST"

log_info "Kiểm tra đồng bộ Pacman..."
if pacman -Syy; then
    log_info "Đồng bộ Pacman thành công! Hệ thống đã sẵn sàng."
else
    log_error "Đồng bộ Pacman thất bại. Vui lòng kiểm tra lại kết nối mạng."
fi
