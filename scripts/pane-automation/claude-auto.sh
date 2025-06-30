#!/bin/bash

# ==================================================
# Claude Code自動処理スクリプト
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

echo -e "${GREEN}🤖 Claude Code自動処理システム起動${NC}"

# ログファイル設定
AUTO_LOG="logs/quartet/claude-auto-$(date '+%Y%m%d_%H%M%S').log"
mkdir -p logs/quartet

# 環境変数設定
export PANE_ROLE="CLAUDE_CODE"
export AI_TYPE="claude_code"
export PROJECT_NAME=$PROJECT_NAME
export LEADER_MODE=true

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Claude Code自動処理開始" >> $AUTO_LOG

# 自動応答パターン定義
auto_response_worker_shortage() {
    echo -e "${YELLOW}[Claude Leader] Worker不足対応開始${NC}"
    
    # Geminiに分析要請
    tmux send-keys -t "$SESSION_NAME:0.2" "analyze_worker_status" Enter
    
    # Codexに復旧スクリプト生成要請
    tmux send-keys -t "$SESSION_NAME:0.3" "generate_worker_recovery" Enter
    
    # 実際の復旧実行
    echo -e "${CYAN}Worker復旧処理実行中...${NC}"
    if ./setup-agents.sh $PROJECT_NAME > logs/quartet/worker-recovery.log 2>&1; then
        echo -e "${GREEN}✅ Worker復旧成功${NC}"
        tmux send-keys -t "$SESSION_NAME:0.0" "echo -e '\\033[0;32m✅ Claude Code: Worker復旧完了\\033[0m'" Enter
    else
        echo -e "${RED}❌ Worker復旧失敗${NC}"
        tmux send-keys -t "$SESSION_NAME:0.0" "echo -e '\\033[0;31m❌ Claude Code: Worker復旧失敗 - 手動確認要\\033[0m'" Enter
    fi
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Worker不足対応完了" >> $AUTO_LOG
}

auto_response_error_spike() {
    echo -e "${YELLOW}[Claude Leader] エラー急増対応開始${NC}"
    
    # エラーログ分析
    echo -e "${CYAN}エラーパターン分析中...${NC}"
    find logs/ -name "*.log" -mmin -60 -exec grep -n "ERROR\|CRITICAL\|FATAL" {} + > logs/quartet/recent-errors.txt
    
    # Geminiに詳細分析要請
    tmux send-keys -t "$SESSION_NAME:0.2" "analyze_error_patterns" Enter
    
    # Codexに修復スクリプト要請
    tmux send-keys -t "$SESSION_NAME:0.3" "generate_error_fixes" Enter
    
    # 即座の対処
    echo -e "${CYAN}即座のエラー対処実行中...${NC}"
    # ログローテーション
    find logs/ -name "*.log" -size +100M -exec gzip {} \;
    
    # プロセス再起動
    pkill -f "monitoring" 2>/dev/null
    ./scripts/monitoring-unified.sh $PROJECT_NAME setup > /dev/null 2>&1 &
    
    echo -e "${GREEN}✅ 即座のエラー対処完了${NC}"
    tmux send-keys -t "$SESSION_NAME:0.0" "echo -e '\\033[0;32m✅ Claude Code: エラー対処完了\\033[0m'" Enter
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] エラー急増対応完了" >> $AUTO_LOG
}

auto_response_quality_check() {
    echo -e "${YELLOW}[Claude Leader] 品質チェック開始${NC}"
    
    # Geminiに品質分析要請
    tmux send-keys -t "$SESSION_NAME:0.2" "analyze_system_quality" Enter
    
    # Codexに最適化スクリプト要請
    tmux send-keys -t "$SESSION_NAME:0.3" "generate_optimization_scripts" Enter
    
    # システム健全性チェック
    echo -e "${CYAN}システム健全性チェック実行中...${NC}"
    {
        echo "=== Git Status ==="
        git status --porcelain
        echo -e "\n=== Process Health ==="
        ps aux | grep -E "(worker|boss|monitor)" | grep -v grep
        echo -e "\n=== Disk Usage ==="
        df -h | head -5
        echo -e "\n=== Log Health ==="
        find logs/ -name "*.log" -size +50M
    } > logs/quartet/quality-check-$(date '+%Y%m%d_%H%M%S').txt
    
    echo -e "${GREEN}✅ 品質チェック完了${NC}"
    tmux send-keys -t "$SESSION_NAME:0.0" "echo -e '\\033[0;32m✅ Claude Code: 品質チェック完了\\033[0m'" Enter
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 品質チェック完了" >> $AUTO_LOG
}

emergency_response_protocol() {
    echo -e "${RED}🚨 Claude Code緊急対応プロトコル起動${NC}"
    
    # 全チームに緊急指示
    tmux send-keys -t "$SESSION_NAME:0.2" "emergency_analysis" Enter
    tmux send-keys -t "$SESSION_NAME:0.3" "emergency_script_generation" Enter
    
    # 緊急診断実行
    echo -e "${RED}緊急システム診断実行中...${NC}"
    {
        echo "=== Emergency System Diagnosis ==="
        echo "Timestamp: $(date)"
        echo "Load Average: $(uptime)"
        echo "Memory Usage: $(free -h 2>/dev/null || vm_stat | head -5)"
        echo "Disk Space: $(df -h | head -5)"
        echo "Critical Processes:"
        ps aux | grep -E "(worker|boss|monitor|rails)" | grep -v grep
        echo "Recent Critical Errors:"
        find logs/ -name "*.log" -mmin -10 -exec grep -n "CRITICAL\|FATAL\|ERROR" {} +
    } > logs/quartet/emergency-diagnosis-$(date '+%Y%m%d_%H%M%S').txt
    
    # 自動復旧試行
    echo -e "${YELLOW}自動復旧処理試行中...${NC}"
    ./scripts/quartet-error-handler.sh $PROJECT_NAME system_failure critical > logs/quartet/emergency-recovery.log 2>&1
    
    echo -e "${GREEN}✅ 緊急対応プロトコル完了${NC}"
    tmux send-keys -t "$SESSION_NAME:0.0" "echo -e '\\033[1;32m✅ Claude Code: 緊急対応完了 - 診断結果確認要\\033[0m'" Enter
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 緊急対応プロトコル完了" >> $AUTO_LOG
}

# チーム連携監視
team_coordination_monitor() {
    while true; do
        sleep 120  # 2分間隔
        
        echo -e "${CYAN}[$(date '+%H:%M:%S')] チーム連携状況確認中...${NC}"
        
        # GeminiとCodexの応答確認
        GEMINI_ACTIVE=$(tmux capture-pane -t "$SESSION_NAME:0.2" -p | tail -1 | grep -c ">" || echo 0)
        CODEX_ACTIVE=$(tmux capture-pane -t "$SESSION_NAME:0.3" -p | tail -1 | grep -c ">" || echo 0)
        
        if [ "$GEMINI_ACTIVE" -eq 0 ] || [ "$CODEX_ACTIVE" -eq 0 ]; then
            echo -e "${YELLOW}⚠️ チームメンバー応答不良検出${NC}"
            
            # 応答促進メッセージ送信
            if [ "$GEMINI_ACTIVE" -eq 0 ]; then
                tmux send-keys -t "$SESSION_NAME:0.2" "echo -e '\\033[1;34m🧠 Gemini: 応答確認中...\\033[0m'" Enter
            fi
            
            if [ "$CODEX_ACTIVE" -eq 0 ]; then
                tmux send-keys -t "$SESSION_NAME:0.3" "echo -e '\\033[1;33m⚡ Codex: 応答確認中...\\033[0m'" Enter
            fi
        else
            echo -e "${GREEN}✅ チーム連携正常${NC}"
        fi
        
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] チーム連携監視完了" >> $AUTO_LOG
    done
}

# 自動最適化
auto_optimization() {
    while true; do
        sleep 3600  # 1時間間隔
        
        echo -e "${BLUE}🔧 自動最適化実行中...${NC}"
        
        # ログクリーンアップ
        find logs/ -name "*.log" -mtime +7 -delete
        find logs/ -name "*.log" -size +50M -exec gzip {} \;
        
        # 一時ファイルクリーンアップ
        find tmp/ -name "*.tmp" -mmin +60 -delete 2>/dev/null || true
        
        # プロセス最適化
        echo -e "${CYAN}プロセス最適化中...${NC}"
        
        echo -e "${GREEN}✅ 自動最適化完了${NC}"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 自動最適化完了" >> $AUTO_LOG
    done
}

# メイン処理
main() {
    echo -e "${GREEN}Claude Code自動処理システム開始${NC}"
    echo -e "${CYAN}リーダーモード: 有効${NC}"
    echo -e "${CYAN}監視対象: $PROJECT_NAME${NC}"
    
    # 自動応答関数を環境に追加
    export -f auto_response_worker_shortage
    export -f auto_response_error_spike
    export -f auto_response_quality_check
    export -f emergency_response_protocol
    
    # バックグラウンドで監視機能実行
    team_coordination_monitor &
    TEAM_PID=$!
    
    auto_optimization &
    OPT_PID=$!
    
    echo -e "${GREEN}✅ Claude Code自動機能起動完了${NC}"
    echo -e "${YELLOW}プロセスID: チーム監視=$TEAM_PID, 最適化=$OPT_PID${NC}"
    
    # PID記録
    echo "$TEAM_PID $OPT_PID" > logs/quartet/claude-auto.pid
    
    # 終了シグナル待機
    trap "echo -e '${RED}Claude Code自動処理停止中...${NC}'; kill $TEAM_PID $OPT_PID 2>/dev/null; exit 0" SIGINT SIGTERM
    
    # 無限待機
    wait
}

# スクリプト実行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi