# 🚀 デプロイ手順書 - 歯科クリニック予約・業務管理システム

**作成日時**: 2025-06-29 19:47  
**対象環境**: AWS Lightsail Production  
**システム**: Rails 7.2 + Docker Compose  

---

## 📋 デプロイ前チェックリスト

### ✅ 必須準備項目
- [ ] AWS Lightsailインスタンス作成（2 vCPU / 4 GB）
- [ ] ドメイン名設定（例: dental-system.example.com）
- [ ] SSH鍵ペア作成・配置
- [ ] 環境変数ファイル(.env.production)準備
- [ ] GitHub Actionsシークレット設定
- [ ] 外部API設定（LINE, Google, Twilio）

### 🔧 必要な環境変数
```bash
# 必須設定項目
SECRET_KEY_BASE=xxx
POSTGRES_PASSWORD=xxx
LINE_CHANNEL_SECRET=xxx
LINE_CHANNEL_TOKEN=xxx
GOOGLE_CLIENT_ID=xxx
GOOGLE_CLIENT_SECRET=xxx
UPTIME_ROBOT_API_KEY=xxx
GRAFANA_CLOUD_API_KEY=xxx
```

---

## 🏗️ 初回デプロイ手順

### Step 1: サーバー準備
```bash
# 1. AWS Lightsailインスタンス作成
# - OS: Ubuntu 22.04 LTS
# - プラン: 2 vCPU, 4 GB RAM, 80 GB SSD
# - 静的IP割り当て

# 2. 基本パッケージインストール
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose-plugin nginx certbot python3-certbot-nginx

# 3. Dockerサービス開始
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ubuntu
```

### Step 2: コード配置
```bash
# 1. リポジトリクローン
git clone git@github.com:your-org/dental-system.git
cd dental-system

# 2. 環境変数設定
cp .env.production.example .env.production
# .env.productionを実際の値で編集

# 3. SSL証明書取得
sudo certbot --nginx -d dental-system.example.com
```

### Step 3: 初回デプロイ実行
```bash
# 1. Capistranoでデプロイ実行
bundle install
bundle exec cap production deploy:initial

# 2. データベース初期化
bundle exec cap production docker:migrate

# 3. ヘルスチェック確認
curl https://dental-system.example.com/up
```

---

## 🔄 日常デプロイ手順

### 自動デプロイ（推奨）
```bash
# GitHub経由での自動デプロイ
git push origin main
# → GitHub Actionsが自動実行
# → テスト・セキュリティチェック・デプロイ
```

### 手動デプロイ
```bash
# Capistrano経由での手動デプロイ
bundle exec cap production deploy

# ロールバック（緊急時）
bundle exec cap production deploy:rollback
```

---

## 📊 監視・ヘルスチェック

### UptimeRobot監視設定
```bash
# 自動セットアップ実行
chmod +x scripts/setup_monitoring.sh
./scripts/setup_monitoring.sh
```

### 手動ヘルスチェック
```bash
# システム全体チェック
/usr/local/bin/health_check.sh

# 個別サービスチェック
docker compose ps
docker compose logs web
docker compose logs sidekiq
```

### KPI監視エンドポイント
- **ヘルスチェック**: `https://domain.com/up`
- **メトリクス**: `https://domain.com/metrics` (IP制限)
- **ステータス**: `https://domain.com/admin/monitoring` (認証必要)

---

## 🚨 トラブルシューティング

### よくある問題と対処法

#### 1. コンテナ起動失敗
```bash
# 問題確認
docker compose logs web
docker compose ps

# 対処
docker compose down
docker compose up -d
```

#### 2. データベース接続エラー
```bash
# 接続確認
docker compose exec db pg_isready -U postgres

# パスワード確認
echo $POSTGRES_PASSWORD

# 再起動
docker compose restart db web
```

#### 3. SSL証明書エラー
```bash
# 証明書状況確認
sudo certbot certificates

# 証明書更新
sudo certbot renew

# Nginx設定確認
sudo nginx -t
sudo systemctl reload nginx
```

#### 4. メモリ不足
```bash
# リソース使用量確認
docker stats
free -h

# 不要コンテナ削除
docker system prune -f
```

---

## 📈 パフォーマンス最適化

### リソース監視
```bash
# CPU・メモリ使用量
htop
docker stats

# ディスク使用量
df -h
du -sh /var/lib/docker

# ログサイズ管理
journalctl --disk-usage
docker logs --tail 100 dental_system_web_1
```

### 定期メンテナンス
```bash
# 毎週実行（日曜日深夜）
0 2 * * 0 docker system prune -f
0 3 * * 0 /usr/local/bin/verify_backups.sh
```

---

## 🔒 セキュリティチェック

### 定期セキュリティ監査
```bash
# パッケージ更新
sudo apt update && sudo apt list --upgradable
sudo apt upgrade -y

# Docker イメージ更新
docker compose pull
docker compose up -d

# SSL証明書チェック
openssl s_client -connect domain.com:443 | openssl x509 -noout -dates
```

---

## 💾 バックアップ・復旧

### 自動バックアップ
```bash
# データベースバックアップ（毎日実行）
0 2 * * * /usr/local/bin/backup_database.sh

# ファイルバックアップ
rsync -av /var/www/dental_system/shared/storage/ backup-server:/backups/
```

### 復旧手順
```bash
# データベース復旧
docker compose exec -T db psql -U postgres -d dental_system_production < backup.sql

# アプリケーション再起動
docker compose restart web sidekiq
```

---

## 📞 緊急時対応

### 障害発生時の連絡先
- **システム管理者**: admin@example.com
- **開発チーム**: dev-team@example.com
- **監視サービス**: UptimeRobot Dashboard

### 緊急コマンド
```bash
# 緊急停止
docker compose down

# 前バージョンへロールバック
bundle exec cap production deploy:rollback

# メンテナンスページ表示
cp maintenance.html /var/www/dental_system/current/public/
```

---

## 📊 月額コスト（¥5,000以内）

| サービス | 月額コスト |
|---------|-----------|
| AWS Lightsail (2vCPU/4GB) | ¥3,500 |
| Redis ElastiCache | ¥1,500 |
| 監視ツール (無料枠) | ¥0 |
| SSL証明書 (Let's Encrypt) | ¥0 |
| **合計** | **¥5,000** |

---

## ✅ デプロイ完了確認

### 最終チェック項目
- [ ] HTTPSアクセス正常
- [ ] ログイン機能動作
- [ ] 予約機能テスト
- [ ] メール送信テスト
- [ ] バックアップ動作確認
- [ ] 監視アラート設定確認
- [ ] パフォーマンス基準達成

**🎉 デプロイ完了！医療系SaaS水準の本番環境が稼働開始しました。**