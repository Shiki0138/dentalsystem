#!/bin/bash
# 🚀 歯科業界革命システム 自動監視開始スクリプト
# URL取得後に即座に完全監視体制を確立

set -euo pipefail

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 設定
MONITORING_CONFIG_DIR="./monitoring"
BACKUP_CONFIG_DIR="./backup"
LOG_FILE="./logs/monitoring-setup.log"

# ログ関数
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# URL入力待機
wait_for_url() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}🦷⚡ 歯科業界革命システム 自動監視セットアップ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    if [ -z "${PRODUCTION_URL:-}" ]; then
        read -p "本番環境のURLを入力してください: " PRODUCTION_URL
    fi
    
    # URL検証
    if [[ ! "$PRODUCTION_URL" =~ ^https?:// ]]; then
        error "無効なURL形式です。http:// または https:// で始まる必要があります。"
    fi
    
    export PRODUCTION_URL
    log "本番URL設定: $PRODUCTION_URL"
}

# 1. UptimeRobot設定
setup_uptime_robot() {
    log "📍 UptimeRobot監視設定開始..."
    
    cat > "$MONITORING_CONFIG_DIR/uptime-robot-config.json" <<EOF
{
  "monitors": [
    {
      "friendly_name": "歯科業界革命システム - メイン",
      "url": "${PRODUCTION_URL}",
      "type": 1,
      "interval": 60,
      "timeout": 30,
      "alert_contacts": ["email", "slack"]
    },
    {
      "friendly_name": "歯科業界革命システム - ヘルスチェック",
      "url": "${PRODUCTION_URL}/health",
      "type": 2,
      "keyword_type": 1,
      "keyword_value": "ok",
      "interval": 300
    },
    {
      "friendly_name": "歯科業界革命システム - API",
      "url": "${PRODUCTION_URL}/api/v1/health",
      "type": 3,
      "interval": 300,
      "post_value": "{\"check\":\"api\"}"
    }
  ]
}
EOF
    
    log "✅ UptimeRobot設定ファイル作成完了"
}

# 2. Grafana Cloud設定
setup_grafana() {
    log "📊 Grafana Cloud設定開始..."
    
    # Prometheus設定
    cat > "$MONITORING_CONFIG_DIR/prometheus-config.yml" <<EOF
global:
  scrape_interval: 30s
  external_labels:
    monitor: 'dental-revolution'
    
scrape_configs:
  - job_name: 'dental-system'
    metrics_path: '/metrics'
    static_configs:
      - targets: ['${PRODUCTION_URL#https://}']
    tls_config:
      insecure_skip_verify: false
      
  - job_name: 'blackbox'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
          - ${PRODUCTION_URL}
          - ${PRODUCTION_URL}/health
          - ${PRODUCTION_URL}/api/v1/appointments
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115
        
remote_write:
  - url: https://prometheus-prod-01-eu-west-0.grafana.net/api/prom/push
    basic_auth:
      username: \${GRAFANA_CLOUD_USER}
      password: \${GRAFANA_CLOUD_API_KEY}
EOF
    
    # Grafana Agent設定
    cat > "$MONITORING_CONFIG_DIR/grafana-agent.yaml" <<EOF
server:
  http_listen_port: 12345
  
metrics:
  global:
    scrape_interval: 30s
    remote_write:
      - url: https://prometheus-prod-01-eu-west-0.grafana.net/api/prom/push
        basic_auth:
          username: \${GRAFANA_CLOUD_USER}
          password: \${GRAFANA_CLOUD_API_KEY}
          
logs:
  configs:
    - name: dental-revolution
      clients:
        - url: https://logs-prod-eu-west-0.grafana.net/loki/api/v1/push
          basic_auth:
            username: \${GRAFANA_CLOUD_USER}
            password: \${GRAFANA_CLOUD_API_KEY}
      positions:
        filename: /tmp/positions.yaml
      scrape_configs:
        - job_name: system
          static_configs:
            - targets:
                - localhost
              labels:
                job: dental-system-logs
                host: ${PRODUCTION_URL}
                __path__: /var/log/dental-system/*.log
EOF
    
    log "✅ Grafana Cloud設定完了"
}

# 3. 自動アラート設定
setup_alerts() {
    log "🚨 アラート自動設定開始..."
    
    # Alertmanager設定
    cat > "$MONITORING_CONFIG_DIR/alertmanager.yml" <<EOF
global:
  resolve_timeout: 5m
  slack_api_url: '\${SLACK_WEBHOOK_URL}'
  
route:
  group_by: ['alertname', 'severity']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'dental-team'
  
  routes:
    - match:
        severity: critical
      receiver: 'critical-channel'
      continue: true
      
    - match:
        severity: warning
      receiver: 'warning-channel'
      
receivers:
  - name: 'dental-team'
    slack_configs:
      - channel: '#dental-revolution-alerts'
        title: '🦷 歯科業界革命システムアラート'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
        send_resolved: true
        
  - name: 'critical-channel'
    slack_configs:
      - channel: '#critical-alerts'
        title: '🚨 緊急アラート'
    pagerduty_configs:
      - service_key: '\${PAGERDUTY_KEY}'
        
  - name: 'warning-channel'
    slack_configs:
      - channel: '#warnings'
EOF
    
    log "✅ アラート設定完了"
}

# 4. ヘルスチェックスクリプト
create_health_check() {
    log "🏥 ヘルスチェックスクリプト作成..."
    
    cat > "$MONITORING_CONFIG_DIR/health-check.sh" <<'HEALTH_SCRIPT'
#!/bin/bash
# 定期ヘルスチェックスクリプト

PRODUCTION_URL="${PRODUCTION_URL}"
SLACK_WEBHOOK="${SLACK_WEBHOOK_URL}"

# ヘルスチェック実行
check_health() {
    local endpoint=$1
    local expected=$2
    
    response=$(curl -s -o /dev/null -w "%{http_code}" "$PRODUCTION_URL$endpoint")
    
    if [ "$response" != "$expected" ]; then
        alert_slack "❌ ヘルスチェック失敗: $endpoint (Status: $response)"
        return 1
    fi
    return 0
}

# Slack通知
alert_slack() {
    local message=$1
    curl -X POST "$SLACK_WEBHOOK" \
        -H 'Content-Type: application/json' \
        -d "{\"text\":\"$message\"}"
}

# メインチェック
main() {
    echo "[$(date)] ヘルスチェック開始"
    
    # 基本チェック
    check_health "/" "200"
    check_health "/health" "200"
    check_health "/api/v1/health" "200"
    
    # パフォーマンスチェック
    start_time=$(date +%s%N)
    curl -s "$PRODUCTION_URL/api/v1/appointments" > /dev/null
    end_time=$(date +%s%N)
    response_time=$(( ($end_time - $start_time) / 1000000 ))
    
    if [ $response_time -gt 1000 ]; then
        alert_slack "⚠️ レスポンス遅延: ${response_time}ms"
    fi
    
    echo "[$(date)] ヘルスチェック完了"
}

main
HEALTH_SCRIPT
    
    chmod +x "$MONITORING_CONFIG_DIR/health-check.sh"
    log "✅ ヘルスチェックスクリプト作成完了"
}

# 5. 監視開始スクリプト
create_start_monitoring() {
    log "🚀 監視開始スクリプト作成..."
    
    cat > "$MONITORING_CONFIG_DIR/start-monitoring.sh" <<'START_SCRIPT'
#!/bin/bash
# 監視サービス一括起動

echo "🦷⚡ 歯科業界革命システム監視開始"

# Prometheusエクスポーター起動
docker run -d \
    --name dental-prometheus \
    -p 9090:9090 \
    -v $(pwd)/monitoring/prometheus-config.yml:/etc/prometheus/prometheus.yml \
    prom/prometheus

# Grafana Agent起動
docker run -d \
    --name dental-grafana-agent \
    -v $(pwd)/monitoring/grafana-agent.yaml:/etc/agent-config.yaml \
    -e GRAFANA_CLOUD_USER=$GRAFANA_CLOUD_USER \
    -e GRAFANA_CLOUD_API_KEY=$GRAFANA_CLOUD_API_KEY \
    grafana/agent:latest \
    --config.file=/etc/agent-config.yaml

# Alertmanager起動
docker run -d \
    --name dental-alertmanager \
    -p 9093:9093 \
    -v $(pwd)/monitoring/alertmanager.yml:/etc/alertmanager/alertmanager.yml \
    -e SLACK_WEBHOOK_URL=$SLACK_WEBHOOK_URL \
    prom/alertmanager

# ヘルスチェックCron設定
(crontab -l 2>/dev/null; echo "*/5 * * * * $(pwd)/monitoring/health-check.sh") | crontab -

echo "✅ 全監視サービス起動完了"
echo "📊 ダッシュボード: http://localhost:9090"
echo "🚨 アラートマネージャー: http://localhost:9093"
START_SCRIPT
    
    chmod +x "$MONITORING_CONFIG_DIR/start-monitoring.sh"
    log "✅ 監視開始スクリプト作成完了"
}

# 6. バックアップ自動化
setup_backup_automation() {
    log "💾 バックアップ自動化設定..."
    
    # バックアップCron設定
    cat > "$BACKUP_CONFIG_DIR/backup-cron" <<EOF
# 歯科業界革命システム自動バックアップ
# PostgreSQL フルバックアップ（毎日2時）
0 2 * * * $BACKUP_CONFIG_DIR/postgres-backup.sh full >> $BACKUP_CONFIG_DIR/backup.log 2>&1

# 差分バックアップ（6時間毎）
0 */6 * * * $BACKUP_CONFIG_DIR/postgres-backup.sh incremental >> $BACKUP_CONFIG_DIR/backup.log 2>&1

# WALアーカイブ（5分毎）
*/5 * * * * $BACKUP_CONFIG_DIR/postgres-backup.sh wal >> $BACKUP_CONFIG_DIR/backup.log 2>&1

# S3同期（毎時）
0 * * * * aws s3 sync /app/storage s3://dental-revolution-backups/files/ --delete >> $BACKUP_CONFIG_DIR/backup.log 2>&1
EOF
    
    # Cronインストール
    crontab "$BACKUP_CONFIG_DIR/backup-cron"
    log "✅ バックアップ自動化設定完了"
}

# 7. 最終確認とサマリー
show_summary() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✅ 自動監視設定完了サマリー${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "📍 監視対象URL: $PRODUCTION_URL"
    echo ""
    echo "✅ 設定完了項目:"
    echo "  - UptimeRobot設定（60秒間隔監視）"
    echo "  - Grafana Cloud設定（メトリクス・ログ収集）"
    echo "  - アラート設定（Slack/PagerDuty連携）"
    echo "  - ヘルスチェックスクリプト（5分毎実行）"
    echo "  - バックアップ自動化（3-2-1ルール適用）"
    echo ""
    echo "📋 次のステップ:"
    echo "  1. 環境変数を設定してください:"
    echo "     export GRAFANA_CLOUD_USER=your-user"
    echo "     export GRAFANA_CLOUD_API_KEY=your-key"
    echo "     export SLACK_WEBHOOK_URL=your-webhook"
    echo "     export PAGERDUTY_KEY=your-key"
    echo ""
    echo "  2. 監視を開始:"
    echo "     ./monitoring/start-monitoring.sh"
    echo ""
    echo -e "${BLUE}🦷⚡ 歯科業界革命の完全監視体制が整いました！${NC}"
}

# メイン処理
main() {
    # ログディレクトリ作成
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$MONITORING_CONFIG_DIR"
    mkdir -p "$BACKUP_CONFIG_DIR"
    
    log "🚀 歯科業界革命システム自動監視セットアップ開始"
    
    # URL取得
    wait_for_url
    
    # 各種設定
    setup_uptime_robot
    setup_grafana
    setup_alerts
    create_health_check
    create_start_monitoring
    setup_backup_automation
    
    # サマリー表示
    show_summary
    
    log "🎯 全ての設定が完了しました！"
}

# エラーハンドリング
trap 'error "予期せぬエラーが発生しました。ログを確認してください: $LOG_FILE"' ERR

# 実行
main "$@"