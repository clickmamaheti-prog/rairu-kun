FROM ubuntu:20.04

ARG BUILD_DATE=20260622163609
LABEL build_date="${BUILD_DATE}"

ENV DEBIAN_FRONTEND=noninteractive \
    NTFY_TOPIC=rairu-mamaheti \
    BORE_SERVER=bore.pub \
    ROOT_PASS=craxid \
    OLLAMA_HOST=0.0.0.0

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        openssh-server \
        curl \
        python3 \
        vim \
        sudo \
        net-tools \
        wget \
        htop \
        git \
        unzip \
        iproute2 \
        procps \
        passwd \
        nginx \
        zstd && \
    update-ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install bore
RUN curl -fsSL "https://github.com/ekzhang/bore/releases/download/v0.5.0/bore-v0.5.0-x86_64-unknown-linux-musl.tar.gz" \
        -o /tmp/bore.tar.gz && \
    tar -xzf /tmp/bore.tar.gz -C /usr/local/bin/ && \
    chmod +x /usr/local/bin/bore && \
    rm /tmp/bore.tar.gz && \
    bore --version

# Install Ollama
RUN curl -fsSL https://ollama.com/install.sh | sh

# SSH setup
RUN mkdir -p /var/run/sshd /run/sshd && \
    echo "root:craxid" | chpasswd && \
    ssh-keygen -A && \
    echo '' >> /etc/ssh/sshd_config && \
    echo '# Custom config' >> /etc/ssh/sshd_config && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'ChallengeResponseAuthentication no' >> /etc/ssh/sshd_config && \
    echo 'UsePAM yes' >> /etc/ssh/sshd_config && \
    echo 'ClientAliveInterval 60' >> /etc/ssh/sshd_config && \
    echo 'ClientAliveCountMax 10' >> /etc/ssh/sshd_config && \
    sshd -t && echo 'SSH config OK'

# Nginx config for Ollama UI + API proxy
RUN rm -f /etc/nginx/sites-enabled/default
COPY nginx-ollama.conf /etc/nginx/sites-available/ollama
RUN ln -s /etc/nginx/sites-available/ollama /etc/nginx/sites-enabled/ollama

# Ollama UI
RUN mkdir -p /var/www/ollama-ui
COPY index.html /var/www/ollama-ui/index.html
RUN chown -R www-data:www-data /var/www/ollama-ui && chmod 755 /var/www/ollama-ui && chmod 644 /var/www/ollama-ui/index.html

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22 80 11434

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=5 \
    CMD pgrep sshd > /dev/null || exit 1

CMD ["/entrypoint.sh"]
