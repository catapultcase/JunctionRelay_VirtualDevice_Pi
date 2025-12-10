#!/bin/bash
# JunctionRelay VirtualDevice - Update Script

set -e

REPO="catapultcase/JunctionRelay_VirtualDevice_Pi"
INSTALL_DIR="/opt/junctionrelay-virtualdevice"
SERVICE_NAME="junctionrelay"

echo "============================================================================"
echo "  JunctionRelay VirtualDevice Updater"
echo "============================================================================"
echo ""

if [ "$(id -u)" != "0" ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

if [ ! -d "$INSTALL_DIR" ]; then
    echo "ERROR: JunctionRelay is not installed at $INSTALL_DIR"
    echo "Please run the installer first:"
    echo "  curl -fsSL https://raw.githubusercontent.com/catapultcase/JunctionRelay_VirtualDevice_Pi/main/install.sh | sudo bash"
    exit 1
fi

# Get current version
CURRENT_VERSION="unknown"
if [ -f "$INSTALL_DIR/package.json" ]; then
    CURRENT_VERSION=$(grep '"version":' "$INSTALL_DIR/package.json" | sed -E 's/.*"([^"]+)".*/\1/')
fi

echo "[1/5] Current version: $CURRENT_VERSION"
echo ""

echo "[2/5] Checking for updates..."
LATEST_RELEASE=$(curl -s https://api.github.com/repos/$REPO/releases/latest)
LATEST_VERSION=$(echo "$LATEST_RELEASE" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
DOWNLOAD_URL=$(echo "$LATEST_RELEASE" | grep '"browser_download_url":' | grep '.tar.gz"' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$DOWNLOAD_URL" ]; then
    echo "  ERROR: Failed to get download URL from GitHub"
    exit 1
fi

echo "  Latest version: $LATEST_VERSION"

if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
    echo "  ✓ Already up to date!"
    exit 0
fi

echo ""
echo "[3/5] Downloading version $LATEST_VERSION..."
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
curl -L -o package.tar.gz "$DOWNLOAD_URL"
echo "  ✓ Download complete"
echo ""

echo "[4/5] Extracting..."
tar -xzf package.tar.gz
EXTRACTED_DIR=$(ls -d */ | head -n 1 | sed 's:/*$::')
cd "$EXTRACTED_DIR"
echo "  ✓ Extracted"
echo ""

echo "[5/5] Updating installation..."
echo "  Stopping service..."
systemctl stop ${SERVICE_NAME}.service

echo "  Backing up current installation..."
BACKUP_DIR="${INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
cp -r "$INSTALL_DIR" "$BACKUP_DIR"
echo "  Backup saved to: $BACKUP_DIR"

echo "  Installing new version..."
cp -r ./* "$INSTALL_DIR/"

if [ -n "$SUDO_USER" ]; then
    ACTUAL_USER="$SUDO_USER"
else
    ACTUAL_USER=$(stat -c '%U' "$INSTALL_DIR")
fi
chown -R ${ACTUAL_USER}:${ACTUAL_USER} "$INSTALL_DIR"

echo "  Starting service..."
systemctl start ${SERVICE_NAME}.service

cd /
rm -rf "$TEMP_DIR"

echo "  ✓ Update complete"
echo ""

echo "============================================================================"
echo "  Update Successful!"
echo "============================================================================"
echo ""
echo "Updated from: $CURRENT_VERSION"
echo "Updated to:   $LATEST_VERSION"
echo ""
echo "Service status:"
systemctl status ${SERVICE_NAME}.service --no-pager | head -n 10
echo ""
echo "Backup saved to: $BACKUP_DIR"
echo ""
