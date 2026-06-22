#!/bin/bash
set -e

NTFY_TOPIC="${NTFY_TOPIC:-rairu-mamaheti}"
BORE_SERVER="${BORE_SERVER:-bore.pub}"
ROOT_PASS="${ROOT_PASS:-craxid}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

notify() {
  local title="$1" body="$2" priority="${3:-default}" tags="${4:-computer}"
  curl -s --max-time 10 -X POST "https://ntfy.sh/$NTFY_TOPIC" \
    -H "Title: $title" \
    -H "Priority: $priority" \
    -H "Tags: $tags" \
    -d "$body" > /dev/null 2>&1 || true
}

log "============================================="
log "  Ubuntu 20.04 VPS — clickmamaheti-prog"
log "  ntfy topic: $NTFY_TOPIC"
log "============================================="

# Set root password dari env
echo "root:${ROOT_PASS}" | chpasswd 2>/dev/null || true

# Pastikan direktori SSH ada
mkdir -p /var/run/sshd /run/sshd

# Regenerate host keys jika belum ada
ls /etc/ssh/ssh_host_rsa_key 2>/dev/null || ssh-keygen -A

# Verifikasi SSH config
sshd -t && log "SSH config valid ✅" || { log "SSH config ERROR"; exit 1; }

# Start SSH daemon
/usr/sbin/sshd -D &
SSHD_PID=$!
sleep 2
if kill -0 $SSHD_PID 2>/dev/null; then
  log "✅ SSH daemon running (PID: $SSHD_PID)"
else
  log "❌ SSH daemon gagal start"
  exit 1
fi

# Notif startup
notify "🚀 VPS Booting..." "Ubuntu 20.04 startup...
SSH daemon aktif. Menghubungkan bore tunnel SSH...
📡 ntfy.sh/${NTFY_TOPIC}" "default" "rocket"

# Fungsi bore tunnel dengan parse port yang benar
bore_tunnel() {
  local lport="$1" label="$2" log_file="/tmp/bore_${lport}.log"
  while true; do
    : > "$log_file"
    bore local "$lport" --to "$BORE_SERVER" >> "$log_file" 2>&1 &
    local PID=$!
    local PORT=""
    local waited=0
    while [ $waited -lt 30 ]; do
      sleep 1
      waited=$((waited+1))
      # Bore v0.5.0 output: "listening at bore.pub:NNNNN"
      PORT=$(grep -oP "(?<=listening at ${BORE_SERVER}:)[0-9]+" "$log_file" 2>/dev/null | head -1)
      [ -n "$PORT" ] && break
      # Fallback: ambil angka 5-digit dari output bore
      PORT=$(grep -oE ":[0-9]{4,5}" "$log_file" 2>/dev/null | grep -v ":22$\|:80$\|:443$\|:8080$" | head -1 | tr -d :)
      [ -n "$PORT" ] && break
    done

    if [ -n "$PORT" ]; then
      log "[$label] ✅ READY → $BORE_SERVER:$PORT"
      echo "$PORT" > "/tmp/port_${lport}.txt"
      # Kirim notif hanya untuk SSH tunnel
      if [ "$lport" = "22" ]; then
        local UPTIME=$(uptime -p 2>/dev/null || echo "baru start")
        notify "✅ VPS ONLINE! SSH Ready" "🔑 ssh root@bore.pub -p ${PORT}
🔒 Password: ${ROOT_PASS}
⏰ Uptime: $UPTIME
📡 ntfy.sh/${NTFY_TOPIC}" "high" "computer,key,white_check_mark"
      fi
    else
      log "[$label] ⚠️ Gagal dapat port setelah 30s. Log: $(head -3 $log_file 2>/dev/null)"
      notify "⚠️ Tunnel Gagal [$label]" "Port $lport gagal connect ke bore.pub. Retry..." "low" "warning"
    fi

    wait $PID 2>/dev/null || true
    local CUR_PORT=$(cat "/tmp/port_${lport}.txt" 2>/dev/null || echo "?")
    log "[$label] Tunnel putus (port $CUR_PORT) → Reconnect 5s..."
    rm -f "/tmp/port_${lport}.txt"
    notify "🔄 Reconnect [$label]" "Tunnel port $lport terputus. Menghubungkan ulang..." "low" "arrows_counterclockwise"
    sleep 5
  done
}

# Monitor 5 menit
monitor_loop() {
  while true; do
    sleep 300
    local P22=$(cat /tmp/port_22.txt 2>/dev/null || echo "?")
    local UPTIME=$(uptime -p 2>/dev/null || echo "running")
    local MEM=$(free -m 2>/dev/null | awk '/Mem:/{printf "%dMB/%dMB", $3, $2}' || echo "n/a")
    local LOAD=$(cat /proc/loadavg 2>/dev/null | awk '{print $1}' || echo "n/a")
    notify "📊 Status VPS (5min)" "⏰ Uptime: $UPTIME
💾 RAM: $MEM
⚡ Load: $LOAD
🔑 SSH: bore.pub:$P22
📡 ntfy.sh/${NTFY_TOPIC}" "min" "bar_chart"
  done
}

# Start SSH tunnel saja (yang paling penting)
bore_tunnel 22 "SSH-22" &

# Monitor loop
monitor_loop &

log "Health check port 8080 aktif"
exec python3 -c "
import http.server, socketserver
class H(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a): pass
socketserver.TCPServer((, 8080), H).serve_forever()
"