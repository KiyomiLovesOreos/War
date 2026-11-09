#!/bin/bash
# Backs up war.db to /opt/backups/ keeping last 30 days.
# Run via cron: 0 3 * * * /opt/backup_db.sh

DEST=/opt/backups
mkdir -p "$DEST"
sqlite3 /opt/war.db ".backup $DEST/war_$(date +%Y%m%d_%H%M%S).db"
find "$DEST" -name "war_*.db" -mtime +30 -delete
