#!/bin/bash
# DevCulture Premium VPS — Entrypoint v3
NTFY_TOPIC="${NTFY_TOPIC:-devculture-vps}"
BORE_SERVER="${BORE_SERVER:-bore.pub}"
ROOT_PASS="${ROOT_PASS:-DevCulture2026}"
AUTO_PULL_MODEL="${AUTO_PULL_MODEL:-smollm2}"
CF_TUNNEL_TOKEN="${CLOUDFLARE_TUNNEL_TOKEN:-}"
PORT="${PORT:-8080}"
START_TIME=$(date '+%d %b %Y %H:%M:%S')

log() { echo -e "[\033[1;96m$(date '+%H:%M:%S')\033[0m] \033[1;92m✦\033[0m $*"; }

log "STEP 1: Set root password..."
echo "root:${ROOT_PASS}" | chpasswd 2>/dev/null || true

# ══════════════════════════════════════════
# STEP 2: Generate Nginx config with correct PORT
# Write config directly - don't rely on sed
# ══════════════════════════════════════════
log "STEP 2: Generating Nginx config for PORT=$PORT..."
cat > /etc/nginx/sites-available/ollama << NGINXEOF
server {
    listen ${PORT};
    server_name _;
    client_max_body_size 100M;

    location /api/ {
        proxy_pass http://127.0.0.1:11434/api/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
        proxy_buffering off;
        proxy_cache off;
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, POST, DELETE, OPTIONS";
        add_header Access-Control-Allow-Headers "Content-Type, Authorization";
    }

    location /ollama/ {
        proxy_pass http://127.0.0.1:11434/;
        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 600s;
    }

    location / {
        root /var/www/ollama-ui;
        index index.html;
        try_files \$uri \$uri/ /index.html;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    location /health {
        return 200 "DevCulture VPS OK\n";
        add_header Content-Type text/plain;
    }
}
NGINXEOF

log "Nginx config written for port $PORT"

# Remove default nginx site to prevent conflicts
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/ollama /etc/nginx/sites-enabled/ollama 2>/dev/null || true

# ══════════════════════════════════════════
# STEP 3: Start Nginx FIRST — Railway healthcheck needs it
# ══════════════════════════════════════════
log "STEP 3: Starting Nginx on port $PORT..."
nginx -t 2>/tmp/nginx-test.err
if [ $? -eq 0 ]; then
    nginx 2>/tmp/nginx.err
    log "✅ Nginx started on port $PORT"
else
    log "⚠️ Nginx config error: $(cat /tmp/nginx-test.err)"
    log "Starting fallback Python health server on port $PORT..."
    python3 -c "
import http.server, socketserver, os
PORT = int(os.environ.get('PORT','8080'))
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type','text/plain')
        self.end_headers()
        self.wfile.write(b'DevCulture VPS OK')
socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(('', PORT), H) as s:
    s.serve_forever()
" &
fi

sleep 2
log "✅ Health endpoint ready on port $PORT at /health"

# ══════════════════════════════════════════
# ntfy
# ══════════════════════════════════════════
notify() {
  local title="$1" body="$2" priority="${3:-default}" tags="${4:-star2}"
  curl -s --max-time 8 --retry 2 \
    -X POST "https://ntfy.sh/$NTFY_TOPIC" \
    -H "Title: $title" -H "Priority: $priority" -H "Tags: $tags" \
    -H "Content-Type: text/plain" -d "$body" >/dev/null 2>&1 || true
}

notify "🚀 DevCulture VPS — Booting..." \
"🔄 Status: Initializing... Port: ${PORT}
🕐 Time: ${START_TIME}
    powered by: DevCulture ©2026" "default" "rocket,hourglass"

# ══════════════════════════════════════════
# STEP 4: SSH
# ══════════════════════════════════════════
log "STEP 4: Starting SSH..."
mkdir -p /run/sshd
/usr/sbin/sshd 2>/tmp/sshd.err && log "✅ SSH started" || log "⚠️ SSH: $(cat /tmp/sshd.err)"

# ══════════════════════════════════════════
# STEP 5: Ollama
# ══════════════════════════════════════════
log "STEP 5: Starting Ollama..."
ollama serve >/tmp/ollama.log 2>&1 &
log "✅ Ollama started (PID $!)"

# ══════════════════════════════════════════
# STEP 6: Cloudflare Tunnel (optional)
# ══════════════════════════════════════════
start_cf_tunnel() {
  [ -z "$CF_TUNNEL_TOKEN" ] && return
  command -v cloudflared >/dev/null 2>&1 || return
  log "Starting Cloudflare Tunnel..."
  cloudflared tunnel --no-autoupdate run --token "$CF_TUNNEL_TOKEN" >/tmp/cloudflared.log 2>&1 &
  sleep 15
  grep -qiE "Connection established|Registered tunnel|conid=" /tmp/cloudflared.log 2>/dev/null && \
    log "✅ Cloudflare Tunnel active"
}
start_cf_tunnel &

# ══════════════════════════════════════════
# STEP 7: Bore tunnels for SSH
# ══════════════════════════════════════════
update_ssh_summary() {
  local P22=$(cat /tmp/port_22.txt 2>/dev/null)
  [ -z "$P22" ] && return
  local MEM=$(free -m 2>/dev/null | awk '/Mem:/{printf "%dMB/%dMB", $3,$2}')
  notify "⚡ DevCulture VPS — ONLINE!" \
"🔑 SSH: ssh root@bore.pub -p ${P22}
Password: ${ROOT_PASS}
🌐 Web: Railway URL port ${PORT}
💾 RAM: ${MEM}
    powered by: DevCulture ©2026" "high" "star2,computer,white_check_mark"
}

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
      [ "$lport" = "22" ] && update_ssh_summary
    else
      log "[$label] ⚠️ bore tunnel timeout"
    fi
    wait $PID 2>/dev/null || true
    rm -f "/tmp/port_${lport}.txt"
    sleep 5
  done
}

bore_tunnel 22 "SSH-22" &

python3 -c "
import http.server,socketserver,threading,time
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self,*a):pass
    def do_GET(self):self.send_response(200);self.end_headers();self.wfile.write(b'OK')
socketserver.TCPServer.allow_reuse_address=True
for p in [443,3000,8888]:
    try:
        s=socketserver.TCPServer(('',p),H)
        threading.Thread(target=s.serve_forever,daemon=True).start()
    except:pass
time.sleep(86400*365)
" &
bore_tunnel 443 "HTTPS-443" &
bore_tunnel 3000 "APP-3000" &
bore_tunnel 8888 "APP-8888" &

# ══════════════════════════════════════════
# STEP 8: Auto-pull Ollama model
# ══════════════════════════════════════════
ollama_pull() {
  local model="${AUTO_PULL_MODEL:-smollm2}"
  log "Waiting for Ollama to be ready..."
  for i in $(seq 1 30); do
    sleep 3
    curl -s --max-time 3 http://localhost:11434/api/tags >/dev/null 2>&1 && break
  done
  log "Pulling model: $model"
  if ollama pull "$model" >>/tmp/ollama-pull.log 2>&1; then
    notify "✅ DevCulture — AI Model Siap!" \
"Model: $model siap digunakan!
Chat: ollama run $model
    powered by: DevCulture ©2026" "high" "robot_face,white_check_mark"
  fi
}
ollama_pull &

# ══════════════════════════════════════════
# STEP 9: Watchdogs
# ══════════════════════════════════════════
{ while true; do sleep 60; pgrep sshd>/dev/null || /usr/sbin/sshd 2>/dev/null; done } &
{ while true; do sleep 60; pgrep nginx>/dev/null || nginx 2>/dev/null; done } &
{ while true; do sleep 60; pgrep ollama>/dev/null || { ollama serve >/tmp/ollama.log 2>&1 & sleep 5; }; done } &
{ n=0; while true; do sleep 300; n=$((n+1))
  P22=$(cat /tmp/port_22.txt 2>/dev/null); [ -z "$P22" ] && continue
  MEM=$(free -m 2>/dev/null | awk '/Mem:/{printf "%dMB/%dMB (%.0f%%)",$3,$2,$3/$2*100}')
  notify "📊 Status #${n}" "⏰ $(uptime -p)
💾 RAM: ${MEM}
🤖 Ollama: $(pgrep ollama>/dev/null&&echo Online||echo Offline)
🔑 SSH: bore.pub:${P22}
    powered by: DevCulture ©2026" "min" "bar_chart,clock4"
done } &

log "🟢 All services launched. Nginx on port $PORT"
log "📱 ntfy: ntfy.sh/$NTFY_TOPIC"

tail -f /dev/null
