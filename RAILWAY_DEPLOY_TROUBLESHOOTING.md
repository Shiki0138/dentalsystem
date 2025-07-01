# 🚨 Railway デプロイ トラブルシューティングガイド

## 📋 現在の状況確認

### ✅ 完了済み修正
1. **Ruby バージョン**: 3.3.8 → 3.3.0
2. **Gemfile.lock**: 削除（Railway側で生成）
3. **Dockerfile**: Gemfile.lockをオプショナルに
4. **nixpacks.toml**: デプロイメントモード無効化
5. **PostgreSQL設定**: GINインデックス簡素化

### 📊 最新コミット
```
09f0780 fix: Gemfile.lock不在エラーに対応
2ff5ed9 fix: Ruby バージョンを3.3.0に統一
738a594 fix: Railway デプロイエラー修正
```

---

## 🔧 よくあるエラーと解決策

### 1. ビルドエラー: Gemfile.lock not found
**症状**: Dockerfile で Gemfile.lock が見つからない

**解決策**: ✅ 実施済み
- Dockerfile修正: `COPY Gemfile.lock* ./`
- nixpacks.toml: deployment false

---

### 2. Ruby バージョン不一致
**症状**: Ruby version mismatch エラー

**解決策**: ✅ 実施済み
- Gemfile: `ruby "3.3.0"`
- Dockerfile: `FROM ruby:3.3.0-slim`

---

### 3. PostgreSQL エクステンションエラー
**症状**: pg_trgm extension エラー

**解決策**: ✅ 実施済み
- マイグレーションファイル修正
- GINインデックスを通常インデックスに変更

---

### 4. アセットプリコンパイルエラー
**症状**: Assets precompile failed

**対処法**:
```bash
# ローカルで確認
RAILS_ENV=production bundle exec rails assets:precompile
```

**Railway環境変数追加**:
```
NODE_ENV = production
RAILS_SERVE_STATIC_FILES = true
```

---

### 5. データベース接続エラー
**症状**: ActiveRecord::ConnectionNotEstablished

**確認事項**:
1. PostgreSQL サービス追加済みか
2. DATABASE_URL 自動設定されているか
3. production.rb の設定確認

---

## 🚀 Railway Web UIでの確認手順

### 1. ビルドログ確認
```
Project → Deployments → 最新デプロイ → View Logs
```

### 2. 環境変数確認
```
Project → Settings → Environment Variables
```

必須環境変数:
- `RAILS_ENV = production`
- `RAILS_SERVE_STATIC_FILES = true`
- `RAILS_LOG_TO_STDOUT = true`
- `SECRET_KEY_BASE = [生成済みキー]`
- `DATABASE_URL = [自動設定]`

### 3. サービス構成確認
```
Project → Services
```
- web サービス（Rails アプリ）
- PostgreSQL サービス

---

## 🆘 追加のトラブルシューティング

### メモリ不足エラー
```
Error: Process killed (exit code 137)
```

**解決策**:
1. Hobby Plan ($5/月) にアップグレード
2. または、ビルドコマンドを軽量化

### ポート設定エラー
```
Error: Web process failed to bind to $PORT
```

**解決策**:
railway.toml で確認:
```toml
[deploy]
startCommand = "bundle exec rails server -p $PORT -e $RAILS_ENV"
```

---

## 📞 サポートリソース

### Railway 公式
- ドキュメント: https://docs.railway.app
- ステータス: https://status.railway.app
- Discord: https://discord.gg/railway

### このプロジェクト
- GitHub: https://github.com/Shiki0138/dentalsystem
- ローカルテスト: `./scripts/start-local-test.sh`

---

## ✅ デプロイ成功確認チェックリスト

- [ ] Build Successful 表示
- [ ] Deploy Successful 表示
- [ ] Generated Domain でアクセス可能
- [ ] ログイン画面表示
- [ ] データベース接続確認
- [ ] アセット（CSS/JS）読み込み確認

---

## 🎯 次のアクション

1. **Railway Dashboard** で最新ビルドログ確認
2. エラーがある場合、このガイドで対処法確認
3. 環境変数の設定漏れチェック
4. 必要に応じて再デプロイ（Settings → Redeploy）