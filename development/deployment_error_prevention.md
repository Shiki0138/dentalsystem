# 🛡️ デプロイメントエラー防止ガイドライン

## 📋 概要
本ガイドラインは、システム開発から本番環境デプロイまでのエラーを最小限に抑えるための開発方針を定めたものです。
全ての開発者（PRESIDENT、boss、worker）は、このガイドラインに従って開発を行うことを必須とします。

## 🎯 基本原則

### 1. 環境変数の完全管理
- **開発初期から環境変数を明確に定義**
- **ローカル、ステージング、本番で同じ変数名を使用**
- **デプロイ前に全環境変数の存在と値を確認**

### 2. エラーの事前防止
- **ローカルでのビルドテストを必須化**
- **デプロイ前の包括的なチェックリスト実行**
- **段階的デプロイ（開発→ステージング→本番）**

### 3. 依存関係の厳密な管理
- **バージョンの固定と明示的な記載**
- **開発環境と本番環境の完全一致**
- **定期的な依存関係の更新と検証**

## 🔍 Railway/Vercel デプロイ特有の注意事項

### データベース接続
```yaml
必須確認事項:
- PostgreSQL接続URLの正確性
- SSL設定の有効化（本番環境）
- 接続プールの適切な設定
- タイムアウト設定の調整
```

### CORS設定
```yaml
チェックリスト:
- 本番ドメインの許可リスト登録
- APIエンドポイントのCORS設定
- 認証リダイレクトURIの設定
- プリフライトリクエストの処理
```

### 環境変数チェックリスト
```yaml
Rails/Railway:
- DATABASE_URL
- RAILS_ENV
- SECRET_KEY_BASE
- RAILS_MASTER_KEY
- RAILS_SERVE_STATIC_FILES
- RAILS_LOG_TO_STDOUT

Next.js/Vercel:
- NEXT_PUBLIC_API_URL
- DATABASE_URL
- NEXTAUTH_URL
- NEXTAUTH_SECRET
```

## 📝 デプロイ前チェックリスト

### 1. ビルドテスト
```bash
# ローカルでの本番ビルド
RAILS_ENV=production bundle exec rails assets:precompile
RAILS_ENV=production bundle exec rails db:migrate

# または Next.js の場合
npm run build
npm run start
```

### 2. 環境変数検証スクリプト
```ruby
# lib/tasks/deployment_check.rake
namespace :deployment do
  desc "デプロイ前の環境変数チェック"
  task check_env: :environment do
    required_vars = %w[
      DATABASE_URL
      SECRET_KEY_BASE
      RAILS_MASTER_KEY
    ]
    
    missing_vars = required_vars.select { |var| ENV[var].blank? }
    
    if missing_vars.any?
      puts "❌ 必須環境変数が不足: #{missing_vars.join(', ')}"
      exit 1
    else
      puts "✅ 全ての必須環境変数が設定されています"
    end
  end
end
```

### 3. デプロイスクリプトテンプレート
```bash
#!/bin/bash
# scripts/safe-deploy.sh

echo "🛡️ セーフデプロイ開始"

# 1. 環境変数チェック
echo "1️⃣ 環境変数チェック"
rails deployment:check_env || exit 1

# 2. ビルドテスト
echo "2️⃣ ビルドテスト"
RAILS_ENV=production bundle exec rails assets:precompile || exit 1

# 3. データベース接続テスト
echo "3️⃣ データベース接続テスト"
RAILS_ENV=production bundle exec rails db:version || exit 1

# 4. デプロイ実行
echo "4️⃣ デプロイ実行"
railway up

echo "✅ デプロイ完了"
```

## 🚨 エラー回避のベストプラクティス

### 1. 段階的リリース
```yaml
フロー:
1. 開発環境でのテスト
2. ステージング環境での検証
3. 本番環境への限定的リリース
4. 完全リリース
```

### 2. ロールバック戦略
```yaml
準備事項:
- デプロイ前のコミットハッシュ記録
- データベースバックアップ
- 環境変数のバックアップ
- ロールバックスクリプトの準備
```

### 3. モニタリング設定
```yaml
監視項目:
- エラーレート
- レスポンスタイム
- データベース接続数
- メモリ使用率
```

## 📋 開発者向け指示

### PRESIDENT
- このガイドラインの遵守を監督
- デプロイ承認前のチェックリスト確認
- エラー発生時の最終判断

### boss1
- チーム全体へのガイドライン周知
- デプロイ前チェックの実施確認
- エラー防止策の継続的改善

### workers
- ガイドラインに従った開発
- ローカルでのテスト徹底
- エラー発生時の即座の報告

## 🔄 継続的改善

### エラーログの分析
- デプロイ後のエラーを記録
- 原因分析と対策の文書化
- ガイドラインへのフィードバック

### 定期レビュー
- 月次でのガイドライン見直し
- 新しいエラーパターンの追加
- ベストプラクティスの更新

## ⚡ 緊急時対応

### エラー発生時のフロー
1. エラーログの収集
2. 影響範囲の特定
3. ロールバックの判断
4. 修正とテスト
5. 再デプロイ

### 連絡体制
- PROSIDENTへの即時報告
- チーム内での情報共有
- ユーザーへの通知（必要時）

---

**重要**: このガイドラインは生きた文書です。新しいエラーパターンや解決策が見つかった場合は、即座に更新してください。