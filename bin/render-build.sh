#!/usr/bin/env bash
# Render.com用ビルドスクリプト
set -o errexit

echo "🚀 Starting Render build for Dental System..."

# Ruby version確認
echo "Ruby version: $(ruby --version)"

# Bundler更新
gem update --system --no-document
gem install bundler --no-document

# 依存関係インストール
echo "📦 Installing dependencies..."
bundle config --local deployment true
bundle config --local without 'development test'
bundle install --jobs=4 --retry=3

# Node.js/Yarn確認（必要な場合）
if [ -f "package.json" ]; then
  echo "📦 Installing Node.js dependencies..."
  npm install
fi

# アセットプリコンパイル
echo "🎨 Compiling assets..."
bundle exec rake assets:precompile

# 古いアセット削除
echo "🧹 Cleaning old assets..."
bundle exec rake assets:clean

# データベースセットアップ
echo "🗄️ Setting up database..."
if [ "$RAILS_ENV" = "production" ]; then
  # 本番環境の場合のみマイグレーション実行
  bundle exec rake db:create db:migrate
  
  # デモデータ作成（条件付き）
  if [ "$DEMO_MODE_ENABLED" = "true" ]; then
    echo "🎬 Creating demo data..."
    bundle exec rake db:seed
  fi
else
  # 開発環境
  bundle exec rake db:setup
fi

echo "✅ Build completed successfully!"
echo "🎊 Dental System is ready for deployment!"