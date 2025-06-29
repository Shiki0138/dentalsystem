#!/bin/bash
# 環境設定修正スクリプト

echo "=== 歯科クリニックシステム環境修正 ==="

# 1. Ruby環境確認・修正
echo "1. Ruby環境チェック..."
CURRENT_RUBY=$(ruby -v | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
REQUIRED_RUBY="3.3.8"

echo "現在のRuby: $CURRENT_RUBY"
echo "要求Ruby: $REQUIRED_RUBY"

if [ "$CURRENT_RUBY" != "$REQUIRED_RUBY" ]; then
    echo "⚠️  Ruby バージョンミスマッチ検出"
    echo "解決策: rbenvまたはrvmを使用してRuby $REQUIRED_RUBY をインストールしてください"
    echo "コマンド例:"
    echo "  rbenv install $REQUIRED_RUBY"
    echo "  rbenv global $REQUIRED_RUBY"
fi

# 2. データベース接続確認
echo -e "\n2. データベース接続チェック..."
if psql -U postgres -h localhost -p 5432 -d dental_system_development -c "SELECT 1;" >/dev/null 2>&1; then
    echo "✅ PostgreSQL接続正常"
else
    echo "⚠️  PostgreSQL接続失敗"
    echo "解決策:"
    echo "  1. データベース作成: createdb dental_system_development"
    echo "  2. 権限設定確認"
    echo "  3. 環境変数設定確認"
fi

# 3. Redis接続確認
echo -e "\n3. Redis接続チェック..."
if redis-cli ping >/dev/null 2>&1; then
    echo "✅ Redis接続正常"
else
    echo "⚠️  Redis接続失敗"
    echo "Redis起動: brew services start redis"
fi

# 4. 環境変数ファイル確認
echo -e "\n4. 環境変数チェック..."
ENV_FILE=".env_dentalsystem"
if [ -f "$ENV_FILE" ]; then
    echo "✅ 環境変数ファイル存在: $ENV_FILE"
    echo "設定内容:"
    cat "$ENV_FILE" | grep -v "PASSWORD\|SECRET" | head -10
else
    echo "⚠️  環境変数ファイル未存在: $ENV_FILE"
    echo "作成中..."
    cat > "$ENV_FILE" << EOF
PROJECT_NAME=dentalsystem
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=postgres
REDIS_URL=redis://localhost:6379/0
RAILS_ENV=development
IMAP_HOST=imap.gmail.com
IMAP_PORT=993
IMAP_USE_SSL=true
EOF
    echo "✅ 基本環境変数ファイル作成完了"
fi

# 5. 必要ディレクトリ作成
echo -e "\n5. ディレクトリ構造チェック..."
REQUIRED_DIRS=(
    "log"
    "tmp/pids"
    "tmp/cache"
    "storage"
    "monitoring/logs"
    "monitoring/alerts"
    "monitoring/metrics"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo "✅ ディレクトリ作成: $dir"
    fi
done

# 6. 権限設定
echo -e "\n6. 権限設定チェック..."
chmod +x scripts/*.sh 2>/dev/null
chmod +x *.sh 2>/dev/null
echo "✅ スクリプト権限設定完了"

# 7. ログファイル初期化
echo -e "\n7. ログファイル初期化..."
touch log/development.log
touch log/production.log
touch monitoring/logs/system.log
echo "✅ ログファイル初期化完了"

echo -e "\n=== 環境修正完了 ==="
echo "次の手順:"
echo "1. Ruby $REQUIRED_RUBY のインストール（必要な場合）"
echo "2. bundle install"
echo "3. rails db:create db:migrate"
echo "4. ./start.sh dentalsystem でシステム再起動"