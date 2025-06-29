# 🚀 歯科クリニック予約・業務管理システム デプロイチェックリスト

## 📋 デプロイ前確認事項

### ✅ 本番環境準備
- [ ] AWS Lightsail インスタンス作成（2 vCPU / 4 GB）
- [ ] Docker & Docker Compose インストール
- [ ] SSL証明書取得・設定（Let's Encrypt推奨）
- [ ] ドメイン名設定・DNS設定
- [ ] セキュリティグループ設定（80, 443, 22番ポート）

### ✅ 環境変数設定
本番環境用 `.env.production` ファイルを作成：

```bash
# データベース設定
DATABASE_NAME=dental_system_production
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=<強力なパスワード>

# Rails設定
SECRET_KEY_BASE=<rails secret で生成>
DEVISE_SECRET_KEY=<rails secret で生成>
RAILS_ENV=production

# LINE API設定
LINE_CHANNEL_SECRET=<LINE Developer Console から取得>
LINE_CHANNEL_TOKEN=<LINE Developer Console から取得>

# メール設定（Gmail IMAP）
GMAIL_USERNAME=<医院のGmailアドレス>
GMAIL_PASSWORD=<アプリパスワード>

# SMS設定（オプション）
TWILIO_ACCOUNT_SID=<Twilioアカウント>
TWILIO_AUTH_TOKEN=<Twilioトークン>

# 監視設定
UPTIME_ROBOT_API_KEY=<UptimeRobot API キー>
GRAFANA_CLOUD_TOKEN=<Grafana Cloud トークン>
```

### ✅ セキュリティ設定
- [ ] 強力なデータベースパスワード設定
- [ ] SECRET_KEY_BASE 生成・設定
- [ ] SSL/TLS証明書設定（TLS 1.2+）
- [ ] ファイアウォール設定
- [ ] 2FA認証有効化
- [ ] バックアップ設定

## 🚀 デプロイ手順

### 1. 初回デプロイ
```bash
# リポジトリクローン
git clone git@github.com:your-org/dental-system.git
cd dental-system

# 本番環境設定ファイル配置
cp .env.production.example .env.production
# 環境変数を編集

# Docker本番環境起動
docker-compose -f docker-compose.production.yml up -d

# データベース初期化
docker-compose -f docker-compose.production.yml exec web bundle exec rails db:create
docker-compose -f docker-compose.production.yml exec web bundle exec rails db:migrate

# 管理者ユーザー作成
docker-compose -f docker-compose.production.yml exec web bundle exec rails console
# User.create!(email: 'admin@clinic.com', password: 'secure_password', role: 'admin')
```

### 2. CI/CD デプロイ（推奨）
```bash
# GitHub Secrets設定
DEPLOY_HOST=<サーバーIPアドレス>
DEPLOY_USER=<デプロイユーザー>
SSH_PRIVATE_KEY=<SSH秘密鍵>
SECRET_KEY_BASE=<Railsシークレット>
DATABASE_PASSWORD=<DBパスワード>
LINE_CHANNEL_SECRET=<LINEシークレット>
LINE_CHANNEL_TOKEN=<LINEトークン>

# Capistrano デプロイ実行
bundle exec cap production deploy:initial
```

## 📊 デプロイ後確認事項

### ✅ 動作確認
- [ ] ヘルスチェック: `curl https://yourdomain.com/up`
- [ ] ログイン画面表示確認
- [ ] 患者登録機能確認
- [ ] 予約作成機能確認
- [ ] リマインダー配信確認
- [ ] 2FA認証確認

### ✅ パフォーマンス確認
- [ ] レスポンス時間 < 1秒（95パーセンタイル）
- [ ] データベース接続確認
- [ ] Sidekiqジョブ処理確認
- [ ] メモリ使用量 < 2GB
- [ ] CPU使用率 < 70%

### ✅ セキュリティ確認
- [ ] HTTPS強制リダイレクト
- [ ] セキュリティヘッダー設定確認
- [ ] レート制限動作確認
- [ ] 管理画面アクセス制限確認
- [ ] ログファイル権限確認

## 🔧 監視設定

### UptimeRobot 設定
1. UptimeRobot アカウント作成（無料）
2. モニター設定：
   - URL: `https://yourdomain.com/up`
   - 間隔: 5分
   - アラート: メール通知

### Grafana Cloud 設定
1. Grafana Cloud アカウント作成（無料枠）
2. Prometheus Agent設定
3. アラートルール設定：
   - エラー率 > 5%
   - レスポンス時間 > 2秒
   - ディスク使用率 > 80%

## 🚨 トラブルシューティング

### よくある問題と解決策

#### データベース接続エラー
```bash
# データベースコンテナ確認
docker-compose -f docker-compose.production.yml ps
docker-compose -f docker-compose.production.yml logs db

# 接続テスト
docker-compose -f docker-compose.production.yml exec web bundle exec rails db:version
```

#### SSL証明書エラー
```bash
# Let's Encrypt証明書取得
sudo certbot certonly --webroot -w /var/www/html -d yourdomain.com

# 証明書更新設定
sudo crontab -e
# 0 2 * * * /usr/bin/certbot renew --quiet
```

#### メモリ不足
```bash
# Docker リソース使用状況確認
docker stats

# 不要なイメージ・コンテナ削除
docker system prune -a
```

## 📈 本番運用

### 定期メンテナンス
- [ ] 週次ログローテーション
- [ ] 月次データベースバックアップ
- [ ] 四半期セキュリティ更新
- [ ] 年次SSL証明書更新

### KPI監視
- [ ] 予約重複率 < 0.1%
- [ ] 前日キャンセル率 < 5%
- [ ] 予約登録時間 < 30秒
- [ ] システム稼働率 > 99.9%

### 緊急時連絡先
- システム管理者: admin@clinic.com
- インフラ担当: infra@clinic.com
- 24時間サポート: support@clinic.com

---

**✅ チェックリスト完了後、本格運用開始！**