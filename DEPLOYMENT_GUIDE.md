# 歯科クリニック予約・業務管理システム デプロイガイド

## 🚀 概要

このガイドでは、AWS Lightsail環境への本番デプロイ手順を説明します。
月額¥5,000以内での安定した本番環境構築を目標としています。

## 📋 前提条件

- AWS Lightsailインスタンス（2 vCPU / 4 GB RAM）
- ドメイン名とSSL証明書
- GitHub Actionsシークレット設定
- Docker及びDocker Compose環境

## 🏗️ インフラ構成

```
Internet → Route53 → ALB → Lightsail Instance
                              ├── Nginx (SSL終端)
                              ├── Rails App (Docker)
                              ├── PostgreSQL (Docker)
                              ├── Redis (Docker)
                              ├── Sidekiq (Docker)
                              └── Monitoring Stack
```

## 🔧 1. AWS Lightsail セットアップ

### 1.1 インスタンス作成
```bash
# Lightsailインスタンス仕様
OS: Ubuntu 22.04 LTS
Plan: 2 vCPU, 4 GB RAM, 80 GB SSD
Monthly Cost: ¥3,500
```

### 1.2 ファイアウォール設定
```bash
# 必要なポートを開放
HTTP (80)     - 0.0.0.0/0
HTTPS (443)   - 0.0.0.0/0
SSH (22)      - Your IP only
Custom (3000) - 127.0.0.1/32  # アプリケーション内部用
```

### 1.3 静的IPアタッチ
```bash
# Lightsailコンソールで静的IPを作成・アタッチ
Static IP Cost: ¥500/月
```

## 🐳 2. Docker環境セットアップ

### 2.1 Docker インストール
```bash
# サーバーにSSH接続
ssh -i ~/.ssh/dental_system_lightsail.pem ubuntu@your-static-ip

# Docker インストール
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Docker Compose インストール
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### 2.2 アプリケーション配置
```bash
# アプリケーションディレクトリ作成
sudo mkdir -p /home/deploy/dental_system
sudo chown $USER:$USER /home/deploy/dental_system
cd /home/deploy/dental_system

# リポジトリクローン
git clone https://github.com/your-org/dental-system.git .
```

## ⚙️ 3. 環境設定

### 3.1 環境変数ファイル作成
```bash
# .env.production ファイル作成
cat > .env.production << EOF
# Database
DATABASE_NAME=dental_system_production
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=$(openssl rand -base64 32)

# Rails
SECRET_KEY_BASE=$(openssl rand -hex 64)
DEVISE_SECRET_KEY=$(openssl rand -hex 64)
RAILS_ENV=production

# External Services
LINE_CHANNEL_SECRET=your_line_secret
LINE_CHANNEL_TOKEN=your_line_token
GMAIL_USERNAME=your_gmail
GMAIL_PASSWORD=your_app_password
TWILIO_ACCOUNT_SID=your_twilio_sid
TWILIO_AUTH_TOKEN=your_twilio_token

# Monitoring
GRAFANA_PASSWORD=$(openssl rand -base64 16)
SLACK_WEBHOOK_URL=your_slack_webhook
EOF

# ファイル権限設定
chmod 600 .env.production
```

### 3.2 SSL証明書設定
```bash
# Let's Encrypt インストール
sudo apt update
sudo apt install certbot python3-certbot-nginx

# SSL証明書取得
sudo certbot certonly --standalone \
  -d your-domain.com \
  --email admin@your-domain.com \
  --agree-tos \
  --non-interactive

# 証明書ディレクトリ作成
mkdir -p ssl
sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem ssl/
sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem ssl/
sudo chown $USER:$USER ssl/*
```

## 🚀 4. アプリケーションデプロイ

### 4.1 初回デプロイ
```bash
# Docker Compose起動
docker compose -f docker-compose.production.yml up -d

# データベースセットアップ
docker compose -f docker-compose.production.yml exec web bundle exec rails db:setup
docker compose -f docker-compose.production.yml exec web bundle exec rails db:seed

# 初期管理者ユーザー作成
docker compose -f docker-compose.production.yml exec web bundle exec rails runner "
  User.create!(
    email: 'admin@your-domain.com',
    password: 'change_this_password',
    name: 'System Admin',
    role: 'admin'
  )
"
```

### 4.2 GitHub Actions設定
```bash
# GitHub Secretsに以下を設定
LIGHTSAIL_HOST: your-static-ip
LIGHTSAIL_USER: ubuntu
LIGHTSAIL_SSH_KEY: (SSH秘密鍵の内容)
SLACK_WEBHOOK_URL: your_slack_webhook_url
```

## 📊 5. 監視システム設定

### 5.1 監視スタック起動
```bash
# 監視設定ディレクトリ作成
mkdir -p monitoring/{prometheus,grafana,loki}

# Prometheus設定
cat > monitoring/prometheus.yml << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'dental-system'
    static_configs:
      - targets: ['web:3000']
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
EOF

# 監視スタック起動
docker compose -f docker-compose.monitoring.yml up -d
```

### 5.2 ヘルスチェック設定
```bash
# ヘルスチェックスクリプト実行権限付与
chmod +x scripts/health_check.sh

# cronジョブ設定
crontab -e
# 以下を追加
*/5 * * * * /home/deploy/dental_system/scripts/health_check.sh
0 2 * * * docker system prune -f  # 毎日2時にクリーンアップ
```

## 🔒 6. セキュリティ設定

### 6.1 ファイアウォール設定
```bash
# UFW有効化
sudo ufw enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443
```

### 6.2 自動更新設定
```bash
# セキュリティアップデート自動適用
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

## 📈 7. 運用監視

### 7.1 アクセス先
- **アプリケーション**: https://your-domain.com
- **Grafana**: https://your-domain.com:3001
- **Uptime Kuma**: https://your-domain.com:3002

### 7.2 ログ確認
```bash
# アプリケーションログ
docker compose -f docker-compose.production.yml logs -f web

# Nginx ログ
docker compose -f docker-compose.production.yml logs -f nginx

# データベースログ
docker compose -f docker-compose.production.yml logs -f db

# システムログ
tail -f /var/log/dental_system/health_check.log
```

## 🔄 8. バックアップ・復旧

### 8.1 データベースバックアップ
```bash
# 自動バックアップスクリプト作成
cat > scripts/backup_db.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/home/deploy/dental_system/backup"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

docker compose -f docker-compose.production.yml exec -T db \
  pg_dump -U postgres dental_system_production > \
  $BACKUP_DIR/backup_$TIMESTAMP.sql

# 30日以前のバックアップ削除
find $BACKUP_DIR -name "backup_*.sql" -mtime +30 -delete
EOF

chmod +x scripts/backup_db.sh

# cronに追加（毎日3時実行）
# 0 3 * * * /home/deploy/dental_system/scripts/backup_db.sh
```

### 8.2 システム復旧手順
```bash
# 緊急時復旧コマンド
docker compose -f docker-compose.production.yml down
docker compose -f docker-compose.production.yml pull
docker compose -f docker-compose.production.yml up -d

# データベース復旧（必要時）
docker compose -f docker-compose.production.yml exec -T db \
  psql -U postgres -d dental_system_production < backup/backup_YYYYMMDD_HHMMSS.sql
```

## 💰 9. コスト概算

| サービス | 月額費用 |
|---------|---------|
| Lightsail Instance (2vCPU/4GB) | ¥3,500 |
| Static IP | ¥500 |
| Domain (Route53) | ¥50 |
| SSL Certificate (Let's Encrypt) | ¥0 |
| **合計** | **¥4,050/月** |

## ⚠️ 10. トラブルシューティング

### よくある問題と解決策

1. **コンテナが起動しない**
   ```bash
   docker compose -f docker-compose.production.yml logs service_name
   ```

2. **データベース接続エラー**
   ```bash
   docker compose -f docker-compose.production.yml restart db
   ```

3. **SSL証明書期限切れ**
   ```bash
   sudo certbot renew
   ```

4. **ディスク容量不足**
   ```bash
   docker system prune -a
   ```

## 📞 サポート

問題が発生した場合は、以下の情報を含めてサポートに連絡してください：
- エラーメッセージ
- 関連するログファイル
- 実行したコマンド
- システム状態（`docker ps`, `df -h`など）

---

**デプロイ完了後は、必ずヘルスチェックと全機能のテストを実施してください。**