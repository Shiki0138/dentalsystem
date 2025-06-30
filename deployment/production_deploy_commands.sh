#!/bin/bash
# 史上最強歯科システム - 本番デプロイ実行スクリプト
# PRESIDENTの承認に基づく本番リリース

echo "🚀 史上最強歯科システム本番デプロイ開始"
echo "承認者: PRESIDENT"
echo "実行者: worker1"
echo "実行日時: $(date)"

# 1. 環境変数確認
echo "📋 環境変数チェック..."
if [ -z "$DATABASE_URL" ] || [ -z "$REDIS_URL" ] || [ -z "$SECRET_KEY_BASE" ]; then
    echo "❌ エラー: 必須環境変数が設定されていません"
    exit 1
fi
echo "✅ 環境変数確認完了"

# 2. Dockerイメージビルド
echo "🐳 Dockerイメージビルド..."
docker build -f Dockerfile.production -t dental-system:latest .
echo "✅ イメージビルド完了"

# 3. データベースマイグレーション
echo "🗄️ データベースマイグレーション..."
docker-compose -f docker-compose.production.yml run --rm web bundle exec rails db:migrate
echo "✅ マイグレーション完了"

# 4. アセットプリコンパイル
echo "📦 アセットプリコンパイル..."
docker-compose -f docker-compose.production.yml run --rm web bundle exec rails assets:precompile
echo "✅ アセット準備完了"

# 5. 本番環境起動
echo "🚀 本番環境起動..."
docker-compose -f docker-compose.production.yml up -d
echo "✅ システム起動完了"

# 6. ヘルスチェック
echo "🏥 ヘルスチェック実行..."
sleep 30
curl -f http://localhost/health || exit 1
echo "✅ システム正常稼働確認"

echo "🎉 史上最強歯科システム本番デプロイ完了！"
echo "📊 稼働率目標: 99.9%"
echo "⚡ 応答時間目標: <200ms"
echo "💰 月額コスト: <5,000円"