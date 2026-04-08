#!/bin/bash

echo "💾 Creating backup of Caddy data"
echo "================================="

BACKUP_DIR="backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/caddy_backup_$TIMESTAMP.tar.gz"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Check if Caddy volumes exist
if docker volume ls | grep -q "cyment-infra_caddy_data\|cyment-infra_caddy_config"; then
    echo "📦 Backing up Caddy volumes..."
    
    # Create temporary container to access volumes
    docker run --rm \
        -v cyment-infra_caddy_data:/data:ro \
        -v cyment-infra_caddy_config:/config:ro \
        -v "$(pwd)/$BACKUP_DIR:/backup" \
        alpine:latest \
        tar -czf "/backup/caddy_backup_$TIMESTAMP.tar.gz" -C / data config
    
    echo "✅ Backup created: $BACKUP_FILE"
    echo ""
    echo "Backup contents:"
    tar -tzf "$BACKUP_FILE" | head -10
    echo "..."
    echo ""
    echo "📊 Backup size: $(du -h "$BACKUP_FILE" | cut -f1)"
else
    echo "⚠️  Caddy volumes not found. Are the services running?"
    exit 1
fi
