# 🚀 Railway デプロイ手順

Railway CLIは対話型のため、以下のコマンドを順番に手動で実行してください。

## 1. Railwayログイン
```bash
railway login
```

## 2. プロジェクト作成
```bash
railway init
```

## 3. PostgreSQL追加
```bash
railway add
```
→ PostgreSQLを選択

## 4. 環境変数設定
```bash
railway variables set RAILS_ENV=production
railway variables set BETA_MODE=true  
railway variables set BETA_ACCESS_CODE=dental2024beta
railway variables set RAILS_SERVE_STATIC_FILES=true
railway variables set RAILS_LOG_TO_STDOUT=true
railway variables set SECRET_KEY_BASE=$(openssl rand -hex 64)
railway variables set WEB_CONCURRENCY=2
railway variables set RAILS_MAX_THREADS=5
```

## 5. デプロイ
```bash
railway up
```

## 6. マイグレーション（デプロイ完了後）
```bash
railway run rails db:create
railway run rails db:migrate
railway run rails beta:setup
```

## 7. URL確認
```bash
railway domain
```

アクセスコード: `dental2024beta`