#!/bin/bash

# データベースバックアップスクリプト
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_DIR="./backups"
DB_NAME="dentalsystem_production"

mkdir -p "$BACKUP_DIR"

echo "📦 データベースバックアップ開始: $TIMESTAMP"

# PostgreSQLバックアップ
pg_dump "$DB_NAME" > "$BACKUP_DIR/db_backup_$TIMESTAMP.sql"

# 古いバックアップ削除（30日以上）
find "$BACKUP_DIR" -name "db_backup_*.sql" -mtime +30 -delete

echo "✅ バックアップ完了: $BACKUP_DIR/db_backup_$TIMESTAMP.sql"
