#!/usr/bin/env bash
# init.sh — first-time setup for the War relay server (Ubuntu 24.04)
# Run as root on the VPS after first SSH in.
#
# What this does:
#   - installs Python 3 + sqlite3
#   - copies relay.py and admin.py to /opt/
#   - creates the backup directory + cron job
#   - installs the systemd service and starts it
#
# Re-running is safe; all steps are idempotent.

set -euo pipefail

RELAY_SRC="$(dirname "$0")/relay.py"
ADMIN_SRC="$(dirname "$0")/admin.py"
BACKUP_SRC="$(dirname "$0")/backup_db.sh"

RELAY_DEST="/opt/war_relay.py"
ADMIN_DEST="/opt/admin.py"
BACKUP_DEST="/opt/backup_db.sh"
BACKUP_DIR="/opt/backups"
SERVICE="/etc/systemd/system/war-relay.service"

# ---------------------------------------------------------------------------
# dependencies
# ---------------------------------------------------------------------------

apt-get update -qq
apt-get install -y -qq python3 sqlite3

# ---------------------------------------------------------------------------
# copy files
# ---------------------------------------------------------------------------

cp "$RELAY_SRC"  "$RELAY_DEST"
cp "$ADMIN_SRC"  "$ADMIN_DEST"
cp "$BACKUP_SRC" "$BACKUP_DEST"
chmod +x "$BACKUP_DEST"

mkdir -p "$BACKUP_DIR"

# ---------------------------------------------------------------------------
# systemd service
# ---------------------------------------------------------------------------

cat > "$SERVICE" <<'EOF'
[Unit]
Description=War Balatro relay server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/war_relay.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now war-relay.service
echo "war-relay: $(systemctl is-active war-relay.service)"

# ---------------------------------------------------------------------------
# backup cron (3am daily)
# ---------------------------------------------------------------------------

CRON_LINE="0 3 * * * /opt/backup_db.sh"
# add only if not already present
( crontab -l 2>/dev/null | grep -qF "$BACKUP_DEST" ) || \
    ( crontab -l 2>/dev/null; echo "$CRON_LINE" ) | crontab -

echo "done — relay listening on :7777"
