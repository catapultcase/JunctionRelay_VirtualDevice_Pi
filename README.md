# JunctionRelay VirtualDevice - Raspberry Pi

One-command installer for JunctionRelay VirtualDevice on Raspberry Pi.

## Quick Install

Flash standard Raspberry Pi OS (64-bit Desktop), then run:

```bash
curl -fsSL https://raw.githubusercontent.com/catapultcase/JunctionRelay_VirtualDevice_Pi/main/install.sh | sudo bash
```

That's it! JunctionRelay will auto-open Chromium to the WebUI on boot.

## What This Does

- Installs Node.js 20+ (if needed)
- Downloads latest JunctionRelay release
- Installs to `/opt/junctionrelay-virtualdevice`
- Creates systemd service (auto-starts on boot)
- Auto-opens Chromium to WebUI on graphical session
- Works with any username you choose in Pi Imager

## Requirements

- **Hardware:** Raspberry Pi 4 or Pi 5
- **OS:** Raspberry Pi OS 64-bit Desktop (Bookworm or later)
- **Internet:** Required for installation

## Setup Process

1. **Flash Pi OS** with [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
   - Choose: Raspberry Pi OS (64-bit) **Desktop**
   - Customize: Username, WiFi, SSH (all optional)

2. **Boot your Pi** and run the install command above

3. **Access WebUI** at `http://localhost:8086/`

## Management Commands

```bash
# Check status
sudo systemctl status junctionrelay

# Restart service
sudo systemctl restart junctionrelay

# View logs
sudo journalctl -u junctionrelay -f

# Update to latest version
sudo /opt/junctionrelay-virtualdevice/update.sh

# Uninstall
sudo /opt/junctionrelay-virtualdevice/scripts/uninstall.sh
```

## Updating

Update with a single command:

```bash
sudo /opt/junctionrelay-virtualdevice/update.sh
```

The updater will:
- Check for latest release
- Download if newer version available
- Backup current installation
- Apply update
- Preserve your settings
- Restart service

## Networking

**Default port:** `8086`

**Access from other devices:**
```
http://<pi-ip-address>:8086/
```

## Troubleshooting

### Service won't start

```bash
# Check logs
sudo journalctl -u junctionrelay -n 50

# Verify Node.js version
node --version  # Should be v20+

# Restart service
sudo systemctl restart junctionrelay
```

### WebUI not accessible

```bash
# Check if service is running
sudo systemctl status junctionrelay

# Check if port is in use
sudo netstat -tlnp | grep 8086
```

## Resources

- **Main Project:** [JunctionRelay_VirtualDevice](https://github.com/catapultcase/JunctionRelay_VirtualDevice)
- **Website:** [junctionrelay.com](https://junctionrelay.com)
- **Issues:** [GitHub Issues](https://github.com/catapultcase/JunctionRelay_VirtualDevice_Pi/issues)
- **Full Documentation:** [Pi Installation Guide](https://github.com/catapultcase/JunctionRelay_VirtualDevice/blob/main/docs/pi-installation.md)

## License

Same as main JunctionRelay VirtualDevice project.
