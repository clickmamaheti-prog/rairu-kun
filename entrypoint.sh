#!/bin/bash

NTFY_TOPIC="${NTFY_TOPIC:-rairu-mamaheti}"
BORE_SERVER="${BORE_SERVER:-bore.pub}"
ROOT_PASS="${ROOT_PASS:-craxid}"
HEALTH_PORT="${PORT:-8080}"

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

notify() {
  local title="$1" body="$2" priority="${3:-default}" tags="${4:-computer}"
  curl -s --max-time 10 -X POST "https://ntfy.sh/$NTFY_TOPIC" \
    -H "Title: $title" \
    -H "Priority: $priority" \
    -H "Tags: $tags" \
    -d "$body" > /dev/null 2>&1 || true
}

log "============================================="
log "  Ubuntu 20.04 VPS + Ollama — clickmamaheti"
log "  ntfy : $NTFY_TOPIC | health port: $HEALTH_PORT"
log "============================================="

echo "root:${ROOT_PASS}" | chpasswd 2>/dev/null || true
mkdir -p /var/run/sshd /run/sshd
ls /etc/ssh/ssh_host_rsa_key 2>/dev/null || ssh-keygen -A
sshd -t && log "SSH config OK" || { log "SSH config ERROR"; exit 1; }

/usr/sbin/sshd -D &
SSHD_PID=$!
sleep 2
kill -0 $SSHD_PID 2>/dev/null && log "SSH daemon running PID=$SSHD_PID" || { log "SSH gagal"; exit 1; }

log "Starting Ollama..."
ollama serve &
OLLAMA_PID=$!
sleep 5
kill -0 $OLLAMA_PID 2>/dev/null && log "Ollama running PID=$OLLAMA_PID" || log "Ollama gagal start"

log "Starting Nginx..."
nginx
sleep 2
pgrep nginx > /dev/null && log "Nginx running" || log "Nginx gagal"

notify "VPS + Ollama Booting..." "Ubuntu 20.04 + Ollama startup. Menghubungkan bore tunnel..." "default" "rocket"

bore_tunnel() {
  local lport="$1" label="$2" log_file="/tmp/bore_${lport}.log"
  while true; do
    : > "$log_file"
    bore local "$lport" --to "$BORE_SERVER" >> "$log_file" 2>&1 &
    local PID=$!
    local PORT_FOUND="" waited=0
    while [ $waited -lt 30 ]; do
      sleep 1
      waited=$((waited+1))
      PORT_FOUND=$(grep -oE "bore\.pub:[0-9]+" "$log_file" 2>/dev/null | head -1 | cut -d: -f2)
      [ -n "$PORT_FOUND" ] && break
      PORT_FOUND=$(grep -oE ":[0-9]{4,5}" "$log_file" 2>/dev/null | grep -vE ":(22|80|443|8080|11434)$" | head -1 | tr -d ":")
      [ -n "$PORT_FOUND" ] && break
    done

    if [ -n "$PORT_FOUND" ]; then
      log "[$label] READY bore.pub:$PORT_FOUND"
      echo "$PORT_FOUND" > "/tmp/port_${lport}.txt"
      local UPTIME
      UPTIME=$(uptime -p 2>/dev/null || echo "baru start")
      if [ "$lport" = "22" ]; then
        notify "VPS ONLINE! SSH Ready" "ssh root@bore.pub -p ${PORT_FOUND}
Password: ${ROOT_PASS}
Uptime: $UPTIME
ntfy.sh/${NTFY_TOPIC}" "high" "computer,key"
      elif [ "$lport" = "80" ]; then
        local P22
        P22=$(cat /tmp/port_22.txt 2>/dev/null || echo "?")
        notify "Ollama UI Ready!" "Ollama Manager: http://bore.pub:${PORT_FOUND}
API: http://bore.pub:${PORT_FOUND}/api
SSH: bore.pub:$P22" "high" "robot"
      fi
    else
      log "[$label] GAGAL dapat port. Log: $(head -3 $log_file 2>/dev/null)"
      notify "Tunnel Gagal [$label]" "Port $lport gagal. Retry..." "low" "warning"
    fi

    wait $PID 2>/dev/null || true
    local CUR_PORT
    CUR_PORT=$(cat "/tmp/port_${lport}.txt" 2>/dev/null || echo "?")
    log "[$label] Putus port=$CUR_PORT Reconnect 5s..."
    rm -f "/tmp/port_${lport}.txt"
    notify "Reconnecting [$label]" "Tunnel putus. Menghubungkan ulang..." "low" "arrows_counterclockwise"
    sleep 5
  done
}

monitor_loop() {
  while true; do
    sleep 300
    local P22 P80 UPTIME MEM LOAD
    P22=$(cat /tmp/port_22.txt 2>/dev/null || echo "?")
    P80=$(cat /tmp/port_80.txt 2>/dev/null || echo "?")
    UPTIME=$(uptime -p 2>/dev/null || echo "running")
    MEM=$(free -m 2>/dev/null | awk '/Mem:/{printf "%dMB/%dMB", $3, $2}' || echo "n/a")
    LOAD=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo "n/a")
    notify "Status VPS 5min" "Uptime: $UPTIME
RAM: $MEM | Load: $LOAD
SSH: bore.pub:$P22
Ollama: bore.pub:$P80" "min" "bar_chart"
  done
}

bore_tunnel 22 "SSH-22" &
bore_tunnel 80 "OLLAMA-80" &
monitor_loop &

log "Health check server port $HEALTH_PORT aktif"
# HTTP health check server — Railway wajib listen di \$PORT
python3 - <<PYEOF
import http.server, socketserver, os

port = int(os.environ.get("PORT", "8080"))

class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"OK - VPS + Ollama running")

socketserver.TCPServer(("0.0.0.0", port), H).serve_forever()
PYEOF