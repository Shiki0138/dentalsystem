#!/bin/bash

echo "=== 歯科クリニック予約・業務管理システム サーバー起動 ==="
echo ""

# Ruby環境設定
export PATH="$HOME/.rbenv/shims:$PATH"

# 環境変数設定
export DATABASE_URL="postgres://localhost/dentalsystem_development"
export REDIS_URL="redis://localhost:6379/0"
export RAILS_ENV="development"
export SECRET_KEY_BASE="demo-secret-key-base-for-local-development-only"
export RAILS_MASTER_KEY="demo-master-key"
export RAILS_LOG_TO_STDOUT=true

# ポート確認
PORT=${PORT:-3001}

echo "サーバーを起動しています..."
echo "URL: http://localhost:$PORT"
echo ""
echo "停止するには Ctrl+C を押してください"
echo ""

# Railsサーバー起動
bundle exec rails server -p $PORT -b 0.0.0.0