#!/bin/bash

# ==================================================
# Quartet Automation Master Controller
# 4ペイン自動処理統合制御システム
# ==================================================

PROJECT_NAME=${1:-dentalsystem}
COMMAND=${2:-start}
CONFIG_FILE="config/quartet-automation.yaml"

# カラー設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

SESSION_NAME="${PROJECT_NAME}_quartet"
MASTER_LOG="logs/quartet/automation-master-$(date '+%Y%m%d_%H%M%S').log"

echo -e "${PURPLE}===================================================${NC}"
echo -e "${PURPLE}    Quartet Automation Master Controller${NC}"
echo -e "${PURPLE}===================================================${NC}"

# ログディレクトリ準備
mkdir -p logs/quartet

# 設定ファイル確認
check_configuration() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}❌ 設定ファイルが見つかりません: $CONFIG_FILE${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ 設定ファイル確認: $CONFIG_FILE${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Configuration loaded: $CONFIG_FILE" >> $MASTER_LOG
}

# Quartetセッション確認
check_quartet_session() {
    if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo -e "${YELLOW}⚠️ Quartetセッションが見つかりません${NC}"
        echo -e "${CYAN}自動でセッションを起動します...${NC}"
        
        if ./setup-cli-quartet.sh $PROJECT_NAME; then
            echo -e "${GREEN}✅ Quartetセッション起動完了${NC}"
            sleep 3
        else
            echo -e "${RED}❌ Quartetセッション起動失敗${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✅ Quartetセッション確認済み${NC}"
    fi
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Quartet session verified: $SESSION_NAME" >> $MASTER_LOG
}

# 各ペインの自動処理開始
start_automation() {
    echo -e "\n${BLUE}=== 自動処理システム起動開始 ===${NC}"
    
    # 各ペインに実行権限付与
    chmod +x scripts/pane-automation/*.sh
    
    # PRESIDENT自動処理起動
    echo -e "${PURPLE}👑 PRESIDENT自動処理起動中...${NC}"
    tmux send-keys -t "$SESSION_NAME:0.0" "cd $(pwd)" Enter
    tmux send-keys -t "$SESSION_NAME:0.0" "nohup ./scripts/pane-automation/president-auto.sh $PROJECT_NAME > logs/quartet/president-auto.log 2>&1 &" Enter
    tmux send-keys -t "$SESSION_NAME:0.0" "echo -e '\\033[1;35m👑 PRESIDENT自動処理起動完了\\033[0m'" Enter
    sleep 2
    
    # Claude Code自動処理起動
    echo -e "${GREEN}🤖 Claude Code自動処理起動中...${NC}"
    tmux send-keys -t "$SESSION_NAME:0.1" "cd $(pwd)" Enter
    tmux send-keys -t "$SESSION_NAME:0.1" "nohup ./scripts/pane-automation/claude-auto.sh $PROJECT_NAME > logs/quartet/claude-auto.log 2>&1 &" Enter
    tmux send-keys -t "$SESSION_NAME:0.1" "echo -e '\\033[1;32m🤖 Claude Code自動処理起動完了\\033[0m'" Enter
    sleep 2
    
    # Gemini CLI自動処理起動
    echo -e "${BLUE}🧠 Gemini CLI自動処理起動中...${NC}"
    tmux send-keys -t "$SESSION_NAME:0.2" "cd $(pwd)" Enter
    tmux send-keys -t "$SESSION_NAME:0.2" "nohup ./scripts/pane-automation/gemini-auto.sh $PROJECT_NAME > logs/quartet/gemini-auto.log 2>&1 &" Enter
    tmux send-keys -t "$SESSION_NAME:0.2" "echo -e '\\033[1;34m🧠 Gemini CLI自動処理起動完了\\033[0m'" Enter
    sleep 2
    
    # Codex CLI自動処理起動
    echo -e "${YELLOW}⚡ Codex CLI自動処理起動中...${NC}"
    tmux send-keys -t "$SESSION_NAME:0.3" "cd $(pwd)" Enter
    tmux send-keys -t "$SESSION_NAME:0.3" "nohup ./scripts/pane-automation/codex-auto.sh $PROJECT_NAME > logs/quartet/codex-auto.log 2>&1 &" Enter
    tmux send-keys -t "$SESSION_NAME:0.3" "echo -e '\\033[1;33m⚡ Codex CLI自動処理起動完了\\033[0m'" Enter
    sleep 2
    
    echo -e "${GREEN}✅ 全ペイン自動処理起動完了${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] All pane automation started" >> $MASTER_LOG
}

# 自動処理停止
stop_automation() {
    echo -e "\n${YELLOW}=== 自動処理システム停止開始 ===${NC}"
    
    # 各ペインの自動処理停止
    echo -e "${PURPLE}👑 PRESIDENT自動処理停止中...${NC}"
    if [[ -f "logs/quartet/president-auto.pid" ]]; then
        PIDS=$(cat logs/quartet/president-auto.pid)
        kill $PIDS 2>/dev/null || true
        rm -f logs/quartet/president-auto.pid
    fi
    tmux send-keys -t "$SESSION_NAME:0.0" "echo -e '\\033[1;35m👑 PRESIDENT自動処理停止完了\\033[0m'" Enter
    
    echo -e "${GREEN}🤖 Claude Code自動処理停止中...${NC}"
    if [[ -f "logs/quartet/claude-auto.pid" ]]; then
        PIDS=$(cat logs/quartet/claude-auto.pid)
        kill $PIDS 2>/dev/null || true
        rm -f logs/quartet/claude-auto.pid
    fi
    tmux send-keys -t "$SESSION_NAME:0.1" "echo -e '\\033[1;32m🤖 Claude Code自動処理停止完了\\033[0m'" Enter
    
    echo -e "${BLUE}🧠 Gemini CLI自動処理停止中...${NC}"
    if [[ -f "logs/quartet/gemini-auto.pid" ]]; then
        PIDS=$(cat logs/quartet/gemini-auto.pid)
        kill $PIDS 2>/dev/null || true
        rm -f logs/quartet/gemini-auto.pid
    fi
    tmux send-keys -t "$SESSION_NAME:0.2" "echo -e '\\033[1;34m🧠 Gemini CLI自動処理停止完了\\033[0m'" Enter
    
    echo -e "${YELLOW}⚡ Codex CLI自動処理停止中...${NC}"
    if [[ -f "logs/quartet/codex-auto.pid" ]]; then
        PIDS=$(cat logs/quartet/codex-auto.pid)
        kill $PIDS 2>/dev/null || true
        rm -f logs/quartet/codex-auto.pid
    fi
    tmux send-keys -t "$SESSION_NAME:0.3" "echo -e '\\033[1;33m⚡ Codex CLI自動処理停止完了\\033[0m'" Enter
    
    echo -e "${GREEN}✅ 全ペイン自動処理停止完了${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] All pane automation stopped" >> $MASTER_LOG
}

# 自動処理状況確認
status_automation() {
    echo -e "\n${CYAN}=== 自動処理システム状況 ===${NC}"
    
    local status_report="logs/quartet/automation-status-$(date '+%Y%m%d_%H%M%S').txt"
    
    {
        echo "=== Quartet Automation Status Report ==="
        echo "Date: $(date)"
        echo "Project: $PROJECT_NAME"
        echo "Session: $SESSION_NAME"
        echo ""
        
        echo "=== Session Status ==="
        if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
            echo "Quartet Session: ACTIVE"
            tmux list-panes -t "$SESSION_NAME" -F "Pane #{pane_index}: #{pane_current_command}"
        else
            echo "Quartet Session: INACTIVE"
        fi
        echo ""
        
        echo "=== Automation Processes ==="
        echo "PRESIDENT Auto:"
        if [[ -f "logs/quartet/president-auto.pid" ]]; then
            PIDS=$(cat logs/quartet/president-auto.pid)
            ps -p $PIDS > /dev/null 2>&1 && echo "  Status: RUNNING (PIDs: $PIDS)" || echo "  Status: STOPPED"
        else
            echo "  Status: NOT STARTED"
        fi
        
        echo "Claude Code Auto:"
        if [[ -f "logs/quartet/claude-auto.pid" ]]; then
            PIDS=$(cat logs/quartet/claude-auto.pid)
            ps -p $PIDS > /dev/null 2>&1 && echo "  Status: RUNNING (PIDs: $PIDS)" || echo "  Status: STOPPED"
        else
            echo "  Status: NOT STARTED"
        fi
        
        echo "Gemini CLI Auto:"
        if [[ -f "logs/quartet/gemini-auto.pid" ]]; then
            PIDS=$(cat logs/quartet/gemini-auto.pid)
            ps -p $PIDS > /dev/null 2>&1 && echo "  Status: RUNNING (PIDs: $PIDS)" || echo "  Status: STOPPED"
        else
            echo "  Status: NOT STARTED"
        fi
        
        echo "Codex CLI Auto:"
        if [[ -f "logs/quartet/codex-auto.pid" ]]; then
            PIDS=$(cat logs/quartet/codex-auto.pid)
            ps -p $PIDS > /dev/null 2>&1 && echo "  Status: RUNNING (PIDs: $PIDS)" || echo "  Status: STOPPED"
        else
            echo "  Status: NOT STARTED"
        fi
        
        echo ""
        echo "=== Recent Logs ==="
        echo "Latest automation activities:"
        find logs/quartet/ -name "*.log" -mmin -30 -exec tail -3 {} + 2>/dev/null | tail -10
        
        echo ""
        echo "=== Generated Scripts ==="
        find logs/quartet/ -name "*.sh" -mmin -60 -ls 2>/dev/null | head -5
        
    } > $status_report
    
    # 画面に状況表示
    cat $status_report
    
    echo -e "\n${CYAN}📊 詳細レポート: $status_report${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Status report generated: $status_report" >> $MASTER_LOG
}

# 自動テスト実行
test_automation() {
    echo -e "\n${BLUE}=== 自動処理テスト開始 ===${NC}"
    
    # 各ペインに基本機能テスト送信
    echo -e "${PURPLE}👑 PRESIDENTテスト中...${NC}"
    tmux send-keys -t "$SESSION_NAME:0.0" "echo -e '\\033[1;35m[TEST] PRESIDENT自動処理テスト\\033[0m'" Enter
    
    echo -e "${GREEN}🤖 Claude Codeテスト中...${NC}"
    tmux send-keys -t "$SESSION_NAME:0.1" "echo -e '\\033[1;32m[TEST] Claude Code自動処理テスト\\033[0m'" Enter
    
    echo -e "${BLUE}🧠 Gemini CLIテスト中...${NC}"
    tmux send-keys -t "$SESSION_NAME:0.2" "analyze_worker_status" Enter
    
    echo -e "${YELLOW}⚡ Codex CLIテスト中...${NC}"
    tmux send-keys -t "$SESSION_NAME:0.3" "generate_optimization_scripts" Enter
    
    sleep 5
    
    # テスト結果確認
    echo -e "${GREEN}✅ 自動処理テスト完了${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Automation test completed" >> $MASTER_LOG
}

# 使用方法表示
show_usage() {
    echo -e "${CYAN}使用方法:${NC}"
    echo -e "  ${YELLOW}./quartet-automation-master.sh [プロジェクト名] [コマンド]${NC}"
    echo ""
    echo -e "${CYAN}利用可能なコマンド:${NC}"
    echo -e "  ${GREEN}start${NC}    - 自動処理システム開始"
    echo -e "  ${RED}stop${NC}     - 自動処理システム停止"
    echo -e "  ${BLUE}status${NC}   - 自動処理システム状況確認"
    echo -e "  ${YELLOW}test${NC}     - 自動処理システムテスト"
    echo -e "  ${CYAN}restart${NC}  - 自動処理システム再起動"
    echo ""
    echo -e "${CYAN}例:${NC}"
    echo -e "  ${YELLOW}./quartet-automation-master.sh dentalsystem start${NC}"
    echo -e "  ${YELLOW}./quartet-automation-master.sh dentalsystem status${NC}"
}

# メイン処理
main() {
    case "$COMMAND" in
        "start")
            check_configuration
            check_quartet_session
            start_automation
            echo -e "\n${GREEN}🎉 Quartet自動処理システム起動完了${NC}"
            echo -e "${CYAN}接続: tmux attach-session -t $SESSION_NAME${NC}"
            ;;
        "stop")
            check_configuration
            stop_automation
            echo -e "\n${GREEN}🛑 Quartet自動処理システム停止完了${NC}"
            ;;
        "status")
            check_configuration
            status_automation
            ;;
        "test")
            check_configuration
            check_quartet_session
            test_automation
            ;;
        "restart")
            check_configuration
            stop_automation
            sleep 3
            start_automation
            echo -e "\n${GREEN}🔄 Quartet自動処理システム再起動完了${NC}"
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Master controller command: $COMMAND completed" >> $MASTER_LOG
}

# 実行
main "$@"