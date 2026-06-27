#!/bin/bash
set +e
NTFY_TOPIC="${NTFY_TOPIC:-devculture-vps}"
BORE_SERVER="${BORE_SERVER:-bore.pub}"
ROOT_PASS="${ROOT_PASS:-DevCulture2026}"
AUTO_PULL_MODEL="${AUTO_PULL_MODEL:-smollm2}"
CF_TUNNEL_TOKEN="${CLOUDFLARE_TUNNEL_TOKEN:-}"
PORT="${PORT:-8080}"

log() { echo "[$(date '+%H:%M:%S')] $*"; }
log "=== DevCulture VPS starting on PORT=$PORT ==="

# Step 1: root password
echo "root:${ROOT_PASS}" | chpasswd 2>/dev/null || true

# Step 2: Write nginx config with correct port
cat > /tmp/nginx-port.conf << EOF
server {
    listen ${PORT};
    server_name _;
    client_max_body_size 100M;
    location /api/ {
        proxy_pass http://127.0.0.1:11434/api/;
        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_read_timeout 600s;
        add_header Access-Control-Allow-Origin *;
    }
    location /ollama/ {
        proxy_pass http://127.0.0.1:11434/;
        proxy_buffering off;
        proxy_read_timeout 600s;
    }
    location / {
        root /var/www/ollama-ui;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }
    location /health {
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
}
EOF

cp /tmp/nginx-port.conf /etc/nginx/sites-available/ollama
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/ollama /etc/nginx/sites-enabled/ollama

# Step 3: Start nginx (handles /health for Railway healthcheck)
log "Starting nginx on port $PORT..."
nginx -t 2>/tmp/nginx-err.txt
NGINX_OK=$?
if test $NGINX_OK -eq 0; then
  nginx
  log "Nginx started OK"
else
  log "Nginx config error - starting python fallback"
  cat /tmp/nginx-err.txt
  python3 - << PYEOF &
import http.server, socketserver, os, sys
p = int(os.environ.get('PORT', '8080'))
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain')
        self.end_headers()
        self.wfile.write(b'DevCulture VPS OK')
socketserver.TCPServer.allow_reuse_address = True
socketserver.TCPServer(('', p), H).serve_forever()
PYEOF
fi
sleep 2
log "Health endpoint ready on port $PORT"

# Step 4: SSH
mkdir -p /run/sshd
/usr/sbin/sshd 2>/dev/null && log "SSH started" || log "SSH failed"

# Step 5: Ollama
ollama serve >/tmp/ollama.log 2>&1 &
log "Ollama started (PID $!)"

# Step 6: ntfy boot notification
curl -s --max-time 5 -X POST "https://ntfy.sh/$NTFY_TOPIC" \
  -H "Title: DevCulture VPS Online" -H "Priority: high" -H "Tags: star2,rocket" \
  -d "VPS online! PORT=$PORT SSH coming via bore tunnel. powered by DevCulture 2026" \
  >/dev/null 2>&1 &

# Step 7: Cloudflare tunnel (optional)
if test -n "$CF_TUNNEL_TOKEN"; then
  cloudflared tunnel --no-autoupdate run --token "$CF_TUNNEL_TOKEN" >/tmp/cf.log 2>&1 &
  log "Cloudflare tunnel started"
fi

# Step 8: bore SSH tunnel
bore_tunnel() {
  local lport="$1" label="$2" logf="/tmp/bore_${1}.log"
  while true; do
    bore local "$lport" --to "$BORE_SERVER" >"$logf" 2>&1 &
    local PID=$! BPORT=""
    for i in $(seq 1 45); do
      sleep 1
      BPORT=$(grep -oE "${BORE_SERVER}:[0-9]+" "$logf" 2>/dev/null | head -1 | cut -d: -f2)
      test -n "$BPORT" && break
    done
    if test -n "$BPORT"; then
      log "$label bore.pub:$BPORT"
      echo "$BPORT" > "/tmp/port_${lport}.txt"
      if test "$lport" = "22"; then
        curl -s --max-time 5 -X POST "https://ntfy.sh/$NTFY_TOPIC" \
          -H "Title: DevCulture SSH Ready" -H "Priority: high" -H "Tags: computer,key" \
          -d "SSH: ssh root@bore.pub -p $BPORT | Pass: $ROOT_PASS" >/dev/null 2>&1 || true
      fi
    else
      log "$label bore timeout, retrying..."
    fi
    wait $PID 2>/dev/null || true
    rm -f "/tmp/port_${lport}.txt"
    sleep 5
  done
}
bore_tunnel 22 "SSH" &

# Placeholder listeners for other bore ports
python3 -c "
import socketserver,threading,time,http.server
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self,*a):pass
    def do_GET(self):self.send_response(200);self.end_headers();self.wfile.write(b'OK')
socketserver.TCPServer.allow_reuse_address=True
for p in [443,3000,8888]:
    try:s=socketserver.TCPServer(('',p),H);threading.Thread(target=s.serve_forever,daemon=True).start()
    except:pass
time.sleep(86400)
" &

bore_tunnel 443 "HTTPS" &
bore_tunnel 3000 "APP3000" &
bore_tunnel 8888 "APP8888" &

# Step 9: auto pull ollama model
(
  for i in $(seq 1 30); do sleep 3
    curl -s --max-time 3 http://localhost:11434/api/tags >/dev/null 2>&1 && break
  done
  log "Pulling model $AUTO_PULL_MODEL..."
  ollama pull "$AUTO_PULL_MODEL" >/tmp/ollama-pull.log 2>&1 && log "Model ready: $AUTO_PULL_MODEL" || log "Model pull failed"
) &

# Step 10: watchdogs
( while true; do sleep 60; pgrep sshd>/dev/null || /usr/sbin/sshd 2>/dev/null; done ) &
( while true; do sleep 60; pgrep nginx>/dev/null || nginx 2>/dev/null; done ) &
( while true; do sleep 60; pgrep ollama>/dev/null || ollama serve >/tmp/ollama.log 2>&1 & done ) &

log "All services launched. Running on port $PORT."
tail -f /dev/null
