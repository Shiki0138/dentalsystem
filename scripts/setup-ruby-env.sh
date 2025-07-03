#!/bin/bash

# Ruby環境セットアップスクリプト
set -e

echo "🔧 Ruby 3.2.0環境をセットアップします..."

# rbenvがインストールされているか確認
if ! command -v rbenv &> /dev/null; then
    echo "⚠️ rbenvがインストールされていません"
    echo "以下のコマンドでインストールしてください:"
    echo "brew install rbenv ruby-build"
    exit 1
fi

# Ruby 3.2.0をインストール
echo "📦 Ruby 3.2.0をインストール中..."
rbenv install 3.2.0 -s

# ローカルのRubyバージョンを設定
echo "⚙️ プロジェクトのRubyバージョンを3.2.0に設定..."
rbenv local 3.2.0

# rbenvを再読み込み
eval "$(rbenv init -)"

# 確認
echo "✅ Ruby環境の確認:"
ruby --version

echo "✨ Ruby環境のセットアップが完了しました！"