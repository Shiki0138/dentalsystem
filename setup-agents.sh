#!/bin/bash
# エージェントセットアップ（6ペイン + Claude Code自動起動）

PROJECT_NAME=${1:-dentalsystem}
MULTIAGENT_SESSION="${PROJECT_NAME}_multiagent"

# カラー定義
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== エージェントセットアップ ===${NC}"
echo "プロジェクト: $PROJECT_NAME"

# 既存セッションクリーンアップ
tmux kill-session -t "$MULTIAGENT_SESSION" 2>/dev/null

# 作業ディレクトリ準備
mkdir -p ./tmp ./messages ./development

# 完了ファイルクリア
rm -f ./tmp/worker*_done.txt 2>/dev/null

# multiagentセッション作成（6ペイン）
echo -e "${GREEN}エージェントセッション作成中...${NC}"
tmux new-session -d -s "$MULTIAGENT_SESSION" -n "agents"

# 3x2グリッド作成
tmux split-window -v -t "${MULTIAGENT_SESSION}:0"
tmux select-layout -t "${MULTIAGENT_SESSION}:0" even-vertical
tmux select-pane -t "${MULTIAGENT_SESSION}:0.0"
tmux split-window -h
tmux split-window -h
tmux select-pane -t "${MULTIAGENT_SESSION}:0.3"
tmux split-window -h
tmux split-window -h
tmux select-layout -t "${MULTIAGENT_SESSION}:0" tiled

# 各ペインにエージェント名設定
PANE_TITLES=("boss1" "worker1" "worker2" "worker3" "worker4" "worker5")
for i in {0..5}; do
    tmux send-keys -t "${MULTIAGENT_SESSION}:0.$i" "cd $(pwd)" C-m
    tmux send-keys -t "${MULTIAGENT_SESSION}:0.$i" "echo '=== ${PANE_TITLES[$i]} エージェント ===' && echo 'プロジェクト: $PROJECT_NAME'" C-m
done

# Claude Code自動起動
echo -e "${GREEN}Claude Code起動中...${NC}"
for i in {0..5}; do
    tmux send-keys -t "${MULTIAGENT_SESSION}:0.$i" 'claude --dangerously-skip-permissions' C-m
    sleep 0.5
done

# 環境変数保存
echo "export PROJECT_NAME=\"$PROJECT_NAME\"" > .env_${PROJECT_NAME}
echo "export MULTIAGENT_SESSION=\"$MULTIAGENT_SESSION\"" >> .env_${PROJECT_NAME}

echo -e "${GREEN}✅ エージェントセットアップ完了！${NC}"
echo ""
echo "セッション確認: tmux attach-session -t $MULTIAGENT_SESSION"
echo ""
echo "📋 エージェント構成:"
echo "  - boss1: チームリーダー"
echo "  - worker1-5: 実行担当者"