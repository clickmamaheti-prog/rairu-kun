#!/bin/bash

NTFY_TOPIC="${NTFY_TOPIC:-rairu-devculture67}"
BORE_SERVER="${BORE_SERVER:-bore.pub}"
SSH_PORT="${SSH_PORT:-22}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

notify() {
  local title="$1" body="$2" priority="${3:-default}" tags="${4:-computer}"
  curl -s --max-time 5 -X POST "https://ntfy.sh/$NTFY_TOPIC" \
    -H "Title: $title" \
    -H "Priority: $priority" \
    -H "Tags: $tags" \
    -d "$body" > /dev/null 2>&1 || true
}

log "========================================"
log "  VPS Railway - Bore SSH Tunnel"
log "========================================"

# Start SSH daemon
/usr/sbin/sshd
log "SSH daemon started"

notify "VPS Railway Starting..." "SSH aktif, menghubungkan bore tunnel..." "default" "rocket"

# Auto-reconnect loop
while true; do
  log "Menghubungkan ke $BORE_SERVER port $SSH_PORT..."
  
  # Hapus log lama
  > /tmp/bore.log
  
  bore local "$SSH_PORT" --to "$BORE_SERVER" > /tmp/bore.log 2>&1 &
  BORE_PID=$!

  # Parse port: cari pola "bore.pub:PORT" bukan angka sembarangan
  PORT=""
  for i in $(seq 1 30); do
    sleep 1
    # Bore output: "listening at bore.pub:XXXXX"
    PORT=$(grep -oE "${BORE_SERVER}:[0-9]+" /tmp/bore.log 2>/dev/null | head -1 | cut -d: -f2)
    [ -n "$PORT" ] && break
    # Fallback: cari pola "port XXXXX"
    [ -z "$PORT" ] && PORT=$(grep -iE "port [0-9]+" /tmp/bore.log 2>/dev/null | grep -oE "[0-9]{3,5}" | tail -1)
    [ -n "$PORT" ] && break
  done

  if [ -n "$PORT" ]; then
    log "========================================"
    log "  SSH TUNNEL READY via Bore"
    log "========================================"
    log "  ssh root@$BORE_SERVER -p $PORT"
    log "  Password: craxid"
    log "========================================"
    
    # Tampilkan isi bore.log untuk debug
    log "Bore output: $(cat /tmp/bore.log)"

    notify \
      "✅ VPS Railway AKTIF! Port: $PORT" \
      "ssh root@bore.pub -p $PORT
Password: craxid" \
      "high" "computer,key"
  else
    log "ERROR: Gagal dapat port bore. Isi log:"
    cat /tmp/bore.log 2>/dev/null || true
    notify "⚠️ VPS Bore GAGAL" "Tunnel gagal. Cek log Railway." "urgent" "warning"
  fi

  wait $BORE_PID 2>/dev/null || true
  log "Bore disconnect. Reconnect dalam 5 detik..."
  notify "🔄 Reconnecting..." "bore putus, mencoba ulang..." "low" "arrows_counterclockwise"
  sleep 5
done &

log "HTTP health check port 8080"
exec python3 -c "
import http.server, socketserver
h = http.server.SimpleHTTPRequestHandler
h.log_message = lambda *a: None
socketserver.TCPServer(('', 8080), h).serve_forever()
"
