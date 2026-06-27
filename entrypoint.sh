#!/bin/bash
set -e

NTFY_TOPIC="${NTFY_TOPIC:-devculture-vps}"
BORE_SERVER="${BORE_SERVER:-bore.pub}"
ROOT_PASS="${ROOT_PASS:-DevCulture2026}"
AUTO_PULL_MODEL="${AUTO_PULL_MODEL:-smollm2}"
CF_TUNNEL_TOKEN="${CLOUDFLARE_TUNNEL_TOKEN:-}"
START_TIME=$(date '+%d %b %Y %H:%M:%S')
HOSTNAME_VPS="devculture-vps"

log() { echo -e "[\033[1;96m$(date '+%H:%M:%S')\033[0m] \033[1;92m✦\033[0m $*"; }

# ══════════════════════════════════════════
# PREMIUM ntfy Notification
# ══════════════════════════════════════════
notify() {
  local title="$1" body="$2" priority="${3:-default}" tags="${4:-star2}"
  curl -s --max-time 10 --retry 2 \
    -X POST "https://ntfy.sh/$NTFY_TOPIC" \
    -H "Title: $title" \
    -H "Priority: $priority" \
    -H "Tags: $tags" \
    -H "Content-Type: text/plain" \
    -d "$body" >/dev/null 2>&1 || true
}

notify_vps_online() {
  local P22=$(cat /tmp/port_22.txt 2>/dev/null || echo "pending")
  local P80=$(cat /tmp/port_80.txt 2>/dev/null || echo "pending")
  local MEM=$(free -m 2>/dev/null | awk '/Mem:/{printf "%dMB / %dMB (%.0f%%)", $3,$2,$3/$2*100}')
  local DISK=$(df -h / 2>/dev/null | awk 'NR==2{printf "%s/%s (%s)", $3,$2,$5}')
  local CPU_CORES=$(nproc 2>/dev/null || echo "?")
  local IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo "fetching...")
  local MODELS=$(ollama list 2>/dev/null | tail -n +2 | awk '{printf "  • %s\n",$1}' | head -5 || echo "  (auto-pull in progress...)")

  notify "⚡ DevCulture VPS — ONLINE!" \
"╔══════════════════════════════════╗
║   DevCulture Premium VPS Ready   ║
╚══════════════════════════════════╝

🔑  SSH Access
    ssh root@bore.pub -p ${P22}
    Password: ${ROOT_PASS}

🌐  Services
    Web UI  → http://bore.pub:${P80}
    API     → http://bore.pub:${P80}/api/
    Ollama  → bore.pub:${P80}

📊  Server Stats
    IP      : ${IP}
    RAM     : ${MEM}
    Disk    : ${DISK}
    CPU     : ${CPU_CORES} cores
    Kernel  : $(uname -r 2>/dev/null)

🤖  AI Models
${MODELS}

🕐  Started : ${START_TIME}
📲  Monitor : ntfy.sh/${NTFY_TOPIC}
──────────────────────────────────
    powered by: DevCulture ©2026" \
  "high" "star2,computer,white_check_mark,tada"
}

update_summary() {
  local P22=$(cat /tmp/port_22.txt 2>/dev/null)
  [ -z "$P22" ] && return
  local P80=$(cat /tmp/port_80.txt 2>/dev/null || echo "pending")
  local MEM=$(free -m 2>/dev/null | awk '/Mem:/{printf "%dMB/%dMB", $3,$2}')
  local MODELS=$(ollama list 2>/dev/null | tail -n +2 | awk '{printf "  • %s\n",$1}' | head -3)

  notify "⚡ DevCulture VPS — ONLINE!" \
"╔══════════════════════════════════╗
║   DevCulture Premium VPS Ready   ║
╚══════════════════════════════════╝

🔑  ssh root@bore.pub -p ${P22}
    Password: ${ROOT_PASS}

🌐  http://bore.pub:${P80}
🤖  /api/ endpoint aktif

💾  RAM: ${MEM}
🤖  Models:
${MODELS:-  (loading...)}

📲  ntfy.sh/${NTFY_TOPIC}
    powered by: DevCulture ©2026" \
  "high" "star2,computer,white_check_mark"
}

# ══════════════════════════════════════════
# Bore tunnel per port
# ══════════════════════════════════════════
bore_tunnel() {
  local lport="$1" label="$2"
  local logf="/tmp/bore_${lport}.log"
  while true; do
    >"$logf"
    bore local "$lport" --to "$BORE_SERVER" >"$logf" 2>&1 &
    local PID=$! PORT=""
    for i in $(seq 1 40); do
      sleep 1
      PORT=$(grep -oE "${BORE_SERVER}:[0-9]+" "$logf" 2>/dev/null | head -1 | cut -d: -f2)
      [ -n "$PORT" ] && break
    done
    if [ -n "$PORT" ]; then
      log "[$label] bore.pub:$PORT"
      echo "$PORT" > "/tmp/port_${lport}.txt"
      [ "$lport" = "22" ] || [ "$lport" = "80" ] && update_summary
    fi
    wait $PID 2>/dev/null || true
    rm -f "/tmp/port_${lport}.txt"
    sleep 5
  done
}

# ══════════════════════════════════════════
# Cloudflare Tunnel
# ══════════════════════════════════════════
start_cf_tunnel() {
  [ -z "$CF_TUNNEL_TOKEN" ] && { log "CF Tunnel: token tidak diset, skip"; return; }
  command -v cloudflared >/dev/null 2>&1 || { log "cloudflared tidak ada, skip"; return; }

  log "Memulai Cloudflare Tunnel..."
  cloudflared tunnel --no-autoupdate --loglevel info run \
    --token "$CF_TUNNEL_TOKEN" >/tmp/cloudflared.log 2>&1 &

  local ok=false
  for i in $(seq 1 20); do
    sleep 3
    grep -qiE "Connection established|Registered tunnel|conid=" /tmp/cloudflared.log 2>/dev/null && { ok=true; break; }
  done

  if $ok; then
    log "✅ Cloudflare Tunnel AKTIF"
    notify "☁️ DevCulture — Domain Live!" \
"╔══════════════════════════════════╗
║    Cloudflare Tunnel Aktif! 🎉   ║
╚══════════════════════════════════╝

🌐  Domain statis tersedia!
    HTTPS gratis & otomatis
    Tidak berubah walau restart

📲  ntfy.sh/${NTFY_TOPIC}
    powered by: DevCulture ©2026" \
    "high" "white_check_mark,cloud,globe_with_meridians"
  fi
}

# ══════════════════════════════════════════
# Auto-pull Ollama model
# ══════════════════════════════════════════
ollama_pull() {
  local model="${AUTO_PULL_MODEL:-smollm2}"
  log "Menunggu Ollama ready untuk pull: $model"
  local ready=false
  for i in $(seq 1 30); do
    sleep 2
    curl -s --max-time 3 http://localhost:11434/api/tags >/dev/null 2>&1 && { ready=true; break; }
  done
  [ "$ready" = false ] && { log "Ollama tidak ready"; return; }

  local IS_UPDATE=false
  ollama list 2>/dev/null | grep -q "^$model" && IS_UPDATE=true

  if $IS_UPDATE; then
    notify "🔄 DevCulture — Update Model" \
"Memperbarui model AI ke versi terbaru...
Model : $model
Status: Running in background

    powered by: DevCulture ©2026" \
    "low" "arrows_counterclockwise,robot_face"
  else
    notify "⬇️ DevCulture — Download Model" \
"Auto-download model AI dimulai...

Model : $model
Size  : ~270MB (smollm2)

Model tersedia:
  • smollm2   = 270MB (default)
  • tinyllama = 637MB
  • phi3      = 2.3GB ⭐
  • llama3.2  = 2.0GB

Notifikasi masuk saat selesai 🎉
    powered by: DevCulture ©2026" \
    "default" "robot_face,hourglass"
  fi

  if ollama pull "$model" >>/tmp/ollama-pull.log 2>&1; then
    local SIZE=$(ollama list 2>/dev/null | grep "^$model" | awk '{print $3,$4}')
    notify "✅ DevCulture — Model AI Siap!" \
"╔══════════════════════════════════╗
║    Model AI Berhasil Dimuat! 🤖   ║
╚══════════════════════════════════╝

Model  : $model
Size   : ${SIZE}
Status : Ready to use!

💬  Chat via SSH:
    ollama run $model

🌐  Chat via Web UI:
    http://bore.pub:<port>

Model lain (pull via SSH):
  ollama pull phi3       # 2.3GB
  ollama pull tinyllama  # 637MB
  ollama pull mistral    # 4.1GB

    powered by: DevCulture ©2026" \
    "high" "robot_face,white_check_mark,tada,star2"
    update_summary
  else
    notify "❌ DevCulture — Pull Gagal" \
"Gagal download model: $model
Log: $(tail -3 /tmp/ollama-pull.log 2>/dev/null)

Coba manual via SSH:
  ollama pull $model

    powered by: DevCulture ©2026" \
    "high" "warning,robot_face"
  fi
}

# ══════════════════════════════════════════
# Monitor 5 menit
# ══════════════════════════════════════════
monitor_loop() {
  local n=0
  while true; do
    sleep 300; n=$((n+1))
    local P22=$(cat /tmp/port_22.txt 2>/dev/null); [ -z "$P22" ] && continue
    local P80=$(cat /tmp/port_80.txt 2>/dev/null || echo "?")
    local MEM=$(free -m 2>/dev/null | awk '/Mem:/{printf "%dMB/%dMB (%.0f%%)",$3,$2,$3/$2*100}')
    local DISK=$(df -h / 2>/dev/null | awk 'NR==2{print $5}')
    local LOAD=$(cat /proc/loadavg | awk '{print $1,$2,$3}')
    local OLLAMA_S="❌ Offline"; pgrep ollama>/dev/null && OLLAMA_S="✅ Online"
    local MODELS=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | tr '\n' ',' | sed 's/,$//')
    notify "📊 DevCulture VPS — Status #${n}" \
"╔══════════════════════════════════╗
║   DevCulture — System Monitor   ║
╚══════════════════════════════════╝

⏰  Uptime : $(uptime -p | sed 's/up //')
💾  RAM    : ${MEM}
⚡  Load   : ${LOAD}
💽  Disk   : ${DISK} used
🤖  Ollama : ${OLLAMA_S}
📦  Models : ${MODELS:-(none)}

🔑  SSH    : bore.pub:${P22}
🌐  Web    : bore.pub:${P80}

    powered by: DevCulture ©2026" \
    "min" "bar_chart,clock4"
  done
}

# ══════════════════════════════════════════
# Watchdogs
# ══════════════════════════════════════════
ssh_wd() {
  while true; do sleep 60
    pgrep sshd>/dev/null || {
      notify "🚨 DevCulture — SSH Mati!" \
"SSH daemon crash! Mencoba restart...
    powered by: DevCulture ©2026" "urgent" "rotating_light,sos"
      /usr/sbin/sshd && notify "🔄 DevCulture — SSH Restart" \
"SSH berhasil direstart ✅
    powered by: DevCulture ©2026" "high" "white_check_mark"
    }
  done
}

nginx_wd() {
  while true; do sleep 60
    pgrep nginx>/dev/null || {
      notify "🚨 DevCulture — Nginx Mati!" \
"Nginx crash! Mencoba restart...
    powered by: DevCulture ©2026" "urgent" "rotating_light"
      nginx && notify "🔄 DevCulture — Nginx Restart" \
"Nginx berhasil direstart ✅
    powered by: DevCulture ©2026" "high" "white_check_mark"
    }
  done
}

ollama_wd() {
  while true; do sleep 60
    pgrep ollama>/dev/null || {
      notify "🚨 DevCulture — Ollama Mati!" \
"Ollama crash! Mencoba restart...
    powered by: DevCulture ©2026" "urgent" "robot_face,rotating_light"
      ollama serve>/tmp/ollama.log 2>&1 &
      sleep 10; pgrep ollama>/dev/null && notify "🔄 DevCulture — Ollama Restart" \
"Ollama berhasil direstart ✅
    powered by: DevCulture ©2026" "high" "robot_face,white_check_mark"
    }
  done
}

# ══════════════════════════════════════════
# MAIN STARTUP
# ══════════════════════════════════════════
clear
echo -e "\033[1;96m"
cat << 'ASCII'
  ____              ____      _ _
 |  _ \  _____   _/ ___|_  _| | |_ _   _ _ __ ___
 | | | |/ _ \ \ / / |   | | | | __| | | | '__/ _ \
 | |_| |  __/\ V /| |___| |_| | |_| |_| | | |  __/
 |____/ \___| \_/  \____|\__,_|\__|\__,_|_|  \___|

 Premium Cloud VPS — Ubuntu 20.04 Multi-Port
 powered by: DevCulture ©2026 linux
ASCII
echo -e "\033[0m"

log "VPS startup — DevCulture Premium Cloud"
log "ntfy  : $NTFY_TOPIC"
log "Model : $AUTO_PULL_MODEL"
log "Ports : 22 80 443 3000 8080 8888 11434"

echo "root:${ROOT_PASS}" | chpasswd 2>/dev/null || true

notify "🚀 DevCulture VPS — Booting..." \
"╔══════════════════════════════════╗
║  DevCulture Premium VPS Startup  ║
╚══════════════════════════════════╝

🔄  Status    : Initializing...
🖥  OS        : Ubuntu 20.04 LTS
🔑  Ports     : 22, 80, 443, 3000, 8080, 8888
🤖  AI Model  : ${AUTO_PULL_MODEL} (auto-pull)
🕐  Time      : ${START_TIME}
📲  Monitor   : ntfy.sh/${NTFY_TOPIC}

Semua layanan sedang disiapkan...
    powered by: DevCulture ©2026" \
"default" "rocket,hourglass,star2"

# Start services
/usr/sbin/sshd && log "✅ SSH"
ollama serve >/tmp/ollama.log 2>&1 & sleep 3 && log "✅ Ollama"
nginx -t 2>&1 | tail -1 && nginx && log "✅ Nginx"

# Cloudflare Tunnel
start_cf_tunnel &

# Placeholder ports
python3 -c "
import http.server,socketserver,threading,time
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self,*a):pass
    def do_GET(self):self.send_response(200);self.end_headers();self.wfile.write(b'DevCulture VPS - OK')
[threading.Thread(target=lambda p=p:socketserver.TCPServer(('',p),H).serve_forever(),daemon=True).start() for p in [443,3000,8888]]
time.sleep(86400*365)
" &
sleep 1

# Auto-pull Ollama model
ollama_pull &

# Bore tunnels (all ports)
bore_tunnel 22   "SSH-22"    &
bore_tunnel 80   "HTTP-80"   &
bore_tunnel 443  "HTTPS-443" &
bore_tunnel 3000 "APP-3000"  &
bore_tunnel 8080 "APP-8080"  &
bore_tunnel 8888 "APP-8888"  &

# Watchdogs & monitor
ssh_wd & nginx_wd & ollama_wd & monitor_loop &

# Health check (Railway requirement)
log "✅ Health check :${PORT:-8080}"
exec python3 -c "
import http.server,socketserver,os
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self,*a):pass
    def do_GET(self):
        self.send_response(200);self.end_headers()
        self.wfile.write(b'DevCulture VPS - Healthy')
socketserver.TCPServer(('',int(os.environ.get('PORT','8080'))),H).serve_forever()
"
