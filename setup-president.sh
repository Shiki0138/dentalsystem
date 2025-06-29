#!/bin/bash
# プレジデントセットアップ（1ペイン + 常時監視システム起動）

PROJECT_NAME=${1:-dentalsystem}
PRESIDENT_SESSION="${PROJECT_NAME}_president"

# カラー定義
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== プレジデントセットアップ ===${NC}"
echo "プロジェクト: $PROJECT_NAME"

# 既存セッションクリーンアップ
tmux kill-session -t "$PRESIDENT_SESSION" 2>/dev/null

# presidentセッション作成（1ペインのみ）
echo -e "${GREEN}プレジデントセッション作成中...${NC}"
tmux new-session -d -s "$PRESIDENT_SESSION" -n "PRESIDENT"
tmux send-keys -t "$PRESIDENT_SESSION" "cd $(pwd)" C-m
tmux send-keys -t "$PRESIDENT_SESSION" "echo '👑 PRESIDENT セッション'" C-m
tmux send-keys -t "$PRESIDENT_SESSION" "echo 'プロジェクト統括責任者'" C-m
tmux send-keys -t "$PRESIDENT_SESSION" "echo 'プロジェクト: $PROJECT_NAME'" C-m

# Claude Code起動
echo -e "${GREEN}Claude Code起動中...${NC}"
tmux send-keys -t "$PRESIDENT_SESSION" 'claude --dangerously-skip-permissions' C-m
sleep 2

# 環境変数更新
echo "export PRESIDENT_SESSION=\"$PRESIDENT_SESSION\"" >> .env_${PROJECT_NAME}

# 常時監視システム起動（boss1向け、5分間隔）
echo -e "${GREEN}常時監視システム起動中...${NC}"

# 監視スクリプト作成
cat > "./tmp/monitor_${PROJECT_NAME}.sh" << 'EOF'
#!/bin/bash
PROJECT_NAME="$1"
MULTIAGENT_SESSION="${PROJECT_NAME}_multiagent"

while true; do
    # boss1が稼働中かチェック
    BOSS_ACTIVE=$(tmux capture-pane -t "${MULTIAGENT_SESSION}:0.0" -p | tail -20 | grep -E "(作業中|実行中|処理中)" | wc -l)
    
    if [ $BOSS_ACTIVE -eq 0 ]; then
        # boss1が非稼働の場合のみ監視実行
        WORKER_STUCK=0
        ERROR_COUNT=$(grep -i "ERROR" development/development_log.txt 2>/dev/null | tail -20 | wc -l)
        
        # worker停滞チェック
        for i in {1..5}; do
            if [ -f "./tmp/worker${i}_done.txt" ]; then
                LAST_UPDATE=$(stat -f "%m" "./tmp/worker${i}_done.txt" 2>/dev/null || stat -c "%Y" "./tmp/worker${i}_done.txt" 2>/dev/null)
                CURRENT_TIME=$(date +%s)
                DIFF=$((CURRENT_TIME - LAST_UPDATE))
                if [ $DIFF -gt 600 ]; then # 10分以上更新なし
                    WORKER_STUCK=$((WORKER_STUCK + 1))
                fi
            fi
        done
        
        # 問題があればboss1に通知
        if [ $ERROR_COUNT -ge 3 ] || [ $WORKER_STUCK -ge 2 ]; then
            tmux send-keys -t "${MULTIAGENT_SESSION}:0.0" "
[自動監視システム]
問題を検出しました:
- エラー数: $ERROR_COUNT
- 停滞Worker数: $WORKER_STUCK
対応をお願いします。" C-m
        fi
    fi
    
    # 5分待機
    sleep 300
done
EOF

chmod +x "./tmp/monitor_${PROJECT_NAME}.sh"
"./tmp/monitor_${PROJECT_NAME}.sh" "$PROJECT_NAME" > /dev/null 2>&1 &
MONITOR_PID=$!

echo "export MONITOR_PID=\"$MONITOR_PID\"" >> .env_${PROJECT_NAME}

echo -e "${GREEN}✅ プレジデントセットアップ完了！${NC}"
echo ""
echo "セッション確認: tmux attach-session -t $PRESIDENT_SESSION"
echo ""
echo "📋 起動内容:"
echo "  - PRESIDENTセッション（1ペイン）"
echo "  - Claude Code"
echo "  - 常時監視システム（5分間隔、boss1向け）"