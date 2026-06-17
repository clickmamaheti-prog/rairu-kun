FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    NTFY_TOPIC=rairu-devculture67 \
    BORE_SERVER=bore.pub \
    SSH_PORT=22

RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-server \
        wget \
        curl \
        python3 \
        vim \
        sudo \
        net-tools && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Bore v0.5.0
RUN wget -q https://github.com/ekzhang/bore/releases/download/v0.5.0/bore-v0.5.0-x86_64-unknown-linux-musl.tar.gz \
        -O /tmp/bore.tar.gz && \
    tar -xzf /tmp/bore.tar.gz -C /usr/local/bin bore && \
    chmod +x /usr/local/bin/bore && \
    rm /tmp/bore.tar.gz

# Setup SSH + root password
RUN mkdir -p /run/sshd && \
    echo "root:craxid" | chpasswd && \
    ssh-keygen -A

RUN sed -i \
    -e 's/#PermitRootLogin.*/PermitRootLogin yes/' \
    -e 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' \
    -e 's/#PasswordAuthentication yes/PasswordAuthentication yes/' \
    -e 's/PasswordAuthentication no/PasswordAuthentication yes/' \
    -e 's/#ClientAliveInterval.*/ClientAliveInterval 60/' \
    -e 's/#ClientAliveCountMax.*/ClientAliveCountMax 10/' \
    /etc/ssh/sshd_config

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=5 \
    CMD pgrep sshd > /dev/null && pgrep bore > /dev/null || exit 1

CMD ["/entrypoint.sh"]
