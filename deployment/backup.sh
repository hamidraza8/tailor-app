#!/bin/bash
# TailorShop Backup Script
# Run daily via cron: 0 2 * * * /opt/tailorshop/deployment/backup.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="${SCRIPT_DIR}/../backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

echo "[$(date)] Starting backup..."

# Database backup
echo "Backing up database..."
docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T postgres \
  pg_dump -U postgres tailorshop | gzip > "$BACKUP_DIR/db_${DATE}.sql.gz"

# Uploads backup
echo "Backing up uploads..."
VOLUME_PATH=$(docker volume inspect deployment_uploads_data -f '{{.Mountpoint}}' 2>/dev/null || echo "")
if [ -n "$VOLUME_PATH" ] && [ -d "$VOLUME_PATH" ]; then
  tar -czf "$BACKUP_DIR/uploads_${DATE}.tar.gz" -C "$VOLUME_PATH" .
fi

# Cleanup old backups (keep last 7 days)
find "$BACKUP_DIR" -name "*.gz" -mtime +7 -delete

echo "[$(date)] Backup complete."
echo "Database: db_${DATE}.sql.gz"
echo "Uploads: uploads_${DATE}.tar.gz"
