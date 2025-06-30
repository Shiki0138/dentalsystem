#!/bin/bash

# ==================================================
# CLI Quartet Setup - 4分割ペイン自動起動システム
# ==================================================

PROJECT_NAME=${1:-dentalsystem}
CONFIG_FILE="config/cli-quartet-config.yaml"

# カラー設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${PURPLE}===================================================${NC}"
echo -e "${PURPLE}    CLI Quartet 4分割ペイン起動システム${NC}"
echo -e "${PURPLE}===================================================${NC}"

# セッション名設定
SESSION_NAME="${PROJECT_NAME}_quartet"

# 既存セッションのチェックと削除
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo -e "${YELLOW}既存セッション '$SESSION_NAME' を削除中...${NC}"
    tmux kill-session -t "$SESSION_NAME"
    sleep 1
fi

# ログディレクトリ作成
mkdir -p logs/quartet

# 新しいセッション作成（4分割）
echo -e "${BLUE}新しいセッション '$SESSION_NAME' を作成中...${NC}"
tmux new-session -d -s "$SESSION_NAME" -n "CLI_Quartet"

# 4分割レイアウト設定
echo -e "${BLUE}4分割レイアウトを設定中...${NC}"

# ペイン分割
tmux split-window -h -t "$SESSION_NAME:0"     # 縦分割（左右）
tmux split-window -v -t "$SESSION_NAME:0.0"   # 左側を横分割
tmux split-window -v -t "$SESSION_NAME:0.2"   # 右側を横分割

# レイアウト調整（均等な4分割）
tmux select-layout -t "$SESSION_NAME:0" tiled

# ペイン設定とコマンド実行
echo -e "${GREEN}各ペインを設定中...${NC}"

# ペイン0: PRESIDENT（左上）
tmux send-keys -t "$SESSION_NAME:0.0" "clear" Enter
tmux send-keys -t "$SESSION_NAME:0.0" "export PANE_ROLE=PRESIDENT" Enter
tmux send-keys -t "$SESSION_NAME:0.0" "export AI_TYPE=claude_president" Enter
tmux send-keys -t "$SESSION_NAME:0.0" "export PROJECT_NAME=$PROJECT_NAME" Enter
tmux send-keys -t "$SESSION_NAME:0.0" "echo -e '\\033[1;35m👑 PRESIDENT ペイン起動完了\\033[0m'" Enter
tmux send-keys -t "$SESSION_NAME:0.0" "echo -e '\\033[0;36m役割: 統括責任者・指示管理\\033[0m'" Enter
tmux send-keys -t "$SESSION_NAME:0.0" "echo -e '\\033[0;33m待機中: 指示をお待ちしています\\033[0m'" Enter

# ペイン1: CLAUDE_CODE（右上）
tmux send-keys -t "$SESSION_NAME:0.1" "clear" Enter
tmux send-keys -t "$SESSION_NAME:0.1" "export PANE_ROLE=CLAUDE_CODE" Enter
tmux send-keys -t "$SESSION_NAME:0.1" "export AI_TYPE=claude_code" Enter
tmux send-keys -t "$SESSION_NAME:0.1" "export PROJECT_NAME=$PROJECT_NAME" Enter
tmux send-keys -t "$SESSION_NAME:0.1" "export LEADER_MODE=true" Enter
tmux send-keys -t "$SESSION_NAME:0.1" "echo -e '\\033[1;32m🤖 Claude Code ペイン起動完了 - リーダーモード\\033[0m'" Enter
tmux send-keys -t "$SESSION_NAME:0.1" "echo -e '\\033[0;36m役割: リーダー・メインシステム\\033[0m'" Enter
tmux send-keys -t "$SESSION_NAME:0.1" "echo -e '\\033[0;33mリーダー準備完了: チーム連携待機中\\033[0m'" Enter

# ペイン2: GEMINI_CLI（左下）
tmux send-keys -t "$SESSION_NAME:0.2" "clear" Enter
tmux send-keys -t "$SESSION_NAME:0.2" "export PANE_ROLE=GEMINI_CLI" Enter
tmux send-keys -t "$SESSION_NAME:0.2" "export AI_TYPE=gemini_assistant" Enter
tmux send-keys -t "$SESSION_NAME:0.2" "export PROJECT_NAME=$PROJECT_NAME" Enter
tmux send-keys -t "$SESSION_NAME:0.2" "echo -e '\\033[1;34m🧠 Gemini CLI ペイン起動完了 - 解析モード\\033[0m'" Enter
tmux send-keys -t "$SESSION_NAME:0.2" "echo -e '\\033[0;36m役割: 推論エンジン・解析担当\\033[0m'" Enter
tmux send-keys -t "$SESSION_NAME:0.2" "echo -e '\\033[0;33m解析エンジン準備完了: Claude Code指示待ち\\033[0m'" Enter

# ペイン3: CODEX_CLI（右下）
tmux send-keys -t "$SESSION_NAME:0.3" "clear" Enter
tmux send-keys -t "$SESSION_NAME:0.3" "export PANE_ROLE=CODEX_CLI" Enter
tmux send-keys -t "$SESSION_NAME:0.3" "export AI_TYPE=codex_assistant" Enter
tmux send-keys -t "$SESSION_NAME:0.3" "export PROJECT_NAME=$PROJECT_NAME" Enter
tmux send-keys -t "$SESSION_NAME:0.3" "echo -e '\\033[1;33m⚡ Codex CLI ペイン起動完了 - 生成モード\\033[0m'" Enter
tmux send-keys -t "$SESSION_NAME:0.3" "echo -e '\\033[0;36m役割: コード生成・自動化担当\\033[0m'" Enter
tmux send-keys -t "$SESSION_NAME:0.3" "echo -e '\\033[0;33m生成エンジン準備完了: Claude Code指示待ち\\033[0m'" Enter

# 通信用ヘルパー関数を各ペインに設定
echo -e "${BLUE}通信機能を設定中...${NC}"

# 全ペインに共通の通信関数を設定
for pane in 0 1 2 3; do
    tmux send-keys -t "$SESSION_NAME:0.$pane" "
# Quartet通信関数
quartet_send() {
    local target_pane=\$1
    local message=\$2
    local timestamp=\$(date '+%Y-%m-%d %H:%M:%S')
    echo \"[\$timestamp] [\$PANE_ROLE→\$target_pane] \$message\" >> logs/quartet-communication.log
    tmux send-keys -t \"$SESSION_NAME:0.\$target_pane\" \"echo -e '\\\\033[0;32m[FROM \$PANE_ROLE]: \$message\\\\033[0m'\" Enter
}

# クイック通信関数
to_president() { quartet_send 0 \"\$1\"; }
to_claude() { quartet_send 1 \"\$1\"; }
to_gemini() { quartet_send 2 \"\$1\"; }
to_codex() { quartet_send 3 \"\$1\"; }
" Enter
done

# 連携テスト機能の設定
echo -e "${BLUE}連携テスト機能を設定中...${NC}"

# PRESIDENT（ペイン0）に指示送信機能を設定
tmux send-keys -t "$SESSION_NAME:0.0" "
# PRESIDENT指示機能
issue_directive() {
    local directive=\$1
    echo -e '\\033[1;35m[PRESIDENT指示] \$directive\\033[0m'
    to_claude \"PRESIDENT指示: \$directive\"
    echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] [PRESIDENT] 指示発行: \$directive\" >> logs/quartet-communication.log
}

# エラー対応指示のサンプル
error_response_directive() {
    issue_directive \"エラー対応開始 - Claude Codeがリーダーとして連携開始\"
}
" Enter

# CLAUDE_CODE（ペイン1）にリーダー機能を設定
tmux send-keys -t "$SESSION_NAME:0.1" "
# Claude Codeリーダー機能
coordinate_team() {
    local task=\$1
    echo -e '\\033[1;32m[CLAUDE LEADER] チーム連携開始: \$task\\033[0m'
    to_gemini \"分析要請: \$task\"
    to_codex \"生成要請: \$task\"
    echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] [CLAUDE_LEADER] チーム連携: \$task\" >> logs/quartet-communication.log
}

# エラー対応連携
error_recovery_lead() {
    coordinate_team \"エラー分析と解決策生成\"
    echo -e '\\033[0;33mGeminiとCodexからの報告を待機中...\\033[0m'
}
" Enter

# GEMINI_CLI（ペイン2）に分析機能を設定
tmux send-keys -t "$SESSION_NAME:0.2" "
# Gemini分析機能
analyze_and_report() {
    local analysis_target=\$1
    echo -e '\\033[1;34m[GEMINI分析] \$analysis_target の分析開始\\033[0m'
    # 分析シミュレート
    sleep 2
    echo -e '\\033[0;36m分析結果: パターン検出完了\\033[0m'
    to_claude \"分析完了: \$analysis_target - 推奨アクション提供\"
    echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] [GEMINI] 分析完了: \$analysis_target\" >> logs/quartet-communication.log
}
" Enter

# CODEX_CLI（ペイン3）に生成機能を設定
tmux send-keys -t "$SESSION_NAME:0.3" "
# Codex生成機能
generate_and_report() {
    local generation_target=\$1
    echo -e '\\033[1;33m[CODEX生成] \$generation_target の生成開始\\033[0m'
    # 生成シミュレート
    sleep 2
    echo -e '\\033[0;36m生成結果: 自動化スクリプト作成完了\\033[0m'
    to_claude \"生成完了: \$generation_target - 実行可能解決策提供\"
    echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] [CODEX] 生成完了: \$generation_target\" >> logs/quartet-communication.log
}
" Enter

# セッション情報保存
echo -e "${BLUE}セッション情報を保存中...${NC}"
cat > logs/quartet/session-info.txt << EOF
CLI Quartet セッション情報
========================

セッション名: $SESSION_NAME
作成日時: $(date '+%Y-%m-%d %H:%M:%S')
プロジェクト: $PROJECT_NAME

ペイン構成:
- ペイン0: PRESIDENT (左上) - 統括責任者
- ペイン1: CLAUDE_CODE (右上) - リーダー・メインシステム
- ペイン2: GEMINI_CLI (左下) - 推論エンジン・解析担当
- ペイン3: CODEX_CLI (右下) - コード生成・自動化担当

接続コマンド:
tmux attach-session -t $SESSION_NAME

ペイン間移動:
Ctrl+b → q → [ペイン番号]

離脱:
Ctrl+b → d
EOF

# 起動完了メッセージ
echo -e "\n${GREEN}===================================================${NC}"
echo -e "${GREEN}    CLI Quartet 起動完了${NC}"
echo -e "${GREEN}===================================================${NC}"
echo -e "${CYAN}セッション名: $SESSION_NAME${NC}"
echo -e "${CYAN}接続コマンド: tmux attach-session -t $SESSION_NAME${NC}"
echo -e "${YELLOW}各ペインの役割:${NC}"
echo -e "  ${PURPLE}👑 ペイン0: PRESIDENT${NC} - 統括責任者"
echo -e "  ${GREEN}🤖 ペイン1: CLAUDE_CODE${NC} - リーダー・メインシステム"
echo -e "  ${BLUE}🧠 ペイン2: GEMINI_CLI${NC} - 推論エンジン・解析担当"
echo -e "  ${YELLOW}⚡ ペイン3: CODEX_CLI${NC} - コード生成・自動化担当"

echo -e "\n${YELLOW}エラー対応テスト:${NC}"
echo -e "  PRESIDENT ペインで: ${CYAN}error_response_directive${NC}"
echo -e "  CLAUDE ペインで: ${CYAN}error_recovery_lead${NC}"

echo -e "\n${YELLOW}通信テスト:${NC}"
echo -e "  任意のペインで: ${CYAN}to_[target] \"メッセージ\"${NC}"
echo -e "  例: ${CYAN}to_claude \"テストメッセージ\"${NC}"

# 自動接続（オプション）
if [[ "$2" == "--attach" ]]; then
    echo -e "\n${GREEN}セッションに自動接続中...${NC}"
    tmux attach-session -t "$SESSION_NAME"
fi