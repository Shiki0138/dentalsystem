#!/bin/bash
# 統合監視・ヘルスチェックシステム
# check_escalation_need.sh, health_check.sh, setup_monitoring.sh を統合

PROJECT_NAME=${1:-dentalsystem}
ACTION=${2:-check}

# カラー定義
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== 統合監視システム ===${NC}"
echo "プロジェクト: $PROJECT_NAME"
echo "アクション: $ACTION"

case $ACTION in
    "check")
        echo -e "${YELLOW}=== システムヘルスチェック ===${NC}"
        
        # エラーチェック
        ERROR_COUNT=$(grep -i "ERROR" development/development_log.txt 2>/dev/null | tail -20 | wc -l)
        echo "直近のエラー数: $ERROR_COUNT"
        
        # Workerステータス
        echo -e "\n${YELLOW}Worker Status:${NC}"
        for i in {1..5}; do
            if [ -f "./tmp/worker${i}_done.txt" ]; then
                LAST_UPDATE=$(stat -f "%m" "./tmp/worker${i}_done.txt" 2>/dev/null || stat -c "%Y" "./tmp/worker${i}_done.txt" 2>/dev/null)
                CURRENT_TIME=$(date +%s)
                DIFF=$((CURRENT_TIME - LAST_UPDATE))
                if [ $DIFF -gt 1800 ]; then
                    echo -e "Worker$i: ${RED}タイムアウト${NC} (${DIFF}秒前)"
                else
                    echo -e "Worker$i: ${GREEN}正常${NC} (${DIFF}秒前)"
                fi
            else
                echo -e "Worker$i: ${YELLOW}未起動${NC}"
            fi
        done
        
        # システムリソース
        echo -e "\n${YELLOW}System Resources:${NC}"
        echo "CPU使用率: $(top -l 1 | grep "CPU usage" | awk '{print $3}')"
        echo "メモリ使用率: $(top -l 1 | grep "PhysMem" | awk '{print $2}')"
        
        # エスカレーション判定
        echo -e "\n${YELLOW}Escalation Check:${NC}"
        ESCALATION_NEEDED=false
        REASON=""
        
        if [ $ERROR_COUNT -ge 3 ]; then
            ESCALATION_NEEDED=true
            REASON="エラー多発（$ERROR_COUNT件）"
        fi
        
        if [ "$ESCALATION_NEEDED" = true ]; then
            echo -e "${RED}Trinity AI Systemへのエスカレーションが必要${NC}"
            echo "理由: $REASON"
        else
            echo -e "${GREEN}正常動作中${NC}"
        fi
        ;;
        
    "setup")
        echo -e "${YELLOW}=== 監視環境セットアップ ===${NC}"
        
        # 監視ディレクトリ作成
        mkdir -p monitoring/{logs,alerts,metrics}
        
        # 監視設定ファイル作成
        cat > monitoring/config.json << EOF
{
  "project": "$PROJECT_NAME",
  "monitoring": {
    "error_threshold": 3,
    "worker_timeout": 1800,
    "check_interval": 300,
    "alert_channels": ["log", "console"]
  },
  "metrics": {
    "cpu_threshold": 80,
    "memory_threshold": 80,
    "response_time_threshold": 3000
  }
}
EOF
        
        echo -e "${GREEN}監視環境セットアップ完了${NC}"
        
        # ログ記録
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [MONITORING] [$PROJECT_NAME] 監視環境セットアップ完了" >> development/development_log.txt
        ;;
        
    "alert")
        # アラート通知
        MESSAGE=${3:-"システムアラート"}
        LEVEL=${4:-"WARNING"}
        
        echo -e "${RED}=== アラート通知 ===${NC}"
        echo "レベル: $LEVEL"
        echo "メッセージ: $MESSAGE"
        
        # アラートログ記録
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$LEVEL] [$PROJECT_NAME] $MESSAGE" >> monitoring/alerts/alert.log
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ALERT] [$PROJECT_NAME] [$LEVEL] $MESSAGE" >> development/development_log.txt
        
        # 重大度に応じた処理
        case $LEVEL in
            "CRITICAL")
                echo -e "${RED}Trinity AI Systemへ自動エスカレーション${NC}"
                ./scripts/trinity-unified.sh $PROJECT_NAME escalate "$MESSAGE"
                ;;
            "ERROR")
                echo -e "${YELLOW}boss1へ通知${NC}"
                ./agent-send.sh $PROJECT_NAME boss1 "エラーアラート: $MESSAGE"
                ;;
        esac
        ;;
        
    "continuous")
        echo -e "${GREEN}=== 継続監視モード開始 ===${NC}"
        
        # バックグラウンドで継続監視
        while true; do
            clear
            $0 $PROJECT_NAME check
            
            # アラート条件チェック
            ERROR_COUNT=$(grep -i "ERROR" development/development_log.txt 2>/dev/null | tail -20 | wc -l)
            if [ $ERROR_COUNT -ge 5 ]; then
                $0 $PROJECT_NAME alert "エラー多発検出" "CRITICAL"
            fi
            
            echo -e "\n${YELLOW}次回チェック: 30分後${NC}"
            echo "終了するには Ctrl+C を押してください"
            sleep 1800
        done
        ;;
        
    *)
        echo "使用方法: $0 [プロジェクト名] [check|setup|alert|continuous]"
        echo ""
        echo "アクション:"
        echo "  check      - システムヘルスチェック実行"
        echo "  setup      - 監視環境セットアップ"
        echo "  alert      - アラート通知送信"
        echo "  continuous - 継続監視モード（30分間隔）"
        echo ""
        echo "例:"
        echo "  $0 dentalsystem check"
        echo "  $0 dentalsystem alert \"メモリ使用率が高い\" WARNING"
        ;;
esac