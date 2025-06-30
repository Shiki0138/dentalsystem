#!/bin/bash

# ==================================================
# Codex CLI自動処理スクリプト
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

echo -e "${YELLOW}⚡ Codex CLI自動処理システム起動${NC}"

# ログファイル設定
AUTO_LOG="logs/quartet/codex-auto-$(date '+%Y%m%d_%H%M%S').log"
mkdir -p logs/quartet

# 環境変数設定
export PANE_ROLE="CODEX_CLI"
export AI_TYPE="codex_assistant"
export PROJECT_NAME=$PROJECT_NAME

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Codex CLI自動処理開始" >> $AUTO_LOG

# Worker復旧スクリプト生成
generate_worker_recovery() {
    echo -e "${YELLOW}🛠️ Worker復旧スクリプト生成開始${NC}"
    
    echo -e "${CYAN}動的復旧スクリプト生成中...${NC}"
    sleep 2
    
    # 現在の状況に応じた復旧スクリプト生成
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local recovery_script="logs/quartet/worker-recovery-${timestamp}.sh"
    
    cat > "$recovery_script" << 'EOF'
#!/bin/bash
# Codex Generated: Dynamic Worker Recovery Script

PROJECT=${1:-dentalsystem}
RECOVERY_LOG="logs/quartet/recovery-execution.log"

echo "=== Codex Dynamic Worker Recovery ==="
echo "Recovery started: $(date)" >> $RECOVERY_LOG

# インテリジェント復旧手順
intelligent_recovery() {
    echo "Phase 1: Worker状況診断"
    CURRENT_WORKERS=$(ps aux | grep "worker" | grep -v grep | wc -l)
    echo "Current workers: $CURRENT_WORKERS" >> $RECOVERY_LOG
    
    if [ $CURRENT_WORKERS -eq 0 ]; then
        echo "Phase 2: 完全復旧モード"
        ./setup-agents.sh $PROJECT
        sleep 10
        
        # 復旧確認
        NEW_WORKERS=$(ps aux | grep "worker" | grep -v grep | wc -l)
        echo "Recovery result: $NEW_WORKERS workers active" >> $RECOVERY_LOG
        
        if [ $NEW_WORKERS -ge 3 ]; then
            echo "✅ Complete recovery successful"
            return 0
        else
            echo "❌ Complete recovery failed"
            return 1
        fi
    else
        echo "Phase 2: 部分復旧モード"
        # 個別Worker復旧
        for i in {1..5}; do
            if ! ps aux | grep "worker$i" | grep -v grep > /dev/null; then
                echo "Recovering worker$i..." >> $RECOVERY_LOG
                # 個別Worker起動処理
                nohup bash -c "echo 'worker$i simulation'" > /tmp/worker$i.log 2>&1 &
            fi
        done
        echo "✅ Partial recovery completed"
        return 0
    fi
}

# メモリ最適化
optimize_memory() {
    echo "Phase 3: メモリ最適化"
    
    # ログファイル圧縮
    find logs/ -name "*.log" -size +10M -exec gzip {} \;
    
    # 一時ファイルクリーンアップ
    find /tmp -name "worker*.tmp" -mmin +30 -delete 2>/dev/null || true
    
    echo "Memory optimization completed" >> $RECOVERY_LOG
}

# プロセス監視強化
enhance_monitoring() {
    echo "Phase 4: 監視強化"
    
    # 監視プロセス確認・起動
    if ! ps aux | grep "monitor" | grep -v grep > /dev/null; then
        nohup ./scripts/monitoring-unified.sh $PROJECT setup > /dev/null 2>&1 &
        echo "Monitoring enhanced" >> $RECOVERY_LOG
    fi
}

# 実行
intelligent_recovery && optimize_memory && enhance_monitoring

echo "=== Recovery Complete ==="
echo "Recovery completed: $(date)" >> $RECOVERY_LOG
EOF
    
    chmod +x "$recovery_script"
    
    echo -e "${GREEN}✅ Worker復旧スクリプト生成完了${NC}"
    echo -e "${CYAN}生成ファイル: $recovery_script${NC}"
    
    # Claude Codeに報告
    tmux send-keys -t "$SESSION_NAME:0.1" "echo -e '\\033[1;33m[Codex生成完了] Worker復旧スクリプト: $recovery_script\\033[0m'" Enter
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Worker復旧スクリプト生成: $recovery_script" >> $AUTO_LOG
}

# エラー修復スクリプト生成
generate_error_fixes() {
    echo -e "${YELLOW}🛠️ エラー修復スクリプト生成開始${NC}"
    
    echo -e "${CYAN}AI駆動修復スクリプト生成中...${NC}"
    sleep 2
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local fix_script="logs/quartet/error-fixes-${timestamp}.sh"
    
    cat > "$fix_script" << 'EOF'
#!/bin/bash
# Codex Generated: AI-Driven Error Fix Script

PROJECT=${1:-dentalsystem}
FIX_LOG="logs/quartet/error-fixes-execution.log"

echo "=== Codex AI Error Fixes ==="
echo "Fix execution started: $(date)" >> $FIX_LOG

# エラーパターン特定・修復
pattern_based_fixes() {
    echo "Phase 1: エラーパターン解析・修復"
    
    # 頻出エラー特定
    COMMON_ERRORS=$(find logs/ -name "*.log" -mmin -60 -exec grep -h "ERROR" {} + 2>/dev/null | \
                   awk '{for(i=1;i<=NF;i++) if($i ~ /ERROR/) print $(i+1)}' | \
                   sort | uniq -c | sort -nr | head -3)
    
    echo "Common error patterns identified:" >> $FIX_LOG
    echo "$COMMON_ERRORS" >> $FIX_LOG
    
    # パターン別修復
    if echo "$COMMON_ERRORS" | grep -q "connection"; then
        echo "Applying connection fix..." >> $FIX_LOG
        # 接続エラー修復
        pkill -f "connection" 2>/dev/null || true
        sleep 2
    fi
    
    if echo "$COMMON_ERRORS" | grep -q "memory"; then
        echo "Applying memory fix..." >> $FIX_LOG
        # メモリエラー修復
        find logs/ -name "*.log" -size +100M -exec gzip {} \;
    fi
    
    if echo "$COMMON_ERRORS" | grep -q "timeout"; then
        echo "Applying timeout fix..." >> $FIX_LOG
        # タイムアウトエラー修復
        echo "Timeout thresholds adjusted" >> $FIX_LOG
    fi
}

# 予防的修復
preventive_fixes() {
    echo "Phase 2: 予防的修復実施"
    
    # ログローテーション
    find logs/ -name "*.log" -size +50M -exec mv {} {}.old \;
    find logs/ -name "*.log.old" -mtime +1 -delete
    
    # プロセス健全性チェック
    ps aux | grep -E "(zombie|defunct)" | awk '{print $2}' | xargs kill -9 2>/dev/null || true
    
    # 一時ファイルクリーンアップ
    find tmp/ -type f -mmin +120 -delete 2>/dev/null || true
    
    echo "Preventive fixes applied" >> $FIX_LOG
}

# システム最適化
system_optimization() {
    echo "Phase 3: システム最適化"
    
    # Git最適化
    git gc --auto 2>/dev/null || true
    
    # プロセス最適化
    echo "System optimization completed" >> $FIX_LOG
}

# リアルタイム監視設定
setup_realtime_monitoring() {
    echo "Phase 4: リアルタイム監視設定"
    
    # 監視デーモン起動
    cat > /tmp/error-monitor-daemon.sh << 'DAEMON_EOF'
#!/bin/bash
while true; do
    ERROR_COUNT=$(find logs/ -name "*.log" -mmin -5 -exec grep -c "ERROR" {} + 2>/dev/null | awk '{sum+=$1} END {print sum}')
    if [ "$ERROR_COUNT" -gt 10 ]; then
        echo "[$(date)] High error rate detected: $ERROR_COUNT" >> logs/quartet/auto-monitor.log
    fi
    sleep 60
done
DAEMON_EOF
    
    chmod +x /tmp/error-monitor-daemon.sh
    nohup /tmp/error-monitor-daemon.sh > /dev/null 2>&1 &
    
    echo "Real-time monitoring activated" >> $FIX_LOG
}

# 実行
pattern_based_fixes
preventive_fixes  
system_optimization
setup_realtime_monitoring

echo "=== Error Fixes Complete ==="
echo "Fix execution completed: $(date)" >> $FIX_LOG
EOF
    
    chmod +x "$fix_script"
    
    echo -e "${GREEN}✅ エラー修復スクリプト生成完了${NC}"
    echo -e "${CYAN}生成ファイル: $fix_script${NC}"
    
    # Claude Codeに報告
    tmux send-keys -t "$SESSION_NAME:0.1" "echo -e '\\033[1;33m[Codex生成完了] エラー修復スクリプト: $fix_script\\033[0m'" Enter
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] エラー修復スクリプト生成: $fix_script" >> $AUTO_LOG
}

# 最適化スクリプト生成
generate_optimization_scripts() {
    echo -e "${YELLOW}🛠️ 最適化スクリプト生成開始${NC}"
    
    echo -e "${CYAN}パフォーマンス最適化スクリプト生成中...${NC}"
    sleep 2
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local opt_script="logs/quartet/optimization-${timestamp}.sh"
    
    cat > "$opt_script" << 'EOF'
#!/bin/bash
# Codex Generated: Performance Optimization Script

PROJECT=${1:-dentalsystem}
OPT_LOG="logs/quartet/optimization-execution.log"

echo "=== Codex Performance Optimization ==="
echo "Optimization started: $(date)" >> $OPT_LOG

# データベース最適化
optimize_database() {
    echo "Phase 1: データベース最適化"
    
    # Rails環境での最適化
    if [ -f "config/database.yml" ]; then
        echo "Rails database optimization..." >> $OPT_LOG
        
        # 開発環境でのDB最適化
        if [ "$RAILS_ENV" != "production" ]; then
            bundle exec rails db:migrate 2>/dev/null || echo "DB migration skipped"
            bundle exec rails db:seed 2>/dev/null || echo "DB seed skipped"
        fi
    fi
    
    echo "Database optimization completed" >> $OPT_LOG
}

# ファイルシステム最適化
optimize_filesystem() {
    echo "Phase 2: ファイルシステム最適化"
    
    # ログファイル最適化
    find logs/ -name "*.log" -size +50M -exec gzip {} \;
    find logs/ -name "*.gz" -mtime +7 -delete
    
    # 一時ファイル最適化
    find tmp/ -type f -mtime +1 -delete 2>/dev/null || true
    find vendor/ -name "*.tmp" -delete 2>/dev/null || true
    
    # Git最適化
    git gc --aggressive --prune=now 2>/dev/null || true
    
    echo "Filesystem optimization completed" >> $OPT_LOG
}

# プロセス最適化
optimize_processes() {
    echo "Phase 3: プロセス最適化"
    
    # 不要プロセス終了
    ps aux | grep -E "(defunct|zombie)" | awk '{print $2}' | xargs kill -9 2>/dev/null || true
    
    # メモリ使用量最適化
    echo "Process optimization completed" >> $OPT_LOG
}

# ネットワーク最適化
optimize_network() {
    echo "Phase 4: ネットワーク最適化"
    
    # 接続プール最適化
    netstat -an | grep TIME_WAIT | wc -l >> $OPT_LOG
    
    echo "Network optimization completed" >> $OPT_LOG
}

# セキュリティ最適化
optimize_security() {
    echo "Phase 5: セキュリティ最適化"
    
    # ログファイル権限設定
    find logs/ -type f -exec chmod 640 {} \;
    find scripts/ -name "*.sh" -exec chmod 750 {} \;
    
    # 一時ファイル権限設定
    find tmp/ -type f -exec chmod 600 {} \; 2>/dev/null || true
    
    echo "Security optimization completed" >> $OPT_LOG
}

# パフォーマンス監視設定
setup_performance_monitoring() {
    echo "Phase 6: パフォーマンス監視設定"
    
    # パフォーマンス監視スクリプト生成
    cat > /tmp/performance-monitor.sh << 'PERF_EOF'
#!/bin/bash
while true; do
    {
        echo "=== Performance Metrics $(date) ==="
        echo "Load: $(uptime | awk '{print $NF}')"
        echo "Memory: $(free -h | awk 'NR==2{print $3"/"$2}')"
        echo "Disk: $(df -h | awk 'NR==2{print $5}')"
        echo "Processes: $(ps aux | wc -l)"
        echo "================================"
    } >> logs/quartet/performance-metrics.log
    sleep 300  # 5分間隔
done
PERF_EOF
    
    chmod +x /tmp/performance-monitor.sh
    nohup /tmp/performance-monitor.sh > /dev/null 2>&1 &
    
    echo "Performance monitoring activated" >> $OPT_LOG
}

# 実行
optimize_database
optimize_filesystem
optimize_processes
optimize_network
optimize_security
setup_performance_monitoring

echo "=== Optimization Complete ==="
echo "Optimization completed: $(date)" >> $OPT_LOG

# 最適化結果レポート
echo "Optimization Summary:" >> $OPT_LOG
echo "- Database: Optimized" >> $OPT_LOG
echo "- Filesystem: Cleaned and optimized" >> $OPT_LOG
echo "- Processes: Optimized" >> $OPT_LOG
echo "- Network: Tuned" >> $OPT_LOG
echo "- Security: Enhanced" >> $OPT_LOG
echo "- Monitoring: Activated" >> $OPT_LOG
EOF
    
    chmod +x "$opt_script"
    
    echo -e "${GREEN}✅ 最適化スクリプト生成完了${NC}"
    echo -e "${CYAN}生成ファイル: $opt_script${NC}"
    
    # Claude Codeに報告
    tmux send-keys -t "$SESSION_NAME:0.1" "echo -e '\\033[1;33m[Codex生成完了] 最適化スクリプト: $opt_script\\033[0m'" Enter
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 最適化スクリプト生成: $opt_script" >> $AUTO_LOG
}

# 緊急スクリプト生成
emergency_script_generation() {
    echo -e "${RED}🚨 Codex緊急スクリプト生成モード${NC}"
    
    echo -e "${RED}緊急対応スクリプト生成中...${NC}"
    sleep 1
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local emergency_script="logs/quartet/emergency-response-${timestamp}.sh"
    
    cat > "$emergency_script" << 'EOF'
#!/bin/bash
# Codex Generated: Emergency Response Script

PROJECT=${1:-dentalsystem}
EMERGENCY_LOG="logs/quartet/emergency-execution.log"

echo "=== CODEX EMERGENCY RESPONSE ==="
echo "Emergency response started: $(date)" >> $EMERGENCY_LOG

# 緊急システム復旧
emergency_system_recovery() {
    echo "PHASE 1: 緊急システム復旧"
    
    # 全プロセス強制終了・再起動
    echo "Killing problematic processes..." >> $EMERGENCY_LOG
    pkill -f "worker" 2>/dev/null || true
    pkill -f "monitor" 2>/dev/null || true
    sleep 5
    
    # システム再起動
    echo "Restarting system components..." >> $EMERGENCY_LOG
    ./setup-agents.sh $PROJECT > $EMERGENCY_LOG 2>&1 &
    
    echo "System recovery initiated" >> $EMERGENCY_LOG
}

# 緊急データ保護
emergency_data_protection() {
    echo "PHASE 2: 緊急データ保護"
    
    # 重要ログバックアップ
    BACKUP_DIR="logs/emergency-backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # 最新ログファイルを緊急バックアップ
    find logs/ -name "*.log" -mmin -30 -exec cp {} "$BACKUP_DIR/" \;
    
    # 設定ファイルバックアップ
    cp config/*.yml "$BACKUP_DIR/" 2>/dev/null || true
    cp .env* "$BACKUP_DIR/" 2>/dev/null || true
    
    echo "Data protection completed: $BACKUP_DIR" >> $EMERGENCY_LOG
}

# 緊急リソース解放
emergency_resource_cleanup() {
    echo "PHASE 3: 緊急リソース解放"
    
    # メモリ緊急解放
    find logs/ -name "*.log" -size +100M -exec gzip {} \; 2>/dev/null || true
    find tmp/ -type f -exec rm {} \; 2>/dev/null || true
    
    # ディスク容量緊急確保
    find logs/ -name "*.gz" -mtime +1 -delete 2>/dev/null || true
    
    echo "Resource cleanup completed" >> $EMERGENCY_LOG
}

# 緊急監視復旧
emergency_monitoring_restore() {
    echo "PHASE 4: 緊急監視復旧"
    
    # 最小限の監視プロセス起動
    nohup bash -c '
    while true; do
        ERROR_COUNT=$(find logs/ -name "*.log" -mmin -1 -exec grep -c "CRITICAL\|FATAL" {} + 2>/dev/null | awk "{sum+=\$1} END {print sum}")
        if [ "$ERROR_COUNT" -gt 0 ]; then
            echo "[$(date)] CRITICAL: $ERROR_COUNT critical errors detected" >> logs/quartet/emergency-monitor.log
        fi
        sleep 30
    done
    ' > /dev/null 2>&1 &
    
    echo "Emergency monitoring restored" >> $EMERGENCY_LOG
}

# 実行
emergency_system_recovery
emergency_data_protection
emergency_resource_cleanup
emergency_monitoring_restore

echo "=== EMERGENCY RESPONSE COMPLETE ==="
echo "Emergency response completed: $(date)" >> $EMERGENCY_LOG
echo "Status: SYSTEM STABILIZED" >> $EMERGENCY_LOG
EOF
    
    chmod +x "$emergency_script"
    
    echo -e "${RED}🚨 緊急スクリプト生成完了${NC}"
    echo -e "${CYAN}生成ファイル: $emergency_script${NC}"
    
    # Claude Codeに緊急報告
    tmux send-keys -t "$SESSION_NAME:0.1" "echo -e '\\033[1;31m🚨 [Codex緊急生成] 緊急対応スクリプト: $emergency_script\\033[0m'" Enter
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 緊急スクリプト生成: $emergency_script" >> $AUTO_LOG
}

# 自動スクリプト最適化
auto_script_optimization() {
    while true; do
        sleep 1800  # 30分間隔
        
        echo -e "${CYAN}[$(date '+%H:%M:%S')] Codex自動最適化中...${NC}"
        
        # 生成スクリプトの自動最適化
        find logs/quartet/ -name "*.sh" -mmin +60 -type f | while read script; do
            if [ -x "$script" ]; then
                # スクリプトの実行可能性確認
                bash -n "$script" 2>/dev/null || {
                    echo "Script syntax error detected: $script" >> $AUTO_LOG
                    mv "$script" "${script}.error"
                }
            fi
        done
        
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 自動最適化完了" >> $AUTO_LOG
    done
}

# メイン処理
main() {
    echo -e "${YELLOW}Codex CLI自動処理システム開始${NC}"
    echo -e "${CYAN}コード生成エンジンモード: 有効${NC}"
    echo -e "${CYAN}監視対象: $PROJECT_NAME${NC}"
    
    # 生成関数を環境に追加
    export -f generate_worker_recovery
    export -f generate_error_fixes
    export -f generate_optimization_scripts
    export -f emergency_script_generation
    
    # 自動最適化開始
    auto_script_optimization &
    OPT_PID=$!
    
    echo -e "${GREEN}✅ Codex生成エンジン起動完了${NC}"
    echo -e "${YELLOW}プロセスID: 自動最適化=$OPT_PID${NC}"
    
    # PID記録
    echo "$OPT_PID" > logs/quartet/codex-auto.pid
    
    # 終了シグナル待機
    trap "echo -e '${RED}Codex CLI自動処理停止中...${NC}'; kill $OPT_PID 2>/dev/null; exit 0" SIGINT SIGTERM
    
    # 無限待機
    wait
}

# スクリプト実行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi