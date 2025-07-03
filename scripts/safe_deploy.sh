#!/bin/bash

# セーフデプロイスクリプト - デプロイメントエラー防止ガイドライン準拠
# development/deployment_error_prevention.md で定められた必須手順を実行

echo "🛡️ セーフデプロイ開始 - ガイドライン準拠チェック"
echo "📋 development/deployment_error_prevention.md 準拠"
echo "======================================================"

# エラー時即座終了
set -e

# 1. 環境変数チェック
echo "1️⃣ 環境変数チェック"
bundle exec rails deployment:check_env || {
    echo "❌ 環境変数チェック失敗 - デプロイを中止します"
    exit 1
}

# 2. アセットプリコンパイル（ガイドライン必須）
echo ""
echo "2️⃣ アセットプリコンパイル（本番環境）"
echo "実行コマンド: RAILS_ENV=production bundle exec rails assets:precompile"
RAILS_ENV=production bundle exec rails assets:precompile || {
    echo "❌ アセットプリコンパイル失敗 - デプロイを中止します"
    exit 1
}

# 3. データベース接続テスト（ガイドライン必須）
echo ""
echo "3️⃣ データベース接続テスト"
echo "実行コマンド: rails deployment:db_connection_test"
bundle exec rails deployment:db_connection_test || {
    echo "❌ データベース接続テスト失敗 - デプロイを中止します"
    exit 1
}

# 4. マイグレーションテスト
echo ""
echo "4️⃣ マイグレーション実行テスト"
RAILS_ENV=production bundle exec rails db:migrate:status || {
    echo "❌ マイグレーション確認失敗 - デプロイを中止します"
    exit 1
}

# 5. 最終ビルド確認
echo ""
echo "5️⃣ 最終ビルド確認"
RAILS_ENV=production bundle exec rails runner "puts 'Rails boot test: OK'" || {
    echo "❌ Rails起動テスト失敗 - デプロイを中止します"
    exit 1
}

echo ""
echo "✅ 全てのデプロイ前チェックが完了しました"
echo "🚀 デプロイを実行しても安全です"
echo ""

# デプロイ実行（プラットフォーム別）
if command -v railway &> /dev/null; then
    echo "🚂 Railway デプロイを実行します..."
    railway up
elif command -v vercel &> /dev/null; then
    echo "▲ Vercel デプロイを実行します..."
    vercel --prod
elif [ -f "docker-compose.production.yml" ]; then
    echo "🐳 Docker 本番環境デプロイを実行します..."
    docker-compose -f docker-compose.production.yml up -d --build
else
    echo "⚠️  デプロイコマンドが見つかりません"
    echo "手動でデプロイを実行してください"
fi

echo ""
echo "🎉 セーフデプロイ完了！"
echo "📊 デプロイ後の監視を開始してください"