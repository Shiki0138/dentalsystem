#!/bin/bash

# 本番デプロイスクリプト
set -e

echo "🚀 本番デプロイ開始..."

# 事前チェック
echo "📋 事前チェック実行中..."
bundle exec rails db:migrate:status
bundle exec rails runner "puts 'Rails環境確認: OK'"

# アセットプリコンパイル
echo "📦 アセットプリコンパイル..."
RAILS_ENV=production bundle exec rails assets:precompile

# データベースマイグレーション
echo "🗄️ データベースマイグレーション..."
bundle exec rails db:migrate

# サーバー再起動
echo "🔄 サーバー再起動..."
sudo systemctl restart puma

echo "✅ デプロイ完了"
