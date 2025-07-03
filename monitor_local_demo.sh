#!/bin/bash
# ローカルデモ環境監視・自動回復スクリプト

PROJECT_NAME="dentalsystem"
LOG_FILE="monitoring_demo.log"
ALERT_THRESHOLD=3
RECOVERY_ATTEMPTS=0
MAX_RECOVERY_ATTEMPTS=3

# ログ関数
log_event() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# 状況確認関数
check_port() {
    local port=$1
    local timeout=5
    
    if timeout $timeout bash -c "</dev/tcp/localhost/$port" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# APIヘルスチェック
check_api_health() {
    local response=$(curl -s -w "%{http_code}" -o /dev/null http://localhost:3001/health --max-time 5)
    if [ "$response" = "200" ]; then
        return 0
    else
        return 1
    fi
}

# サーバー起動関数
start_api_server() {
    log_event "🚀 APIサーバー起動試行中..."
    
    # 既存プロセス確認・停止
    pkill -f "api_demo_server.rb" 2>/dev/null || true
    sleep 2
    
    # 新しいサーバー起動
    nohup ./api_demo_server.rb 3001 > api_server_recovery.log 2>&1 &
    
    # 起動確認
    sleep 3
    if check_api_health; then
        log_event "✅ APIサーバー起動成功"
        return 0
    else
        log_event "❌ APIサーバー起動失敗"
        return 1
    fi
}

# 回復処理
perform_recovery() {
    local issue=$1
    RECOVERY_ATTEMPTS=$((RECOVERY_ATTEMPTS + 1))
    
    log_event "🔧 回復処理開始 (試行 $RECOVERY_ATTEMPTS/$MAX_RECOVERY_ATTEMPTS): $issue"
    
    case $issue in
        "port_3001")
            start_api_server
            ;;
        "api_health")
            start_api_server
            ;;
        *)
            log_event "⚠️ 未知の問題: $issue"
            return 1
            ;;
    esac
}

# 通知関数
send_alert() {
    local message=$1
    local status=$2
    
    log_event "📢 アラート: $message ($status)"
    
    # ここでSlack/Discord/メール通知などを追加可能
    # 例: curl -X POST webhook_url -d "{'text': '$message'}"
}

# メイン監視ループ
main_monitor() {
    log_event "🛡️ ローカルデモ環境監視開始"
    log_event "監視対象: Port 3000, 3001, API Health"
    
    local error_count=0
    local consecutive_success=0
    
    while true; do
        local current_errors=0
        local status_report=""
        
        # Port 3000 チェック
        if check_port 3000; then
            status_report+="Port 3000: ✅ "
        else
            status_report+="Port 3000: ❌ "
            current_errors=$((current_errors + 1))
        fi
        
        # Port 3001 チェック
        if check_port 3001; then
            status_report+="Port 3001: ✅ "
        else
            status_report+="Port 3001: ❌ "
            current_errors=$((current_errors + 1))
            if [ $RECOVERY_ATTEMPTS -lt $MAX_RECOVERY_ATTEMPTS ]; then
                perform_recovery "port_3001"
            fi
        fi
        
        # API Health チェック
        if check_api_health; then
            status_report+="API: ✅"
            consecutive_success=$((consecutive_success + 1))
        else
            status_report+="API: ❌"
            current_errors=$((current_errors + 1))
            if [ $RECOVERY_ATTEMPTS -lt $MAX_RECOVERY_ATTEMPTS ]; then
                perform_recovery "api_health"
            fi
        fi
        
        # エラー状況評価
        if [ $current_errors -eq 0 ]; then
            if [ $consecutive_success -eq 1 ]; then
                log_event "🎉 全システム正常稼働中: $status_report"
            fi
            error_count=0
            RECOVERY_ATTEMPTS=0
        else
            error_count=$((error_count + 1))
            log_event "⚠️ エラー検出 ($error_count/$ALERT_THRESHOLD): $status_report"
            
            if [ $error_count -ge $ALERT_THRESHOLD ]; then
                send_alert "ローカルデモ環境で深刻な問題を検出" "CRITICAL"
                error_count=0
            fi
        fi
        
        # 監視間隔
        sleep 30
    done
}

# 初回チェック
initial_check() {
    log_event "🔍 初回システムチェック実行"
    
    echo "=== ローカルデモ環境状況 ==="
    echo "Port 3000: $(check_port 3000 && echo "稼働中" || echo "停止")"
    echo "Port 3001: $(check_port 3001 && echo "稼働中" || echo "停止")"
    echo "API Health: $(check_api_health && echo "正常" || echo "異常")"
    echo ""
    
    # 必要に応じて初回起動
    if ! check_api_health; then
        log_event "🚀 APIサーバーが停止中のため起動します"
        start_api_server
    fi
}

# シグナルハンドリング
trap 'log_event "🛑 監視停止"; exit 0' SIGTERM SIGINT

# メイン実行
case "${1:-monitor}" in
    "check")
        initial_check
        ;;
    "start")
        start_api_server
        ;;
    "monitor")
        initial_check
        main_monitor
        ;;
    "status")
        echo "=== ローカルデモ環境状況 ==="
        echo "Port 3000: $(check_port 3000 && echo "稼働中" || echo "停止")"
        echo "Port 3001: $(check_port 3001 && echo "稼働中" || echo "停止")"
        echo "API Health: $(check_api_health && echo "正常" || echo "異常")"
        echo "プロセス: $(ps aux | grep -E 'api_demo_server|rails|puma' | grep -v grep | wc -l) 個実行中"
        ;;
    *)
        echo "使用方法: $0 {check|start|monitor|status}"
        echo "  check   - 初回チェックのみ実行"
        echo "  start   - APIサーバー起動"
        echo "  monitor - 継続監視開始"
        echo "  status  - 現在の状況表示"
        ;;
esac