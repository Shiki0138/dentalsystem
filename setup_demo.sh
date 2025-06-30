#!/bin/bash

echo "=== 歯科クリニック予約・業務管理システム デモ環境セットアップ ==="
echo ""

# Ruby環境設定
export PATH="$HOME/.rbenv/shims:$PATH"

# PostgreSQLが起動しているか確認
if ! pgrep -x "postgres" > /dev/null; then
    echo "PostgreSQLを起動しています..."
    brew services start postgresql@16 2>/dev/null || echo "PostgreSQL起動をスキップ"
fi

# Redisが起動しているか確認
if ! pgrep -x "redis-server" > /dev/null; then
    echo "Redisを起動しています..."
    brew services start redis 2>/dev/null || echo "Redis起動をスキップ"
fi

# データベース作成
echo "データベースを作成しています..."
createdb dentalsystem_development 2>/dev/null || echo "データベースは既に存在します"

# 環境変数設定
export DATABASE_URL="postgres://localhost/dentalsystem_development"
export REDIS_URL="redis://localhost:6379/0"
export RAILS_ENV="development"
export SECRET_KEY_BASE="demo-secret-key-base-for-local-development-only"
export RAILS_MASTER_KEY="demo-master-key"

# マイグレーション実行
echo "データベースマイグレーションを実行しています..."
bundle exec rails db:migrate 2>/dev/null || echo "マイグレーションをスキップ"

# アセットコンパイル
echo "アセットをコンパイルしています..."
bundle exec rails assets:precompile 2>/dev/null || echo "アセットコンパイルをスキップ"

# デモデータ作成
echo "デモデータを作成しています..."
bundle exec rails db:seed 2>/dev/null || echo "シードデータをスキップ"

echo ""
echo "=== セットアップ完了 ==="
echo ""
echo "サーバー起動コマンド:"
echo "  ./start_server.sh"
echo ""
echo "アクセスURL:"
echo "  http://localhost:3001"
echo ""
echo "管理者ログイン:"
echo "  メール: admin@example.com"
echo "  パスワード: password123"
echo ""