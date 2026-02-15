#!/bin/bash

echo "Starting Backhaul Installer..."

IR_IP=$1

# =========================
# Detect Role
# =========================
if [ -z "$IR_IP" ]; then
  ROLE="server"
  echo "Mode: IR Server"
else
  ROLE="client"
  echo "Mode: OUT Client"
  echo "IR Server IP: $IR_IP"
fi
echo "Role detection done."

# =========================
# Detect Architecture
# =========================
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
echo "Architecture detection done."

# =========================
# Download Latest Release
# =========================
echo "Downloading Backhaul..."
curl -L "https://github.com/Musixal/Backhaul/releases/latest/download/$FILE" -o "$FILE" || exit 1
echo "Download done."

# =========================
# Extract Binary
# =========================
mkdir -p /root/backhaul
tar -xzf "$FILE" -C /root/backhaul || exit 1
rm -f "$FILE" /root/backhaul/LICENSE /root/backhaul/README.md
echo "Extraction done."

# =========================
# Create Config
# =========================
if [ "$ROLE" = "server" ]; then

cat > /root/backhaul/config.toml <<EOF
[server]
bind_addr = "0.0.0.0:3080"
transport = "wsmux"
token = "M0hsen@de"
keepalive_period = 75
nodelay = true
heartbeat = 40
channel_size = 2048
mux_con = 8
mux_version = 1
mux_framesize = 32768
mux_recievebuffer = 4194304
mux_streambuffer = 65536
sniffer = true
web_port = 2160
sniffer_log = "/root/backhaul.json"
log_level = "info"
ports = [
"80",
"443"
]
EOF

echo "Server config created."

else

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

echo "Client config created."

fi

# =========================
# Create systemd Service
# =========================
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

echo "Service file created."

# =========================
# Enable & Start Service
# =========================
systemctl daemon-reload
echo "Daemon reload done."

systemctl enable backhaul
echo "Service enable done."

systemctl restart backhaul
echo "Service start done."

echo "===================================="
echo "Backhaul installation completed."
systemctl status backhaul --no-pager
