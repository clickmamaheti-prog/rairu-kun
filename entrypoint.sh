#!/bin/bash
# DevCulture Premium VPS — Entrypoint
# NO set -e : services are non-critical, health server must survive

NTFY_TOPIC="${NTFY_TOPIC:-devculture-vps}"
BORE_SERVER="${BORE_SERVER:-bore.pub}"
ROOT_PASS="${ROOT_PASS:-DevCulture2026}"
AUTO_PULL_MODEL="${AUTO_PULL_MODEL:-smollm2}"
CF_TUNNEL_TOKEN="${CLOUDFLARE_TUNNEL_TOKEN:-}"
PORT="${PORT:-8080}"
START_TIME=$(date '+%d %b %Y %H:%M:%S')

log() { echo -e "[\033[1;96m$(date '+%H:%M:%S')\033[0m] \033[1;92m✦\033[0m $*"; }

# ══════════════════════════════════════════
# STEP 1: Set root password
# ══════════════════════════════════════════
log "Setting root password..."
echo "root:${ROOT_PASS}" | chpasswd 2>/dev/null || true

# ══════════════════════════════════════════
# STEP 2: Configure Nginx to listen on $PORT
# Railway only exposes one external port ($PORT)
# ══════════════════════════════════════════
log "Configuring Nginx on port $PORT..."
sed -i "s/listen 80;/listen ${PORT};/" /etc/nginx/sites-available/ollama

# ══════════════════════════════════════════
# STEP 3: Start Nginx FIRST (Railway healthcheck)
# Railway healthcheck: GET /health -> must respond fast
# ══════════════════════════════════════════
log "🏥 Starting Nginx (health check on port $PORT /health)..."
nginx -t 2>/tmp/nginx-test.err && nginx 2>/tmp/nginx.err && log "✅ Nginx started on port $PORT" || {
  log "⚠️ Nginx error: $(cat /tmp/nginx-test.err 2>/dev/null | head -5)"
  # Fallback: minimal Python health server so Railway doesn't kill us
  log "⚠️ Falling back to Python health server..."
  python3 -c "
import http.server, socketserver, os
PORT = int(os.environ.get('PORT','8080'))
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type','text/plain')
        self.end_headers()
        self.wfile.write(b'DevCulture VPS - OK')
socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(('', PORT), H) as s:
    s.serve_forever()
" &
  FALLBACK_PID=$!
fi

sleep 3
log "✅ Health endpoint ready on port $PORT"

# ══════════════════════════════════════════
# ntfy notification
# ══════════════════════════════════════════
notify() {
  local title="$1" body="$2" priority="${3:-default}" tags="${4:-star2}"
  curl -s --max-time 8 --retry 2 \
    -X POST "https://ntfy.sh/$NTFY_TOPIC" \
    -H "Title: $title" \
    -H "Priority: $priority" \
    -H "Tags: $tags" \
    -H "Content-Type: text/plain" \
    -d "$body" >/dev/null 2>&1 || true
}

update_ssh_summary() {
  local P22=$(cat /tmp/port_22.txt 2>/dev/null)
  [ -z "$P22" ] && return
  local P80=$(cat /tmp/port_80.txt 2>/dev/null || echo "pending")
  local MEM=$(free -m 2>/dev/null | awk '/Mem:/{printf "%dMB/%dMB",  $3,$2}')
  notify "⚡ DevCulture VPS — ONLINE!" \
"╔══════════════════════════════════╗
║   DevCulture Premium VPS Ready   ║
╚══════════════════════════════════╝

🔑  SSH Access
    ssh root@bore.pub -p ${P22}
    Password: ${ROOT_PASS}

🌐  Web UI
    http://bore.pub:${P80}

💾  RAM: ${MEM}
📲  ntfy.sh/${NTFY_TOPIC}
    powered by: DevCulture ©2026" \
  "high" "star2,computer,white_check_mark"
}

# ══════════════════════════════════════════
# Send boot notification
# ══════════════════════════════════════════
notify "🚀 DevCulture VPS — Booting..." \
"🔄 Status    : Initializing services...
🖥  OS        : Ubuntu 20.04 LTS
🔑  Ports     : 22, 80, 443, 3000, ${PORT}
🤖  AI Model  : ${AUTO_PULL_MODEL} (auto-pull)
🕐  Time      : ${START_TIME}
📲  Monitor   : ntfy.sh/${NTFY_TOPIC}

    powered by: DevCulture ©2026" \
"default" "rocket,hourglass"

# ══════════════════════════════════════════
# STEP 4: SSH
# ══════════════════════════════════════════
log "Starting SSH..."
mkdir -p /run/sshd
/usr/sbin/sshd 2>/tmp/sshd.err && log "✅ SSH daemon started" || log "⚠️ SSH: $(cat /tmp/sshd.err)"

# ══════════════════════════════════════════
# STEP 5: Ollama
# ══════════════════════════════════════════
log "Starting Ollama..."
ollama serve >/tmp/ollama.log 2>&1 &
OLLAMA_PID=$!
log "✅ Ollama started (PID $OLLAMA_PID)"

# ══════════════════════════════════════════
# STEP 6: Cloudflare Tunnel (optional)
# ══════════════════════════════════════════
start_cf_tunnel() {
  [ -z "$CF_TUNNEL_TOKEN" ] && return
  command -v cloudflared >/dev/null 2>&1 || return
  log "Starting Cloudflare Tunnel..."
  cloudflared tunnel --no-autoupdate run --token "$CF_TUNNEL_TOKEN" >/tmp/cloudflared.log 2>&1 &
  sleep 15
  grep -qiE "Connection established|Registered tunnel|conid=" /tmp/cloudflared.log 2>/dev/null && {
    log "✅ Cloudflare Tunnel active"
    notify "☁️ DevCulture — CF Tunnel Live!" \
"Cloudflare Tunnel aktif! Domain statis tersedia 🎉
    powered by: DevCulture ©2026" \
    "high" "white_check_mark,cloud"
  }
}
start_cf_tunnel &

# ══════════════════════════════════════════
# STEP 7: Bore tunnels (SSH & internal ports)
# ══════════════════════════════════════════
bore_tunnel() {
  local lport="$1" label="$2"
  local logf="/tmp/bore_${lport}.log"
  while true; do
    >"$logf"
    bore local "$lport" --to "$BORE_SERVER" >"$logf" 2>&1 &
    local PID=$! PORT_BORE=""
    for i in $(seq 1 45); do
      sleep 1
      PORT_BORE=$(grep -oE "${BORE_SERVER}:[0-9]+" "$logf" 2>/dev/null | head -1 | cut -d: -f2)
      [ -n "$PORT_BORE" ] && break
    done
    if [ -n "$PORT_BORE" ]; then
      log "[$label] ✅ bore.pub:$PORT_BORE"
      echo "$PORT_BORE" > "/tmp/port_${lport}.txt"
      [ "$lport" = "22" ] || [ "$lport" = "80" ] && update_ssh_summary
    else
      log "[$label] ⚠️ bore tunnel timeout"
    fi
    wait $PID 2>/dev/null || true
    rm -f "/tmp/port_${lport}.txt"
    sleep 5
  done
}

bore_tunnel 22   "SSH-22" &
bore_tunnel 443  "HTTPS-443" &
bore_tunnel 3000 "APP-3000" &
bore_tunnel 8888 "APP-8888" &

# Placeholder listeners for bore-tunneled ports
python3 -c "
import http.server,socketserver,threading,time,os
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self,*a):pass
    def do_GET(self):self.send_response(200);self.end_headers();self.wfile.write(b'DevCulture OK')
socketserver.TCPServer.allow_reuse_address=True
for p in [443,3000,8888]:
    try:
        s=socketserver.TCPServer(('',p),H)
        threading.Thread(target=s.serve_forever,daemon=True).start()
    except:pass
time.sleep(86400*365)
" &

# ══════════════════════════════════════════
# STEP 8: Auto-pull Ollama model
# ══════════════════════════════════════════
ollama_pull() {
  local model="${AUTO_PULL_MODEL:-smollm2}"
  log "Waiting Ollama ready (for $model pull)..."
  for i in $(seq 1 30); do
    sleep 3
    curl -s --max-time 3 http://localhost:11434/api/tags >/dev/null 2>&1 && break
  done
  notify "⬇️ DevCulture — Downloading AI Model" \
"Auto-download model: $model
Size: ~270MB (smollm2)

Notif masuk saat selesai 🤖
    powered by: DevCulture ©2026" \
  "default" "robot_face,hourglass"
  if ollama pull "$model" >>/tmp/ollama-pull.log 2>&1; then
    local SIZE=$(ollama list 2>/dev/null | grep "^$model" | awk '{print $3,$4}')
    notify "✅ DevCulture — AI Model Siap!" \
"╔══════════════════════════════════╗
║    Model AI Ready! 🤖             ║
╚══════════════════════════════════╝

Model  : $model
Size   : ${SIZE}

Chat via SSH:  ollama run $model
Chat via Web:  Akses via Railway URL

    powered by: DevCulture ©2026" \
    "high" "robot_face,white_check_mark,tada"
  fi
}
ollama_pull &

# ══════════════════════════════════════════
# STEP 9: Watchdogs
# ══════════════════════════════════════════
ssh_wd() {
  while true; do sleep 60
    pgrep sshd>/dev/null || { /usr/sbin/sshd 2>/dev/null || true; }
  done
}
nginx_wd() {
  while true; do sleep 60
    pgrep nginx>/dev/null || { nginx 2>/dev/null || true; }
  done
}
ollama_wd() {
  while true; do sleep 60
    pgrep ollama>/dev/null || { ollama serve >/tmp/ollama.log 2>&1 & sleep 5; }
  done
}
monitor_loop() {
  local n=0
  while true; do
    sleep 300; n=$((n+1))
    local P22=$(cat /tmp/port_22.txt 2>/dev/null); [ -z "$P22" ] && continue
    local MEM=$(free -m 2>/dev/null | awk '/Mem:/{printf "%dMB/%dMB (%.0f%%)",$3,$2,$3/$2*100}')
    local MODELS=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | tr '\n' ',' | sed 's/,$//')
    notify "📊 DevCulture VPS — Status #${n}" \
"⏰ Uptime : $(uptime -p | sed 's/up //')
💾 RAM    : ${MEM}
🤖 Ollama : $(pgrep ollama>/dev/null&&echo Online||echo Offline)
📦 Models : ${MODELS:-(none)}
🔑 SSH    : bore.pub:${P22}
🌐 Web    : Railway URL (port ${PORT})

    powered by: DevCulture ©2026" \
    "min" "bar_chart,clock4"
  done
}
ssh_wd & nginx_wd & ollama_wd & monitor_loop &

# ══════════════════════════════════════════
# STEP 10: Keep container alive
# ══════════════════════════════════════════
log "🟢 All services launched. Nginx running on port $PORT"
log "📱 Subscribe ntfy: ntfy.sh/$NTFY_TOPIC"

# Keep container alive by tailing logs
tail -f /dev/null
