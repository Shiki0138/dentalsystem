#!/bin/bash

# AI間分析結果送信スクリプト
# 各AIエージェントがPRESIDENTに分析結果を送信

PROJECT_NAME=${1:-dentalsystem}
FROM_AI=${2:-unknown}
ANALYSIS_TYPE=${3:-general}
MESSAGE=${4:-"分析結果"}

if [ $# -lt 4 ]; then
    echo "使用方法: $0 [プロジェクト名] [送信元AI] [分析タイプ] [メッセージ]"
    echo ""
    echo "例:"
    echo "  $0 dentalsystem claude_code implementation \"実装エラーの原因は...\""
    echo "  $0 dentalsystem gemini_cli environment \"環境設定の問題は...\""
    echo "  $0 dentalsystem codex_cli code_quality \"コード品質の改善点は...\""
    exit 1
fi

# タイムスタンプ付きログ記録
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="analysis_reports/${PROJECT_NAME}_ai_analysis.log"

# ログディレクトリ作成
mkdir -p analysis_reports

# 分析結果をログに記録
cat >> "$LOG_FILE" << EOF
[$TIMESTAMP] [$ANALYSIS_TYPE] [$FROM_AI] 
分析結果: $MESSAGE

EOF

# PRESIDENTペインのメイン（ペイン0）にメッセージ送信
tmux send-keys -t ${PROJECT_NAME}_president:main.0 "" C-m
tmux send-keys -t ${PROJECT_NAME}_president:main.0 "echo '📨 [$FROM_AI] 分析報告受信: $ANALYSIS_TYPE'" C-m
tmux send-keys -t ${PROJECT_NAME}_president:main.0 "echo '$MESSAGE'" C-m

# 分析レポート統合ファイル更新
REPORT_FILE="analysis_reports/${PROJECT_NAME}_integrated_report.md"

# レポートファイル初期化（初回のみ）
if [ ! -f "$REPORT_FILE" ]; then
    cat > "$REPORT_FILE" << EOF
# 🤖 AI Trio Analysis Report - $PROJECT_NAME

## 📊 分析概要
複数AIエージェントによる協調エラー解析システムの統合レポート

## 🎯 参加エージェント
- **PRESIDENT**: 統括・実行・最終決定
- **Claude Code**: 実装・技術詳細分析
- **Gemini CLI**: システム環境・設定分析  
- **Codex CLI**: コード品質・最適化分析

---

EOF
fi

# 新しい分析結果を追加
cat >> "$REPORT_FILE" << EOF
## [$TIMESTAMP] $FROM_AI - $ANALYSIS_TYPE

$MESSAGE

---

EOF

echo "✅ 分析結果をPRESIDENTに送信完了"
echo "📄 ログファイル: $LOG_FILE"
echo "📋 統合レポート: $REPORT_FILE"