#!/bin/bash
# シンプルなシステム起動スクリプト

PROJECT_NAME=${1:-dentalsystem}

# カラー定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Dental System 起動 ===${NC}"
echo "プロジェクト: $PROJECT_NAME"
echo ""

# 1. エージェントセットアップ
echo -e "${GREEN}1. エージェント起動中...${NC}"
./setup-agents.sh $PROJECT_NAME
echo ""

# 2. プレジデントセットアップ
echo -e "${GREEN}2. プレジデント起動中...${NC}"
./setup-president.sh $PROJECT_NAME
echo ""

echo -e "${GREEN}✅ システム起動完了！${NC}"
echo ""
echo "📋 起動内容:"
echo "  - エージェント（6ペイン）: boss1 + worker1-5"
echo "  - プレジデント（1ペイン）: 統括責任者"
echo "  - 常時監視システム: 5分間隔でboss1に通知"
echo ""
echo "🔗 セッション確認:"
echo "  tmux attach-session -t ${PROJECT_NAME}_multiagent"
echo "  tmux attach-session -t ${PROJECT_NAME}_president"
echo ""
echo "📧 メッセージ送信:"
echo "  ./agent-send.sh $PROJECT_NAME [エージェント名] \"メッセージ\""