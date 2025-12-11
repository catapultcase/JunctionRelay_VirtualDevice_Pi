#!/bin/bash
# JunctionRelay VirtualDevice - One-Command Installer for Raspberry Pi

set -e

REPO="catapultcase/JunctionRelay_VirtualDevice_Pi"
INSTALL_DIR="/opt/junctionrelay-virtualdevice"
SERVICE_NAME="junctionrelay"
MIN_NODE_VERSION=20

echo "============================================================================"
echo "  JunctionRelay VirtualDevice Installer"
echo "============================================================================"
echo ""

if [ "$(id -u)" != "0" ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

if [ -n "$SUDO_USER" ]; then
    ACTUAL_USER="$SUDO_USER"
    ACTUAL_HOME=$(eval echo ~$SUDO_USER)
else
    ACTUAL_USER=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1; exit}' /etc/passwd)
    ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)
fi

echo "[1/6] Detected user: $ACTUAL_USER"
echo ""

echo "[2/6] Checking Node.js..."
if ! command -v node &> /dev/null; then
    echo "  Node.js not found. Installing Node.js ${MIN_NODE_VERSION}..."
    curl -fsSL https://deb.nodesource.com/setup_${MIN_NODE_VERSION}.x | bash -
    apt-get install -y nodejs
else
    NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
    if [ "$NODE_VERSION" -lt "$MIN_NODE_VERSION" ]; then
        echo "  Node.js $NODE_VERSION found, but v${MIN_NODE_VERSION}+ required. Upgrading..."
        curl -fsSL https://deb.nodesource.com/setup_${MIN_NODE_VERSION}.x | bash -
        apt-get install -y nodejs
    else
        echo "  ✓ Node.js $(node -v) found"
    fi
fi
echo ""

echo "[3/6] Downloading latest release..."
LATEST_RELEASE=$(curl -s https://api.github.com/repos/$REPO/releases/latest)
VERSION=$(echo "$LATEST_RELEASE" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
DOWNLOAD_URL=$(echo "$LATEST_RELEASE" | grep '"browser_download_url":' | grep '.tar.gz"' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$DOWNLOAD_URL" ]; then
    echo "  ERROR: Failed to get download URL from GitHub"
    exit 1
fi

echo "  Version: $VERSION"
echo "  Downloading from: $DOWNLOAD_URL"

TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
curl -L -o package.tar.gz "$DOWNLOAD_URL"
echo "  ✓ Download complete"
echo ""

echo "[4/6] Extracting..."
tar -xzf package.tar.gz
EXTRACTED_DIR=$(ls -d */ | head -n 1 | sed 's:/*$::')
cd "$EXTRACTED_DIR"
echo "  ✓ Extracted"
echo ""

echo "[5/6] Installing..."
if [ -d "$INSTALL_DIR" ]; then
    echo "  Existing installation found, backing up..."
    BACKUP_DIR="${INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    mv "$INSTALL_DIR" "$BACKUP_DIR"
    echo "  Backup saved to: $BACKUP_DIR"
fi

mkdir -p "$INSTALL_DIR"
cp -r ./* "$INSTALL_DIR/"

# Copy update.sh to root of install dir and make executable
if [ -f "$INSTALL_DIR/scripts/update.sh" ]; then
    cp "$INSTALL_DIR/scripts/update.sh" "$INSTALL_DIR/update.sh"
    chmod +x "$INSTALL_DIR/update.sh"
fi

# Create startup script
cat > "$INSTALL_DIR/start-with-browser.sh" <<'EOFSTARTUP'
#!/bin/bash
# JunctionRelay VirtualDevice - Start with Firefox Browser

INSTALL_DIR="/opt/junctionrelay-virtualdevice"
WEBUI_URL="http://localhost:8086/"

# Cleanup function
cleanup() {
    if [ -n "$FIREFOX_PID" ]; then
        kill $FIREFOX_PID 2>/dev/null
    fi
}

trap cleanup EXIT SIGTERM SIGINT

# Start backend
cd "$INSTALL_DIR"
node launcher.js &
LAUNCHER_PID=$!

# Wait for backend to be ready (max 30 seconds)
for i in {1..60}; do
    if curl -s http://localhost:8086/api/health > /dev/null 2>&1; then
        break
    fi
    sleep 0.5
done

# Open Firefox if DISPLAY is available
if [ -n "$DISPLAY" ]; then
    if command -v firefox &> /dev/null; then
        firefox --kiosk "$WEBUI_URL" &
        FIREFOX_PID=$!
    fi
fi

# Wait for launcher process
wait $LAUNCHER_PID
exit $?
EOFSTARTUP

chmod +x "$INSTALL_DIR/start-with-browser.sh"
chown -R ${ACTUAL_USER}:${ACTUAL_USER} "$INSTALL_DIR"
echo "  ✓ Files installed"
echo ""

echo "[6/6] Setting up systemd service..."
cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOFSERVICE
[Unit]
Description=JunctionRelay VirtualDevice
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${ACTUAL_USER}
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/${ACTUAL_USER}/.Xauthority
Environment=WAYLAND_DISPLAY=wayland-0
Environment=XDG_RUNTIME_DIR=/run/user/1000
Environment=MOZ_ENABLE_WAYLAND=1
WorkingDirectory=${INSTALL_DIR}
ExecStart=/bin/bash ${INSTALL_DIR}/start-with-browser.sh
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=30

[Install]
WantedBy=graphical.target
EOFSERVICE

systemctl daemon-reload
systemctl enable ${SERVICE_NAME}.service
systemctl start ${SERVICE_NAME}.service
echo "  ✓ Service installed and started"
echo ""

cd /
rm -rf "$TEMP_DIR"

echo "============================================================================"
echo "  Installation Complete!"
echo "============================================================================"
echo ""
echo "Version: $VERSION"
echo "Install directory: $INSTALL_DIR"
echo "Service: $SERVICE_NAME"
echo ""
echo "Service status:"
systemctl status ${SERVICE_NAME}.service --no-pager | head -n 10
echo ""
echo "Firefox will auto-open to WebUI on next graphical session"
echo "Or access manually at: http://localhost:8086/"
echo ""
echo "Management commands:"
echo "  sudo systemctl status $SERVICE_NAME      # Check status"
echo "  sudo systemctl restart $SERVICE_NAME     # Restart service"
echo "  sudo systemctl stop $SERVICE_NAME        # Stop service"
echo "  sudo journalctl -u $SERVICE_NAME -f      # View logs"
echo "  sudo ${INSTALL_DIR}/scripts/uninstall.sh  # Uninstall"
echo ""
echo "The system will now reboot..."
sleep 3
reboot
