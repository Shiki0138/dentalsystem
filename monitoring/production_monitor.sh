#!/bin/bash

# 本番環境監視スクリプト

PROJECT_NAME="dentalsystem"
MONITOR_PORT=${1:-3001}

echo "🛡️ 本番環境監視開始 - ポート: $MONITOR_PORT"

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    # ヘルスチェック
    if curl -s "http://localhost:$MONITOR_PORT/health" >/dev/null 2>&1; then
        echo "[$TIMESTAMP] ✅ システム正常"
    else
        echo "[$TIMESTAMP] ❌ システム異常検出"
        
        # 自動復旧試行
        echo "[$TIMESTAMP] 🔄 自動復旧開始..."
        ./start_production_server.sh $MONITOR_PORT &
    fi
    
    sleep 30
done
