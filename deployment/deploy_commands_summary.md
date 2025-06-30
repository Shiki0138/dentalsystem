# 🚀 デプロイコマンドサマリー

## 📋 クイックリファレンス

### 1️⃣ GitHub Actions経由（推奨）

```bash
# mainブランチにプッシュすると自動デプロイ
git add .
git commit -m "Deploy: Production release"
git push origin main
```

### 2️⃣ 手動デプロイ

```bash
# 環境変数設定（.env.productionファイルに記載）
source .env.production

# デプロイ実行
./scripts/deploy.sh
```

### 3️⃣ デプロイ状況確認

```bash
# GitHub Actions
# https://github.com/[your-org]/dentalsystem/actions

# 本番環境ヘルスチェック
curl https://your-domain.com/health

# ログ確認（SSH接続後）
sudo journalctl -u dentalsystem -f
```

### 4️⃣ ロールバック

```bash
# 自動ロールバック（デプロイ失敗時）
# GitHub Actionsが自動実行

# 手動ロールバック
./scripts/rollback.sh
```

### 5️⃣ 緊急停止

```bash
# SSH接続後
sudo systemctl stop dentalsystem
sudo systemctl stop nginx
```

---

## 🔍 デプロイ前チェックコマンド

```bash
# 全体チェック
ruby bin/deploy_check.rb

# テスト実行
bundle exec rspec

# セキュリティチェック
bundle exec brakeman

# 環境変数確認
env | grep -E "(RAILS|DATABASE|REDIS|SECRET)"
```

---

## 📊 デプロイ後確認コマンド

```bash
# サービス状態確認
systemctl status dentalsystem
systemctl status nginx
systemctl status postgresql
systemctl status redis

# ディスク使用率
df -h

# メモリ使用率
free -m

# プロセス確認
ps aux | grep -E "(puma|rails)"

# ポート確認
sudo netstat -tlnp
```

---

## 🛠️ トラブルシューティングコマンド

```bash
# アプリケーションログ
tail -f /var/www/dentalsystem/log/production.log

# システムログ
sudo journalctl -xe

# データベース接続テスト
rails db:migrate:status RAILS_ENV=production

# アセット再コンパイル
rails assets:precompile RAILS_ENV=production

# キャッシュクリア
rails tmp:clear RAILS_ENV=production
redis-cli FLUSHALL
```

---

## 📱 通知コマンド

```bash
# Slack通知（デプロイ成功）
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"✅ Dental System deployed successfully to production"}' \
  $SLACK_WEBHOOK_URL

# Slack通知（デプロイ失敗）
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"❌ Dental System deployment failed"}' \
  $SLACK_WEBHOOK_URL
```

---

**重要**: すべてのコマンドは適切な権限とバックアップを確認してから実行してください。