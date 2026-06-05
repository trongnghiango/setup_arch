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

log_info "Bỏ comment các dòng Server trong mirrorlist..."
sed -i 's/^#Server/Server/' "$MIRRORLIST"

log_info "Kiểm tra danh sách server có sẵn..."
SERVER_COUNT=$(grep -c "^Server" "$MIRRORLIST" 2>/dev/null || echo 0)
if [ "$SERVER_COUNT" -eq 0 ]; then
    log_error "Không tìm thấy dòng Server nào trong mirrorlist. File mirrorlist có thể bị hỏng."
fi
log_info "Tìm thấy $SERVER_COUNT server trong mirrorlist."

log_info "Đo tốc độ kết nối đến các server..."
REPO="core"
ARCH=$(uname -m)
RESULTS=$(mktemp)
PID_LIST=""

idx=0
while IFS= read -r line; do
    url=$(echo "$line" | sed "s/\$repo/$REPO/g; s/\$arch/$ARCH/g")
    idx=$((idx + 1))
    (
        latency=$(curl -o /dev/null -s -k -w "%{time_connect}" --connect-timeout 2 "$url" 2>/dev/null || echo "999")
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
sort -n "$RESULTS" | head -20 > "$FASTEST"

log_info "Top 20 server nhanh nhất (dưới 1 giây):"
while IFS=' ' read -r latency url; do
    if [ "$(echo "$latency < 1" | bc -l 2>/dev/null)" = "1" ]; then
        printf "  ✅ %4.0fms  %s\n" "$(echo "$latency * 1000" | bc)" "$url"
    elif [ "$latency" = "999" ]; then
        :
    else
        printf "  ⚠️ %4.0fms  %s\n" "$(echo "$latency * 1000 | bc" 2>/dev/null || echo "?")" "$url"
    fi
done < "$FASTEST"

log_info "Cập nhật mirrorlist với các server nhanh nhất..."
grep -v "^Server" "$MIRRORLIST" > "${MIRRORLIST}.tmp"
while IFS=' ' read -r latency line; do
    echo "$line" >> "${MIRRORLIST}.tmp"
done < "$FASTEST"
mv "${MIRRORLIST}.tmp" "$MIRRORLIST"
rm -f "$RESULTS" "$FASTEST" "${MIRRORLIST}.bak"

log_info "Kiểm tra đồng bộ Pacman..."
if pacman -Syy; then
    log_info "Đồng bộ Pacman thành công! Hệ thống đã sẵn sàng."
else
    log_error "Đồng bộ Pacman thất bại. Kiểm tra lại kết nối mạng hoặc chạy lại optimize_mirrors.sh."
fi
