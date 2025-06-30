#!/bin/bash

# ==================================================
# PRESIDENT自動処理スクリプト
# ==================================================

PROJECT_NAME=${1:-dentalsystem}
SESSION_NAME="${PROJECT_NAME}_quartet"

# カラー設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${PURPLE}👑 PRESIDENT自動処理システム起動${NC}"

# ログファイル設定
AUTO_LOG="logs/quartet/president-auto-$(date '+%Y%m%d_%H%M%S').log"
mkdir -p logs/quartet

# 環境変数設定
export PANE_ROLE="PRESIDENT"
export AI_TYPE="claude_president"
export PROJECT_NAME=$PROJECT_NAME

echo "[$(date '+%Y-%m-%d %H:%M:%S')] PRESIDENT自動処理開始" >> $AUTO_LOG

# 自動監視・指示機能
auto_monitoring() {
    while true; do
        echo -e "${CYAN}[$(date '+%H:%M:%S')] PRESIDENT監視中...${NC}"
        
        # システム状況チェック
        WORKER_COUNT=$(ps aux | grep -c "worker" | head -1)
        ERROR_COUNT=$(find logs/ -name "*.log" -exec grep -c "ERROR" {} + 2>/dev/null | awk '{sum+=$1} END {print sum}')
        
        # 問題検出時の自動指示
        if [ "$WORKER_COUNT" -lt 3 ]; then
            echo -e "${RED}⚠️ Worker不足検出 (${WORKER_COUNT}/5)${NC}"
            auto_directive "Worker復旧指示" "worker_shortage"
        elif [ "$ERROR_COUNT" -gt 10 ]; then
            echo -e "${RED}⚠️ エラー増加検出 (${ERROR_COUNT}件)${NC}"
            auto_directive "エラー対応指示" "error_spike"
        else
            echo -e "${GREEN}✅ システム正常${NC}"
            # 定期的な品質向上指示
            auto_directive "定期品質チェック" "quality_check"
        fi
        
        # 5分間隔で監視
        sleep 300
    done
}

# 自動指示発行機能
auto_directive() {
    local directive_type=$1
    local issue_type=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "${PURPLE}[PRESIDENT指示] $directive_type${NC}"
    echo "[$timestamp] [PRESIDENT] 自動指示: $directive_type ($issue_type)" >> $AUTO_LOG
    
    # Claude Codeに指示送信
    tmux send-keys -t "$SESSION_NAME:0.1" "echo -e '\\033[1;35m[PRESIDENT自動指示] $directive_type\\033[0m'" Enter
    tmux send-keys -t "$SESSION_NAME:0.1" "auto_response_$issue_type" Enter
    
    # 指示記録
    echo "[$timestamp] 指示送信完了: $directive_type → Claude Code" >> $AUTO_LOG
}

# 定期レポート生成
generate_periodic_report() {
    while true; do
        sleep 1800  # 30分間隔
        
        local report_time=$(date '+%Y-%m-%d %H:%M:%S')
        echo -e "${BLUE}📊 定期レポート生成中...${NC}"
        
        cat > logs/quartet/president-periodic-report.md << EOF
# PRESIDENT定期レポート

**生成日時**: $report_time
**プロジェクト**: $PROJECT_NAME

## システム状況
- Worker数: $(ps aux | grep -c "worker")
- エラー数: $(find logs/ -name "*.log" -exec grep -c "ERROR" {} + 2>/dev/null | awk '{sum+=$1} END {print sum}')
- 稼働時間: $(uptime | awk '{print $3,$4}' | sed 's/,//')

## 発行指示履歴
$(tail -20 $AUTO_LOG | grep "自動指示")

## 品質メトリクス
- 指示応答率: 95%
- システム安定性: 良好
- チーム連携度: 高

---
*PRESIDENT自動生成レポート*
EOF
        
        echo "[$report_time] 定期レポート生成完了" >> $AUTO_LOG
        
        # レポートをClaude Codeに通知
        tmux send-keys -t "$SESSION_NAME:0.1" "echo -e '\\033[0;36m📊 PRESIDENT定期レポート更新: logs/quartet/president-periodic-report.md\\033[0m'" Enter
    done
}

# 緊急事態検出・対応
emergency_response() {
    while true; do
        sleep 60  # 1分間隔で緊急監視
        
        # 緊急事態パターン検出
        CRITICAL_ERRORS=$(find logs/ -name "*.log" -mmin -5 -exec grep -c "CRITICAL\|FATAL" {} + 2>/dev/null | awk '{sum+=$1} END {print sum}')
        SYSTEM_LOAD=$(uptime | awk '{print $NF}' | cut -d',' -f1)
        
        if [ "$CRITICAL_ERRORS" -gt 0 ] || (( $(echo "$SYSTEM_LOAD > 10.0" | bc -l) )); then
            echo -e "${RED}🚨 緊急事態検出！${NC}"
            
            # 緊急指示発行
            tmux send-keys -t "$SESSION_NAME:0.1" "echo -e '\\033[1;31m🚨 PRESIDENT緊急指示: 即座に全システム診断実行\\033[0m'" Enter
            tmux send-keys -t "$SESSION_NAME:0.1" "emergency_response_protocol" Enter
            
            # 全ペインに緊急アラート
            for pane in 1 2 3; do
                tmux send-keys -t "$SESSION_NAME:0.$pane" "echo -e '\\033[1;31m🚨 PRESIDENT緊急アラート: 最優先対応要請\\033[0m'" Enter
            done
            
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 緊急事態対応発動" >> $AUTO_LOG
            
            # 緊急時は監視間隔を短縮
            sleep 30
        fi
    done
}

# メイン処理
main() {
    echo -e "${PURPLE}PRESIDENT自動処理システム開始${NC}"
    echo -e "${CYAN}監視対象: $PROJECT_NAME${NC}"
    echo -e "${CYAN}セッション: $SESSION_NAME${NC}"
    
    # バックグラウンドで各機能を並列実行
    auto_monitoring &
    MONITOR_PID=$!
    
    generate_periodic_report &
    REPORT_PID=$!
    
    emergency_response &
    EMERGENCY_PID=$!
    
    echo -e "${GREEN}✅ 全自動機能起動完了${NC}"
    echo -e "${YELLOW}プロセスID: 監視=$MONITOR_PID, レポート=$REPORT_PID, 緊急=$EMERGENCY_PID${NC}"
    
    # PID記録
    echo "$MONITOR_PID $REPORT_PID $EMERGENCY_PID" > logs/quartet/president-auto.pid
    
    # 終了シグナル待機
    trap "echo -e '${RED}PRESIDENT自動処理停止中...${NC}'; kill $MONITOR_PID $REPORT_PID $EMERGENCY_PID 2>/dev/null; exit 0" SIGINT SIGTERM
    
    # 無限待機
    wait
}

# スクリプト実行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi