# 🚀 Railway デプロイ完全ガイド

## ✅ 準備完了

### 📁 作成済みファイル
- ✅ `railway.toml` - Railway設定
- ✅ `Procfile` - 起動コマンド
- ✅ `.env.production` - 環境変数テンプレート
- ✅ `config/environments/production.rb` - 本番設定最適化
- ✅ `app/models/application_record.rb` - 基底モデル
- ✅ `config/initializers/devise.rb` - 認証設定

### 📤 GitHubコミット完了
- コミット: `90ba040`
- リポジトリ: https://github.com/Shiki0138/dentalsystem.git

---

## 🚀 Railway デプロイ手順

### ステップ1: Railway アカウント作成・ログイン
```bash
# Railway公式サイトでアカウント作成
# https://railway.app

# GitHubアカウントでサインアップ推奨
```

### ステップ2: Railway CLI インストール（オプション）
```bash
# npm経由でインストール
npm install -g @railway/cli

# ログイン
railway login

# プロジェクト確認
railway status
```

### ステップ3: Web UIでプロジェクト作成
```
1. Railway Dashboard → "New Project"
2. "Deploy from GitHub repo" 選択
3. "Shiki0138/dentalsystem" を選択
4. "Deploy Now" クリック
```

### ステップ4: データベース追加
```
1. Project Dashboard → "Add Service"
2. "Add Database" → "PostgreSQL" 選択
3. 自動でDATABASE_URL環境変数が設定される
```

### ステップ5: Redis追加（推奨）
```
1. Project Dashboard → "Add Service"  
2. "Add Database" → "Redis" 選択
3. 自動でREDIS_URL環境変数が設定される
```

### ステップ6: 環境変数設定
```
Project → Settings → Environment Variables

必須設定:
RAILS_ENV = production
RAILS_SERVE_STATIC_FILES = true
RAILS_LOG_TO_STDOUT = true
SECRET_KEY_BASE = [生成されたキー]

オプション設定:
RAILS_MASTER_KEY = [credentials key]
LINE_CHANNEL_SECRET = [LINE設定]
LINE_CHANNEL_ACCESS_TOKEN = [LINE設定]
```

### ステップ7: シークレットキー生成
```bash
# ローカルで生成（コピーして環境変数に設定）
openssl rand -hex 32

# または
ruby -rsecurerandom -e 'puts SecureRandom.hex(32)'
```

### ステップ8: デプロイ実行
```
1. 環境変数設定後、自動リデプロイ開始
2. Build Logs確認
3. Deploy成功まで5-10分待機
```

### ステップ9: データベース初期化
```bash
# Railway CLI経由（推奨）
railway run rails db:create
railway run rails db:migrate
railway run rails db:seed

# または Web UI の Console から実行
```

### ステップ10: ドメイン確認
```
1. Project → Settings → Domains
2. Generated Domain: https://[project-name].up.railway.app
3. カスタムドメイン設定可能
```

---

## 🔧 環境変数設定詳細

### 必須環境変数
```bash
RAILS_ENV=production
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true
SECRET_KEY_BASE=<32文字以上のランダム文字列>
DATABASE_URL=<自動設定>
```

### 推奨環境変数
```bash
REDIS_URL=<自動設定>
RAILS_MAX_THREADS=5
WEB_CONCURRENCY=2
DATABASE_POOL_SIZE=5
```

### 外部連携（必要に応じて）
```bash
LINE_CHANNEL_SECRET=<LINE Developer設定>
LINE_CHANNEL_ACCESS_TOKEN=<LINE Developer設定>
GOOGLE_CLIENT_ID=<Google API設定>
GOOGLE_CLIENT_SECRET=<Google API設定>
```

---

## 🔍 デプロイ後確認事項

### 1. アプリケーション動作確認
```bash
# アプリケーションURL確認
https://[your-project].up.railway.app

# ヘルスチェック
curl https://[your-project].up.railway.app/health
```

### 2. データベース確認
```bash
# Railway CLI でDB接続確認
railway connect postgresql

# テーブル確認
\dt

# ユーザーテーブル確認
SELECT * FROM users LIMIT 5;
```

### 3. ログ確認
```bash
# Railway CLI でログ確認
railway logs

# リアルタイムログ
railway logs --tail
```

---

## 🛠️ トラブルシューティング

### Build Error対応
```bash
# Gemfile.lock削除して再ビルド
rm Gemfile.lock
git add Gemfile.lock
git commit -m "Remove Gemfile.lock for Railway"
git push origin master
```

### Database Migration Error
```bash
# 手動でマイグレーション実行
railway run rails db:migrate RAILS_ENV=production

# または強制リセット（開発時のみ）
railway run rails db:drop db:create db:migrate
```

### Static Assets Error
```bash
# アセットプリコンパイル確認
railway run rails assets:precompile

# 環境変数確認
RAILS_SERVE_STATIC_FILES=true
```

### SSL/HTTPS Issues
```bash
# production.rbに追加
config.force_ssl = true
config.ssl_options = { redirect: { status: 301, port: 443 } }
```

---

## 📊 予想されるコスト

### Hobby Plan（推奨）
- **Web Service**: $5/月
- **PostgreSQL**: 無料枠内
- **Redis**: 無料枠内
- **合計**: **$5/月**

### Pro Plan（本格運用）
- **Web Service**: $20/月
- **PostgreSQL**: $5/月
- **Redis**: $3/月
- **合計**: **$28/月**

---

## 🎯 デプロイ完了後のタスク

### 1. 初期データ作成
```bash
railway run rails runner "
User.create!(
  email: 'admin@dental.jp',
  password: 'password123',
  name: '管理者',
  role: 'admin'
)
"
```

### 2. カスタムドメイン設定
```
1. DNS設定でCNAME追加
2. Railway → Settings → Domains → Add Domain
3. SSL証明書自動発行（数分〜1時間）
```

### 3. 監視設定
```bash
# Sentry等のエラー監視サービス統合
# UptimeRobot等の稼働監視設定
```

---

## ✅ チェックリスト

### 事前準備
- [ ] GitHubリポジトリ最新状態
- [ ] railway.toml作成済み
- [ ] Procfile設定済み
- [ ] 本番環境設定完了

### デプロイ実行
- [ ] Railway プロジェクト作成
- [ ] GitHub連携完了
- [ ] PostgreSQL追加
- [ ] 環境変数設定
- [ ] 初回デプロイ成功

### 動作確認
- [ ] URL アクセス可能
- [ ] ログイン機能動作
- [ ] データベース接続確認
- [ ] 主要機能テスト

---

**🎉 これで歯科クリニックシステムが月額$5でRailway本番運用開始です！**