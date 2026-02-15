#!/bin/bash

# ==== CHECK IP ARGUMENT ====
IR_IP=$1
if [ -z "$IR_IP" ]; then
  echo "Usage: bash install.sh <IR_SERVER_IP>"
  exit 1
fi

echo "Using IR server IP: $IR_IP"

# ==== DETECT ARCH ====
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

if [ "$ARCH" = "x86_64" ]; then
  ARCH="amd64"
elif [ "$ARCH" = "aarch64" ]; then
  ARCH="arm64"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

FILE="backhaul_${OS}_${ARCH}.tar.gz"

echo "Downloading $FILE..."
curl -L "https://github.com/Musixal/Backhaul/releases/latest/download/$FILE" -o "$FILE" || exit 1

mkdir -p /root/backhaul
tar -xzf "$FILE" -C /root/backhaul || exit 1
rm -f "$FILE" /root/backhaul/LICENSE /root/backhaul/README.md

# ==== CREATE CONFIG ====
cat > /root/backhaul/config.toml <<EOF
[client]
remote_addr = "$IR_IP:3080"
transport = "wsmux"
token = "M0hsen@de"
connection_pool = 8
aggressive_pool = false
keepalive_period = 75
dial_timeout = 10
nodelay = true
retry_interval = 3
mux_version = 1
mux_framesize = 32768
mux_recievebuffer = 4194304
mux_streambuffer = 65536
sniffer = true
web_port = 2160
sniffer_log = "/root/backhaul.json"
log_level = "info"
EOF

# ==== CREATE SERVICE ====
cat > /etc/systemd/system/backhaul.service <<EOF
[Unit]
Description=Backhaul Reverse Tunnel Service
After=network.target

[Service]
Type=simple
ExecStart=/root/backhaul/backhaul -c /root/backhaul/config.toml
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

# ==== ENABLE & START ====
systemctl daemon-reload
systemctl enable backhaul
systemctl restart backhaul

echo "===================================="
echo "Backhaul Installed and Started"
systemctl status backhaul --no-pager
