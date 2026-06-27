FROM ubuntu:20.04

ARG BUILD_DATE
LABEL maintainer="DevCulture <devculture.id>" \
      version="2.0" \
      description="DevCulture Premium VPS — Ubuntu 20.04 Multi-Port"

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Jakarta \
    NTFY_TOPIC=devculture-vps \
    BORE_SERVER=bore.pub \
    ROOT_PASS=DevCulture2026 \
    AUTO_PULL_MODEL=smollm2 \
    OLLAMA_HOST=0.0.0.0

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates openssh-server curl python3 \
        vim nano sudo net-tools wget htop git unzip \
        iproute2 iputils-ping procps passwd tmux screen \
        lsof dnsutils jq tzdata zstd neofetch \
        nginx && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone && \
    update-ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# bore tunnel
RUN curl -fsSL "https://github.com/ekzhang/bore/releases/download/v0.5.0/bore-v0.5.0-x86_64-unknown-linux-musl.tar.gz" \
        -o /tmp/bore.tar.gz && \
    tar -xzf /tmp/bore.tar.gz -C /usr/local/bin/ && \
    chmod +x /usr/local/bin/bore && \
    rm /tmp/bore.tar.gz

# cloudflared
RUN curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" \
        -o /usr/local/bin/cloudflared && \
    chmod +x /usr/local/bin/cloudflared

# Ollama AI
RUN curl -fsSL https://ollama.com/install.sh | sh

# SSH config
RUN mkdir -p /run/sshd && \
    echo "root:DevCulture2026" | chpasswd && \
    ssh-keygen -A && \
    sed -i \
      -e 's/#PermitRootLogin.*/PermitRootLogin yes/' \
      -e 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' \
      -e 's/#PasswordAuthentication.*/PasswordAuthentication yes/' \
      -e 's/PasswordAuthentication no/PasswordAuthentication yes/' \
      -e 's/#ClientAliveInterval.*/ClientAliveInterval 60/' \
      -e 's/#ClientAliveCountMax.*/ClientAliveCountMax 10/' \
      -e 's/#MaxSessions.*/MaxSessions 50/' \
      -e 's/#TCPKeepAlive.*/TCPKeepAlive yes/' \
      /etc/ssh/sshd_config

# DevCulture SSH banner (plain, for pre-auth)
RUN printf "╔══════════════════════════════════════════════════╗\n║          D E V C U L T U R E   V P S            ║\n║             Premium Cloud Server                 ║\n╚══════════════════════════════════════════════════╝\n" \
    > /etc/ssh/banner.txt && \
    echo "Banner /etc/ssh/banner.txt" >> /etc/ssh/sshd_config

# Nginx
RUN rm -f /etc/nginx/sites-enabled/default
COPY nginx-ollama.conf /etc/nginx/sites-available/ollama
RUN ln -s /etc/nginx/sites-available/ollama /etc/nginx/sites-enabled/ollama

# Ollama Web UI
RUN mkdir -p /var/www/ollama-ui
COPY index.html /var/www/ollama-ui/index.html
RUN chmod -R 755 /var/www/ollama-ui

# DevCulture login banner (ANSI colors, shown after SSH login)
COPY devculture-banner.sh /etc/profile.d/99-devculture-banner.sh
RUN chmod +x /etc/profile.d/99-devculture-banner.sh

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22 80 443 3000 8080 8888 11434

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 \
    CMD curl -sf http://localhost:8080 > /dev/null || exit 1

CMD ["/entrypoint.sh"]
