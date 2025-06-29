#!/bin/bash

# 🎯 ClaudeAuto 統合管理システム
# 複数の.shファイルを統合し、シンプルで分かりやすい操作を提供

echo "================================================"
echo " 🎯 ClaudeAuto 統合管理システム"
echo "================================================"

PROJECT_NAME="$1"
COMMAND="$2"

# 使用方法表示
show_usage() {
    echo ""
    echo "🚀 ClaudeAuto 統合管理システム - 使用方法"
    echo "============================================"
    echo ""
    echo "基本コマンド:"
    echo "  ./claude-auto-manager.sh [プロジェクト名] [コマンド]"
    echo ""
    echo "📋 利用可能なコマンド:"
    echo ""
    echo "🏗️  プロジェクト管理:"
    echo "  setup                プロジェクト初期設定（全自動化システム起動）"
    echo "  resume              作業再開（シャットダウン後の復旧）"
    echo "  status              プロジェクト全体の状況確認"
    echo "  clean               プロジェクトのクリーンアップ"
    echo ""
    echo "👑 AI システム:"
    echo "  trinity             Trinity AI System 起動（PRESIDENT + Gemini + Codex）"
    echo "  trinity-status      Trinity AI の状態確認"
    echo "  advisors            マルチAI補佐官システム起動"
    echo ""
    echo "🔍 監視・自動化:"
    echo "  monitor-start       進捗監視システム開始"
    echo "  monitor-stop        進捗監視システム停止"
    echo "  monitor-status      監視システム状況確認"
    echo "  auto-check          自動エラーチェック実行"
    echo ""
    echo "🎯 モデル・品質管理:"
    echo "  switch-mode [mode]  モデル切り替え（sonnet/opus/auto）"
    echo "  convert-spec        仕様書変換（改善提案付き）"
    echo "  error-fix           エラー修正テンプレート表示"
    echo ""
    echo "📊 レポート・分析:"
    echo "  logs                開発ログ表示"
    echo "  logs-live           開発ログリアルタイム監視"
    echo "  report              総合レポート生成"
    echo ""
    echo "💡 例:"
    echo "  ./claude-auto-manager.sh myproject setup"
    echo "  ./claude-auto-manager.sh myproject trinity"
    echo "  ./claude-auto-manager.sh myproject monitor-start"
    echo "  ./claude-auto-manager.sh myproject switch-mode auto"
    echo ""
}

# プロジェクト名チェック
check_project() {
    if [ -z "$PROJECT_NAME" ]; then
        echo "❌ エラー: プロジェクト名が指定されていません"
        show_usage
        exit 1
    fi
}

# 環境変数読み込み
load_project_env() {
    local env_file=".env_${PROJECT_NAME}"
    if [ -f "$env_file" ]; then
        source "$env_file"
        return 0
    else
        return 1
    fi
}

# プロジェクト初期設定（setup.sh統合）
cmd_setup() {
    echo "🚀 プロジェクト初期設定を開始..."
    echo "  - マルチエージェント環境構築"
    echo "  - 進捗監視システム自動起動"
    echo "  - スマートAI統合コーディネーター起動"
    echo "  - 自動モデル切り替えシステム起動"
    echo ""
    
    if [ -f "setup.sh" ]; then
        ./setup.sh "$PROJECT_NAME"
    else
        echo "❌ setup.sh が見つかりません"
        exit 1
    fi
}

# 作業再開（resume-work.sh統合）
cmd_resume() {
    echo "🔄 作業再開システムを起動..."
    
    if ! load_project_env; then
        echo "❌ プロジェクト '$PROJECT_NAME' が見つかりません"
        echo "先に setup コマンドを実行してください"
        exit 1
    fi
    
    if [ -f "resume-work.sh" ]; then
        ./resume-work.sh "$PROJECT_NAME"
    else
        echo "❌ resume-work.sh が見つかりません"
        exit 1
    fi
}

# Trinity AI System（trinity-ai-system.sh統合）
cmd_trinity() {
    echo "👑 Trinity AI System を起動..."
    
    check_project
    
    if [ -f "trinity-ai-system.sh" ]; then
        ./trinity-ai-system.sh "$PROJECT_NAME"
    else
        echo "❌ trinity-ai-system.sh が見つかりません"
        exit 1
    fi
}

# Trinity AI 状態確認
cmd_trinity_status() {
    echo "📊 Trinity AI System 状態確認..."
    
    check_project
    
    if [ -f "trinity-status.sh" ]; then
        ./trinity-status.sh "$PROJECT_NAME"
    else
        echo "⚠️ trinity-status.sh が見つかりません"
        
        # 代替確認
        TRINITY_SESSION="${PROJECT_NAME}_trinity"
        if tmux has-session -t "$TRINITY_SESSION" 2>/dev/null; then
            echo "✅ Trinity AI Session: アクティブ"
            tmux list-panes -t "$TRINITY_SESSION" -F "#{pane_index}: #{pane_title}"
        else
            echo "❌ Trinity AI Session: 非アクティブ"
        fi
    fi
}

# マルチAI補佐官システム（multi-ai-advisor.sh統合）
cmd_advisors() {
    echo "🤖 マルチAI補佐官システムを起動..."
    
    check_project
    
    if [ -f "multi-ai-advisor.sh" ]; then
        ./multi-ai-advisor.sh "$PROJECT_NAME"
    else
        echo "❌ multi-ai-advisor.sh が見つかりません"
        exit 1
    fi
}

# 進捗監視開始（start-monitoring.sh統合）
cmd_monitor_start() {
    echo "🔍 進捗監視システムを開始..."
    
    check_project
    
    if [ -f "start-monitoring.sh" ]; then
        ./start-monitoring.sh "$PROJECT_NAME"
    else
        echo "❌ start-monitoring.sh が見つかりません"
        exit 1
    fi
}

# 進捗監視停止（stop-monitoring.sh統合）
cmd_monitor_stop() {
    echo "🛑 進捗監視システムを停止..."
    
    check_project
    
    if [ -f "stop-monitoring.sh" ]; then
        ./stop-monitoring.sh "$PROJECT_NAME"
    else
        echo "❌ stop-monitoring.sh が見つかりません"
        exit 1
    fi
}

# 監視状況確認（check-monitoring.sh統合）
cmd_monitor_status() {
    echo "📊 進捗監視システム状況確認..."
    
    check_project
    
    if [ -f "check-monitoring.sh" ]; then
        ./check-monitoring.sh "$PROJECT_NAME"
    else
        echo "❌ check-monitoring.sh が見つかりません"
        exit 1
    fi
}

# 自動エラーチェック（auto-error-check.sh統合）
cmd_auto_check() {
    echo "🔍 自動エラーチェックを実行..."
    
    check_project
    
    local check_target="${3:-all}"
    
    if [ -f "auto-error-check.sh" ]; then
        ./auto-error-check.sh "$PROJECT_NAME" "$check_target"
    else
        echo "❌ auto-error-check.sh が見つかりません"
        exit 1
    fi
}

# モデル切り替え（switch-mode.sh統合）
cmd_switch_mode() {
    local mode="${3:-auto}"
    echo "🎯 Claude Code モードを $mode に切り替え..."
    
    if [ -f "switch-mode.sh" ]; then
        ./switch-mode.sh "$mode"
    else
        echo "❌ switch-mode.sh が見つかりません"
        exit 1
    fi
}

# 仕様書変換（scripts/convert_spec.sh統合）
cmd_convert_spec() {
    echo "📋 仕様書変換（改善提案付き）を実行..."
    
    check_project
    load_project_env
    
    if [ -f "scripts/convert_spec.sh" ]; then
        ./scripts/convert_spec.sh
    else
        echo "❌ scripts/convert_spec.sh が見つかりません"
        exit 1
    fi
}

# エラー修正テンプレート表示
cmd_error_fix() {
    echo "🚨 エラー修正テンプレートを表示..."
    
    if [ -f "templates/error-fix-template.md" ]; then
        cat "templates/error-fix-template.md"
    else
        echo "❌ templates/error-fix-template.md が見つかりません"
        exit 1
    fi
}

# 開発ログ表示
cmd_logs() {
    echo "📊 開発ログを表示..."
    
    if [ -f "development/development_log.txt" ]; then
        echo "📄 最新の開発ログ（最後の50行）:"
        echo "=========================================="
        tail -50 "development/development_log.txt"
    else
        echo "⚠️ 開発ログファイルが見つかりません"
    fi
}

# 開発ログリアルタイム監視
cmd_logs_live() {
    echo "📊 開発ログをリアルタイム監視中..."
    echo "終了: Ctrl+C"
    echo ""
    
    if [ -f "development/development_log.txt" ]; then
        tail -f "development/development_log.txt"
    else
        echo "⚠️ 開発ログファイルが見つかりません"
    fi
}

# プロジェクト状況確認
cmd_status() {
    echo "📊 プロジェクト全体状況確認: $PROJECT_NAME"
    echo "=========================================="
    
    check_project
    
    if ! load_project_env; then
        echo "❌ プロジェクト設定が見つかりません"
        echo "先に setup コマンドを実行してください"
        return 1
    fi
    
    echo "✅ プロジェクト設定: 確認済み"
    
    # tmuxセッション確認
    echo ""
    echo "🖥️ tmuxセッション:"
    if tmux has-session -t "$PROJECT_NAME" 2>/dev/null; then
        echo "  ✅ メインセッション: アクティブ"
        PANES=$(tmux list-panes -t "$PROJECT_NAME" | wc -l)
        echo "     ペイン数: $PANES"
    else
        echo "  ❌ メインセッション: 非アクティブ"
    fi
    
    # Trinity AI確認
    TRINITY_SESSION="${PROJECT_NAME}_trinity"
    if tmux has-session -t "$TRINITY_SESSION" 2>/dev/null; then
        echo "  ✅ Trinity AI: アクティブ"
    else
        echo "  ❌ Trinity AI: 非アクティブ"
    fi
    
    # 監視システム確認
    echo ""
    echo "🔍 監視システム:"
    PID_FILE="tmp/progress-monitor_${PROJECT_NAME}.pid"
    if [ -f "$PID_FILE" ]; then
        MONITOR_PID=$(cat "$PID_FILE")
        if kill -0 "$MONITOR_PID" 2>/dev/null; then
            echo "  ✅ 進捗監視: 稼働中 (PID: $MONITOR_PID)"
        else
            echo "  ❌ 進捗監視: 停止中"
        fi
    else
        echo "  ❌ 進捗監視: 未起動"
    fi
    
    # 開発ログ確認
    echo ""
    echo "📊 開発ログ:"
    if [ -f "development/development_log.txt" ]; then
        LOG_LINES=$(wc -l < "development/development_log.txt")
        echo "  ✅ ログファイル: $LOG_LINES 行"
        echo "  📅 最終更新: $(stat -c %y "development/development_log.txt" 2>/dev/null || stat -f %Sm "development/development_log.txt" 2>/dev/null)"
    else
        echo "  ❌ ログファイル: 見つかりません"
    fi
}

# 総合レポート生成
cmd_report() {
    echo "📋 総合レポートを生成中..."
    
    check_project
    
    local report_file="reports/project_report_${PROJECT_NAME}_$(date '+%Y%m%d_%H%M%S').md"
    mkdir -p reports
    
    cat > "$report_file" << EOF
# 📊 ClaudeAuto プロジェクトレポート

**プロジェクト名**: $PROJECT_NAME
**生成日時**: $(date '+%Y-%m-%d %H:%M:%S')

## 🎯 プロジェクト概要

$(cmd_status)

## 📈 開発ログサマリー

$(if [ -f "development/development_log.txt" ]; then
    echo "### 最新の活動（最後の20行）"
    echo '```'
    tail -20 "development/development_log.txt"
    echo '```'
else
    echo "開発ログが見つかりません"
fi)

## 🔍 監視・自動化システム状況

- 進捗監視システム: $([ -f "tmp/progress-monitor_${PROJECT_NAME}.pid" ] && echo "稼働中" || echo "停止中")
- Trinity AI System: $(tmux has-session -t "${PROJECT_NAME}_trinity" 2>/dev/null && echo "稼働中" || echo "停止中")
- メインセッション: $(tmux has-session -t "$PROJECT_NAME" 2>/dev/null && echo "稼働中" || echo "停止中")

## 💡 推奨アクション

$(if ! tmux has-session -t "$PROJECT_NAME" 2>/dev/null; then
    echo "- メインセッションを起動: ./claude-auto-manager.sh $PROJECT_NAME setup"
fi)
$(if ! tmux has-session -t "${PROJECT_NAME}_trinity" 2>/dev/null; then
    echo "- Trinity AI を起動: ./claude-auto-manager.sh $PROJECT_NAME trinity"
fi)
$(if ! [ -f "tmp/progress-monitor_${PROJECT_NAME}.pid" ]; then
    echo "- 進捗監視を開始: ./claude-auto-manager.sh $PROJECT_NAME monitor-start"
fi)

---

**レポート生成**: ClaudeAuto 統合管理システム
EOF
    
    echo "✅ レポート生成完了: $report_file"
    
    read -p "📖 今すぐレポートを表示しますか？ (y/n): " show_report
    if [[ "$show_report" =~ ^[yY]([eE][sS])?$ ]]; then
        cat "$report_file"
    fi
}

# プロジェクトクリーンアップ
cmd_clean() {
    echo "🧹 プロジェクトクリーンアップを実行..."
    
    check_project
    
    echo ""
    echo "⚠️ 以下の操作を実行します:"
    echo "  - tmuxセッションの停止"
    echo "  - 監視プロセスの停止"
    echo "  - 一時ファイルの削除"
    echo ""
    read -p "続行しますか？ (y/n): " confirm
    
    if [[ "$confirm" =~ ^[yY]([eE][sS])?$ ]]; then
        # tmuxセッション停止
        tmux kill-session -t "$PROJECT_NAME" 2>/dev/null || true
        tmux kill-session -t "${PROJECT_NAME}_trinity" 2>/dev/null || true
        tmux kill-session -t "${PROJECT_NAME}_ai_advisors" 2>/dev/null || true
        
        # 監視プロセス停止
        if [ -f "tmp/progress-monitor_${PROJECT_NAME}.pid" ]; then
            MONITOR_PID=$(cat "tmp/progress-monitor_${PROJECT_NAME}.pid")
            kill "$MONITOR_PID" 2>/dev/null || true
            rm -f "tmp/progress-monitor_${PROJECT_NAME}.pid"
        fi
        
        # 一時ファイル削除
        rm -f tmp/*_${PROJECT_NAME}.*
        rm -f tmp/worker*_done.txt
        rm -f tmp/cycle_*.txt
        
        echo "✅ クリーンアップ完了"
    else
        echo "❌ クリーンアップをキャンセルしました"
    fi
}

# メイン処理
main() {
    if [ -z "$PROJECT_NAME" ] || [ "$PROJECT_NAME" == "help" ] || [ "$PROJECT_NAME" == "--help" ]; then
        show_usage
        exit 0
    fi
    
    case "$COMMAND" in
        "setup")
            cmd_setup
            ;;
        "resume")
            cmd_resume
            ;;
        "trinity")
            cmd_trinity
            ;;
        "trinity-status")
            cmd_trinity_status
            ;;
        "advisors")
            cmd_advisors
            ;;
        "monitor-start")
            cmd_monitor_start
            ;;
        "monitor-stop")
            cmd_monitor_stop
            ;;
        "monitor-status")
            cmd_monitor_status
            ;;
        "auto-check")
            cmd_auto_check
            ;;
        "switch-mode")
            cmd_switch_mode
            ;;
        "convert-spec")
            cmd_convert_spec
            ;;
        "error-fix")
            cmd_error_fix
            ;;
        "logs")
            cmd_logs
            ;;
        "logs-live")
            cmd_logs_live
            ;;
        "status")
            cmd_status
            ;;
        "report")
            cmd_report
            ;;
        "clean")
            cmd_clean
            ;;
        *)
            echo "❌ 不明なコマンド: $COMMAND"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# 実行
main "$@"