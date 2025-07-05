#!/bin/bash
# 統合歯科医院管理システム起動スクリプト

echo "🦷 歯科医院統合管理システム起動中..."
echo "=" * 50

# サーバーのPIDファイルをチェック
if [ -f "server.pid" ]; then
  echo "既存のサーバーが見つかりました。停止中..."
  kill $(cat server.pid) 2>/dev/null
  rm server.pid
fi

echo "統合サーバーを起動中..."
echo "🌐 http://localhost:3000 でアクセスしてください"
echo "📊 機能: 新UI + 完全CRUD + カレンダー + メッセージ管理"
echo ""
echo "停止するには Ctrl+C を押してください"
echo "=" * 50

# サーバー起動
ruby integrated_dental_server.rb