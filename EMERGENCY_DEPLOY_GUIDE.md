# 🚨 【緊急】代替デプロイ実行ガイド

**作成日時**: 2025-07-04 00:31 JST  
**緊急度**: 🔴 最高  
**想定時間**: 10-15分

---

## 🏆 推奨: Render即時デプロイ

### ステップ1: 必要ファイル確認
```bash
✅ render.yaml - 作成済み
✅ bin/render-build.sh - 作成済み（実行権限付与済み）
```

### ステップ2: Renderアカウント作成・接続
```bash
# 1. https://dashboard.render.com/ でアカウント作成
# 2. GitHub連携を有効化
# 3. "New" → "Web Service" クリック
# 4. GitHubリポジトリ選択
```

### ステップ3: 自動デプロイ実行
```bash
# render.yamlが自動検出される
# "Create Web Service" をクリック
# 自動的にビルド・デプロイ開始
```

### ステップ4: デプロイ完了確認
```bash
# 10-15分後にURL取得
# https://dentalsystem-xxxx.onrender.com
```

---

## 🚀 Railway代替デプロイ

### ステップ1: Railway CLI
```bash
npm install -g @railway/cli
railway login
```

### ステップ2: プロジェクト作成
```bash
railway new dentalsystem
cd dentalsystem
railway link
```

### ステップ3: データベース追加
```bash
railway add postgresql
railway add redis
```

### ステップ4: デプロイ実行
```bash
git add railway.json
git commit -m "Add Railway config"
railway up
```

---

## ⚡ Fly.io代替デプロイ

### ステップ1: Fly CLI
```bash
# macOS
brew install flyctl

# または
curl -L https://fly.io/install.sh | sh
```

### ステップ2: アプリ作成
```bash
flyctl auth login
flyctl launch --name dentalsystem --region nrt
```

### ステップ3: データベース追加
```bash
flyctl postgres create --name dentalsystem-db
flyctl redis create --name dentalsystem-redis
```

### ステップ4: デプロイ
```bash
flyctl deploy
```

---

## 🔥 緊急時即時対応

### 最速デプロイ（5分）
```bash
# 1. Renderアカウント作成
# 2. GitHub接続
# 3. リポジトリ選択
# 4. render.yaml自動検出
# 5. "Create Web Service" クリック

# 完了！
```

### URL確認方法
```bash
# Render
# ダッシュボードで確認: https://dashboard.render.com/

# Railway  
railway open

# Fly.io
flyctl open
```

---

## 📊 各環境のURL例

```yaml
Render: https://dentalsystem-abcd.onrender.com
Railway: https://dentalsystem-production.up.railway.app  
Fly.io: https://dentalsystem.fly.dev
```

---

## 🔄 既存Herokuからの移行

### 環境変数移行
```bash
# Heroku → Render
heroku config --shell > .env
# Renderダッシュボードで環境変数設定

# Heroku → Railway
heroku config --shell | railway variables set

# Heroku → Fly.io
heroku config --shell > fly.env
flyctl secrets import < fly.env
```

### データベース移行（必要な場合）
```bash
# Heroku PostgreSQL ダンプ
heroku pg:backups:capture
heroku pg:backups:download

# 新環境にリストア
# （各PaaSのドキュメント参照）
```

---

## ✅ 検証チェックリスト

### デプロイ後確認項目
- [ ] アプリケーション起動確認
- [ ] データベース接続確認  
- [ ] Redis接続確認
- [ ] SSL証明書確認
- [ ] デモモード動作確認
- [ ] AI機能動作確認
- [ ] WebSocket動作確認

### テストURL
```bash
# ヘルスチェック
curl https://[新URL]/health

# デモモード
https://[新URL]/dashboard/demo?demo=true
```

---

## 🆘 トラブルシューティング

### ビルドエラー
```bash
# Ruby version確認
echo "ruby '3.3.0'" > .ruby-version

# Bundler version
bundle --version
```

### データベースエラー
```bash
# マイグレーション確認
rails db:migrate:status

# 手動マイグレーション
rails db:migrate RAILS_ENV=production
```

### アセットエラー  
```bash
# プリコンパイル確認
RAILS_ENV=production rails assets:precompile
```

---

## 📞 緊急連絡先

### 技術サポート
- **Render**: Discord, Email
- **Railway**: Discord  
- **Fly.io**: Community Forum

### 内部エスカレーション
- **即座**: worker4 → PRESIDENT
- **技術**: worker1,2,3,5 → boss1

---

**🚀 準備完了！緊急時でも安心のデプロイ環境です！**

*緊急対応: 2025-07-04 00:31 / worker4*