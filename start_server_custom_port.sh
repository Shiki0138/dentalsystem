#!/bin/bash

# 歯科クリニック予約・業務管理システム - カスタムポート起動スクリプト
# 使用方法: ./start_server_custom_port.sh [ポート番号]
# デフォルト: 3001

# ポート番号の設定（引数がない場合は3001）
PORT=${1:-3001}

# ポート番号の妥当性チェック
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1024 ] || [ "$PORT" -gt 65535 ]; then
    echo "❌ エラー: ポート番号は1024-65535の範囲で指定してください"
    exit 1
fi

# ポートが使用中かチェック
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null ; then
    echo "⚠️  警告: ポート $PORT は既に使用中です"
    echo "別のポート番号を指定するか、使用中のプロセスを停止してください"
    exit 1
fi

echo "🚀 歯科クリニック予約・業務管理システムを起動します"
echo "📍 ポート: $PORT"
echo "🌐 URL: http://localhost:$PORT"
echo ""

# 環境変数の設定
export RAILS_ENV=development
export PORT=$PORT

# Docker Composeを使用する場合
if [ -f "docker-compose.yml" ]; then
    echo "🐳 Docker環境で起動します..."
    
    # docker-compose.ymlのポート設定を一時的に変更
    if command -v yq &> /dev/null; then
        yq eval ".services.web.ports[0] = \"$PORT:3000\"" -i docker-compose.yml
    else
        echo "⚠️  yqがインストールされていません。docker-compose.ymlを手動で編集してください"
    fi
    
    # Docker Compose起動
    docker-compose up -d
    
    echo ""
    echo "✅ Docker環境が起動しました"
    echo "📊 ログ確認: docker-compose logs -f web"
    echo "🛑 停止: docker-compose down"
    
# 通常のRails起動
else
    echo "💎 Rails開発サーバーを起動します..."
    
    # Railsサーバー起動
    bundle exec rails server -p $PORT -b 0.0.0.0
fi

echo ""
echo "🎉 システムが起動しました！"
echo "🌐 ブラウザで http://localhost:$PORT にアクセスしてください"
echo ""
echo "📝 デフォルト管理者アカウント:"
echo "   メール: admin@dental.example.com"
echo "   パスワード: (環境変数で設定)"