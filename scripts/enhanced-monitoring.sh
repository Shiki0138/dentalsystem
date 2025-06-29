#!/bin/bash
# 強化されたエラー監視システム

PROJECT_NAME=${1:-dentalsystem}
ACTION=${2:-monitor}

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

case $ACTION in
    "monitor")
        echo -e "${BLUE}=== 強化エラー監視システム開始 ===${NC}"
        
        while true; do
            CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')
            echo -e "\n${YELLOW}[$CURRENT_TIME] 監視実行中...${NC}"
            
            # 1. Worker状況詳細チェック
            ACTIVE_WORKERS=0
            STALLED_WORKERS=0
            WORKER_STATUS=""
            
            for i in {1..5}; do
                if [ -f "./tmp/worker${i}_done.txt" ]; then
                    LAST_UPDATE=$(stat -f "%m" "./tmp/worker${i}_done.txt" 2>/dev/null || stat -c "%Y" "./tmp/worker${i}_done.txt" 2>/dev/null)
                    CURRENT_TIMESTAMP=$(date +%s)
                    DIFF=$((CURRENT_TIMESTAMP - LAST_UPDATE))
                    
                    if [ $DIFF -lt 3600 ]; then
                        ACTIVE_WORKERS=$((ACTIVE_WORKERS + 1))
                        WORKER_STATUS="${WORKER_STATUS}Worker${i}:正常($((DIFF/60))分前) "
                    else
                        STALLED_WORKERS=$((STALLED_WORKERS + 1))
                        WORKER_STATUS="${WORKER_STATUS}Worker${i}:停滞($((DIFF/3600))時間前) "
                    fi
                else
                    STALLED_WORKERS=$((STALLED_WORKERS + 1))
                    WORKER_STATUS="${WORKER_STATUS}Worker${i}:未起動 "
                fi
            done
            
            # 2. エラー数チェック（より詳細な分析）
            ERROR_COUNT_1H=$(grep -E "(ERROR|FAIL|EXCEPTION|CRITICAL)" development/development_log.txt | grep "$(date '+%Y-%m-%d %H')" | wc -l)
            ERROR_COUNT_24H=$(grep -E "(ERROR|FAIL|EXCEPTION|CRITICAL)" development/development_log.txt | grep "$(date '+%Y-%m-%d')" | wc -l)
            
            # 3. システムリソースチェック
            CPU_USAGE=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//')
            MEMORY_INFO=$(top -l 1 | grep "PhysMem")
            
            # 4. 重要サービス状況
            REDIS_STATUS="不明"
            POSTGRES_STATUS="不明"
            
            if redis-cli ping >/dev/null 2>&1; then
                REDIS_STATUS="正常"
            else
                REDIS_STATUS="異常"
            fi
            
            if pgrep postgres >/dev/null; then
                POSTGRES_STATUS="正常"
            else
                POSTGRES_STATUS="異常"
            fi
            
            # 5. 監視結果表示
            echo -e "${BLUE}=== システム状況 ===${NC}"
            echo "稼働Workers: $ACTIVE_WORKERS/5"
            echo "停滞Workers: $STALLED_WORKERS/5"
            echo "Worker詳細: $WORKER_STATUS"
            echo "エラー数(1時間): $ERROR_COUNT_1H"
            echo "エラー数(24時間): $ERROR_COUNT_24H"
            echo "Redis: $REDIS_STATUS"
            echo "PostgreSQL: $POSTGRES_STATUS"
            echo "CPU使用率: ${CPU_USAGE}%"
            
            # 6. アラート条件判定
            ALERT_LEVEL="正常"
            ALERT_MESSAGE=""
            
            if [ $STALLED_WORKERS -ge 3 ]; then
                ALERT_LEVEL="CRITICAL"
                ALERT_MESSAGE="Worker大量停滞($STALLED_WORKERS/5)"
            elif [ $STALLED_WORKERS -ge 2 ]; then
                ALERT_LEVEL="HIGH"
                ALERT_MESSAGE="Worker停滞検出($STALLED_WORKERS/5)"
            elif [ $ERROR_COUNT_1H -ge 5 ]; then
                ALERT_LEVEL="HIGH"
                ALERT_MESSAGE="エラー多発($ERROR_COUNT_1H件/1時間)"
            elif [ "$REDIS_STATUS" = "異常" ] || [ "$POSTGRES_STATUS" = "異常" ]; then
                ALERT_LEVEL="CRITICAL"
                ALERT_MESSAGE="重要サービス停止"
            fi
            
            # 7. アラート処理
            if [ "$ALERT_LEVEL" != "正常" ]; then
                echo -e "${RED}アラート: $ALERT_LEVEL - $ALERT_MESSAGE${NC}"
                
                # ログ記録
                echo "[$CURRENT_TIME] [ALERT] [$PROJECT_NAME] [$ALERT_LEVEL] $ALERT_MESSAGE" >> development/development_log.txt
                
                # 緊急対応実行
                if [ "$ALERT_LEVEL" = "CRITICAL" ] && [ $STALLED_WORKERS -ge 2 ]; then
                    echo -e "${RED}緊急対応実行中...${NC}"
                    ./scripts/emergency-worker-restart.sh $PROJECT_NAME
                elif [ "$ALERT_LEVEL" = "HIGH" ] && [ $STALLED_WORKERS -ge 1 ]; then
                    echo -e "${YELLOW}警告レベル対応実行中...${NC}"
                    ./agent-send.sh $PROJECT_NAME boss1 "【警告】エラー監視システム: $ALERT_MESSAGE。対応確認をお願いします。"
                fi
            else
                echo -e "${GREEN}システム正常稼働中${NC}"
            fi
            
            # 8. 次回チェックまで待機
            echo -e "${YELLOW}次回チェック: 5分後${NC}"
            echo "停止: Ctrl+C"
            sleep 300
        done
        ;;
        
    "check")
        # 単発チェック
        ./scripts/monitoring-unified.sh $PROJECT_NAME check
        ;;
        
    "emergency")
        # 緊急対応モード
        echo -e "${RED}=== 緊急対応モード ===${NC}"
        ./scripts/emergency-worker-restart.sh $PROJECT_NAME
        ;;
        
    *)
        echo "使用方法: $0 [プロジェクト名] [monitor|check|emergency]"
        echo ""
        echo "monitor   - 継続監視モード（5分間隔）"
        echo "check     - 単発ヘルスチェック"
        echo "emergency - 緊急Worker再起動"
        ;;
esac