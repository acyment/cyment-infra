#!/bin/bash
set -euo pipefail

echo "💾 Creating Cyment infrastructure backup"
echo "========================================"

PROJECT_NAME=${COMPOSE_PROJECT_NAME:-cyment-infra}
BACKUP_ROOT=${BACKUP_DIR:-backups}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
WORK_DIR="$BACKUP_ROOT/$TIMESTAMP"
ARCHIVE="$BACKUP_ROOT/cyment_backup_$TIMESTAMP.tar.gz"
FAILED=0

mkdir -p "$WORK_DIR"

volume_exists() {
    docker volume inspect "$1" > /dev/null 2>&1
}

container_running() {
    [ "$(docker compose ps -q "$1" 2>/dev/null | xargs docker inspect -f '{{.State.Running}}' 2>/dev/null || true)" = "true" ]
}

backup_volume() {
    local volume="$1"
    local output="$2"

    if volume_exists "$volume"; then
        echo "📦 Backing up Docker volume: $volume"
        docker run --rm \
            -v "$volume:/source:ro" \
            -v "$(pwd)/$WORK_DIR:/backup" \
            alpine:latest \
            tar -czf "/backup/$output" -C /source .
    else
        echo "⚠️  Skipping missing volume: $volume"
        FAILED=1
    fi
}

dump_postgres() {
    local service="$1"
    local user="$2"
    local database="$3"
    local output="$4"

    if container_running "$service"; then
        echo "🗄️  Dumping PostgreSQL database: $database"
        docker compose exec -T "$service" pg_dump -U "$user" "$database" > "$WORK_DIR/$output"
    else
        echo "⚠️  Skipping $database dump; $service is not running"
        FAILED=1
    fi
}

backup_volume "${PROJECT_NAME}_caddy_data" "caddy_data.tar.gz"
backup_volume "${PROJECT_NAME}_caddy_config" "caddy_config.tar.gz"
backup_volume "${PROJECT_NAME}_botini_media" "botini_media.tar.gz"

dump_postgres "botini-db" "botini" "botini" "botini.sql"
dump_postgres "umami-db" "umami" "umami" "umami.sql"

echo "🧾 Writing backup manifest"
{
    echo "timestamp=$TIMESTAMP"
    echo "project_name=$PROJECT_NAME"
    echo "created_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "files="
    for file in "$WORK_DIR"/*; do
        [ -f "$file" ] && echo "$file"
    done | sort
} > "$WORK_DIR/manifest.txt"

tar -czf "$ARCHIVE" -C "$BACKUP_ROOT" "$TIMESTAMP"

echo "✅ Backup created: $ARCHIVE"
echo "📊 Backup size: $(du -h "$ARCHIVE" | cut -f1)"
echo ""
echo "Backup contents:"
tar -tzf "$ARCHIVE" | awk 'NR <= 20 { print }'

if [ "$FAILED" -ne 0 ]; then
    echo ""
    echo "❌ Backup completed with missing critical data"
    exit 1
fi
