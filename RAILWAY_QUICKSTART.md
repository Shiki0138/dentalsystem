# ⚡ Railway 5分デプロイ クイックスタート

## 🎯 前提条件
- ✅ GitHubアカウント
- ✅ リポジトリ: https://github.com/Shiki0138/dentalsystem.git
- ✅ デプロイ設定完了

## 🚀 5分でデプロイ

### ステップ1: Railway登録 (1分)
```
1. https://railway.app にアクセス
2. "Login with GitHub" クリック
3. GitHub認証完了
```

### ステップ2: プロジェクト作成 (30秒)
```
1. "New Project" クリック
2. "Deploy from GitHub repo" 選択
3. "Shiki0138/dentalsystem" を選択
4. "Deploy Now" クリック
```

### ステップ3: PostgreSQL追加 (30秒)
```
1. "+ New" → "Database" → "Add PostgreSQL"
2. 自動でDATABASE_URL設定される
```

### ステップ4: 環境変数設定 (2分)
```
Settings → Environment Variables → Add Variable

必須設定:
RAILS_ENV = production
RAILS_SERVE_STATIC_FILES = true  
RAILS_LOG_TO_STDOUT = true
SECRET_KEY_BASE = [下記で生成]
```

### ステップ5: シークレットキー生成
```bash
# ローカルターミナルで実行
./scripts/generate-secrets.sh

# または手動生成
openssl rand -hex 32
```

### ステップ6: デプロイ完了待機 (1分)
```
環境変数設定後、自動リデプロイ開始
Build完了まで待機
```

---

## ✅ デプロイ完了確認

### アクセス確認
```
Generated Domain: https://[project-name].up.railway.app
```

### 初期ユーザー作成
```bash
# Railway Console または CLI で実行
railway run rails runner "
User.create!(
  email: 'admin@dental.jp', 
  password: 'password123',
  name: '管理者',
  role: 'admin'
)
"
```

---

## 💰 料金プラン

### Hobby ($5/月) - 推奨
- 512MB RAM
- PostgreSQL込み
- カスタムドメイン可
- 小規模クリニック向け

### Pro ($20/月) - 本格運用
- 8GB RAM
- 高性能CPU
- 24時間サポート
- 中規模クリニック向け

---

## 🔧 デプロイ後の設定

### カスタムドメイン
```
1. DNS設定: CNAME your-domain.com → xxx.up.railway.app
2. Railway → Settings → Domains → Add Domain
3. SSL自動発行（15分-1時間）
```

### メンテナンスモード
```bash
# メンテナンス開始
railway run rails runner "File.write('tmp/maintenance.txt', 'メンテナンス中')"

# メンテナンス終了  
railway run rails runner "File.delete('tmp/maintenance.txt')"
```

---

## 📊 監視・ログ

### ログ確認
```bash
# Railway CLI
npm install -g @railway/cli
railway login
railway logs --tail
```

### エラー監視
```bash
# Sentry追加（無料枠5,000エラー/月）
# Gemfile追加: gem 'sentry-ruby'
# 環境変数: SENTRY_DSN=your_dsn
```

---

## 🎉 完了！

**🦷 歯科クリニックシステムがRailwayで本番運用開始**

- 💰 月額$5から
- 🚀 5分でデプロイ完了
- 🔒 SSL/HTTPS自動
- 📱 スマホ対応UI
- 🔄 自動バックアップ

### 主要機能
- ✅ 患者管理
- ✅ 予約システム  
- ✅ スタッフ管理
- ✅ ダッシュボード
- ✅ レポート機能

### ログイン情報
- **URL**: https://[your-project].up.railway.app
- **管理者**: admin@dental.jp / password123

---

## 📞 サポート

### トラブル時
```bash
# デプロイ状況確認
./scripts/railway-deploy-setup.sh

# 詳細ガイド
cat RAILWAY_DEPLOY_GUIDE.md
```

### 緊急時コマンド
```bash
# 即座にロールバック
railway rollback

# データベースリセット（開発時のみ）
railway run rails db:reset

# 強制再デプロイ
git commit --allow-empty -m "Force redeploy"
git push origin master
```

**🎊 Railway デプロイ完了！月額$5で本格運用開始です！**