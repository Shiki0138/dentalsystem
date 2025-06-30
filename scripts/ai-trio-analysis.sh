#!/bin/bash

# AI Trio Error Analysis System
# PRESIDENTペインを4分割してClaude/Gemini/Codex CLIで協調エラー解析

PROJECT_NAME=${1:-dentalsystem}

echo "🤖 AI Trio Error Analysis System 起動"
echo "=================================="

# PRESIDENTセッションを4分割に変更
echo "📋 PRESIDENTセッションを4分割します..."

# 既存のPRESIDENTセッションを終了
tmux kill-session -t ${PROJECT_NAME}_president 2>/dev/null || true

# 新しい4分割PRESIDENTセッションを作成
tmux new-session -d -s ${PROJECT_NAME}_president -n main

# 4分割レイアウト作成
tmux split-window -h -t ${PROJECT_NAME}_president:main
tmux split-window -v -t ${PROJECT_NAME}_president:main.0
tmux split-window -v -t ${PROJECT_NAME}_president:main.1

# 各ペインに役割を設定
tmux send-keys -t ${PROJECT_NAME}_president:main.0 "echo '🎯 PRESIDENT (統括・実行)'; export AI_ROLE=PRESIDENT" C-m
tmux send-keys -t ${PROJECT_NAME}_president:main.1 "echo '💻 Claude Code (実装分析)'; export AI_ROLE=CLAUDE_CODE" C-m
tmux send-keys -t ${PROJECT_NAME}_president:main.2 "echo '💎 Gemini CLI (環境分析)'; export AI_ROLE=GEMINI_CLI" C-m
tmux send-keys -t ${PROJECT_NAME}_president:main.3 "echo '🔧 Codex CLI (コード品質分析)'; export AI_ROLE=CODEX_CLI" C-m

# 各ペインでClaude Codeを起動
echo "🚀 各ペインでClaude Code起動中..."

# PRESIDENT (メイン統括)
tmux send-keys -t ${PROJECT_NAME}_president:main.0 "claude code" C-m

# Claude Code (実装分析担当)
tmux send-keys -t ${PROJECT_NAME}_president:main.1 "claude code" C-m

# Gemini CLI (環境分析担当) 
tmux send-keys -t ${PROJECT_NAME}_president:main.2 "claude code" C-m

# Codex CLI (コード品質分析担当)
tmux send-keys -t ${PROJECT_NAME}_president:main.3 "claude code" C-m

echo ""
echo "✅ AI Trio Analysis System セットアップ完了"
echo ""
echo "📊 アクセス方法:"
echo "  tmux attach-session -t ${PROJECT_NAME}_president"
echo ""
echo "🎯 各ペインの役割:"
echo "  ペイン0: PRESIDENT (統括・実行・最終決定)"
echo "  ペイン1: Claude Code (実装・技術詳細分析)"
echo "  ペイン2: Gemini CLI (システム環境・設定分析)"
echo "  ペイン3: Codex CLI (コード品質・最適化分析)"
echo ""
echo "🔄 ワークフロー:"
echo "  1. 各AIがそれぞれの専門分野でエラー分析"
echo "  2. 分析結果をPRESIDENTに報告"
echo "  3. PRESIDENTが統合判断して実行"
echo ""