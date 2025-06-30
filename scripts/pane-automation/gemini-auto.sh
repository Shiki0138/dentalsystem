#!/bin/bash

# ==================================================
# Gemini CLI自動処理スクリプト
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

echo -e "${BLUE}🧠 Gemini CLI自動処理システム起動${NC}"

# ログファイル設定
AUTO_LOG="logs/quartet/gemini-auto-$(date '+%Y%m%d_%H%M%S').log"
mkdir -p logs/quartet

# 環境変数設定
export PANE_ROLE="GEMINI_CLI"
export AI_TYPE="gemini_assistant"
export PROJECT_NAME=$PROJECT_NAME

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Gemini CLI自動処理開始" >> $AUTO_LOG

# Worker状況分析
analyze_worker_status() {
    echo -e "${BLUE}🔍 Worker状況分析開始${NC}"
    
    local analysis_result=""
    local worker_count=$(ps aux | grep -c "worker" | head -1)
    local worker_processes=$(ps aux | grep "worker" | grep -v grep)
    
    echo -e "${CYAN}Worker分析中...${NC}"
    sleep 2
    
    if [ "$worker_count" -lt 3 ]; then
        analysis_result="CRITICAL: Worker大幅不足 ($worker_count/5) - 即座の復旧必要"
        echo -e "${RED}$analysis_result${NC}"
    elif [ "$worker_count" -lt 5 ]; then
        analysis_result="WARNING: Worker一部停止 ($worker_count/5) - 段階的復旧推奨"
        echo -e "${YELLOW}$analysis_result${NC}"
    else
        analysis_result="NORMAL: Worker正常稼働 ($worker_count/5)"
        echo -e "${GREEN}$analysis_result${NC}"
    fi
    
    # 詳細分析結果生成
    cat > logs/quartet/worker-analysis.txt << EOF
Worker状況分析結果
==================

分析日時: $(date)
Worker数: $worker_count/5

詳細状況:
$worker_processes

分析結論: $analysis_result

推奨アクション:
$([ "$worker_count" -lt 3 ] && echo "1. 緊急Worker再起動" || echo "1. 定期メンテナンス")
$([ "$worker_count" -lt 5 ] && echo "2. 部分的Worker復旧" || echo "2. 監視継続")
3. プロセス健全性チェック

リスク評価:
- システム安定性: $([ "$worker_count" -lt 3 ] && echo "高リスク" || echo "低リスク")
- パフォーマンス影響: $([ "$worker_count" -lt 4 ] && echo "中程度" || echo "軽微")
EOF
    
    # Claude Codeに報告
    tmux send-keys -t "$SESSION_NAME:0.1" "echo -e '\\033[1;34m[Gemini分析報告] $analysis_result\\033[0m'" Enter
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Worker分析完了: $analysis_result" >> $AUTO_LOG
}

# エラーパターン分析
analyze_error_patterns() {
    echo -e "${BLUE}🔍 エラーパターン分析開始${NC}"
    
    echo -e "${CYAN}エラーログ収集・解析中...${NC}"
    sleep 2
    
    # エラーパターン収集
    local error_count=$(find logs/ -name "*.log" -mmin -60 -exec grep -c "ERROR\|CRITICAL\|FATAL" {} + 2>/dev/null | awk '{sum+=$1} END {print sum}')
    local critical_count=$(find logs/ -name "*.log" -mmin -60 -exec grep -c "CRITICAL\|FATAL" {} + 2>/dev/null | awk '{sum+=$1} END {print sum}')
    
    # パターン分析実行
    local pattern_analysis=""
    if [ "$critical_count" -gt 0 ]; then
        pattern_analysis="CRITICAL: 致命的エラー検出 ($critical_count件) - システム不安定"
        echo -e "${RED}$pattern_analysis${NC}"
    elif [ "$error_count" -gt 20 ]; then
        pattern_analysis="HIGH: エラー急増パターン ($error_count件/1h) - 根本原因調査必要"
        echo -e "${YELLOW}$pattern_analysis${NC}"
    elif [ "$error_count" -gt 5 ]; then
        pattern_analysis="MEDIUM: 軽微なエラー増加 ($error_count件/1h) - 監視強化推奨"
        echo -e "${CYAN}$pattern_analysis${NC}"
    else
        pattern_analysis="NORMAL: エラー水準正常 ($error_count件/1h)"
        echo -e "${GREEN}$pattern_analysis${NC}"
    fi
    
    # エラー分類分析
    local common_errors=$(find logs/ -name "*.log" -mmin -60 -exec grep -h "ERROR\|CRITICAL" {} + 2>/dev/null | awk '{print $NF}' | sort | uniq -c | sort -nr | head -3)
    
    # 分析結果生成
    cat > logs/quartet/error-analysis.txt << EOF
エラーパターン分析結果
===================

分析日時: $(date)
対象期間: 過去1時間

エラー統計:
- 総エラー数: $error_count件
- 致命的エラー: $critical_count件

頻出エラーパターン:
$common_errors

分析結論: $pattern_analysis

根本原因推定:
$([ "$critical_count" -gt 0 ] && echo "- システムリソース枯渇" || echo "- 通常運用範囲内")
$([ "$error_count" -gt 20 ] && echo "- 設定不整合可能性" || echo "- 軽微な運用課題")

推奨対応策:
1. $([ "$critical_count" -gt 0 ] && echo "即座のシステム再起動" || echo "定期メンテナンス")
2. $([ "$error_count" -gt 10 ] && echo "設定ファイル見直し" || echo "監視継続")
3. ログローテーション実施
EOF
    
    # Claude Codeに報告
    tmux send-keys -t "$SESSION_NAME:0.1" "echo -e '\\033[1;34m[Gemini分析報告] $pattern_analysis\\033[0m'" Enter
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] エラー分析完了: $pattern_analysis" >> $AUTO_LOG
}

# システム品質分析
analyze_system_quality() {
    echo -e "${BLUE}🔍 システム品質分析開始${NC}"
    
    echo -e "${CYAN}品質指標収集・分析中...${NC}"
    sleep 3
    
    # 品質指標収集
    local git_status=$(git status --porcelain | wc -l)
    local process_count=$(ps aux | grep -E "(worker|boss|monitor)" | grep -v grep | wc -l)
    local disk_usage=$(df -h | awk 'NR==2 {print $5}' | sed 's/%//')
    local log_size=$(find logs/ -name "*.log" -exec du -sh {} + | awk '{sum+=$1} END {print sum}')
    
    # 品質評価算出
    local quality_score=100
    [ "$git_status" -gt 10 ] && quality_score=$((quality_score - 10))
    [ "$process_count" -lt 8 ] && quality_score=$((quality_score - 15))
    [ "$disk_usage" -gt 80 ] && quality_score=$((quality_score - 20))
    
    local quality_level=""
    if [ "$quality_score" -ge 90 ]; then
        quality_level="EXCELLENT: システム品質優秀 (${quality_score}点)"
        echo -e "${GREEN}$quality_level${NC}"
    elif [ "$quality_score" -ge 70 ]; then
        quality_level="GOOD: システム品質良好 (${quality_score}点)"
        echo -e "${CYAN}$quality_level${NC}"
    elif [ "$quality_score" -ge 50 ]; then
        quality_level="FAIR: システム品質要改善 (${quality_score}点)"
        echo -e "${YELLOW}$quality_level${NC}"
    else
        quality_level="POOR: システム品質深刻 (${quality_score}点)"
        echo -e "${RED}$quality_level${NC}"
    fi
    
    # 品質レポート生成
    cat > logs/quartet/quality-analysis.txt << EOF
システム品質分析結果
=================

分析日時: $(date)
品質スコア: ${quality_score}/100

品質指標詳細:
- Git状況: $git_status個の変更ファイル
- プロセス数: $process_count個
- ディスク使用率: ${disk_usage}%
- ログサイズ: ${log_size}MB

品質評価: $quality_level

改善提案:
$([ "$git_status" -gt 5 ] && echo "- Git状況整理（コミット推奨）" || echo "- Git状況良好")
$([ "$process_count" -lt 8 ] && echo "- プロセス不足（再起動推奨）" || echo "- プロセス数適正")
$([ "$disk_usage" -gt 80 ] && echo "- ディスク容量整理必要" || echo "- ディスク容量適正")

次回改善目標:
- 品質スコア: $((quality_score + 10))点以上
- 継続的監視と予防的メンテナンス
EOF
    
    # Claude Codeに報告
    tmux send-keys -t "$SESSION_NAME:0.1" "echo -e '\\033[1;34m[Gemini分析報告] $quality_level\\033[0m'" Enter
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 品質分析完了: $quality_level" >> $AUTO_LOG
}

# 緊急分析
emergency_analysis() {
    echo -e "${RED}🚨 Gemini緊急分析モード起動${NC}"
    
    echo -e "${RED}緊急事態パターン分析中...${NC}"
    sleep 1
    
    # 緊急度評価
    local critical_errors=$(find logs/ -name "*.log" -mmin -5 -exec grep -c "CRITICAL\|FATAL" {} + 2>/dev/null | awk '{sum+=$1} END {print sum}')
    local system_load=$(uptime | awk '{print $NF}' | cut -d',' -f1)
    local memory_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}' 2>/dev/null || echo "不明")
    
    local emergency_level=""
    if [ "$critical_errors" -gt 5 ] || (( $(echo "$system_load > 15.0" | bc -l 2>/dev/null || echo 0) )); then
        emergency_level="CRITICAL: システム危機的状況 - 即座の対応必要"
        echo -e "${RED}$emergency_level${NC}"
    elif [ "$critical_errors" -gt 0 ] || (( $(echo "$system_load > 10.0" | bc -l 2>/dev/null || echo 0) )); then
        emergency_level="HIGH: 高負荷状況 - 迅速な対応推奨"
        echo -e "${YELLOW}$emergency_level${NC}"
    else
        emergency_level="MODERATE: 監視継続レベル"
        echo -e "${CYAN}$emergency_level${NC}"
    fi
    
    # 緊急分析レポート
    cat > logs/quartet/emergency-analysis.txt << EOF
緊急分析結果
============

分析日時: $(date)
緊急度: $emergency_level

緊急指標:
- 致命的エラー: $critical_errors件（過去5分）
- システム負荷: $system_load
- メモリ使用率: ${memory_usage}%

即座の対応策:
$([ "$critical_errors" -gt 5 ] && echo "1. 全サービス再起動" || echo "1. 監視強化")
$([ "$critical_errors" -gt 0 ] && echo "2. エラーログ詳細確認" || echo "2. 定期チェック継続")
3. システムリソース最適化

リスク評価:
- データ損失リスク: $([ "$critical_errors" -gt 5 ] && echo "高" || echo "低")
- サービス停止リスク: $([ "$critical_errors" -gt 0 ] && echo "中" || echo "低")
EOF
    
    # Claude Codeに緊急報告
    tmux send-keys -t "$SESSION_NAME:0.1" "echo -e '\\033[1;31m🚨 [Gemini緊急分析] $emergency_level\\033[0m'" Enter
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 緊急分析完了: $emergency_level" >> $AUTO_LOG
}

# 継続的監視分析
continuous_monitoring() {
    while true; do
        sleep 180  # 3分間隔
        
        echo -e "${CYAN}[$(date '+%H:%M:%S')] Gemini継続監視中...${NC}"
        
        # 軽量な健全性チェック
        local current_errors=$(find logs/ -name "*.log" -mmin -3 -exec grep -c "ERROR" {} + 2>/dev/null | awk '{sum+=$1} END {print sum}')
        
        if [ "$current_errors" -gt 5 ]; then
            echo -e "${YELLOW}⚠️ エラー増加傾向検出 ($current_errors件/3分)${NC}"
            analyze_error_patterns
        fi
        
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 継続監視実施: $current_errors件エラー" >> $AUTO_LOG
    done
}

# メイン処理
main() {
    echo -e "${BLUE}Gemini CLI自動処理システム開始${NC}"
    echo -e "${CYAN}分析エンジンモード: 有効${NC}"
    echo -e "${CYAN}監視対象: $PROJECT_NAME${NC}"
    
    # 分析関数を環境に追加
    export -f analyze_worker_status
    export -f analyze_error_patterns
    export -f analyze_system_quality
    export -f emergency_analysis
    
    # 継続監視開始
    continuous_monitoring &
    MONITOR_PID=$!
    
    echo -e "${GREEN}✅ Gemini分析エンジン起動完了${NC}"
    echo -e "${YELLOW}プロセスID: 継続監視=$MONITOR_PID${NC}"
    
    # PID記録
    echo "$MONITOR_PID" > logs/quartet/gemini-auto.pid
    
    # 終了シグナル待機
    trap "echo -e '${RED}Gemini CLI自動処理停止中...${NC}'; kill $MONITOR_PID 2>/dev/null; exit 0" SIGINT SIGTERM
    
    # 無限待機
    wait
}

# スクリプト実行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi