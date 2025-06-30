# 💰 超低コスト歯科システム本番デプロイガイド 2024

## 🎯 最安構成（月額 $0-8）

### 1. Railway（推奨）- 月額 $8-20
**最もバランスが取れた選択**
```bash
# 1. Railway登録（GitHubアカウントで）
# https://railway.app

# 2. GitHub連携デプロイ
git push origin main

# 3. Railway自動検出・デプロイ
# PostgreSQL + Redis自動追加
```

**コスト内訳:**
- Web Service: $5/月
- PostgreSQL: $3/月 
- Redis: $0/月（小規模なら無料枠）
- **合計: $8/月**

---

### 2. Render（次点）- 月額 $7-21
```bash
# 1. Render登録
# https://render.com

# 2. Web Service作成
# GitHub連携でauto-deploy

# 3. PostgreSQL追加（$7/月）
```

**コスト内訳:**
- Web Service: $7/月
- PostgreSQL: $7/月
- Redis: $7/月
- **合計: $21/月**

---

### 3. 🏆 最安オプション: Railway Hobby（月額 $5）

**制限あり** だが小規模なら十分:
- 512MB RAM
- $5クレジット/月
- PostgreSQL込み
- カスタムドメイン可

```bash
# 環境変数設定（最小限）
RAILS_ENV=production
SECRET_KEY_BASE=xxx
DATABASE_URL=postgresql://...
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true
```

---

## 🚀 5分デプロイ手順（Railway）

### ステップ1: Railway準備
```bash
# 1. Railway CLI インストール
npm install -g @railway/cli

# 2. ログイン
railway login

# 3. プロジェクト作成
railway new
```

### ステップ2: デプロイ設定
```bash
# railway.toml作成
cat > railway.toml << 'EOF'
[build]
builder = "NIXPACKS"

[deploy]
startCommand = "bundle exec rails server -p $PORT"
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 3

[environments.production]
name = "dental-system-prod"
EOF
```

### ステップ3: 環境変数設定
```bash
# 必須環境変数
railway variables set RAILS_ENV=production
railway variables set SECRET_KEY_BASE=$(rails secret)
railway variables set RAILS_SERVE_STATIC_FILES=true
railway variables set RAILS_LOG_TO_STDOUT=true

# データベース（自動設定）
railway add postgresql
railway add redis  # 必要に応じて
```

### ステップ4: デプロイ実行
```bash
# GitHubからデプロイ
railway connect  # GitHub repo選択
railway deploy   # 初回デプロイ

# または直接デプロイ
git push railway main
```

---

## 🔧 本番用最適化（必須）

### 1. 環境設定最適化
```ruby
# config/environments/production.rb
Rails.application.configure do
  config.force_ssl = true
  config.log_level = :info
  config.assets.compile = false
  config.assets.digest = true
  
  # Database pool optimization
  config.database_pool_size = ENV.fetch("DATABASE_POOL_SIZE", 5).to_i
  
  # Cache configuration
  config.cache_store = :redis_cache_store, {
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
    pool_size: 5,
    pool_timeout: 5
  }
end
```

### 2. Gemfile最適化
```ruby
# 本番で不要なgemを除外
group :development, :test do
  gem 'byebug'
  gem 'rspec-rails'
  # 本番では読み込まれない
end

# 本番最適化
gem 'bootsnap', require: false
gem 'image_processing', '~> 1.2'  # ActiveStorage用
```

### 3. Database最適化
```bash
# マイグレーション実行
railway run rails db:migrate

# 本番データ初期化
railway run rails db:seed
```

---

## 📱 ドメイン設定（無料）

### 1. 無料ドメイン取得
- **Freenom**: .tk, .ml, .ga ドメイン
- **Cloudflare**: DNS管理（無料）

### 2. Railway カスタムドメイン
```bash
# Railwayでドメイン追加
railway domain add yourdomain.com

# DNS設定（Cloudflareなど）
# CNAME: yourdomain.com → xxx.up.railway.app
```

---

## 🔒 セキュリティ（無料で強化）

### 1. 環境変数暗号化
```bash
# Rails credentialsを使用
rails credentials:edit --environment=production

# production.key をRailwayに設定
railway variables set RAILS_MASTER_KEY=xxx
```

### 2. SSL/HTTPS（自動）
```ruby
# config/environments/production.rb
config.force_ssl = true
config.ssl_options = {
  redirect: { status: 301, port: 443 }
}
```

---

## 📊 監視・ログ（無料）

### 1. ヘルスチェック
```ruby
# config/routes.rb
get '/health', to: 'application#health'

# app/controllers/application_controller.rb
def health
  render json: { status: 'ok', timestamp: Time.current }
end
```

### 2. エラー監視（無料枠）
```ruby
# Gemfile
gem 'sentry-ruby'
gem 'sentry-rails'

# config/initializers/sentry.rb
Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.environment = Rails.env
end
```

---

## 💾 バックアップ戦略（低コスト）

### 1. Database バックアップ
```bash
# Railway CLI でバックアップ
railway pg:backups

# 定期バックアップ（GitHub Actions）
name: DB Backup
on:
  schedule:
    - cron: '0 2 * * *'  # 毎日2時
jobs:
  backup:
    runs-on: ubuntu-latest
    steps:
    - name: Backup Database
      run: |
        railway pg:dump > backup.sql
        # S3やGoogleDriveにアップロード
```

### 2. コードバックアップ
- GitHub（無料プライベートリポジトリ）
- 定期的なブランチ作成

---

## 🎯 コスト比較（年額）

| プラットフォーム | 月額 | 年額 | 特徴 |
|-----------------|------|------|------|
| **Railway Hobby** | $5 | $60 | 小規模向け、全部込み |
| **Railway Pro** | $8-20 | $96-240 | 本格運用、高性能 |
| **Render** | $21 | $252 | 安定、高性能 |
| **Heroku** | $25+ | $300+ | 実績豊富、高コスト |
| **VPS自管理** | $5-10 | $60-120 | 管理コスト大 |

## 🏆 最終推奨

**小規模クリニック（〜50人/日）**: Railway Hobby ($5/月)
**中規模クリニック（50-200人/日）**: Railway Pro ($8-20/月)

### デプロイ実行コマンド
```bash
# 1分でデプロイ開始
git clone https://github.com/Shiki0138/dentalsystem.git
cd dentalsystem
npm install -g @railway/cli
railway login
railway new
railway connect
railway add postgresql
railway variables set RAILS_ENV=production
railway variables set SECRET_KEY_BASE=$(openssl rand -hex 32)
railway deploy
```

**🎉 5-10分で本番環境完成！**

---

## 📞 サポート・トラブルシューティング

### よくある問題
1. **アセットコンパイルエラー**: `rails assets:precompile` 実行
2. **DB接続エラー**: 環境変数 `DATABASE_URL` 確認
3. **SSL証明書**: Railwayは自動設定、48時間待機

### 緊急時対応
```bash
# ログ確認
railway logs

# 環境変数確認
railway variables

# ロールバック
railway rollback
```

**月額$5から始める本格的な歯科システム運用が可能です！**