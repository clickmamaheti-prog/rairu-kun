FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    openssh-server wget curl unzip vim python3 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install bore (TCP tunnel gratis tanpa akun)
RUN wget -q https://github.com/ekzhang/bore/releases/download/v0.5.0/bore-v0.5.0-x86_64-unknown-linux-musl.tar.gz -O /tmp/bore.tar.gz \
    && tar -xzf /tmp/bore.tar.gz -C /usr/local/bin/ \
    && chmod +x /usr/local/bin/bore \
    && rm /tmp/bore.tar.gz

# Setup SSH
RUN mkdir -p /run/sshd \
    && echo "PermitRootLogin yes" >> /etc/ssh/sshd_config \
    && echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config \
    && echo root:craxid | chpasswd \
    && ssh-keygen -A

# Entrypoint
RUN printf '#!/bin/bash\\n\
NTFY_TOPIC="rairu-devculture67"\\n\
echo "Starting SSH server..."\\n\
/usr/sbin/sshd\\n\
echo "Starting bore tunnel..."\\n\
bore local 22 --to bore.pub &\\n\
BORE_PID=$!\\n\
sleep 5\\n\
# Cek apakah bore berjalan\\n\
if kill -0 $BORE_PID 2>/dev/null; then\\n\
  echo "========================================"\\n\
  echo "VPS Railway AKTIF via bore.pub!"\\n\
  echo "Cek log Railway untuk port number"\\n\
  echo "Command: ssh root@bore.pub -p <PORT>"\\n\
  echo "Password: craxid"\\n\
  echo "========================================"\\n\
  curl -s -X POST "https://ntfy.sh/$NTFY_TOPIC" \\\\\\n\
    -H "Title: VPS Railway Aktif" \\\\\\n\
    -H "Priority: high" \\\\\\n\
    -H "Tags: computer,key" \\\\\\n\
    -d "Cek log Railway untuk port. ssh root@bore.pub -p <PORT> | Password: craxid" > /dev/null 2>&1\\n\
else\\n\
  echo "ERROR: bore gagal."\\n\
  curl -s -X POST "https://ntfy.sh/$NTFY_TOPIC" \\\\\\n\
    -H "Title: VPS ERROR" \\\\\\n\
    -H "Priority: urgent" \\\\\\n\
    -d "bore tunnel gagal. Cek log Railway." > /dev/null 2>&1\\n\
fi\\n\
# Start simple HTTP health check server on port 8080\\n\
python3 -c \\"import http.server,socketserver;h=http.server.SimpleHTTPRequestHandler;socketserver.TCPServer(('"'"''"'"',8080),h).serve_forever()\\" &\\n\
wait $BORE_PID\\n\
' > /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 22 8080
CMD ["/entrypoint.sh"]
