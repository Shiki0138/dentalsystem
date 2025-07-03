# 🚀 既存のdentalsystemプロジェクトへのデプロイ

## 1. プロジェクトにリンク
```bash
railway link
```
→ `dentalsystem` を選択

## 2. 環境変数を設定
```bash
# 一括設定スクリプトを作成
cat > setup_env_vars.sh << 'EOF'
#!/bin/bash
echo "Setting Railway environment variables..."
railway variables set RAILS_ENV=production
railway variables set BETA_MODE=true  
railway variables set BETA_ACCESS_CODE=dental2024beta
railway variables set RAILS_SERVE_STATIC_FILES=true
railway variables set RAILS_LOG_TO_STDOUT=true
railway variables set SECRET_KEY_BASE=$(openssl rand -hex 64)
railway variables set WEB_CONCURRENCY=2
railway variables set RAILS_MAX_THREADS=5
echo "Environment variables set successfully!"
EOF

chmod +x setup_env_vars.sh
./setup_env_vars.sh
```

## 3. デプロイ実行
```bash
railway up
```

## 4. デプロイ状態確認（3-5分待機）
```bash
# ログをリアルタイムで確認
railway logs --tail
```

## 5. データベースセットアップ
```bash
# DBが既に存在する場合はマイグレーションのみ
railway run rails db:migrate

# ベータ環境セットアップ
railway run rails beta:setup
```

## 6. URL確認
```bash
railway domain
```

## 🎯 アクセス情報
- URL: 上記コマンドで表示されるURL
- ベータログインページ: `/beta_login`
- アクセスコード: `dental2024beta`

## ⚡ トラブルシューティング

### 既存のデータを保持したい場合
```bash
# マイグレーションのみ実行
railway run rails db:migrate
```

### クリーンな状態から始めたい場合
```bash
# データベースをリセット（注意：全データが削除されます）
railway run rails db:drop
railway run rails db:create
railway run rails db:migrate
railway run rails beta:setup
```

### エラーログ確認
```bash
railway logs --tail 100
```